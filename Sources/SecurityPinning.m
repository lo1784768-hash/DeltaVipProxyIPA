#import "SecurityPinning.h"
#import <Security/Security.h>
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonDigest.h>

// ─────────────────────────────────────────────────────────────────────────────
// SSL Pin — Let's Encrypt Intermediate CA (index 1 trong chain)
// YR1 valid đến Sep 2028 — không cần update khi leaf cert tự renew mỗi 90 ngày
// ─────────────────────────────────────────────────────────────────────────────
static NSString * const kPinnedHashes[] = {
    @"E5SWNNmc1v1qqAvANP76zOsZaf7vmGWGcT7NuwV1jT8=",  // LE YR1 → Sep 2028
};
static const NSUInteger kPinnedHashCount = 1;

// ─────────────────────────────────────────────────────────────────────────────
// HMAC-SHA256 Key — 4-segment multi-method obfuscation
//
// Mỗi segment dùng phương pháp encode KHÁC NHAU:
//   Seg A (0-7):  XOR với key_A
//   Seg B (8-15): Addition mod 256
//   Seg C (16-23): ROR5 (rotate right 5-bit trong 8-bit)
//   Seg D (24-31): XOR với key_D (khác key_A)
//
// Scatter 4 hàm riêng biệt + noinline + optnone → IDA phải trace từng hàm
// __attribute__((optnone)) ngăn compiler đơn giản hoá thành hằng số
// ─────────────────────────────────────────────────────────────────────────────

// ── Segment A: XOR ──────────────────────────────────────────────────────────
__attribute__((noinline, optnone))
static void __sg_hmac_seg_a(volatile uint8_t out[8]) {
    static const volatile uint8_t enc[8] = {0x3E,0xFA,0xD8,0x4B,0x45,0x5B,0xD6,0xFF};
    static const volatile uint8_t key[8] = {0x5A,0xC9,0xB4,0x3F,0x71,0x28,0xE5,0x9C};
    for (volatile int i = 0; i < 8; i++) out[i] = enc[i] ^ key[i];
}

// ── Segment B: Subtraction mod 256 ──────────────────────────────────────────
__attribute__((noinline, optnone))
static void __sg_hmac_seg_b(volatile uint8_t out[8]) {
    static const volatile uint8_t enc[8] = {0x8C,0xF4,0x7F,0xFC,0x91,0x9C,0x39,0xEF};
    static const volatile uint8_t add[8] = {0x17,0x82,0x4C,0x91,0x5E,0x23,0x07,0xBF};
    for (volatile int i = 0; i < 8; i++)
        out[i] = (uint8_t)((enc[i] - add[i] + 256) & 0xFF);
}

// ── Segment C: ROL5 (undo ROR5 encoding) ─────────────────────────────────────
__attribute__((noinline, optnone))
static void __sg_hmac_seg_c(volatile uint8_t out[8]) {
    static const volatile uint8_t enc[8] = {0x91,0xB1,0x09,0x02,0x19,0x21,0x29,0xF2};
    // Decode: ROL5(v) = (v << 5) | (v >> 3) & 0xFF
    for (volatile int i = 0; i < 8; i++)
        out[i] = (uint8_t)(((enc[i] << 5) | (enc[i] >> 3)) & 0xFF);
}

// ── Segment D: XOR với key lạ ────────────────────────────────────────────────
__attribute__((noinline, optnone))
static void __sg_hmac_seg_d(volatile uint8_t out[8]) {
    static const volatile uint8_t enc[8] = {0xD6,0x27,0xF8,0x46,0x8D,0x7B,0x65,0x85};
    static const volatile uint8_t key[8] = {0xF0,0x0D,0xD0,0x0F,0xC0,0x3C,0x30,0xCC};
    for (volatile int i = 0; i < 8; i++) out[i] = enc[i] ^ key[i];
}

// ── Combine → HMAC secret ───────────────────────────────────────────────────
static NSData *hmacSecret(void) {
    static NSData *secret;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        volatile uint8_t raw[32];
        __sg_hmac_seg_a(raw + 0);
        __sg_hmac_seg_b(raw + 8);
        __sg_hmac_seg_c(raw + 16);
        __sg_hmac_seg_d(raw + 24);
        // Copy ra non-volatile buffer cho NSData
        uint8_t buf[32];
        for (int i = 0; i < 32; i++) buf[i] = raw[i];
        // Xoá raw khỏi stack ngay sau khi copy
        memset((void *)raw, 0, sizeof(raw));
        secret = [NSData dataWithBytes:buf length:32];
        memset(buf, 0, 32);
    });
    return secret;
}

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

        // Tắt system proxy → chặn ProxyPin / mitmproxy / Charles
        cfg.connectionProxyDictionary = @{};

        // Ép TLS 1.2 tối thiểu
        if (@available(iOS 13, *)) {
            cfg.TLSMinimumSupportedProtocolVersion = tls_protocol_version_TLSv12;
        }

        _session = [NSURLSession sessionWithConfiguration:cfg
                                                 delegate:self
                                            delegateQueue:nil];
    });
    return _session;
}

#pragma mark - HMAC signing

- (NSString *)signedBody:(NSString *)rawBody {
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

    // Bước 1: Validate chain CA
    CFErrorRef cfErr = NULL;
    BOOL chainOK = SecTrustEvaluateWithError(trust, &cfErr);
    if (cfErr) CFRelease(cfErr);
    if (!chainOK) {
        completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
        return;
    }

    // Bước 2: Pin INTERMEDIATE CA (index 1) — không phải leaf (đổi mỗi 90 ngày)
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
            NSURLCredential *cred = [NSURLCredential credentialForTrust:trust];
            completionHandler(NSURLSessionAuthChallengeUseCredential, cred);
            return;
        }
    }

    // Cert không khớp → từ chối im lặng
    completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
}

@end
