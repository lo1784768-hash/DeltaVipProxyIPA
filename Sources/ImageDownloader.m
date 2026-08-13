#import "ImageDownloader.h"
#import "DebugLogger.h"

@implementation ImageDownloader

+ (instancetype)sharedDownloader {
    static ImageDownloader *downloader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        downloader = [[ImageDownloader alloc] init];
    });
    return downloader;
}

- (void)downloadImagesWithCompletion:(void (^)(BOOL success))completion {
    DebugLogger *logger = [DebugLogger sharedLogger];
    [logger log:@"[ImageDL] 🚀 Starting image download..."];

    // Create cache directory
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSString *appImagesDir = [documentsPath stringByAppendingPathComponent:@"AppImages"];

    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:appImagesDir]) {
        NSError *error = nil;
        [fm createDirectoryAtPath:appImagesDir withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            [logger log:@"[ImageDL] ❌ Failed to create AppImages dir: %@", error];
            if (completion) completion(NO);
            return;
        }
    }

    // Image URLs
    NSDictionary *imageURLs = @{
        @"FreeFireMax": @"https://getuid.vip/FreeFireMax.png",
        @"FreeFireTH": @"https://getuid.vip/FreeFireTH.png"
    };

    __block NSInteger downloadedCount = 0;
    __block NSInteger totalCount = imageURLs.count;

    // Download each image
    for (NSString *name in imageURLs) {
        NSString *urlString = imageURLs[name];
        [logger log:@"[ImageDL] ⬇️  Downloading %@...", name];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            @try {
                NSURL *url = [NSURL URLWithString:urlString];
                NSData *imageData = [NSData dataWithContentsOfURL:url];

                if (imageData) {
                    NSString *imagePath = [appImagesDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png", name]];
                    BOOL success = [imageData writeToFile:imagePath atomically:YES];

                    if (success) {
                        [logger log:@"[ImageDL] ✅ Downloaded & cached: %@", name];
                        downloadedCount++;
                    } else {
                        [logger log:@"[ImageDL] ❌ Failed to write: %@", name];
                    }
                } else {
                    [logger log:@"[ImageDL] ❌ Failed to download: %@", name];
                }

                // Check if all downloads complete
                if (downloadedCount + (totalCount - downloadedCount - 1) >= totalCount - 1) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        BOOL success = (downloadedCount > 0);
                        [logger log:@"[ImageDL] 📊 Download complete: %lu/%lu", (unsigned long)downloadedCount, (unsigned long)totalCount];
                        if (completion) completion(success);
                    });
                }
            } @catch (NSException *e) {
                [logger log:@"[ImageDL] ❌ Exception: %@", e];
            }
        });
    }
}

- (UIImage *)cachedImageNamed:(NSString *)name {
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSString *appImagesDir = [documentsPath stringByAppendingPathComponent:@"AppImages"];
    NSString *imagePath = [appImagesDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png", name]];

    if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
        return [UIImage imageWithContentsOfFile:imagePath];
    }

    return nil;
}

@end
