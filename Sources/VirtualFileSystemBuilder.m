#import "VirtualFileSystemBuilder.h"
#import "MCMFilzaIntegration.h"
#import "AppEnumerator.h"

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
            NSLog(@"[VFS] ❌ Failed to create virtual root at %@: %@", rootPath, error ? *error : @"unknown");
            return nil;
        }
        NSLog(@"[VFS] ✅ Created virtual root: %@", rootPath);
    } else {
        NSLog(@"[VFS] ✅ Virtual root already exists: %@", rootPath);
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
                NSLog(@"[VFS] ❌ Failed to create section: %@", section);
            } else {
                NSLog(@"[VFS] ✅ Created section: %@", section);
                created++;
            }
        } else {
            NSLog(@"[VFS] ℹ️  Section already exists: %@", section);
            created++;
        }
    }

    NSLog(@"[VFS] ✅ Virtual filesystem structure ready (%lu sections)", (unsigned long)created);
    return rootPath;
}

- (BOOL)populateAppDataAtRoot:(NSString *)rootPath
                   limit:(NSUInteger)limit
                  error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *appDataPath = [rootPath stringByAppendingPathComponent:@"[MHA-C2] App Data"];

    // Verify app data folder exists
    if (![fm fileExistsAtPath:appDataPath]) {
        NSLog(@"[VFS] ERROR: App Data folder doesn't exist at %@", appDataPath);
        return NO;
    }

    // Get all app identifiers
    AppEnumerator *enumerator = [AppEnumerator sharedEnumerator];
    NSArray *allApps = [enumerator allApplicationIdentifiers];
    NSLog(@"[VFS] 📊 AppEnumerator found %lu total apps", (unsigned long)allApps.count);

    if (allApps.count == 0) {
        NSLog(@"[VFS] ⚠️  ERROR: No apps returned by AppEnumerator! LSApplicationWorkspace might not be working.");
        return NO;
    }

    NSArray *apps = limit > 0 ? [allApps subarrayWithRange:NSMakeRange(0, MIN(limit, allApps.count))]
                              : allApps;

    NSUInteger created = 0;
    NSUInteger failed = 0;

    for (NSString *appID in apps) {
        @try {
            // Get container path via MCM
            NSString *containerError = nil;
            NSString *containerPath = MCMFilzaDataContainerPath(appID, &containerError);

            if (!containerPath) {
                NSLog(@"[VFS] ❌ Could not get path for %@: %@", appID, containerError ?: @"unknown error");
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
                    NSLog(@"[VFS] ✅ Symlink: %@ → %@", appID, containerPath);
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
                        NSLog(@"[VFS] 📄 Fallback folder (symlink failed): %@ → %@ (ref: .path)", appID, containerPath);
                    } else {
                        NSLog(@"[VFS] ❌ Failed to create folder for %@: %@", appID, folderError);
                        failed++;
                    }
                }
            }

        } @catch (NSException *e) {
            NSLog(@"[VFS] ❌ Exception processing %@: %@", appID, e);
            failed++;
        }
    }

    NSLog(@"[VFS] 📦 Populated app data: %lu created, %lu failed out of %lu attempted",
          (unsigned long)created, (unsigned long)failed, (unsigned long)apps.count);

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
