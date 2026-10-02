#import <CoreFoundation/CoreFoundation.h>

extern NSString *const VCNAuthSessionChangedNotification;
extern NSString *const VCNCameraConfigChangedNotification;
extern NSString *const VCNCameraStatusChangedNotification;
extern NSString *const VCNCapabilityChangedNotification;
extern NSString *const VCNFloatingControlChangedNotification;
extern NSString *const VCNOverlayToggleNotification;
extern NSString *const VCNServerStatusChangedNotification;
extern NSString *const VCNStateChangedNotification;
extern NSString *const VCNStreamStartNotification;
extern NSString *const VCNStreamStopNotification;

extern NSString *const VCNAccountErrorDomain;
extern NSString *const VCNSecurityErrorDomain;

void VCNPostDarwinNotification(NSString *name);
void VCNObserveDarwinNotification(NSString *name, CFNotificationCallback callback, const void *observer);
void VCNRemoveDarwinObserver(const void *observer);
