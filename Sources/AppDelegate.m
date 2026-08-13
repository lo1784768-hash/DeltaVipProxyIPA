#import "AppDelegate.h"
#import "AppDataViewController.h"
#import "DebugLogger.h"

@interface AppDelegate ()
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Initialize debug logger
    DebugLogger *logger = [DebugLogger sharedLogger];
    [logger log:@"🚀 IMGUIDELTA App Launched"];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    // Launch new HUD-style App Data view
    AppDataViewController *rootVC = [[AppDataViewController alloc] init];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:rootVC];

    self.window.rootViewController = navController;
    [self.window makeKeyAndVisible];

    [logger log:@"✅ App UI initialized"];

    return YES;
}

@end
