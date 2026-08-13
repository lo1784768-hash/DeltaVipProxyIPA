#import "AppStatusChecker.h"

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
    @try {
        Class LSAppWorkspaceClass = NSClassFromString(@"LSApplicationWorkspace");
        if (!LSAppWorkspaceClass) return NO;

        SEL defaultWorkspaceSelector = NSSelectorFromString(@"defaultWorkspace");
        id workspace = [LSAppWorkspaceClass performSelector:defaultWorkspaceSelector];
        if (!workspace) return NO;

        SEL appProxySelector = NSSelectorFromString(@"applicationProxyForIdentifier:");
        id appProxy = [workspace performSelector:appProxySelector withObject:bundleID];
        if (!appProxy) return NO;

        SEL isRunningSelector = NSSelectorFromString(@"isRunning");
        if ([appProxy respondsToSelector:isRunningSelector]) {
            return [[appProxy performSelector:isRunningSelector] boolValue];
        }

        return NO;
    } @catch (NSException *e) {
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
