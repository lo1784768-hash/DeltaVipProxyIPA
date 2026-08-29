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
// Decodes: "D3ltaPr0" (bytes 0-7 of HMAC secret, rotated v1.3.7)
__attribute__((noinline, optnone))
static void __sg_hmac_seg_a(volatile uint8_t out[8]) {
    static const volatile uint8_t enc[8] = {0xDB,0x6E,0x44,0x95,0x65,0xEC,0xDD,0x43};
    static const volatile uint8_t key[8] = {0x9F,0x5D,0x28,0xE1,0x04,0xBC,0xAF,0x73};
    for (volatile int i = 0; i < 8; i++) out[i] = enc[i] ^ key[i];
}

// ── Segment B: Subtraction mod 256 ──────────────────────────────────────────
// Decodes: "xyV1P_S3" (bytes 8-15)
__attribute__((noinline, optnone))
static void __sg_hmac_seg_b(volatile uint8_t out[8]) {
    static const volatile uint8_t enc[8] = {0x3C,0x91,0x3D,0xD3,0x5B,0xB5,0x44,0x80};
    static const volatile uint8_t add[8] = {0xC4,0x18,0xE7,0xA2,0x0B,0x56,0xF1,0x4D};
    for (volatile int i = 0; i < 8; i++)
        out[i] = (uint8_t)((enc[i] - add[i] + 256) & 0xFF);
}

// ── Segment C: ROL5 (undo ROR5 encoding) ─────────────────────────────────────
// Decodes: "cr3t_K3y" (bytes 16-23)
__attribute__((noinline, optnone))
static void __sg_hmac_seg_c(volatile uint8_t out[8]) {
    static const volatile uint8_t enc[8] = {0x1B,0x93,0x99,0xA3,0xFA,0x5A,0x99,0xCB};
    // Decode: ROL5(v) = (v << 5) | (v >> 3) & 0xFF
    for (volatile int i = 0; i < 8; i++)
        out[i] = (uint8_t)(((enc[i] << 5) | (enc[i] >> 3)) & 0xFF);
}

// ── Segment D: XOR với key lạ ────────────────────────────────────────────────
// Decodes: "_2026!xQ" (bytes 24-31)
__attribute__((noinline, optnone))
static void __sg_hmac_seg_d(volatile uint8_t out[8]) {
    static const volatile uint8_t enc[8] = {0x61,0xB9,0x77,0xAE,0x57,0xD4,0x72,0x87};
    static const volatile uint8_t key[8] = {0x3E,0x8B,0x47,0x9C,0x61,0xF5,0x0A,0xD6};
    for (volatile int i = 0; i < 8; i++) out[i] = enc[i] ^ key[i];
}

// ── Build Token Secret (secondary HMAC, layer 2 anticrack) ───────────────────
// "bLd_T0k_V1P!2026" (16 bytes) — XOR obfuscated, scheme khác 4-seg ở trên
// Crack cần tìm THÊM secret này ngoài secret HMAC chính
__attribute__((noinline, optnone))
static void __sg_bld_secret(volatile uint8_t out[16]) {
    static const volatile uint8_t enc[16] = {
        0xC5,0x73,0x7D,0xBB,0xD6,0xF6,0x66,0x0E,
        0xE5,0xC4,0x2C,0x0B,0xAC,0x71,0xBF,0xFC
    };
    static const volatile uint8_t key[16] = {
        0xA7,0x3F,0x19,0xE4,0x82,0xC6,0x0D,0x51,
        0xB3,0xF5,0x7C,0x2A,0x9E,0x41,0x8D,0xCA
    };
    for (volatile int i = 0; i < 16; i++) out[i] = enc[i] ^ key[i];
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

// ── Install nonce — sinh 1 lần khi cài app, lưu Keychain, không bao giờ ra ngoài ──
// Cracker dù biết bld_secret cũng không tính được bld_tok vì không biết nonce của device
- (NSString *)installNonce {
    static NSString *nonce = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *svc = @"vip.getuid.delta.install";
        NSString *acc = @"inst_nc";
        NSDictionary *q = @{
            (__bridge id)kSecClass:       (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecAttrService: svc,
            (__bridge id)kSecAttrAccount: acc,
            (__bridge id)kSecReturnData:  @YES,
            (__bridge id)kSecMatchLimit:  (__bridge id)kSecMatchLimitOne
        };
        CFTypeRef out = NULL;
        if (SecItemCopyMatching((__bridge CFDictionaryRef)q, &out) == errSecSuccess && out) {
            NSData *d = (__bridge_transfer NSData *)out;
            nonce = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
        }
        if (!nonce.length) {
            // Sinh nonce mới — 32 hex bytes
            uint8_t rnd[16];
            arc4random_buf(rnd, sizeof(rnd));
            NSMutableString *s = [NSMutableString stringWithCapacity:32];
            for (int i = 0; i < 16; i++) [s appendFormat:@"%02x", rnd[i]];
            nonce = [s copy];

            NSData *nd = [nonce dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *add = @{
                (__bridge id)kSecClass:          (__bridge id)kSecClassGenericPassword,
                (__bridge id)kSecAttrService:    svc,
                (__bridge id)kSecAttrAccount:    acc,
                (__bridge id)kSecValueData:      nd,
                (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            };
            SecItemAdd((__bridge CFDictionaryRef)add, NULL);
        }
    });
    return nonce ?: @"fallback-nonce";
}

// Build token = HMAC-SHA256(build_secret, "app_ver:install_nonce")
// Server không verify nonce (không biết) — chỉ verify HMAC
// Mục tiêu: cracker phải extract nonce từ Keychain của từng device → không thể patch chung 1 IPA
- (NSString *)buildTokenForVersion:(NSString *)appVer {
    volatile uint8_t raw[16];
    __sg_bld_secret(raw);

    uint8_t bsec[16];
    for (int i = 0; i < 16; i++) bsec[i] = raw[i];
    memset((void *)raw, 0, sizeof(raw));

    // Mix app_ver + install_nonce vào message
    NSString *nonce  = [self installNonce];
    NSString *msg    = [NSString stringWithFormat:@"%@:%@", appVer, nonce];
    NSData *keyData  = [NSData dataWithBytes:bsec length:16];
    NSData *msgData  = [msg dataUsingEncoding:NSUTF8StringEncoding];

    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, keyData.bytes, keyData.length,
           msgData.bytes, msgData.length, digest);

    memset(bsec, 0, 16);

    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++)
        [hex appendFormat:@"%02x", digest[i]];
    return hex;
}

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
