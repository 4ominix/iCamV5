// CONFIRMED FROM BINARY: SecKeyCreateRandomKey, kSecAttrKeyTypeECSECPrimeRandom
// CONFIRMED FROM BINARY: "com.vcnext.device.ec.private" keychain tag
// CONFIRMED FROM BINARY: CTServerConnectionCreate dlsym
// CONFIRMED FROM BINARY: "com.vcnext.app" bundle ID for cellular policy
// CONFIRMED: LaunchDaemon com.vcnext.networkd, UserName=root
// RECONSTRUCTED: Startup sequence (keygen → cellular → HTTP → auth → heartbeat → runloop)

#import <Foundation/Foundation.h>
#import <signal.h>
#import "VCNAuthHeartbeat.h"
#import "VCNHTTPClient.h"
#import "VCNCellularPolicy.h"
#import "VCNConfig.h"
#import "VCNSecurity.h"
#import "VCNNotifications.h"
#import "VCNPaths.h"

#define API_BASE_URL @"https://vcnext.corev.bond"

static VCNAuthHeartbeat *g_heartbeat = nil;

static void signalHandler(int sig) {
    [g_heartbeat stopHeartbeat];
    exit(0);
}

static void onAuthChanged(CFNotificationCenterRef center, void *observer,
                           CFNotificationName name, const void *object,
                           CFDictionaryRef userInfo) {
    [g_heartbeat handleAuthNotification];
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        signal(SIGTERM, signalHandler);
        signal(SIGINT, signalHandler);
        signal(SIGPIPE, SIG_IGN);

        printf("VCNNetworkDaemon: starting\n");

        [VCNConfig ensureDirectoryExists:VCN_SHARED_DIR];

        // Generate device EC key pair if not present
        SecKeyRef existingKey = [VCNSecurity loadKeyFromKeychain:@"com.vcnext.device.ec.private"];
        if (!existingKey) {
            printf("VCNNetworkDaemon: generating device key pair\n");
            SecKeyRef pubKey = NULL, privKey = NULL;
            if ([VCNSecurity generateECKeyPairPublicKey:&pubKey privateKey:&privKey]) {
                [VCNSecurity saveKeyToKeychain:privKey withTag:@"com.vcnext.device.ec.private"];
                [VCNSecurity saveKeyToKeychain:pubKey withTag:@"com.vcnext.device.ec.public"];
                if (pubKey) CFRelease(pubKey);
                if (privKey) CFRelease(privKey);
            }
        } else {
            CFRelease(existingKey);
        }

        // Allow cellular data for our processes
        [VCNCellularPolicy allowCellularDataForBundleId:@"com.vcnext.app"];

        VCNHTTPClient *httpClient = [[VCNHTTPClient alloc] initWithBaseURL:API_BASE_URL];
        g_heartbeat = [[VCNAuthHeartbeat alloc] initWithHTTPClient:httpClient];

        // Register for auth change notifications
        VCNObserveDarwinNotification(VCNAuthSessionChangedNotification, onAuthChanged, NULL);

        // Authenticate on startup
        [g_heartbeat authenticateWithCompletion:^(BOOL success, NSError *error) {
            if (success) {
                printf("VCNNetworkDaemon: authenticated successfully\n");
            } else {
                printf("VCNNetworkDaemon: authentication failed, will retry on heartbeat\n");
            }
        }];

        [g_heartbeat startHeartbeat];

        printf("VCNNetworkDaemon: entering run loop\n");
        [[NSRunLoop currentRunLoop] run];

        return 0;
    }
}
