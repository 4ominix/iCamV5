// CONFIRMED FROM BINARY: All Darwin notification name strings
// CONFIRMED FROM BINARY: CFNotificationCenterGetDarwinNotifyCenter usage
// CONFIRMED: CFNotificationSuspensionBehaviorDeliverImmediately delivery mode

#import "VCNNotifications.h"
#import <Foundation/Foundation.h>

NSString *const VCNAuthSessionChangedNotification     = @"com.vcnext.auth.changed";
NSString *const VCNCameraConfigChangedNotification   = @"com.vcnext.camera.config.changed";
NSString *const VCNCameraStatusChangedNotification   = @"com.vcnext.camera.status";
NSString *const VCNCapabilityChangedNotification     = @"com.vcnext.capability.changed";
NSString *const VCNFloatingControlChangedNotification = @"com.vcnext.overlay.control";
NSString *const VCNOverlayToggleNotification         = @"com.vcnext.overlay.toggle";
NSString *const VCNServerStatusChangedNotification   = @"com.vcnext.server.status";
NSString *const VCNStateChangedNotification          = @"com.vcnext.state.changed";
NSString *const VCNStreamStartNotification           = @"com.vcnext.stream.start";
NSString *const VCNStreamStopNotification            = @"com.vcnext.stream.stop";

NSString *const VCNAccountErrorDomain  = @"VCNAccountErrorDomain";
NSString *const VCNSecurityErrorDomain = @"VCNSecurityErrorDomain";

void VCNPostDarwinNotification(NSString *name) {
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge CFStringRef)name, NULL, NULL, true
    );
}

void VCNObserveDarwinNotification(NSString *name, CFNotificationCallback callback, const void *observer) {
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        observer,
        callback,
        (__bridge CFStringRef)name,
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately
    );
}

void VCNRemoveDarwinObserver(const void *observer) {
    CFNotificationCenterRemoveObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        observer, NULL, NULL
    );
}
