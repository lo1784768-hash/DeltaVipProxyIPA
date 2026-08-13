#import "AppEnumerator.h"
#import "DebugLogger.h"

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (NSArray *)allApplications;
@end

@interface LSApplicationProxy : NSObject
@property (nonatomic, readonly) NSString *bundleIdentifier;
@property (nonatomic, readonly) NSString *localizedName;
@property (nonatomic, readonly) BOOL isSystemApplication;
@end

@implementation AppEnumerator

+ (instancetype)sharedEnumerator {
    static AppEnumerator *enumerator = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        enumerator = [[AppEnumerator alloc] init];
    });
    return enumerator;
}

- (NSArray<NSString *> *)allApplicationIdentifiers {
    NSMutableArray *identifiers = [NSMutableArray array];

    @try {
        Class LSAppWorkspaceClass = NSClassFromString(@"LSApplicationWorkspace");
        if (!LSAppWorkspaceClass) {
            [[DebugLogger sharedLogger] log:@"[AppEnum] ❌ LSApplicationWorkspace class not available!"];
            return identifiers;
        }
        [[DebugLogger sharedLogger] log:@"[AppEnum] ✅ LSApplicationWorkspace class found"];

        SEL defaultWorkspaceSelector = NSSelectorFromString(@"defaultWorkspace");
        id workspace = [LSAppWorkspaceClass performSelector:defaultWorkspaceSelector];

        if (!workspace) {
            [[DebugLogger sharedLogger] log:@"[AppEnum] ❌ Could not get defaultWorkspace"];
            return identifiers;
        }
        [[DebugLogger sharedLogger] log:@"[AppEnum] ✅ Got workspace instance"];

        SEL allAppsSelector = NSSelectorFromString(@"allApplications");
        if (![workspace respondsToSelector:allAppsSelector]) {
            [[DebugLogger sharedLogger] log:@"[AppEnum] ❌ allApplications selector not found"];
            return identifiers;
        }
        [[DebugLogger sharedLogger] log:@"[AppEnum] ✅ allApplications selector available"];

        NSArray *allApps = [workspace performSelector:allAppsSelector];
        [[DebugLogger sharedLogger] log:@"[AppEnum] 📊 Retrieved %lu app proxies", (unsigned long)allApps.count];

        if (!allApps || allApps.count == 0) {
            [[DebugLogger sharedLogger] log:@"[AppEnum] ⚠️  allApplications returned nil or empty!"];
            return identifiers;
        }

        for (id app in allApps) {
            @try {
                SEL bundleIDSelector = NSSelectorFromString(@"bundleIdentifier");
                if ([app respondsToSelector:bundleIDSelector]) {
                    NSString *bundleID = [app performSelector:bundleIDSelector];
                    if (bundleID && bundleID.length > 0) {
                        [identifiers addObject:bundleID];
                    }
                }
            } @catch (NSException *e) {
                [[DebugLogger sharedLogger] log:@"[AppEnum] ❌ Error getting bundle ID: %@", e];
            }
        }

        [[DebugLogger sharedLogger] log:@"[AppEnum] ✅ Successfully extracted %lu bundle identifiers", (unsigned long)identifiers.count];

    } @catch (NSException *e) {
        [[DebugLogger sharedLogger] log:@"[AppEnum] ❌ Exception during app enumeration: %@", e];
    }

    return identifiers;
}

- (NSString *)displayNameForIdentifier:(NSString *)identifier {
    @try {
        Class LSAppWorkspaceClass = NSClassFromString(@"LSApplicationWorkspace");
        if (!LSAppWorkspaceClass) return identifier;

        SEL defaultWorkspaceSelector = NSSelectorFromString(@"defaultWorkspace");
        id workspace = [LSAppWorkspaceClass performSelector:defaultWorkspaceSelector];
        if (!workspace) return identifier;

        SEL appProxySelector = NSSelectorFromString(@"applicationProxyForIdentifier:");
        if (![workspace respondsToSelector:appProxySelector]) return identifier;

        id appProxy = [workspace performSelector:appProxySelector withObject:identifier];
        if (!appProxy) return identifier;

        SEL localizedNameSelector = NSSelectorFromString(@"localizedName");
        if ([appProxy respondsToSelector:localizedNameSelector]) {
            NSString *name = [appProxy performSelector:localizedNameSelector];
            if (name && name.length > 0) {
                return name;
            }
        }
    } @catch (NSException *e) {
        [[DebugLogger sharedLogger] log:@"Error getting display name: %@", e];
    }

    return identifier;
}

- (NSArray<NSString *> *)filterIdentifiers:(NSArray<NSString *> *)identifiers
                               excludeSystem:(BOOL)excludeSystem {
    if (!excludeSystem) {
        return identifiers;
    }

    NSMutableArray *filtered = [NSMutableArray array];

    for (NSString *identifier in identifiers) {
        @try {
            Class LSAppWorkspaceClass = NSClassFromString(@"LSApplicationWorkspace");
            if (!LSAppWorkspaceClass) {
                [filtered addObject:identifier];
                continue;
            }

            SEL defaultWorkspaceSelector = NSSelectorFromString(@"defaultWorkspace");
            id workspace = [LSAppWorkspaceClass performSelector:defaultWorkspaceSelector];

            SEL appProxySelector = NSSelectorFromString(@"applicationProxyForIdentifier:");
            id appProxy = [workspace performSelector:appProxySelector withObject:identifier];

            SEL isSystemSelector = NSSelectorFromString(@"isSystemApplication");
            if ([appProxy respondsToSelector:isSystemSelector]) {
                BOOL isSystem = [[appProxy performSelector:isSystemSelector] boolValue];
                if (!isSystem) {
                    [filtered addObject:identifier];
                }
            } else {
                [filtered addObject:identifier];
            }
        } @catch (NSException *e) {
            [filtered addObject:identifier];
        }
    }

    return filtered;
}

@end
