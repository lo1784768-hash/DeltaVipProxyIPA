#import "AppDelegate.h"
#import "AppDataViewController.h"
#import "DebugLogger.h"
#import "ImageDownloader.h"
#import "SecurityGuard.h"
#import "SandboxEscapeManager.h"

@interface AppDelegate ()
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Bảo vệ: chống debug / Frida / tiêm dylib (gọi sớm nhất)
    [SecurityGuard activate];

    // Initialize debug logger
    DebugLogger *logger = [DebugLogger sharedLogger];
    [logger log:@"🚀 DELTA PROXY App Launched"];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    // Launch HUD-style App Data view
    AppDataViewController *rootVC = [[AppDataViewController alloc] init];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:rootVC];

    self.window.rootViewController = navController;
    [self.window makeKeyAndVisible];

    [logger log:@"✅ App UI initialized"];

    // Chạy kernel exploit + sandbox escape ngay sau khi UI hiện
    // Sau khi escape: AppDataViewController có thể reload apps với container paths đúng
    [logger log:@"⚙️  Bắt đầu sandbox escape..."];
    [SandboxEscapeManager runEscapeWithCompletion:^(BOOL success) {
        if (success) {
            [logger log:@"✅ Sandbox escape thành công — reload apps"];
            // Reload app list với quyền truy cập đầy đủ
            UINavigationController *nav = (UINavigationController *)self.window.rootViewController;
            AppDataViewController *advc = (AppDataViewController *)nav.viewControllers.firstObject;
            [advc refreshApps];  // reload với quyền filesystem đầy đủ
        } else {
            [logger log:@"⚠️  Sandbox escape thất bại — iOS này có thể chưa hỗ trợ exploit"];
        }
    }];

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
