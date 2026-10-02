#import <Foundation/Foundation.h>

#define VCN_ROOT_PREFIX @"/var/jb"
#define VCN_SHARED_DIR  VCN_ROOT_PREFIX @"/var/mobile/Library/VCNext"

extern NSString *const VCNAuthSessionPath;
extern NSString *const VCNCameraConfigurationPath;
extern NSString *const VCNCameraStatusPath;
extern NSString *const VCNCapabilityLeasePath;
extern NSString *const VCNServerStatusPath;
extern NSString *const VCNMediaDirectory;
extern NSString *const VCNLegacyMediaDirectory;
extern NSString *const VCNStreamDirectory;
extern NSString *const VCNIncomingStreamPath;
extern NSString *const VCNLatestStreamPath;
extern NSString *const VCNLiveStreamPath;

static inline NSString *VCNNetworkPolicyPath(void) {
    return [VCN_SHARED_DIR stringByAppendingPathComponent:@"NetworkPolicy.plist"];
}

static inline NSString *VCNA13CanaryPath(void) {
    return [VCN_SHARED_DIR stringByAppendingPathComponent:@"A13CameraCanary"];
}

static inline NSString *VCNInjectedMarkerPath(void) {
    return [VCN_SHARED_DIR stringByAppendingPathComponent:@"Injected"];
}
