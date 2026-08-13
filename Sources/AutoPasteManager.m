#import "AutoPasteManager.h"

@implementation AutoPasteManager

+ (instancetype)sharedManager {
    static AutoPasteManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AutoPasteManager alloc] init];
    });
    return instance;
}

- (void)pasteFileWithServerMode:(BOOL)isServer1
                       bundleID:(NSString *)bundleID
                     completion:(void (^)(BOOL success, NSString *message))completion {

    // Determine server URL and file name based on bundle ID
    NSString *serverURL = nil;
    NSString *fileName = nil;
    NSString *containerPath = nil;

    if ([bundleID isEqualToString:@"com.dts.freefireth"]) {
        fileName = @"cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D";

        // Build container path dynamically
        NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        containerPath = [documentsPath stringByAppendingPathComponent:@"Device Storage/[MHA-C2] App Data/com.dts.freefireth/Documents/contentcache/Compulsory/ios/gameassetbundles/"];

        // Select server URL
        if (isServer1) {
            serverURL = @"https://getuid.vip/ServerPaste/pastebody/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D";
        } else {
            serverURL = @"https://getuid.vip/ServerPaste/pastebodygoc/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D";
        }
    } else {
        if (completion) {
            completion(NO, @"⚠️ App này chưa cấu hình server paste");
        }
        return;
    }

    // Download file from server
    [self downloadFromURL:serverURL
               toPath:[containerPath stringByAppendingPathComponent:fileName]
           completion:completion];
}

- (void)downloadFromURL:(NSString *)urlString
                 toPath:(NSString *)filePath
             completion:(void (^)(BOOL success, NSString *message))completion {

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        NSURL *url = [NSURL URLWithString:urlString];

        // Download file
        NSData *fileData = [NSData dataWithContentsOfURL:url options:0 error:&error];

        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(NO, [NSString stringWithFormat:@"❌ Download failed: %@", error.localizedDescription]);
                }
            });
            return;
        }

        if (!fileData || fileData.length == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(NO, @"❌ Empty file received");
                }
            });
            return;
        }

        // Create directory if needed
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *dirPath = [filePath stringByDeletingLastPathComponent];

        [fm createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:&error];

        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(NO, [NSString stringWithFormat:@"❌ Cannot create directory: %@", error.localizedDescription]);
                }
            });
            return;
        }

        // Write file
        BOOL success = [fileData writeToFile:filePath atomically:YES];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                if (completion) {
                    completion(YES, [NSString stringWithFormat:@"✅ Pasted! (%lu KB)", (unsigned long)fileData.length / 1024]);
                }
            } else {
                if (completion) {
                    completion(NO, @"❌ Write failed");
                }
            }
        });
    });
}

@end
