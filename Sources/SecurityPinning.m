#import "SecurityPinning.h"
#import <Security/Security.h>
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonDigest.h>

// ─────────────────────────────────────────────────────────────────────────────
// SSL Pin — Let's Encrypt Intermediate CA (tự động, không cần update khi renew)
// ─────────────────────────────────────────────────────────────────────────────
//
// Pin vào INTERMEDIATE CA (cert index 1 trong chain) thay vì leaf cert:
//   - Leaf cert đổi mỗi 90 ngày (Let's Encrypt auto-renew) → cần update app liên tục
//   - Intermediate "YR1" giữ nguyên đến Sep 2028 → không cần làm gì cả
//
// Khi nào cần update: Let's Encrypt đổi intermediate (vài năm/lần, họ thông báo trước)
// Lấy hash intermediate mới (khi cần):
//   echo | openssl s_client -connect getuid.vip:443 -showcerts 2>/dev/null \
//     | awk '/-----BEGIN CERTIFICATE-----/{c++} c==2{print}' \
//     | openssl x509 -outform DER | openssl dgst -sha256 -binary | base64

static NSString * const kPinnedHashes[] = {
    @"E5SWNNmc1v1qqAvANP76zOsZaf7vmGWGcT7NuwV1jT8=",  // Let's Encrypt YR1 (valid đến Sep 2028)
};
static const NSUInteger kPinnedHashCount = 1;

// ─────────────────────────────────────────────────────────────────────────────
// HMAC-SHA256 Secret (XOR-obfuscated — không lộ plaintext trong binary)
// ─────────────────────────────────────────────────────────────────────────────
//
// Secret sau khi decode: "d3lt4s3cur3k3y2026!@#$%^&*(IMGUI"
// PHẢI khớp với $HMAC_SECRET trong check_key.php.
// Đổi sang bytes random mới khi production (rồi cập nhật check_key.php).

static const uint8_t kHmacXor[8] = {
    0xA3, 0x7F, 0x2C, 0x91, 0xE4, 0x58, 0xB6, 0x1D
};
static const uint8_t kHmacEnc[32] = {
    0xC7, 0x4C, 0x40, 0xE5, 0xD0, 0x2B, 0x85, 0x7E,
    0xD6, 0x0D, 0x1F, 0xFA, 0xD7, 0x21, 0x84, 0x2D,
    0x91, 0x49, 0x0D, 0xD1, 0xC7, 0x7C, 0x93, 0x43,
    0x85, 0x55, 0x04, 0xD8, 0xA9, 0x1F, 0xE3, 0x54
};

// ─────────────────────────────────────────────────────────────────────────────

@implementation SecurityPinning {
    NSURLSession *_session;
}

+ (instancetype)shared {
    static SecurityPinning *inst;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [SecurityPinning new]; });
    return inst;
}

- (NSURLSession *)pinnedSession {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
        cfg.timeoutIntervalForRequest  = 15;
        cfg.timeoutIntervalForResource = 30;
        _session = [NSURLSession sessionWithConfiguration:cfg
                                                 delegate:self
                                            delegateQueue:nil];
    });
    return _session;
}

#pragma mark - HMAC signing

static NSData *hmacSecret(void) {
    static NSData *secret;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableData *d = [NSMutableData dataWithLength:sizeof(kHmacEnc)];
        uint8_t *b = d.mutableBytes;
        for (NSUInteger i = 0; i < sizeof(kHmacEnc); i++)
            b[i] = kHmacEnc[i] ^ kHmacXor[i % sizeof(kHmacXor)];
        secret = [d copy];
    });
    return secret;
}

- (NSString *)signedBody:(NSString *)rawBody {
    // ts = unix timestamp (giây), dùng để chặn replay attack (server từ chối > 5 phút)
    NSString *ts  = [NSString stringWithFormat:@"%lld",
                     (long long)[[NSDate date] timeIntervalSince1970]];
    NSString *msg = [NSString stringWithFormat:@"%@&ts=%@", rawBody, ts];

    NSData *key  = hmacSecret();
    NSData *data = [msg dataUsingEncoding:NSUTF8StringEncoding];

    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, key.bytes, key.length, data.bytes, data.length, digest);

    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++)
        [hex appendFormat:@"%02x", digest[i]];

    return [NSString stringWithFormat:@"%@&sig=%@", msg, hex];
}

#pragma mark - NSURLSessionDelegate — SSL Pinning

- (void)URLSession:(NSURLSession *)session
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition,
                             NSURLCredential * _Nullable))completionHandler {

    // Chỉ xử lý server trust challenge
    if (![challenge.protectionSpace.authenticationMethod
          isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
        return;
    }

    SecTrustRef trust = challenge.protectionSpace.serverTrust;
    if (!trust) {
        completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
        return;
    }

    // Bước 1: Validate trust chain (CA chuẩn)
    CFErrorRef cfErr = NULL;
    BOOL chainOK = SecTrustEvaluateWithError(trust, &cfErr);
    if (cfErr) CFRelease(cfErr);
    if (!chainOK) {
        completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
        return;
    }

    // Bước 2: So sánh INTERMEDIATE CA cert SHA-256 với danh sách pin
    // Index 0 = leaf (đổi mỗi 90 ngày), Index 1 = intermediate (ổn định vài năm)
    CFIndex certCount = SecTrustGetCertificateCount(trust);
    if (certCount < 2) {
        completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
        return;
    }
    SecCertificateRef cert = SecTrustGetCertificateAtIndex(trust, 1);
    if (!cert) {
        completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
        return;
    }

    NSData *derData = (__bridge_transfer NSData *)SecCertificateCopyData(cert);
    if (!derData) {
        completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
        return;
    }

    uint8_t sha[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(derData.bytes, (CC_LONG)derData.length, sha);
    NSString *b64 = [[NSData dataWithBytes:sha length:CC_SHA256_DIGEST_LENGTH]
                     base64EncodedStringWithOptions:0];

    for (NSUInteger i = 0; i < kPinnedHashCount; i++) {
        if ([kPinnedHashes[i] isEqualToString:b64]) {
            // Cert khớp — cho phép kết nối
            NSURLCredential *cred = [NSURLCredential credentialForTrust:trust];
            completionHandler(NSURLSessionAuthChallengeUseCredential, cred);
            return;
        }
    }

    // Cert không nằm trong danh sách pin → từ chối im lặng
    // (App sẽ hiện "Lỗi kết nối máy chủ" — không lộ lý do)
    completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
}

@end
