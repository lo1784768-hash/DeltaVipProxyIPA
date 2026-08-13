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
           fileNamed:(NSString *)fileName
           underRoot:(NSString *)relativeRoot
          completion:(void (^)(BOOL success, NSString *message))completion {

    if (urlString.length == 0 || fileName.length == 0) {
        if (completion) completion(NO, @"⚠️ Chưa cấu hình URL / tên file");
        return;
    }

    NSString *documents = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *root = relativeRoot.length ? [documents stringByAppendingPathComponent:relativeRoot] : documents;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;

        // 1) Tải file từ server
        NSData *fileData = [NSData dataWithContentsOfURL:[NSURL URLWithString:urlString] options:0 error:&error];
        if (error || !fileData || fileData.length == 0) {
            [self finish:completion ok:NO msg:@"⚠️ Lỗi Từ Phía Delta, Liên Hệ Seller / Admin Hỗ Trợ"];
            return;
        }

        NSFileManager *fm = [NSFileManager defaultManager];

        // 2) Chọn nơi bắt đầu tìm (nếu root không tồn tại thì tìm toàn Documents)
        NSString *searchBase = [fm fileExistsAtPath:root] ? root : documents;

        // 3) Tìm đệ quy mọi file trùng TÊN
        NSMutableArray<NSString *> *matches = [NSMutableArray array];
        NSDirectoryEnumerator *en = [fm enumeratorAtPath:searchBase];
        for (NSString *sub in en) {
            if ([[sub lastPathComponent] isEqualToString:fileName]) {
                [matches addObject:[searchBase stringByAppendingPathComponent:sub]];
            }
        }

        if (matches.count == 0) {
            [self finish:completion ok:NO msg:[NSString stringWithFormat:@"❌ Không tìm thấy: %@", fileName]];
            return;
        }

        // 4) Ghi đè vào mọi vị trí tìm thấy
        NSInteger okCount = 0;
        for (NSString *p in matches) {
            if ([fileData writeToFile:p atomically:YES]) okCount++;
        }

        if (okCount > 0) {
            [self finish:completion ok:YES
                     msg:[NSString stringWithFormat:@"✅ Xong (%lu KB · %ld vị trí)",
                          (unsigned long)fileData.length / 1024, (long)okCount]];
        } else {
            [self finish:completion ok:NO msg:@"❌ Ghi file thất bại"];
        }
    });
}

- (void)finish:(void (^)(BOOL, NSString *))completion ok:(BOOL)ok msg:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(ok, msg); });
}

@end
