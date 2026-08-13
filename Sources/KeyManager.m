#import "KeyManager.h"
#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import <dlfcn.h>

static NSString *const kEndpoint      = @"https://getuid.vip/check_key.php";
static NSString *const kResetEndpoint = @"https://getuid.vip/reset_bind.php";
static NSString *const kDefKey     = @"lk_key";
static NSString *const kDefExpiry  = @"lk_expiry_epoch";   // absolute expiry (seconds since 1970)

// libMobileGestalt — đọc UDID phần cứng thật
typedef CFStringRef (*MGCopyAnswer_t)(CFStringRef);

static BOOL sIsHardwareUDID = NO;   // đọc được UDID thật hay không

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

#pragma mark - Device id

// Ưu tiên UDID phần cứng thật (TrollStore). Nếu ký eSign (sandbox) không đọc được
// thì dùng ID cố định lưu trong Keychain (ThisDeviceOnly):
//   - Sống qua xoá app cài lại (keychain không bị xoá theo app).
//   - KHÔNG theo backup sang máy khác (ThisDeviceOnly) → chống chia sẻ key.
- (NSString *)deviceUDID {
    static NSString *cached = nil;   // cache RAM theo tiến trình
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *hw = [self readHardwareUDID];
        if (hw.length) {
            sIsHardwareUDID = YES;
            cached = hw;
        } else {
            sIsHardwareUDID = NO;
            cached = [self keychainDeviceID];
        }
    });
    return cached;
}

// Trả UDID phần cứng qua MobileGestalt, hoặc nil nếu không đọc được (sandbox eSign).
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
    }
    return result.length ? result : nil;
}

// ID cố định trong Keychain — sinh 1 lần, tái dùng mãi. Prefix "KC-" để phân biệt.
- (NSString *)keychainDeviceID {
    NSString *service = @"com.imguidelta.license";
    NSString *account = @"app_device_id";

    NSDictionary *query = @{
        (__bridge id)kSecClass:       (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: service,
        (__bridge id)kSecAttrAccount: account,
        (__bridge id)kSecReturnData:  @YES,
        (__bridge id)kSecMatchLimit:  (__bridge id)kSecMatchLimitOne
    };

    CFTypeRef out = NULL;
    OSStatus st = SecItemCopyMatching((__bridge CFDictionaryRef)query, &out);
    if (st == errSecSuccess && out) {
        NSData *data = (__bridge_transfer NSData *)out;
        NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (s.length) return s;
    }

    // Chưa có → sinh mới và lưu
    NSString *newID = [@"KC-" stringByAppendingString:[[NSUUID UUID] UUIDString]];
    NSDictionary *add = @{
        (__bridge id)kSecClass:       (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: service,
        (__bridge id)kSecAttrAccount: account,
        (__bridge id)kSecValueData:   [newID dataUsingEncoding:NSUTF8StringEncoding],
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    };
    SecItemDelete((__bridge CFDictionaryRef)add); // đảm bảo không trùng
    SecItemAdd((__bridge CFDictionaryRef)add, NULL);
    return newID;
}

- (BOOL)usingHardwareUDID {
    [self deviceUDID];   // đảm bảo đã tính (dispatch_once)
    return sIsHardwareUDID;
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

- (void)resetBindForKey:(NSString *)key adminPass:(NSString *)pass completion:(void (^)(BOOL, NSString *))completion {
    NSString *k = [key stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *p = [pass stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (k.length == 0 || p.length == 0) {
        if (completion) completion(NO, @"Nhập đủ key và mật khẩu admin.");
        return;
    }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:kResetEndpoint]];
    req.HTTPMethod = @"POST";
    req.timeoutInterval = 15;
    [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    NSString *body = [NSString stringWithFormat:@"key_code=%@&admin_pass=%@",
                      [self urlEncode:k], [self urlEncode:p]];
    req.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        void (^finish)(BOOL, NSString *) = ^(BOOL ok, NSString *msg) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(ok, msg); });
        };
        if (error || !data) { finish(NO, @"Lỗi kết nối máy chủ."); return; }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![json isKindOfClass:[NSDictionary class]]) { finish(NO, @"Phản hồi không hợp lệ."); return; }
        BOOL ok = [json[@"status"] isEqualToString:@"ok"];
        finish(ok, json[@"message"] ?: (ok ? @"Đã reset." : @"Thất bại."));
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
