// CONFIRMED: Hooks SpringBoard -applicationDidFinishLaunching: (filter plist)
// CONFIRMED: UIWindowLevelAlert, UIPanGestureRecognizer imports
// CONFIRMED: UIApplicationDidBecomeActiveNotification, UIDeviceOrientationDidChangeNotification
// CONFIRMED: NSUserDefaults "com.vcnext.overlay" suite name
// RECONSTRUCTED: Window creation timing, panel integration, notification wiring

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "VCNFloatingWindow.h"
#import "VCNControlPanel.h"
#import "VCNPaths.h"
#import "VCNNotifications.h"
#import "VCNConfig.h"

static VCNFloatingWindow *g_floatingWindow = nil;
static VCNControlPanel   *g_controlPanel   = nil;

static void onStateChanged(CFNotificationCenterRef center, void *observer,
                            CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *config = [VCNConfig cameraConfiguration];
        NSDictionary *status = [VCNConfig cameraStatus];
        NSDictionary *capability = [VCNConfig capabilityLease];
        [g_controlPanel updateWithConfig:config status:status capability:capability];
    });
}

static void onFloatingControlChanged(CFNotificationCenterRef center, void *observer,
                                      CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.vcnext.overlay"];
        BOOL visible = [defaults boolForKey:@"floatingVisible"];
        g_floatingWindow.hidden = !visible;
    });
}

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)app {
    %orig;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIWindowScene *scene = nil;
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]]) {
                scene = (UIWindowScene *)s;
                break;
            }
        }
        if (!scene) return;

        g_floatingWindow = [[VCNFloatingWindow alloc] initWithWindowScene:scene];
        g_controlPanel = [[VCNControlPanel alloc] init];
        [g_floatingWindow installOverlayInView:g_controlPanel];

        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.vcnext.overlay"];
        [defaults registerDefaults:@{@"floatingVisible": @YES, @"floatingX": @(50), @"floatingY": @(100)}];
        g_floatingWindow.hidden = ![defaults boolForKey:@"floatingVisible"];

        VCNObserveDarwinNotification(VCNStateChangedNotification, onStateChanged, NULL);
        VCNObserveDarwinNotification(VCNCameraStatusChangedNotification, onStateChanged, NULL);
        VCNObserveDarwinNotification(VCNCapabilityChangedNotification, onStateChanged, NULL);
        VCNObserveDarwinNotification(VCNFloatingControlChangedNotification, onFloatingControlChanged, NULL);
        VCNObserveDarwinNotification(VCNServerStatusChangedNotification, onStateChanged, NULL);

        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                          object:nil queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *n) { onStateChanged(NULL, NULL, NULL, NULL, NULL); }];
        [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceOrientationDidChangeNotification
                                                          object:nil queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *n) { [g_floatingWindow adjustForOrientation]; }];
        [UIDevice.currentDevice beginGeneratingDeviceOrientationNotifications];

        onStateChanged(NULL, NULL, NULL, NULL, NULL);
    });
}

%end

%ctor {
    @autoreleasepool {
        NSString *prog = [NSProcessInfo processInfo].processName;
        if ([prog isEqualToString:@"SpringBoard"]) {
            %init;
        }
    }
}
