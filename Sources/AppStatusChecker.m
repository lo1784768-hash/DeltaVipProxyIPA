#import "AppStatusChecker.h"
#import "DebugLogger.h"

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (id)applicationProxyForIdentifier:(NSString *)identifier;
@end

@interface LSApplicationProxy : NSObject
@property (nonatomic, readonly) NSString *bundleIdentifier;
@property (nonatomic, readonly) NSString *localizedName;
@property (nonatomic, readonly) UIImage *icon;
@property (nonatomic, readonly) BOOL isRunning;
@end

@implementation AppStatusChecker

+ (instancetype)sharedChecker {
    static AppStatusChecker *checker = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        checker = [[AppStatusChecker alloc] init];
    });
    return checker;
}

- (BOOL)isAppRunning:(NSString *)bundleID {
    DebugLogger *logger = [DebugLogger sharedLogger];

    @try {
        // Method 1: Check UIApplication.sharedApplication._runningApplications
        Class UIAppClass = NSClassFromString(@"UIApplication");
        if (UIAppClass) {
            id sharedApp = nil;
            @try {
                SEL sharedAppSelector = NSSelectorFromString(@"sharedApplication");
                if ([UIAppClass respondsToSelector:sharedAppSelector]) {
                    sharedApp = [UIAppClass performSelector:sharedAppSelector];
                }
            } @catch (NSException *e) {
                [logger log:@"[AppStatus] ⚠️  Could not get UIApplication.sharedApplication"];
            }

            if (sharedApp) {
                SEL applicationsSelector = NSSelectorFromString(@"_runningApplications");
                if ([sharedApp respondsToSelector:applicationsSelector]) {
                    NSArray *runningApps = [sharedApp performSelector:applicationsSelector];
                    [logger log:@"[AppStatus] 📊 Found %lu running apps via UIApplication", (unsigned long)runningApps.count];

                    for (id app in runningApps) {
                        @try {
                            SEL bundleIDSelector = NSSelectorFromString(@"bundleIdentifier");
                            if ([app respondsToSelector:bundleIDSelector]) {
                                NSString *appBundleID = [app performSelector:bundleIDSelector];
                                if ([appBundleID isEqualToString:bundleID]) {
                                    [logger log:@"[AppStatus] 🟢 %@ is RUNNING", bundleID];
                                    return YES;
                                }
                            }
                        } @catch (NSException *e) {
                            // Continue
                        }
                    }
                }
            }
        }

        // Method 2: LSApplicationWorkspace.applicationProxyForIdentifier
        Class LSAppWorkspaceClass = NSClassFromString(@"LSApplicationWorkspace");
        if (LSAppWorkspaceClass) {
            @try {
                SEL defaultWorkspaceSelector = NSSelectorFromString(@"defaultWorkspace");
                id workspace = [LSAppWorkspaceClass performSelector:defaultWorkspaceSelector];
                if (workspace) {
                    SEL appProxySelector = NSSelectorFromString(@"applicationProxyForIdentifier:");
                    id appProxy = [workspace performSelector:appProxySelector withObject:bundleID];
                    if (appProxy) {
                        // Try isRunning
                        SEL isRunningSelector = NSSelectorFromString(@"isRunning");
                        if ([appProxy respondsToSelector:isRunningSelector]) {
                            BOOL running = [[appProxy performSelector:isRunningSelector] boolValue];
                            if (running) {
                                [logger log:@"[AppStatus] 🟢 %@ is RUNNING (LSAppWorkspace.isRunning)", bundleID];
                                return YES;
                            }
                        }
                    }
                }
            } @catch (NSException *e) {
                [logger log:@"[AppStatus] ⚠️  LSApplicationWorkspace check failed"];
            }
        }

        [logger log:@"[AppStatus] ⚫ %@ is NOT running", bundleID];
        return NO;
    } @catch (NSException *e) {
        [[DebugLogger sharedLogger] log:@"[AppStatus] ❌ Unexpected exception: %@", e];
        return NO;
    }
}

- (UIImage *)iconForApp:(NSString *)bundleID {
    @try {
        Class LSAppWorkspaceClass = NSClassFromString(@"LSApplicationWorkspace");
        if (!LSAppWorkspaceClass) return nil;

        SEL defaultWorkspaceSelector = NSSelectorFromString(@"defaultWorkspace");
        id workspace = [LSAppWorkspaceClass performSelector:defaultWorkspaceSelector];
        if (!workspace) return nil;

        SEL appProxySelector = NSSelectorFromString(@"applicationProxyForIdentifier:");
        id appProxy = [workspace performSelector:appProxySelector withObject:bundleID];
        if (!appProxy) return nil;

        SEL iconSelector = NSSelectorFromString(@"icon");
        if ([appProxy respondsToSelector:iconSelector]) {
            return [appProxy performSelector:iconSelector];
        }

        return nil;
    } @catch (NSException *e) {
        return nil;
    }
}

- (NSString *)displayNameForApp:(NSString *)bundleID {
    @try {
        Class LSAppWorkspaceClass = NSClassFromString(@"LSApplicationWorkspace");
        if (!LSAppWorkspaceClass) return bundleID;

        SEL defaultWorkspaceSelector = NSSelectorFromString(@"defaultWorkspace");
        id workspace = [LSAppWorkspaceClass performSelector:defaultWorkspaceSelector];
        if (!workspace) return bundleID;

        SEL appProxySelector = NSSelectorFromString(@"applicationProxyForIdentifier:");
        id appProxy = [workspace performSelector:appProxySelector withObject:bundleID];
        if (!appProxy) return bundleID;

        SEL localizedNameSelector = NSSelectorFromString(@"localizedName");
        if ([appProxy respondsToSelector:localizedNameSelector]) {
            NSString *name = [appProxy performSelector:localizedNameSelector];
            if (name && name.length > 0) {
                return name;
            }
        }

        return bundleID;
    } @catch (NSException *e) {
        return bundleID;
    }
}

@end
