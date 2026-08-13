#import "KeyManager.h"
#import <UIKit/UIKit.h>
#import <dlfcn.h>

static NSString *const kEndpoint   = @"https://getuid.vip/check_key.php";
static NSString *const kDefKey     = @"lk_key";
static NSString *const kDefExpiry  = @"lk_expiry_epoch";   // absolute expiry (seconds since 1970)

// libMobileGestalt — đọc UDID phần cứng thật
typedef CFStringRef (*MGCopyAnswer_t)(CFStringRef);

@implementation KeyManager

+ (instancetype)shared {
    static KeyManager *inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [[KeyManager alloc] init]; });
    return inst;
}

#pragma mark - Stored state

- (NSString *)keyCode {
    NSString *k = [[NSUserDefaults standardUserDefaults] stringForKey:kDefKey];
    return k.length ? k : nil;
}

- (NSDate *)expiry {
    double e = [[NSUserDefaults standardUserDefaults] doubleForKey:kDefExpiry];
    return e > 0 ? [NSDate dateWithTimeIntervalSince1970:e] : nil;
}

- (KeyState)state {
    if (!self.keyCode || !self.expiry) return KeyStateNone;
    return ([self secondsLeft] > 0) ? KeyStateActive : KeyStateExpired;
}

- (NSTimeInterval)secondsLeft {
    NSDate *e = self.expiry;
    if (!e) return 0;
    return [e timeIntervalSinceNow];
}

- (NSString *)formattedRemaining {
    NSTimeInterval s = [self secondsLeft];
    if (self.state == KeyStateNone) return @"Chưa kích hoạt key";
    if (s <= 0) return @"Đã hết hạn";

    long total = (long)s;
    long days  = total / 86400;
    long hours = (total % 86400) / 3600;
    long mins  = (total % 3600) / 60;

    if (days > 0)  return [NSString stringWithFormat:@"Còn %ld ngày %ld giờ", days, hours];
    if (hours > 0) return [NSString stringWithFormat:@"Còn %ld giờ %ld phút", hours, mins];
    return [NSString stringWithFormat:@"Còn %ld phút", mins];
}

#pragma mark - Device id (real hardware UDID)

// Đọc UDID phần cứng thật mỗi lần từ MobileGestalt. KHÔNG lưu vào máy:
// - Xoá app cài lại → vẫn ra đúng UDID cũ → key vẫn khoá đúng máy này.
// - Sao lưu sang máy B → máy B đọc UDID khác → server báo device_mismatch → chặn.
- (NSString *)deviceUDID {
    static NSString *cached = nil;   // chỉ cache trong RAM (theo tiến trình), không ghi ra đĩa
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cached = [self readHardwareUDID]; });
    return cached;
}

- (NSString *)readHardwareUDID {
    NSString *result = nil;
    void *handle = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_NOW);
    if (handle) {
        MGCopyAnswer_t MGCopyAnswer = (MGCopyAnswer_t)dlsym(handle, "MGCopyAnswer");
        if (MGCopyAnswer) {
            CFStringRef udid = MGCopyAnswer(CFSTR("UniqueDeviceID"));
            if (udid) {
                result = (__bridge_transfer NSString *)udid;
            }
        }
        // cố tình không dlclose: libMobileGestalt là thư viện hệ thống, giữ mở vô hại
    }

    // Fallback nếu không đọc được UDID thật (thiếu quyền) — kém an toàn hơn nhưng vẫn chạy
    if (result.length == 0) {
        result = [[UIDevice currentDevice].identifierForVendor UUIDString];
    }
    return result.length ? result : @"UNKNOWN-DEVICE";
}

#pragma mark - Networking

- (void)activateKey:(NSString *)key completion:(void (^)(BOOL, NSString *))completion {
    NSString *trimmed = [key stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        if (completion) completion(NO, @"Vui lòng nhập key.");
        return;
    }
    [self postKey:trimmed completion:completion];
}

- (void)refreshWithCompletion:(void (^)(BOOL, NSString *))completion {
    NSString *k = self.keyCode;
    if (!k) { if (completion) completion(NO, @"Chưa có key."); return; }
    [self postKey:k completion:completion];
}

- (void)postKey:(NSString *)key completion:(void (^)(BOOL, NSString *))completion {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:kEndpoint]];
    req.HTTPMethod = @"POST";
    req.timeoutInterval = 15;
    [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

    NSString *body = [NSString stringWithFormat:@"key_code=%@&udid=%@",
                      [self urlEncode:key], [self urlEncode:[self deviceUDID]]];
    req.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        void (^finish)(BOOL, NSString *) = ^(BOOL ok, NSString *msg) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(ok, msg); });
        };

        if (error || !data) {
            finish(NO, @"Lỗi kết nối máy chủ.");
            return;
        }

        NSError *jerrr = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jerrr];
        if (![json isKindOfClass:[NSDictionary class]]) {
            finish(NO, @"Phản hồi máy chủ không hợp lệ.");
            return;
        }

        NSString *status  = json[@"status"];
        NSString *code    = json[@"code"] ?: @"";
        NSString *message = json[@"message"] ?: @"";

        if ([status isEqualToString:@"active"]) {
            NSNumber *secs = json[@"seconds_left"];
            NSTimeInterval left = secs ? secs.doubleValue : 0;
            NSDate *expiry = [NSDate dateWithTimeIntervalSinceNow:left];

            NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
            [d setObject:key forKey:kDefKey];
            [d setDouble:[expiry timeIntervalSince1970] forKey:kDefExpiry];

            finish(YES, message.length ? message : @"Key hợp lệ.");
        } else if ([status isEqualToString:@"expired"]) {
            // vẫn lưu key nhưng hạn = quá khứ để hiển thị "hết hạn"
            NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
            [d setObject:key forKey:kDefKey];
            [d setDouble:[[NSDate date] timeIntervalSince1970] - 1 forKey:kDefExpiry];
            finish(NO, message.length ? message : @"Key đã hết hạn.");
        } else {
            // Server từ chối dứt khoát (sai máy / không tồn tại / bị khoá):
            // XOÁ trạng thái đã lưu để backup mang sang máy khác không còn "active" giả.
            if ([code isEqualToString:@"device_mismatch"] ||
                [code isEqualToString:@"not_found"] ||
                [code isEqualToString:@"banned"]) {
                [weakSelf clearStored];
            }
            finish(NO, message.length ? message : @"Key không hợp lệ.");
        }
    }];
    [task resume];
}

- (void)clearStored {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d removeObjectForKey:kDefKey];
    [d removeObjectForKey:kDefExpiry];
}

- (NSString *)urlEncode:(NSString *)s {
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
                               @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~"];
    return [s stringByAddingPercentEncodingWithAllowedCharacters:allowed];
}

@end
