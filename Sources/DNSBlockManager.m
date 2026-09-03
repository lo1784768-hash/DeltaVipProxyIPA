#import "DNSBlockManager.h"
#import <NetworkExtension/NetworkExtension.h>

// ── NextDNS config của bạn ────────────────────────────────────────────────────
static NSString *const kNextDNSProfileName = @"Delta Proxy — DNS Filter";
static NSString *const kNextDNSDoHURL      = @"https://dns.nextdns.io/1a48d7";
static NSString *const kNextDNSDoTHost     = @"1a48d7.dns.nextdns.io";

@interface DNSBlockManager ()
@property (nonatomic, assign) BOOL isEnabled;
@end

@implementation DNSBlockManager

+ (instancetype)shared {
    static DNSBlockManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

// ── Refresh trạng thái từ hệ thống ───────────────────────────────────────────

- (void)refreshStatusWithCompletion:(void(^)(BOOL enabled))completion {
    if (@available(iOS 14.0, *)) {
        [NEDNSSettingsManager.sharedManager loadFromPreferencesWithCompletionHandler:^(NSError *err) {
            BOOL on = (NEDNSSettingsManager.sharedManager.dnsSettings != nil)
                   && NEDNSSettingsManager.sharedManager.isEnabled;
            self.isEnabled = on;
            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(on); });
        }];
    } else {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO); });
    }
}

// ── Bật DNS profile ───────────────────────────────────────────────────────────

- (void)enableWithCompletion:(DNSBlock)completion {
    if (@available(iOS 14.0, *)) {
        NEDNSSettingsManager *mgr = NEDNSSettingsManager.sharedManager;
        [mgr loadFromPreferencesWithCompletionHandler:^(NSError *loadErr) {
            if (loadErr) {
                if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, loadErr); });
                return;
            }

            // Tạo DoH settings trỏ về NextDNS
            NEDNSOverHTTPSSettings *doh = [[NEDNSOverHTTPSSettings alloc] init];
            doh.serverURL = [NSURL URLWithString:kNextDNSDoHURL];

            mgr.dnsSettings  = doh;
            mgr.localizedDescription = kNextDNSProfileName;

            [mgr saveToPreferencesWithCompletionHandler:^(NSError *saveErr) {
                if (saveErr) {
                    if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, saveErr); });
                    return;
                }
                // Sau khi save, bật lên
                [mgr loadFromPreferencesWithCompletionHandler:^(NSError *e2) {
                    self.isEnabled = YES;
                    if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(YES, nil); });
                }];
            }];
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
