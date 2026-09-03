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

// ── Query test.nextdns.io — trả YES nếu device đang dùng NextDNS ──────────────
// test.nextdns.io trả HTML+JS redirect sang subdomain ngẫu nhiên,
// cần parse subdomain rồi request lại để lấy JSON thật.
- (void)_checkNextDNSActiveWithCompletion:(void(^)(BOOL active))completion {
    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg];

    NSURL *url = [NSURL URLWithString:@"https://test.nextdns.io"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.timeoutInterval = 6.0;
    req.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;

    NSURLSessionDataTask *task = [session dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error || !data) {
                NSLog(@"[DNSBlock] step1 ERROR: %@", error.localizedDescription);
                if (completion) completion(NO); return;
            }
            NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

            // Parse subdomain từ: xhr.open('GET', 'https://XXXX.test.nextdns.io/', false);
            NSRegularExpression *re = [NSRegularExpression
                regularExpressionWithPattern:@"'GET',\\s*'(https://[^']+\\.test\\.nextdns\\.io/[^']*)'"
                options:0 error:nil];
            NSTextCheckingResult *match = [re firstMatchInString:html options:0
                range:NSMakeRange(0, html.length)];
            if (!match || match.numberOfRanges < 2) {
                NSLog(@"[DNSBlock] step1 no subdomain found in: %@", html);
                if (completion) completion(NO); return;
            }
            NSString *subURL = [html substringWithRange:[match rangeAtIndex:1]];
            NSLog(@"[DNSBlock] step1 subdomain URL: %@", subURL);

            // Request subdomain để lấy JSON thật
            NSMutableURLRequest *req2 = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:subURL]];
            req2.timeoutInterval = 6.0;
            req2.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
            // Thêm Accept: application/json để NextDNS trả JSON thay vì HTML
            [req2 setValue:@"application/json" forHTTPHeaderField:@"Accept"];

            [[session dataTaskWithRequest:req2
                completionHandler:^(NSData *data2, NSURLResponse *resp2, NSError *err2) {
                    if (err2 || !data2) {
                        NSLog(@"[DNSBlock] step2 ERROR: %@", err2.localizedDescription);
                        if (completion) completion(NO); return;
                    }
                    NSString *raw2 = [[NSString alloc] initWithData:data2 encoding:NSUTF8StringEncoding];
                    NSLog(@"[DNSBlock] step2 RAW: %@", raw2);
                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data2 options:0 error:nil];
                    if (![json isKindOfClass:[NSDictionary class]]) {
                        NSLog(@"[DNSBlock] step2 parse failed");
                        if (completion) completion(NO); return;
                    }
                    NSString *status = json[@"status"];
                    NSString *destIP = json[@"destIP"];
                    BOOL isNextDNS = [destIP hasPrefix:@"45.90.28."] || [destIP hasPrefix:@"45.90.30."];
                    BOOL active = [status isEqualToString:@"ok"] && isNextDNS;
                    NSLog(@"[DNSBlock] step2 status=%@ destIP=%@ isNextDNS=%d active=%d", status, destIP, isNextDNS, active);
                    if (completion) completion(active);
                }] resume];
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
