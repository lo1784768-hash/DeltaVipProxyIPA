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

- (void)pasteFromURL:(NSString *)urlString
      toRelativePath:(NSString *)relativePath
          completion:(void (^)(BOOL success, NSString *message))completion {

    if (urlString.length == 0 || relativePath.length == 0) {
        if (completion) completion(NO, @"⚠️ Chưa cấu hình URL / đường dẫn");
        return;
    }

    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *filePath = [documentsPath stringByAppendingPathComponent:relativePath];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        NSURL *url = [NSURL URLWithString:urlString];

        NSData *fileData = [NSData dataWithContentsOfURL:url options:0 error:&error];

        if (error || !fileData || fileData.length == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(NO, error ? [NSString stringWithFormat:@"❌ Tải lỗi: %@", error.localizedDescription]
                                         : @"❌ File rỗng từ server");
                }
            });
            return;
        }

        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *dirPath = [filePath stringByDeletingLastPathComponent];
        [fm createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:&error];

        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, [NSString stringWithFormat:@"❌ Không tạo được thư mục: %@", error.localizedDescription]);
            });
            return;
        }

        BOOL success = [fileData writeToFile:filePath atomically:YES];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                if (success) {
                    completion(YES, [NSString stringWithFormat:@"✅ Xong (%lu KB)", (unsigned long)fileData.length / 1024]);
                } else {
                    completion(NO, @"❌ Ghi file thất bại");
                }
            }
        });
    });
}

@end
