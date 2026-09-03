#import "DNSBlockManager.h"
#import <NetworkExtension/NetworkExtension.h>

// ── NextDNS config của bạn ────────────────────────────────────────────────────
static NSString *const kNextDNSProfileName = @"IPA Delta Antiband 4.0";
static NSString *const kNextDNSDoHURL      = @"https://dns.nextdns.io/1a48d7";
static NSString *const kNextDNSDoTHost     = @"1a48d7.dns.nextdns.io";

@interface DNSBlockManager ()
@end

@implementation DNSBlockManager

+ (instancetype)shared {
    static DNSBlockManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

// ── Refresh trạng thái từ hệ thống ───────────────────────────────────────────
// isEnabled = profile đã cài VÀ đang được chọn trong Settings > DNS
// Fallback: nếu NEDNSSettingsManager không detect được (IPC failed, beta iOS, cert issue...)
// thì query test.nextdns.io để xác nhận DNS thật sự đang active

- (void)refreshStatusWithCompletion:(void(^)(BOOL installed, BOOL active))completion {
    if (@available(iOS 14.0, *)) {
        [NEDNSSettingsManager.sharedManager loadFromPreferencesWithCompletionHandler:^(NSError *err) {
            NEDNSSettingsManager *mgr = NEDNSSettingsManager.sharedManager;
            BOOL installed = (mgr.dnsSettings != nil);
            BOOL active    = installed && mgr.isEnabled;

            if (active) {
                // NEDNSSettingsManager xác nhận active → dùng luôn
                self.isEnabled = YES;
                if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(YES, YES); });
            } else {
                // Fallback: query test.nextdns.io để detect DNS cài thủ công qua mobileconfig
                // hoặc khi iOS beta trả "Không xác định" (installed=YES nhưng isEnabled=NO)
                [self _checkNextDNSActiveWithCompletion:^(BOOL nextdnsActive) {
                    // installed = YES nếu NEDNSSettingsManager thấy profile CẦN hoặc nextdns active
                    BOOL finalInstalled = installed || nextdnsActive;
                    BOOL finalActive    = nextdnsActive; // chỉ active khi nextdns xác nhận
                    self.isEnabled = finalActive;
                    if (completion) dispatch_async(dispatch_get_main_queue(), ^{
                        completion(finalInstalled, finalActive);
                    });
                }];
            }
        }];
    } else {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, NO); });
    }
}

// ── Query test.nextdns.io — trả YES nếu device đang dùng NextDNS profile 1a48d7 ──
- (void)_checkNextDNSActiveWithCompletion:(void(^)(BOOL active))completion {
    NSURL *url = [NSURL URLWithString:@"https://test.nextdns.io"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.timeoutInterval = 4.0;
    req.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;

    // Dùng ephemeral session để tránh cache — kết quả phải reflect DNS hiện tại
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    NSURLSessionDataTask *task = [session
        dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error || !data) {
                NSLog(@"[DNSBlock] test.nextdns.io ERROR: %@", error.localizedDescription);
                if (completion) completion(NO); return;
            }
            NSString *rawStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSLog(@"[DNSBlock] test.nextdns.io RAW: %@", rawStr);
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (![json isKindOfClass:[NSDictionary class]]) {
                NSLog(@"[DNSBlock] test.nextdns.io parse failed");
                if (completion) completion(NO); return;
            }
            NSString *status = json[@"status"];
            NSString *destIP = json[@"destIP"];
            BOOL isNextDNS = [destIP hasPrefix:@"45.90.28."] || [destIP hasPrefix:@"45.90.30."];
            BOOL active = [status isEqualToString:@"ok"] && isNextDNS;
            NSLog(@"[DNSBlock] test.nextdns.io status=%@ destIP=%@ isNextDNS=%d active=%d", status, destIP, isNextDNS, active);
            if (completion) completion(active);
        }];
    [task resume];
}

// ── Cài DNS profile (chưa tự bật — user phải vào Settings chọn) ──────────────
// Xoá profile cũ trước để tránh lỗi "configuration is unchanged"

- (void)enableWithCompletion:(DNSBlock)completion {
    if (@available(iOS 14.0, *)) {
        NEDNSSettingsManager *mgr = NEDNSSettingsManager.sharedManager;
        [mgr loadFromPreferencesWithCompletionHandler:^(NSError *loadErr) {
            if (loadErr) {
                if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, loadErr); });
                return;
            }

            void(^doSave)(void) = ^{
                NEDNSOverHTTPSSettings *doh = [[NEDNSOverHTTPSSettings alloc] init];
                doh.serverURL = [NSURL URLWithString:kNextDNSDoHURL];
                mgr.dnsSettings          = doh;
                mgr.localizedDescription = kNextDNSProfileName;
                [mgr saveToPreferencesWithCompletionHandler:^(NSError *saveErr) {
                    self.isEnabled = NO;
                    if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(saveErr == nil, saveErr); });
                }];
            };

            // Nếu đã có profile cũ → xoá trước để tránh "configuration is unchanged"
            if (mgr.dnsSettings != nil) {
                [mgr removeFromPreferencesWithCompletionHandler:^(NSError *removeErr) {
                    doSave();
                }];
            } else {
                doSave();
            }
        }];
    } else {
        NSError *err = [NSError errorWithDomain:@"DNSBlock" code:0
            userInfo:@{NSLocalizedDescriptionKey: @"Cần iOS 14.0 trở lên"}];
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, err); });
    }
}

// ── Tắt DNS profile ───────────────────────────────────────────────────────────

- (void)disableWithCompletion:(DNSBlock)completion {
    if (@available(iOS 14.0, *)) {
        NEDNSSettingsManager *mgr = NEDNSSettingsManager.sharedManager;
        [mgr loadFromPreferencesWithCompletionHandler:^(NSError *loadErr) {
            if (loadErr || !mgr.dnsSettings) {
                // Profile không tồn tại — coi như đã tắt
                self.isEnabled = NO;
                if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(YES, nil); });
                return;
            }
            [mgr removeFromPreferencesWithCompletionHandler:^(NSError *removeErr) {
                self.isEnabled = NO;
                if (completion) dispatch_async(dispatch_get_main_queue(), ^{
                    completion(removeErr == nil, removeErr);
                });
            }];
        }];
    } else {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(YES, nil); });
    }
}

@end
