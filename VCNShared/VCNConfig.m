// CONFIRMED FROM BINARY: Plist read/write pattern for all config files
// CONFIRMED FROM BINARY: iPhone12,* A13 device detection pattern
// CONFIRMED FROM BINARY: chmod 0600, chown 501:501 file protection
// RECONSTRUCTED: Config accessor methods, notification posting on write

#import "VCNConfig.h"
#import "VCNPaths.h"
#import "VCNNotifications.h"
#import <sys/utsname.h>

@implementation VCNConfig

+ (NSDictionary *)readPlist:(NSString *)path {
    return [NSDictionary dictionaryWithContentsOfFile:path];
}

+ (BOOL)writePlist:(NSDictionary *)dict toPath:(NSString *)path {
    [self ensureDirectoryExists:[path stringByDeletingLastPathComponent]];
    BOOL ok = [dict writeToFile:path atomically:YES];
    if (ok) [self setFileProtection:path];
    return ok;
}

+ (void)ensureDirectoryExists:(NSString *)path {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) {
        [fm createDirectoryAtPath:path
     withIntermediateDirectories:YES
                      attributes:@{NSFileProtectionKey: NSFileProtectionCompleteUntilFirstUserAuthentication}
                           error:nil];
    }
}

+ (void)setFileProtection:(NSString *)path {
    [[NSFileManager defaultManager] setAttributes:@{
        NSFileProtectionKey: NSFileProtectionCompleteUntilFirstUserAuthentication
    } ofItemAtPath:path error:nil];
    chmod(path.UTF8String, 0600);
    chown(path.UTF8String, 501, 501);
}

+ (NSDictionary *)cameraConfiguration {
    return [self readPlist:VCNCameraConfigurationPath];
}

+ (void)setCameraConfiguration:(NSDictionary *)config {
    [self writePlist:config toPath:VCNCameraConfigurationPath];
    VCNPostDarwinNotification(VCNStateChangedNotification);
}

+ (NSDictionary *)cameraStatus {
    return [self readPlist:VCNCameraStatusPath];
}

+ (void)setCameraStatus:(NSDictionary *)status {
    [self writePlist:status toPath:VCNCameraStatusPath];
    VCNPostDarwinNotification(VCNCameraStatusChangedNotification);
}

+ (NSDictionary *)capabilityLease {
    return [self readPlist:VCNCapabilityLeasePath];
}

+ (void)setCapabilityLease:(NSDictionary *)lease {
    [self writePlist:lease toPath:VCNCapabilityLeasePath];
    VCNPostDarwinNotification(VCNCapabilityChangedNotification);
}

+ (NSDictionary *)authSession {
    return [self readPlist:VCNAuthSessionPath];
}

+ (void)setAuthSession:(NSDictionary *)session {
    [self writePlist:session toPath:VCNAuthSessionPath];
    VCNPostDarwinNotification(VCNAuthSessionChangedNotification);
}

+ (NSDictionary *)serverStatus {
    return [self readPlist:VCNServerStatusPath];
}

+ (void)setServerStatus:(NSDictionary *)status {
    [self writePlist:status toPath:VCNServerStatusPath];
    VCNPostDarwinNotification(VCNServerStatusChangedNotification);
}

+ (NSDictionary *)cameraConfig {
    return [self cameraConfiguration];
}

+ (void)setCameraConfig:(NSDictionary *)config {
    [self setCameraConfiguration:config];
}

+ (NSString *)deviceModel {
    struct utsname info;
    uname(&info);
    return [NSString stringWithUTF8String:info.machine];
}

+ (NSString *)deviceIdentifier {
    NSString *key = @"com.vcnext.device.uuid";
    NSString *uuid = [[NSUserDefaults standardUserDefaults] stringForKey:key];
    if (!uuid) {
        uuid = [[NSUUID UUID] UUIDString];
        [[NSUserDefaults standardUserDefaults] setObject:uuid forKey:key];
    }
    return uuid;
}

+ (BOOL)isA13Device {
    return [[self deviceModel] hasPrefix:@"iPhone12,"];
}

@end
