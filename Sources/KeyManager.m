#import "KeyManager.h"
#import "Endpoints.h"
#import "SecurityPinning.h"
#import "SecurityGuard.h"
#import "ResponseVerifier.h"
#import "LanguageManager.h"
#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import <dlfcn.h>

// ─── Keychain service/account constants ─────────────────────────────────────
// Key code lưu trong Keychain (không phải NSUserDefaults) để chống extract
static NSString *const kKCService  = @"vip.getuid.delta.license";
static NSString *const kKCAccKey   = @"key_code";
static NSString *const kKCAccExp   = @"expiry_epoch";
static NSString *const kKCAccUDID  = @"hw_udid";       // UDID lấy qua profile

// NSUserDefaults keys (legacy — migration)
static NSString *const kDefKey     = @"lk_key";
static NSString *const kDefExpiry  = @"lk_expiry_epoch";

// libMobileGestalt
typedef CFStringRef (*MGCopyAnswer_t)(CFStringRef);
static BOOL sIsHardwareUDID = NO;

@interface KeyManager ()
@property (nonatomic, copy, readwrite) NSString *pendingConfirmKey;
@property (nonatomic, copy, readwrite) NSString *pendingConfirmMessage;
@end

@implementation KeyManager

+ (instancetype)shared {
    static KeyManager *inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [[KeyManager alloc] init]; });
    return inst;
}

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - Keychain helpers
// ─────────────────────────────────────────────────────────────────────────────

- (NSString *)_kcRead:(NSString *)account {
    NSDictionary *q = @{
        (__bridge id)kSecClass:       (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kKCService,
        (__bridge id)kSecAttrAccount: account,
        (__bridge id)kSecReturnData:  @YES,
        (__bridge id)kSecMatchLimit:  (__bridge id)kSecMatchLimitOne
    };
    CFTypeRef out = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)q, &out) == errSecSuccess && out) {
        NSData *d = (__bridge_transfer NSData *)out;
        return [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    }
    return nil;
}

- (void)_kcWrite:(NSString *)value account:(NSString *)account {
    if (!value || !account) return;
    NSData *d = [value dataUsingEncoding:NSUTF8StringEncoding];

    // Delete old first
    NSDictionary *del = @{
        (__bridge id)kSecClass:       (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kKCService,
        (__bridge id)kSecAttrAccount: account,
    };
    SecItemDelete((__bridge CFDictionaryRef)del);

    NSDictionary *add = @{
        (__bridge id)kSecClass:            (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService:      kKCService,
        (__bridge id)kSecAttrAccount:      account,
        (__bridge id)kSecValueData:        d,
        // Không sync iCloud, không backup, gắn với thiết bị
        (__bridge id)kSecAttrAccessible:   (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    };
    SecItemAdd((__bridge CFDictionaryRef)add, NULL);
}

- (void)_kcDelete:(NSString *)account {
    NSDictionary *del = @{
        (__bridge id)kSecClass:       (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kKCService,
        (__bridge id)kSecAttrAccount: account,
    };
    SecItemDelete((__bridge CFDictionaryRef)del);
}

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - Migration: NSUserDefaults → Keychain
// ─────────────────────────────────────────────────────────────────────────────

- (void)_migrateIfNeeded {
    // Nếu Keychain đã có key → không cần migrate
    if ([self _kcRead:kKCAccKey].length > 0) return;

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSString *oldKey = [d stringForKey:kDefKey];
    if (oldKey.length) {
        [self _kcWrite:oldKey account:kKCAccKey];
        double exp = [d doubleForKey:kDefExpiry];
        if (exp > 0) [self _kcWrite:[@(exp) stringValue] account:kKCAccExp];
        // Xoá khỏi NSUserDefaults sau khi migrate
        [d removeObjectForKey:kDefKey];
        [d removeObjectForKey:kDefExpiry];
        [d synchronize];
    }
}

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - Stored state
// ─────────────────────────────────────────────────────────────────────────────

- (NSString *)keyCode {
    [self _migrateIfNeeded];
    return [self _kcRead:kKCAccKey];
}

- (NSDate *)expiry {
    NSString *s = [self _kcRead:kKCAccExp];
    double e = s.doubleValue;
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
    if (self.state == KeyStateNone) return LS(@"Chưa kích hoạt key", @"Key not activated");
    if (s <= 0) return LS(@"Đã hết hạn", @"Expired");
    long total = (long)s;
    long days  = total / 86400;
    long hours = (total % 86400) / 3600;
    long mins  = (total % 3600) / 60;
    if (days > 0)  return [NSString stringWithFormat:LS(@"Còn %ld ngày %ld giờ", @"%ld day(s) %ld hr left"), days, hours];
    if (hours > 0) return [NSString stringWithFormat:LS(@"Còn %ld giờ %ld phút", @"%ld hr %ld min left"), hours, mins];
    return [NSString stringWithFormat:LS(@"Còn %ld phút", @"%ld min left"), mins];
}

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - Device UDID
// ─────────────────────────────────────────────────────────────────────────────
// Thứ tự ưu tiên:
//   0. UDID từ profile (lưu trong Keychain "hw_udid") — gắn phần cứng thật
//   1. MobileGestalt "UniqueDeviceID" — phần cứng, cần entitlement đặc biệt
//   2. identifierForVendor (IDFV) — ổn định theo vendor
//   3. Keychain random UUID ("KC-") — last resort

- (NSString *)deviceUDID {
    static NSString *cached = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // 0. Profile UDID — chắc nhất
        NSString *profUDID = [self _kcRead:kKCAccUDID];
        if (profUDID.length == 40 || profUDID.length == 36) {
            // 40 = hex UDID, 36 = UUID format (thường thấy ở iOS 17+)
            sIsHardwareUDID = YES;
            cached = [@"HW-" stringByAppendingString:profUDID];
            return;
        }

        // 1. MobileGestalt hardware UDID
        NSString *hw = [self readHardwareUDID];
        if (hw.length) {
            sIsHardwareUDID = YES;
            cached = hw;
            return;
        }

        // 2. identifierForVendor
        NSString *idfv = [UIDevice currentDevice].identifierForVendor.UUIDString;
        if (idfv.length) {
            sIsHardwareUDID = NO;
            [self clearKeychainDeviceID];
            cached = [@"IV-" stringByAppendingString:idfv];
            return;
        }

        // 3. Keychain UUID
        sIsHardwareUDID = NO;
        cached = [self keychainDeviceID];
    });
    return cached;
}

- (NSString *)readHardwareUDID {
    NSString *result = nil;
    void *handle = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_NOW);
    if (handle) {
        MGCopyAnswer_t MGCopyAnswer = (MGCopyAnswer_t)dlsym(handle, "MGCopyAnswer");
        if (MGCopyAnswer) {
            CFStringRef udid = MGCopyAnswer(CFSTR("UniqueDeviceID"));
            if (udid) result = (__bridge_transfer NSString *)udid;
        }
    }
    return result.length ? result : nil;
}

// Lưu UDID lấy được từ profile vào Keychain (gọi từ AppDelegate URL handler)
- (void)saveHardwareUDIDFromProfile:(NSString *)udid {
    if (!udid.length) return;
    NSString *clean = [udid stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    // Chấp nhận 40-char hex hoặc 36-char UUID
    if (clean.length != 40 && clean.length != 36) return;
    [self _kcWrite:clean account:kKCAccUDID];
    // Reset cache để lần sau lấy lại từ Keychain
    // (dispatch_once không reset được — sẽ có hiệu lực sau app restart)
}

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
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &out) == errSecSuccess && out) {
        NSData *data = (__bridge_transfer NSData *)out;
        NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (s.length) return s;
    }
    NSString *newID = [@"KC-" stringByAppendingString:[[NSUUID UUID] UUIDString]];
    NSDictionary *add = @{
        (__bridge id)kSecClass:           (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService:     service,
        (__bridge id)kSecAttrAccount:     account,
        (__bridge id)kSecValueData:       [newID dataUsingEncoding:NSUTF8StringEncoding],
        (__bridge id)kSecAttrAccessible:  (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    };
    SecItemDelete((__bridge CFDictionaryRef)add);
    SecItemAdd((__bridge CFDictionaryRef)add, NULL);
    return newID;
}

- (void)clearKeychainDeviceID {
    NSDictionary *del = @{
        (__bridge id)kSecClass:       (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: @"com.imguidelta.license",
        (__bridge id)kSecAttrAccount: @"app_device_id",
    };
    SecItemDelete((__bridge CFDictionaryRef)del);
}

- (BOOL)usingHardwareUDID { [self deviceUDID]; return sIsHardwareUDID; }

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - Networking
// ─────────────────────────────────────────────────────────────────────────────

- (void)activateKey:(NSString *)key completion:(void (^)(BOOL, NSString *))completion {
    NSString *trimmed = [key stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) { if (completion) completion(NO, @"Please enter a key."); return; }
    [self postKey:trimmed completion:completion];
}

- (void)refreshWithCompletion:(void (^)(BOOL, NSString *))completion {
    NSString *k = self.keyCode;
    if (!k) { if (completion) completion(NO, @"No key yet."); return; }
    [self postKey:k completion:completion];
}

- (void)postKey:(NSString *)key completion:(void (^)(BOOL, NSString *))completion {
    [self postKey:key confirm:NO completion:completion];
}

- (void)postKey:(NSString *)key confirm:(BOOL)confirmed
     completion:(void (^)(BOOL, NSString *))completion {
    if (![SecurityGuard isEnvironmentTrusted]) {
        if (completion) completion(NO, @"Server connection error.");
        return;
    }
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:
                                [NSURL URLWithString:EndpointCheckKey()]];
    req.HTTPMethod = @"POST";
    req.timeoutInterval = 15;
    [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

    NSString *ver    = [[NSBundle mainBundle]
                        objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"0";
    NSString *nonce  = [[SecurityPinning shared] installNonce];
    NSString *bldTok = [[SecurityPinning shared] buildTokenForVersion:ver];
    NSString *rawBody = [NSString stringWithFormat:@"key_code=%@&udid=%@&app_ver=%@&inst_nc=%@&bld_tok=%@%@",
                         [self urlEncode:key],
                         [self urlEncode:[self deviceUDID]],
                         [self urlEncode:ver],
                         [self urlEncode:nonce],
                         bldTok,
                         confirmed ? @"&confirm=1" : @""];
    NSString *signedBody = [[SecurityPinning shared] signedBody:rawBody];
    req.HTTPBody = [signedBody dataUsingEncoding:NSUTF8StringEncoding];

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [[SecurityPinning shared].pinnedSession
        dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        void (^finish)(BOOL, NSString *) = ^(BOOL ok, NSString *msg) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(ok, msg); });
        };
        if (error || !data) { finish(NO, @"Server connection error."); return; }

        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![json isKindOfClass:[NSDictionary class]]) {
            finish(NO, @"Invalid server response."); return;
        }

        // Verify response signature — chặn fake JSON local
        if (![ResponseVerifier verifyResponse:json]) {
            finish(NO, @"Server connection error.");
            return;
        }

        NSString *status  = json[@"status"];
        NSString *code    = json[@"code"] ?: @"";
        NSString *message = json[@"message"] ?: @"";

        if ([status isEqualToString:@"active"]) {
            weakSelf.pendingConfirmKey     = nil;
            weakSelf.pendingConfirmMessage = nil;
            NSNumber *secs = json[@"seconds_left"];
            NSTimeInterval left = secs ? secs.doubleValue : 0;
            NSDate *expiry = [NSDate dateWithTimeIntervalSinceNow:left];
            // Lưu vào Keychain (không phải NSUserDefaults)
            [weakSelf _kcWrite:key account:kKCAccKey];
            [weakSelf _kcWrite:[@([expiry timeIntervalSince1970]) stringValue] account:kKCAccExp];
            finish(YES, message.length ? message : @"Key is valid.");

        } else if ([status isEqualToString:@"needs_confirm"]) {
            NSString *confirmMsg = message.length ? message
                : @"Lifetime key will be converted to 3 months. Tap Agree to continue.";
            weakSelf.pendingConfirmKey     = key;
            weakSelf.pendingConfirmMessage = confirmMsg;
            finish(NO, confirmMsg);

        } else if ([status isEqualToString:@"expired"]) {
            weakSelf.pendingConfirmKey     = nil;
            weakSelf.pendingConfirmMessage = nil;
            [weakSelf _kcWrite:key account:kKCAccKey];
            NSDate *past = [NSDate dateWithTimeIntervalSinceNow:-1];
            [weakSelf _kcWrite:[@([past timeIntervalSince1970]) stringValue] account:kKCAccExp];
            finish(NO, message.length ? message : @"Key has expired.");

        } else {
            weakSelf.pendingConfirmKey     = nil;
            weakSelf.pendingConfirmMessage = nil;
            if ([code isEqualToString:@"device_mismatch"] ||
                [code isEqualToString:@"not_found"]       ||
                [code isEqualToString:@"banned"]          ||
                [code isEqualToString:@"wrong_type"]) {
                [weakSelf clearStored];
            }
            finish(NO, message.length ? message : @"Invalid key.");
        }
    }];
    [task resume];
}

- (void)resetBindForKey:(NSString *)key adminPass:(NSString *)pass
            completion:(void (^)(BOOL, NSString *))completion {
    NSString *k = [key stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *p = [pass stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (k.length == 0 || p.length == 0) {
        if (completion) completion(NO, @"Enter key and admin password."); return;
    }
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:
                                [NSURL URLWithString:EndpointResetBind()]];
    req.HTTPMethod = @"POST";
    req.timeoutInterval = 15;
    [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    NSString *rawBody = [NSString stringWithFormat:@"key_code=%@&admin_pass=%@",
                         [self urlEncode:k], [self urlEncode:p]];
    NSString *signedBody = [[SecurityPinning shared] signedBody:rawBody];
    req.HTTPBody = [signedBody dataUsingEncoding:NSUTF8StringEncoding];

    NSURLSessionDataTask *task = [[SecurityPinning shared].pinnedSession
        dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        void (^finish)(BOOL, NSString *) = ^(BOOL ok, NSString *msg) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(ok, msg); });
        };
        if (error || !data) { finish(NO, @"Server connection error."); return; }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![json isKindOfClass:[NSDictionary class]]) { finish(NO, @"Invalid response."); return; }
        BOOL ok = [json[@"status"] isEqualToString:@"ok"];
        finish(ok, json[@"message"] ?: (ok ? @"Reset successful." : @"Failed."));
    }];
    [task resume];
}

- (void)confirmPendingActivationWithCompletion:(void (^)(BOOL, NSString *))completion {
    NSString *key = self.pendingConfirmKey;
    if (!key) { if (completion) completion(NO, @"No pending key to confirm."); return; }
    self.pendingConfirmKey     = nil;
    self.pendingConfirmMessage = nil;
    [self postKey:key confirm:YES completion:completion];
}

- (void)clearStored {
    [self _kcDelete:kKCAccKey];
    [self _kcDelete:kKCAccExp];
    // Không xoá kKCAccUDID — UDID hardware không liên quan đến key
}

- (NSString *)urlEncode:(NSString *)s {
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
                               @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~"];
    return [s stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"";
}

@end
