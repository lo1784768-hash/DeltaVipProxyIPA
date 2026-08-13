#import "AppDelegate.h"
#import "DeviceStorageViewController.h"
#import "DebugLogger.h"

@interface AppDelegate ()
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Initialize debug logger
    DebugLogger *logger = [DebugLogger sharedLogger];
    [logger log:@"🚀 IMGUIDELTA App Launched"];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    DeviceStorageViewController *rootVC = [[DeviceStorageViewController alloc] init];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:rootVC];

    self.window.rootViewController = navController;
    [self.window makeKeyAndVisible];

    [logger log:@"✅ App UI initialized"];

    return YES;
}

@end
