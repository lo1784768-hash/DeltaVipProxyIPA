#import "ContainerManager.h"
#import <Foundation/Foundation.h>

// Private class declarations (from MobileContainerManager)
@interface MCMApplicationIdentity : NSObject
@end

@interface MCMContainerManager : NSObject
+ (instancetype)defaultManager;
- (NSString *)containerPathForIdentifier:(NSString *)identifier type:(int)type;
- (NSArray *)containerPathsForIdentifiers:(NSArray *)identifiers type:(int)type;
@end

@implementation ContainerManager

+ (instancetype)sharedManager {
    static ContainerManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[ContainerManager alloc] init];
    });
    return manager;
}

- (NSArray<NSDictionary *> *)listAppContainers {
    // Try to access MCM to list app containers
    // This requires private APIs and may fail on non-jailbroken devices

    NSMutableArray *containers = [NSMutableArray array];

    @try {
        // Private API: MCMContainerManager.defaultManager
        Class MCMClass = NSClassFromString(@"MCMContainerManager");
        if (!MCMClass) {
            NSLog(@"MCMContainerManager not available");
            return containers;
        }

        SEL selector = NSSelectorFromString(@"defaultManager");
        if (![MCMClass respondsToSelector:selector]) {
            return containers;
        }

        id mcm = [MCMClass performSelector:selector];
        if (!mcm) {
            return containers;
        }

        // Attempt to enumerate some known app identifiers
        NSArray *commonApps = @[
            @"com.apple.mobilesafari",
            @"com.apple.mobilenotes",
            @"com.apple.mobilecal",
            @"com.apple.mobilemail",
            @"com.apple.mobilephone",
            @"com.apple.mobilesms"
        ];

        for (NSString *appId in commonApps) {
            @try {
                SEL getPath = NSSelectorFromString(@"containerPathForIdentifier:type:");
                if ([mcm respondsToSelector:getPath]) {
                    NSString *path = [mcm performSelector:getPath
                                              withObject:appId
                                              withObject:@(2)]; // type 2 = app data

                    if (path && ![path isEqualToString:@""]) {
                        [containers addObject:@{
                            @"name": appId,
                            @"path": path
                        }];
                    }
                }
            } @catch (NSException *e) {
                // Continue if this app fails
            }
        }
    } @catch (NSException *e) {
        NSLog(@"Error accessing MCM: %@", e);
    }

    return containers;
}

- (NSArray<NSDictionary *> *)listAppGroups {
    NSMutableArray *groups = [NSMutableArray array];

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *groupPath = @"/private/var/mobile/Containers/Shared/AppGroup";

    NSError *error = nil;
    NSArray *contents = [fm contentsOfDirectoryAtPath:groupPath error:&error];

    if (error) {
        NSLog(@"Error reading app groups: %@", error);
        return groups;
    }

    for (NSString *folder in contents) {
        NSString *fullPath = [groupPath stringByAppendingPathComponent:folder];
        [groups addObject:@{
            @"name": folder,
            @"path": fullPath
        }];
    }

    return groups;
}

- (NSArray<NSDictionary *> *)listSystemContainers {
    NSMutableArray *containers = [NSMutableArray array];

    NSFileManager *fm = [NSFileManager defaultManager];

    // Try to access system group containers
    NSString *systemGroupPath = @"/private/var/containers/Shared/SystemGroup";
    NSString *systemDataPath = @"/private/var/containers/Data/System";

    @try {
        NSError *error = nil;
        NSArray *systemGroups = [fm contentsOfDirectoryAtPath:systemGroupPath error:&error];

        if (!error && systemGroups.count > 0) {
            [containers addObject:@{
                @"name": @"[MHA-C13] System Groups",
                @"path": systemGroupPath,
                @"count": @(systemGroups.count)
            }];
        }

        NSArray *systemData = [fm contentsOfDirectoryAtPath:systemDataPath error:&error];
        if (!error && systemData.count > 0) {
            [containers addObject:@{
                @"name": @"[MHA-C12] System Data",
                @"path": systemDataPath,
                @"count": @(systemData.count)
            }];
        }
    } @catch (NSException *e) {
        NSLog(@"Error reading system containers: %@", e);
    }

    return containers;
}

- (NSString *)containerPathForIdentifier:(NSString *)identifier type:(NSInteger)type {
    NSString *basePath = @"/private/var/mobile/Containers/Data/Application";

    if (type == 2) { // App data
        return [basePath stringByAppendingPathComponent:@"{UUID}"]; // Placeholder
    } else if (type == 7) { // App groups
        return @"/private/var/mobile/Containers/Shared/AppGroup/{UUID}";
    }

    return nil;
}

@end
