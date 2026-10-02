// CONFIRMED FROM BINARY: "/api/v2/heartbeat" endpoint string
// CONFIRMED FROM BINARY: "/api/v2/auth/verify" endpoint string
// CONFIRMED FROM BINARY: "/api/v2/capability/lease" endpoint string
// CONFIRMED FROM BINARY: "Bearer" authorization header format
// CONFIRMED FROM BINARY: kSecKeyAlgorithmECDSASignatureMessageX962SHA256
// CONFIRMED FROM BINARY: NSTimer patterns (~300s interval)
// RECONSTRUCTED: ECDSA-signed payload format (deviceId:model:timestamp)
// RECONSTRUCTED: Lease refresh interval (3600s from timer patterns)

#import "VCNAuthHeartbeat.h"
#import "VCNConfig.h"
#import "VCNSecurity.h"
#import "VCNNotifications.h"
#import "VCNPaths.h"
#import <sys/utsname.h>

#define HEARTBEAT_INTERVAL 300.0
#define LEASE_REFRESH_INTERVAL 3600.0

@interface VCNAuthHeartbeat ()
@property (nonatomic, strong) NSTimer *heartbeatTimer;
@property (nonatomic, strong) NSTimer *leaseTimer;
@property (nonatomic, assign) BOOL authenticated;
@end

@implementation VCNAuthHeartbeat

- (instancetype)initWithHTTPClient:(VCNHTTPClient *)client {
    self = [super init];
    if (self) {
        _httpClient = client;
        _heartbeatInterval = HEARTBEAT_INTERVAL;
        _authenticated = NO;
    }
    return self;
}

- (void)startHeartbeat {
    [self stopHeartbeat];

    self.heartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:self.heartbeatInterval
                                                          target:self
                                                        selector:@selector(performHeartbeat)
                                                        userInfo:nil
                                                         repeats:YES];

    self.leaseTimer = [NSTimer scheduledTimerWithTimeInterval:LEASE_REFRESH_INTERVAL
                                                      target:self
                                                    selector:@selector(refreshCapabilityLease)
                                                    userInfo:nil
                                                     repeats:YES];

    [self performHeartbeat];
}

- (void)stopHeartbeat {
    [self.heartbeatTimer invalidate];
    self.heartbeatTimer = nil;
    [self.leaseTimer invalidate];
    self.leaseTimer = nil;
}

- (void)performHeartbeat {
    NSDictionary *authSession = [VCNConfig authSession];
    if (!authSession || !authSession[@"token"]) {
        self.authenticated = NO;
        return;
    }

    [self.httpClient setAuthorizationHeader:authSession[@"token"]];

    // Build heartbeat payload with ECDSA signature
    NSString *deviceId = [VCNConfig deviceIdentifier];
    NSString *deviceModel = [VCNConfig deviceModel];
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];

    NSString *signPayload = [NSString stringWithFormat:@"%@:%@:%.0f", deviceId, deviceModel, timestamp];
    NSData *signData = [signPayload dataUsingEncoding:NSUTF8StringEncoding];

    SecKeyRef privateKey = [VCNSecurity loadKeyFromKeychain:@"com.vcnext.device.ec.private"];
    NSData *signature = nil;
    if (privateKey) {
        signature = [VCNSecurity ecdsaSignData:signData withPrivateKey:privateKey];
        CFRelease(privateKey);
    }

    NSDictionary *body = @{
        @"deviceId": deviceId ?: @"",
        @"model": deviceModel ?: @"",
        @"timestamp": @(timestamp),
        @"signature": signature ? [signature base64EncodedStringWithOptions:0] : @"",
        @"version": @"0.16.73",
    };

    [self.httpClient POST:@"/api/v2/heartbeat" body:body completion:^(NSDictionary *response, NSError *error) {
        if (error) {
            printf("VCNNetworkDaemon: heartbeat failed: %s\n", error.localizedDescription.UTF8String);
            return;
        }

        if ([response[@"status"] isEqualToString:@"ok"]) {
            self.authenticated = YES;

            if (response[@"capability"]) {
                [VCNConfig setCapabilityLease:response[@"capability"]];
                VCNPostDarwinNotification(VCNCapabilityChangedNotification);
            }
        } else if ([response[@"status"] isEqualToString:@"unauthorized"]) {
            self.authenticated = NO;
            [VCNConfig setAuthSession:@{}];
            VCNPostDarwinNotification(VCNAuthSessionChangedNotification);
        }
    }];
}

- (void)authenticateWithCompletion:(void (^)(BOOL, NSError *))completion {
    NSDictionary *authSession = [VCNConfig authSession];
    if (!authSession[@"username"] || !authSession[@"token"]) {
        if (completion) completion(NO, nil);
        return;
    }

    [self.httpClient setAuthorizationHeader:authSession[@"token"]];
    [self.httpClient GET:@"/api/v2/auth/verify" parameters:nil completion:^(NSDictionary *response, NSError *error) {
        if (error) {
            if (completion) completion(NO, error);
            return;
        }

        BOOL valid = [response[@"valid"] boolValue];
        self.authenticated = valid;

        if (valid && response[@"capability"]) {
            [VCNConfig setCapabilityLease:response[@"capability"]];
            VCNPostDarwinNotification(VCNCapabilityChangedNotification);
        }

        if (completion) completion(valid, nil);
    }];
}

- (void)refreshCapabilityLease {
    if (!self.authenticated) return;

    NSDictionary *authSession = [VCNConfig authSession];
    if (!authSession[@"token"]) return;

    [self.httpClient setAuthorizationHeader:authSession[@"token"]];
    [self.httpClient GET:@"/api/v2/capability/lease" parameters:nil completion:^(NSDictionary *response, NSError *error) {
        if (error) return;

        if (response[@"lease"]) {
            [VCNConfig setCapabilityLease:response[@"lease"]];
            VCNPostDarwinNotification(VCNCapabilityChangedNotification);
        }
    }];
}

- (void)handleAuthNotification {
    NSDictionary *authSession = [VCNConfig authSession];
    if (authSession[@"token"]) {
        [self authenticateWithCompletion:nil];
    } else {
        self.authenticated = NO;
    }
}

@end
