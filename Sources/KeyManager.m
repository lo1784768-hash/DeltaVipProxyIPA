#import "KeyManager.h"
#import <UIKit/UIKit.h>

static NSString *const kEndpoint   = @"https://getuid.vip/check_key.php";
static NSString *const kDefKey     = @"lk_key";
static NSString *const kDefExpiry  = @"lk_expiry_epoch";   // absolute expiry (seconds since 1970)
static NSString *const kDefUDID    = @"lk_udid";

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

- (NSString *)deviceUDID {
    NSString *stored = [[NSUserDefaults standardUserDefaults] stringForKey:kDefUDID];
    if (stored.length) return stored;

    NSString *idfv = [[UIDevice currentDevice].identifierForVendor UUIDString];
    if (!idfv.length) idfv = [[NSUUID UUID] UUIDString];
    [[NSUserDefaults standardUserDefaults] setObject:idfv forKey:kDefUDID];
    return idfv;
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
            finish(NO, message.length ? message : @"Key không hợp lệ.");
        }
        (void)weakSelf;
    }];
    [task resume];
}

- (NSString *)urlEncode:(NSString *)s {
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
                               @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~"];
    return [s stringByAddingPercentEncodingWithAllowedCharacters:allowed];
}

@end
