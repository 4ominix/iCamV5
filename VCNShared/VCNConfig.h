#import <Foundation/Foundation.h>

@interface VCNConfig : NSObject

+ (NSDictionary *)readPlist:(NSString *)path;
+ (BOOL)writePlist:(NSDictionary *)dict toPath:(NSString *)path;
+ (void)ensureDirectoryExists:(NSString *)path;
+ (void)setFileProtection:(NSString *)path;

+ (NSDictionary *)cameraConfiguration;
+ (void)setCameraConfiguration:(NSDictionary *)config;
+ (NSDictionary *)cameraConfig;
+ (void)setCameraConfig:(NSDictionary *)config;

+ (NSDictionary *)cameraStatus;
+ (void)setCameraStatus:(NSDictionary *)status;

+ (NSDictionary *)capabilityLease;
+ (void)setCapabilityLease:(NSDictionary *)lease;

+ (NSDictionary *)authSession;
+ (void)setAuthSession:(NSDictionary *)session;

+ (NSDictionary *)serverStatus;
+ (void)setServerStatus:(NSDictionary *)status;

+ (NSString *)deviceModel;
+ (NSString *)deviceIdentifier;
+ (BOOL)isA13Device;

@end
