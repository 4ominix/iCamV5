#import "VCNCellularPolicy.h"
#import <dlfcn.h>

// CoreTelephony private API for cellular data policy
// CTServerConnectionCreate, CTServerConnectionSetCellularUsagePolicy
// These are private SPI used by the original binary for network policy control

typedef void *CTServerConnectionRef;
typedef void (*CTServerConnectionCallBack)(CTServerConnectionRef connection, CFStringRef notification, CFDictionaryRef info, void *context);

static CTServerConnectionRef (*CTServerConnectionCreate)(CFAllocatorRef allocator, CTServerConnectionCallBack callback, void *context) = NULL;
static int (*CTServerConnectionSetCellularUsagePolicy)(CTServerConnectionRef connection, CFStringRef bundleId, CFDictionaryRef policy) = NULL;

static void loadCoreTelephonySPI(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *handle = dlopen("/System/Library/Frameworks/CoreTelephony.framework/CoreTelephony", RTLD_LAZY);
        if (!handle) return;
        CTServerConnectionCreate = dlsym(handle, "CTServerConnectionCreate");
        CTServerConnectionSetCellularUsagePolicy = dlsym(handle, "CTServerConnectionSetCellularUsagePolicy");
    });
}

static void serverConnectionCallback(CTServerConnectionRef connection, CFStringRef notification, CFDictionaryRef info, void *context) {
    // No-op callback required by CTServerConnectionCreate
}

@implementation VCNCellularPolicy

+ (void)allowCellularDataForBundleId:(NSString *)bundleId {
    loadCoreTelephonySPI();
    if (!CTServerConnectionCreate || !CTServerConnectionSetCellularUsagePolicy) return;

    CTServerConnectionRef conn = CTServerConnectionCreate(kCFAllocatorDefault, serverConnectionCallback, NULL);
    if (!conn) return;

    NSDictionary *policy = @{
        @"kCTCellularDataUsagePolicy": @"kCTCellularDataUsagePolicyAlwaysAllow",
    };

    CTServerConnectionSetCellularUsagePolicy(conn, (__bridge CFStringRef)bundleId,
                                              (__bridge CFDictionaryRef)policy);
    CFRelease(conn);
}

+ (void)denyCellularDataForBundleId:(NSString *)bundleId {
    loadCoreTelephonySPI();
    if (!CTServerConnectionCreate || !CTServerConnectionSetCellularUsagePolicy) return;

    CTServerConnectionRef conn = CTServerConnectionCreate(kCFAllocatorDefault, serverConnectionCallback, NULL);
    if (!conn) return;

    NSDictionary *policy = @{
        @"kCTCellularDataUsagePolicy": @"kCTCellularDataUsagePolicyDeny",
    };

    CTServerConnectionSetCellularUsagePolicy(conn, (__bridge CFStringRef)bundleId,
                                              (__bridge CFDictionaryRef)policy);
    CFRelease(conn);
}

+ (BOOL)isCellularDataAllowedForBundleId:(NSString *)bundleId {
    // The original binary doesn't actually read the policy back - it just sets it
    // Return YES as default
    return YES;
}

@end
