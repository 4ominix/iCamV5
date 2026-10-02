#import "VCNAccountManager.h"
#import "VCNConfig.h"
#import "VCNSecurity.h"
#import "VCNNotifications.h"
#import "VCNPaths.h"

#define API_BASE @"https://vcnext.corev.bond"

@interface VCNAccountManager ()
@property (nonatomic, strong) NSString *username;
@property (nonatomic, assign) BOOL isLoggedIn;
@end

@implementation VCNAccountManager

+ (instancetype)shared {
    static VCNAccountManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self refreshAuthSession];
    }
    return self;
}

- (void)refreshAuthSession {
    NSDictionary *session = [VCNConfig authSession];
    self.username = session[@"username"];
    self.isLoggedIn = (session[@"token"] != nil && [session[@"token"] length] > 0);
}

- (void)loginWithUsername:(NSString *)username password:(NSString *)password completion:(void (^)(BOOL, NSString *))completion {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/api/v2/auth/login", API_BASE]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"VCNextPlus/0.16" forHTTPHeaderField:@"User-Agent"];

    NSString *deviceId = [VCNConfig deviceIdentifier];
    NSString *deviceModel = [VCNConfig deviceModel];

    NSDictionary *body = @{
        @"username": username,
        @"password": [VCNSecurity sha256HexString:password],
        @"deviceId": deviceId ?: @"",
        @"model": deviceModel ?: @"",
    };

    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            if (completion) completion(NO, error.localizedDescription);
            return;
        }

        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (!json) {
            if (completion) completion(NO, @"Invalid response");
            return;
        }

        if ([json[@"status"] isEqualToString:@"ok"] && json[@"token"]) {
            NSDictionary *authData = @{
                @"username": username,
                @"token": json[@"token"],
                @"expiresAt": json[@"expiresAt"] ?: @(0),
                @"loginTime": @([[NSDate date] timeIntervalSince1970]),
            };

            [VCNConfig setAuthSession:authData];
            VCNPostDarwinNotification(VCNAuthSessionChangedNotification);

            self.username = username;
            self.isLoggedIn = YES;

            if (completion) completion(YES, nil);
        } else {
            NSString *msg = json[@"message"] ?: @"Login failed";
            if (completion) completion(NO, msg);
        }
    }] resume];
}

- (void)logout {
    [VCNConfig setAuthSession:@{}];
    [VCNConfig setCapabilityLease:@{}];
    self.username = nil;
    self.isLoggedIn = NO;
    VCNPostDarwinNotification(VCNAuthSessionChangedNotification);
    VCNPostDarwinNotification(VCNCapabilityChangedNotification);
}

@end
