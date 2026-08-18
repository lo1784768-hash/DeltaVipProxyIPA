#import "AppDelegate.h"
#import "AppDataViewController.h"
#import "DebugLogger.h"
#import "ImageDownloader.h"
#import "SecurityGuard.h"
#import "SandboxEscapeManager.h"
#import "KeyManager.h"

@interface AppDelegate ()
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    // Bảo vệ lần 1 (main.m constructor đã gọi ptrace — đây là lần 2)
    [SecurityGuard activate];

    DebugLogger *logger = [DebugLogger sharedLogger];
    [logger log:@"🚀 DELTA PROXY App Launched"];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    AppDataViewController *rootVC = [[AppDataViewController alloc] init];
    UINavigationController *nav   = [[UINavigationController alloc] initWithRootViewController:rootVC];
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    [logger log:@"✅ App UI initialized"];

    // Kernel exploit + sandbox escape
    [logger log:@"⚙️  Bắt đầu sandbox escape..."];
    [SandboxEscapeManager runEscapeWithCompletion:^(BOOL success) {
        if (success) {
            [logger log:@"✅ Sandbox escape thành công — reload apps"];
            UINavigationController *n = (UINavigationController *)self.window.rootViewController;
            AppDataViewController *advc = (AppDataViewController *)n.viewControllers.firstObject;
            [advc refreshApps];
        } else {
            [logger log:@"⚠️  Sandbox escape thất bại — iOS này có thể chưa hỗ trợ exploit"];
        }
    }];

    [[ImageDownloader sharedDownloader] downloadImagesWithCompletion:nil];

    // Kiểm tra bảo mật lần 2 sau khi app load xong (bẫy inject chậm)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)),
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (![SecurityGuard isEnvironmentTrusted]) { [SecurityGuard bailOut]; }
    });

    return YES;
}

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - URL Scheme: deltaproxy://udid?value=<UDID>
// Gọi sau khi user cài profile trên Safari → server redirect về app với UDID
// ─────────────────────────────────────────────────────────────────────────────

- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {

    // Scheme: deltaproxy
    if (![[url scheme] isEqualToString:@"deltaproxy"]) return NO;

    // Host: udid
    if ([[url host] isEqualToString:@"udid"]) {
        NSURLComponents *comps = [NSURLComponents componentsWithURL:url
                                               resolvingAgainstBaseURL:NO];
        NSString *udid = nil;
        for (NSURLQueryItem *item in comps.queryItems) {
            if ([item.name isEqualToString:@"value"]) {
                udid = item.value;
                break;
            }
        }
        if (udid.length > 0) {
            [[KeyManager shared] saveHardwareUDIDFromProfile:udid];
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *alert = [UIAlertController
                    alertControllerWithTitle:@"✅ Đã Đăng Ký Thiết Bị"
                    message:[NSString stringWithFormat:
                             @"UDID phần cứng đã được lưu.\nKey của bạn sẽ được bind chặt hơn vào thiết bị này.\n\nUDID: %@",
                             udid]
                    preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                    style:UIAlertActionStyleDefault handler:nil]];
                UIViewController *top = self.window.rootViewController;
                while (top.presentedViewController) top = top.presentedViewController;
                [top presentViewController:alert animated:YES completion:nil];
            });
        }
        return YES;
    }

    return NO;
}

@end
