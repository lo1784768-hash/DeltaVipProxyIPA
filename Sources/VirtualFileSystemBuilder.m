#import "VirtualFileSystemBuilder.h"
#import "MCMFilzaIntegration.h"
#import "SandboxEscapeManager.h"
#import "AppEnumerator.h"
#import "DebugLogger.h"

@implementation VirtualFileSystemBuilder

+ (instancetype)sharedBuilder {
    static VirtualFileSystemBuilder *builder = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        builder = [[VirtualFileSystemBuilder alloc] init];
    });
    return builder;
}

- (NSString *)createVirtualFileSystemAtRoot:(NSString *)rootPath
                                     error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];

    // Create root if not exists
    if (![fm fileExistsAtPath:rootPath]) {
        if (![fm createDirectoryAtPath:rootPath
           withIntermediateDirectories:YES
                            attributes:nil
                                 error:error]) {
            [[DebugLogger sharedLogger] log:@"[VFS] ❌ Failed to create virtual root at %@: %@", rootPath, error ? *error : @"unknown"];
            return nil;
        }
        [[DebugLogger sharedLogger] log:@"[VFS] ✅ Created virtual root: %@", rootPath];
    } else {
        [[DebugLogger sharedLogger] log:@"[VFS] ✅ Virtual root already exists: %@", rootPath];
    }

    // Create section folders
    NSArray *sections = @[
        @"[MHA-C2] App Data",
        @"[MHA-C7] App Groups",
        @"[MHA-C10] Service Data",
        @"[MHA-C12] System Data",
        @"[MHA-C13] System Groups"
    ];

    NSUInteger created = 0;
    for (NSString *section in sections) {
        NSString *sectionPath = [rootPath stringByAppendingPathComponent:section];
        if (![fm fileExistsAtPath:sectionPath]) {
            if (![fm createDirectoryAtPath:sectionPath
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:error]) {
                [[DebugLogger sharedLogger] log:@"[VFS] ❌ Failed to create section: %@", section];
            } else {
                [[DebugLogger sharedLogger] log:@"[VFS] ✅ Created section: %@", section];
                created++;
            }
        } else {
            [[DebugLogger sharedLogger] log:@"[VFS] ℹ️  Section already exists: %@", section];
            created++;
        }
    }

    [[DebugLogger sharedLogger] log:@"[VFS] ✅ Virtual filesystem structure ready (%lu sections)", (unsigned long)created];
    return rootPath;
}

- (BOOL)populateAppDataAtRoot:(NSString *)rootPath
                   limit:(NSUInteger)limit
                  error:(NSError **)error {
    DebugLogger *logger = [DebugLogger sharedLogger];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *appDataPath = [rootPath stringByAppendingPathComponent:@"[MHA-C2] App Data"];

    // Verify app data folder exists
    if (![fm fileExistsAtPath:appDataPath]) {
        [logger log:@"[VFS] ❌ App Data folder doesn't exist at %@", appDataPath];
        return NO;
    }

    // Get all app identifiers
    AppEnumerator *enumerator = [AppEnumerator sharedEnumerator];
    NSArray *allApps = [enumerator allApplicationIdentifiers];
    [logger log:@"[VFS] 📊 AppEnumerator found %lu total apps", (unsigned long)allApps.count];

    if (allApps.count == 0) {
        [logger log:@"[VFS] ⚠️  AppEnumerator returned 0 apps, trying alternative method..."];

        // Fallback: Scan device filesystem for app containers
        NSString *containersPath = @"/var/mobile/Containers/Data/Application";
        NSArray *containers = [fm contentsOfDirectoryAtPath:containersPath error:nil];

        if (containers && containers.count > 0) {
            [logger log:@"[VFS] ✅ Found %lu app containers in filesystem", (unsigned long)containers.count];
            allApps = containers;
        } else {
            [logger log:@"[VFS] ❌ No containers found in filesystem either"];
            return NO;
        }
    }

    NSArray *apps = limit > 0 ? [allApps subarrayWithRange:NSMakeRange(0, MIN(limit, allApps.count))]
                              : allApps;

    NSUInteger created = 0;
    NSUInteger failed = 0;

    for (NSString *appID in apps) {
        @try {
            // Ưu tiên: đọc metadata plist trực tiếp (sau khi sandbox escaped)
            NSString *containerPath = [SandboxEscapeManager containerPathForBundleID:appID];

            // Fallback: MCM + sandbox extension activation + LSApplicationProxy
            NSString *containerError = nil;
            if (!containerPath) {
                containerPath = MCMFilzaDataContainerPath(appID, &containerError);
            }

            if (!containerPath) {
                [logger log:@"[VFS] ❌ Could not get path for %@: %@", appID, containerError ?: @"unknown error"];
                failed++;
                continue;
            }

            // Create folder for app
            NSString *appFolder = [appDataPath stringByAppendingPathComponent:appID];
            if (![fm fileExistsAtPath:appFolder]) {
                NSError *linkError = nil;

                // Try to create symlink
                if ([fm createSymbolicLinkAtPath:appFolder
                          withDestinationPath:containerPath
                                       error:&linkError]) {
                    created++;
                    [logger log:@"[VFS] ✅ Symlink: %@ → %@", appID, containerPath];
                } else {
                    // Fallback: create folder with .path reference file
                    NSError *folderError = nil;
                    if ([fm createDirectoryAtPath:appFolder
                       withIntermediateDirectories:YES
                                        attributes:nil
                                             error:&folderError]) {
                        // Write real path to .path file for reference
                        NSString *readmePath = [appFolder stringByAppendingPathComponent:@".path"];
                        [containerPath writeToFile:readmePath
                                       atomically:YES
                                         encoding:NSUTF8StringEncoding
                                            error:nil];

                        created++;
                        [logger log:@"[VFS] 📄 Fallback folder (symlink failed): %@ → %@ (ref: .path)", appID, containerPath];
                    } else {
                        [logger log:@"[VFS] ❌ Failed to create folder for %@: %@", appID, folderError];
                        failed++;
                    }
                }
            }

        } @catch (NSException *e) {
            [logger log:@"[VFS] ❌ Exception processing %@: %@", appID, e];
            failed++;
        }
    }

    [logger log:@"[VFS] 📦 Populated app data: %lu created, %lu failed out of %lu attempted",
          (unsigned long)created, (unsigned long)failed, (unsigned long)apps.count];

    return created > 0;
}

- (BOOL)populateAppGroupsAtRoot:(NSString *)rootPath
                         error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *groupsPath = [rootPath stringByAppendingPathComponent:@"[MHA-C7] App Groups"];

    NSString *realGroupsPath = @"/private/var/mobile/Containers/Shared/AppGroup";
    NSError *readError = nil;
    NSArray *groups = [fm contentsOfDirectoryAtPath:realGroupsPath error:&readError];

    if (!groups) {
        NSLog(@"[VFS] Could not read app groups: %@", readError);
        return NO;
    }

    NSUInteger created = 0;
    for (NSString *groupID in groups) {
        @try {
            NSString *groupPath = [groupsPath stringByAppendingPathComponent:groupID];
            NSString *realPath = [realGroupsPath stringByAppendingPathComponent:groupID];

            if (![fm fileExistsAtPath:groupPath]) {
                if (![fm createSymbolicLinkAtPath:groupPath
                          withDestinationPath:realPath
                                       error:error]) {
                    NSLog(@"  [VFS] Failed to link group: %@", groupID);
                    continue;
                }
            }

            created++;
        } @catch (NSException *e) {
            NSLog(@"  [VFS] Error processing group: %@", e);
        }
    }

    NSLog(@"[VFS] Populated app groups: %lu", (unsigned long)created);
    return created > 0;
}

@end
