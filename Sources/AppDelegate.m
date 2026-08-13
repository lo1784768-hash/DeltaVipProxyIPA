#import "AppDelegate.h"
#import "AppDataViewController.h"
#import "DebugLogger.h"
#import "ImageDownloader.h"
#import "SecurityGuard.h"

@interface AppDelegate ()
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Bảo vệ: chống debug / Frida / tiêm dylib (gọi sớm nhất)
    [SecurityGuard activate];

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

    // Download app images in background
    [logger log:@"⬇️  Starting image downloads..."];
    [[ImageDownloader sharedDownloader] downloadImagesWithCompletion:^(BOOL success) {
        if (success) {
            [logger log:@"✅ App images downloaded successfully"];
        } else {
            [logger log:@"⚠️  Some images failed to download"];
        }
    }];

    return YES;
}

@end
