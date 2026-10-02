#import "VCNAppDelegate.h"
#import "VCNMainViewController.h"
#import "VCNNotifications.h"
#import "VCNConfig.h"
#import "VCNPaths.h"

@implementation VCNAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [VCNConfig ensureDirectoryExists:VCN_SHARED_DIR];
    [VCNConfig ensureDirectoryExists:VCNMediaDirectory];

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    VCNMainViewController *mainVC = [[VCNMainViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:mainVC];

    nav.navigationBar.prefersLargeTitles = YES;
    nav.navigationBar.barTintColor = [UIColor blackColor];
    nav.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor]};
    nav.navigationBar.largeTitleTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor]};

    if (@available(iOS 15.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        appearance.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
        appearance.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor]};
        appearance.largeTitleTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor]};
        nav.navigationBar.standardAppearance = appearance;
        nav.navigationBar.scrollEdgeAppearance = appearance;
    }

    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];

    return YES;
}

@end
