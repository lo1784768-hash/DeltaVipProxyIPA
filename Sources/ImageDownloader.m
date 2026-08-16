#import "ImageDownloader.h"
#import "Endpoints.h"
#import "SecurityPinning.h"
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
    NSString *cachesPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSString *appImagesDir = [cachesPath stringByAppendingPathComponent:@"AppImages"];

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

    // Image URLs lấy từ Endpoint functions (XOR-encoded, không hardcode plaintext)
    NSDictionary<NSString *, NSString *> *imageURLs = @{
        @"FreeFireMax": EndpointImgFreeFireMax(),
        @"FreeFireTH":  EndpointImgFreeFireTH(),
    };

    NSUInteger totalCount = imageURLs.count;
    __block NSUInteger finishedCount = 0;
    __block NSUInteger successCount  = 0;
    NSLock *lock = [[NSLock alloc] init];

    void (^oneDone)(BOOL) = ^(BOOL ok) {
        [lock lock];
        if (ok) successCount++;
        finishedCount++;
        BOOL allDone = (finishedCount == totalCount);
        NSUInteger sc = successCount;
        [lock unlock];

        if (allDone) {
            [logger log:@"[ImageDL] 📊 Done: %lu/%lu", (unsigned long)sc, (unsigned long)totalCount];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(sc > 0);
            });
        }
    };

    for (NSString *name in imageURLs) {
        NSString *urlString = imageURLs[name];
        [logger log:@"[ImageDL] ⬇️  Downloading %@...", name];

        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        req.timeoutInterval = 20;

        // Dùng pinnedSession → SSL pinning, chặn MITM inject ảnh độc hại
        NSURLSessionDataTask *task = [[SecurityPinning shared].pinnedSession dataTaskWithRequest:req
            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

            if (error || !data || data.length == 0) {
                [logger log:@"[ImageDL] ❌ Failed to download: %@", name];
                oneDone(NO);
                return;
            }

            NSInteger code = [response isKindOfClass:[NSHTTPURLResponse class]]
                             ? [(NSHTTPURLResponse *)response statusCode] : 0;
            if (code != 200) {
                [logger log:@"[ImageDL] ❌ HTTP %ld for: %@", (long)code, name];
                oneDone(NO);
                return;
            }

            NSString *imagePath = [appImagesDir stringByAppendingPathComponent:
                                   [NSString stringWithFormat:@"%@.png", name]];
            if ([data writeToFile:imagePath atomically:YES]) {
                [logger log:@"[ImageDL] ✅ Cached: %@", name];
                oneDone(YES);
            } else {
                [logger log:@"[ImageDL] ❌ Failed to write: %@", name];
                oneDone(NO);
            }
        }];
        [task resume];
    }
}

- (UIImage *)cachedImageNamed:(NSString *)name {
    NSString *cachesPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSString *appImagesDir = [cachesPath stringByAppendingPathComponent:@"AppImages"];
    NSString *imagePath = [appImagesDir stringByAppendingPathComponent:
                           [NSString stringWithFormat:@"%@.png", name]];

    if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
        return [UIImage imageWithContentsOfFile:imagePath];
    }
    return nil;
}

@end
