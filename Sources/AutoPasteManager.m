#import "AutoPasteManager.h"
#import "AppPaths.h"
#import "Endpoints.h"
#import "KeyManager.h"

@implementation AutoPasteManager

+ (instancetype)sharedManager {
    static AutoPasteManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AutoPasteManager alloc] init];
    });
    return instance;
}

- (void)pasteFeature:(NSString *)feature
                 mod:(BOOL)isMod
           fileNamed:(NSString *)fileName
           underRoot:(NSString *)relativeRoot
          completion:(void (^)(BOOL success, NSString *message))completion {

    if (feature.length == 0 || fileName.length == 0) {
        [self finish:completion ok:NO msg:@"⚠️ Chưa cấu hình chức năng"];
        return;
    }

    NSString *key  = [KeyManager shared].keyCode;
    NSString *udid = [[KeyManager shared] deviceUDID];
    if (key.length == 0) {
        [self finish:completion ok:NO msg:@"🔒 Chưa có license key"];
        return;
    }

    NSString *base = AppHiddenDataBase();
    NSString *root = relativeRoot.length ? [base stringByAppendingPathComponent:relativeRoot] : base;

    // POST key+udid+feature+mode tới endpoint (mã hoá) — server xác thực rồi trả file
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:EndpointGetMod()]];
    req.HTTPMethod = @"POST";
    req.timeoutInterval = 20;
    [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    NSString *body = [NSString stringWithFormat:@"key_code=%@&udid=%@&feature=%@&mode=%@",
                      [self enc:key], [self enc:udid], [self enc:feature], (isMod ? @"mod" : @"goc")];
    req.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

        if (error || !data) {
            [self finish:completion ok:NO msg:@"⚠️ Lỗi Từ Phía Delta, Liên Hệ Seller / Admin Hỗ Trợ"];
            return;
        }

        NSInteger code = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response statusCode] : 0;

        // Không phải 200 → server từ chối (key sai/hết hạn/sai máy...) → đọc message JSON
        if (code != 200) {
            NSDictionary *j = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSString *msg = ([j isKindOfClass:[NSDictionary class]] ? j[@"message"] : nil)
                            ?: @"🔒 Key không hợp lệ / hết hạn";
            [self finish:completion ok:NO msg:msg];
            return;
        }

        if (data.length == 0) {
            [self finish:completion ok:NO msg:@"⚠️ Lỗi Từ Phía Delta, Liên Hệ Seller / Admin Hỗ Trợ"];
            return;
        }

        // Đã có file → tìm theo tên & ghi đè
        [self writeData:data toFileNamed:fileName under:root fallback:base completion:completion];
    }];
    [task resume];
}

- (void)writeData:(NSData *)fileData toFileNamed:(NSString *)fileName
            under:(NSString *)root fallback:(NSString *)base
       completion:(void (^)(BOOL, NSString *))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *searchBase = [fm fileExistsAtPath:root] ? root : base;

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

        NSInteger okCount = 0;
        for (NSString *p in matches) {
            if ([fileData writeToFile:p atomically:YES]) okCount++;
        }

        if (okCount > 0) {
            [self finish:completion ok:YES msg:@"OK"];
        } else {
            [self finish:completion ok:NO msg:@"❌ Ghi file thất bại"];
        }
    });
}

- (NSString *)enc:(NSString *)s {
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
                               @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~"];
    return [s stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"";
}

- (void)finish:(void (^)(BOOL, NSString *))completion ok:(BOOL)ok msg:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(ok, msg); });
}

@end
