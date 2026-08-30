#import "ResponseVerifier.h"
#import "SecurityGuard.h"
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonDigest.h>

// ─── Response HMAC secret — 3-segment obfuscation, scheme khác request HMAC ───
// Giải mã: "Rsp_V3r1fy_D3ltA!2026#kQ"
// Seg A (0–7): XOR — decodes bytes 0-7 of response HMAC secret
__attribute__((noinline, optnone))
static void __rv_seg_a(volatile uint8_t out[8]) {
    static const volatile uint8_t enc[8] = {0xE0,0xCD,0x01,0x81,0x97,0x04,0x82,0x02};
    static const volatile uint8_t key[8] = {0xB2,0xBE,0x71,0xDE,0xC1,0x37,0xF0,0x33};
    for (volatile int i = 0; i < 8; i++) out[i] = enc[i] ^ key[i];
}
// Seg B (8–15): subtraction mod 256 — decodes bytes 8-15
__attribute__((noinline, optnone))
static void __rv_seg_b(volatile uint8_t out[8]) {
    static const volatile uint8_t enc[8] = {0xA9,0x3B,0x9F,0x25,0xFD,0x7F,0xE2,0x24};
    static const volatile uint8_t sub[8] = {0x43,0xC2,0x40,0xE1,0xCA,0x13,0x6E,0xE3};
    for (volatile int i = 0; i < 8; i++)
        out[i] = (uint8_t)((enc[i] - sub[i] + 256) & 0xFF);
}
// Seg C (16–23): ROL3 (decode = shift left 3) — decodes bytes 16-23
__attribute__((noinline, optnone))
static void __rv_seg_c(volatile uint8_t out[8]) {
    static const volatile uint8_t enc[8] = {0x24,0x46,0x06,0x46,0xC6,0x64,0x6D,0x2A};
    for (volatile int i = 0; i < 8; i++)
        out[i] = (uint8_t)(((enc[i] << 3) | (enc[i] >> 5)) & 0xFF);
}

static NSData *rv_secret(void) {
    static NSData *sec;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        volatile uint8_t raw[24];
        __rv_seg_a(raw + 0);
        __rv_seg_b(raw + 8);
        __rv_seg_c(raw + 16);
        uint8_t buf[24];
        for (int i = 0; i < 24; i++) buf[i] = raw[i];
        memset((void *)raw, 0, sizeof(raw));
        sec = [NSData dataWithBytes:buf length:24];
        memset(buf, 0, 24);
    });
    return sec;
}

// ─────────────────────────────────────────────────────────────────────────────

@implementation ResponseVerifier

+ (BOOL)verifyResponse:(NSDictionary *)json {
    if (![json isKindOfClass:[NSDictionary class]]) return NO;

    // Lấy rsig
    NSString *rsig = json[@"rsig"];
    if (![rsig isKindOfClass:[NSString class]] || rsig.length != 64) return NO;

    // Lấy rts (response timestamp) — chống replay fake cũ
    NSNumber *rtsNum = json[@"rts"];
    if (![rtsNum isKindOfClass:[NSNumber class]]) return NO;
    long long rts = rtsNum.longLongValue;
    long long now = (long long)[[NSDate date] timeIntervalSince1970];
    // Cho phép ±120 giây (network delay)
    if (llabs(now - rts) > 120) return NO;

    // Tái tạo canonical theo thứ tự CỐ ĐỊNH (phải khớp server)
    NSString *status = json[@"status"] ?: @"";
    NSString *code   = json[@"code"]   ?: @"";
    NSString *rtsStr = [NSString stringWithFormat:@"%lld", rts];

    NSMutableString *canonical = [NSMutableString stringWithFormat:
        @"status=%@&code=%@&rts=%@", status, code, rtsStr];

    // seconds_left nếu có
    if (json[@"seconds_left"]) {
        [canonical appendFormat:@"&seconds_left=%@", json[@"seconds_left"]];
    }
    // key_code nếu có
    if (json[@"key_code"]) {
        [canonical appendFormat:@"&key_code=%@", json[@"key_code"]];
    }

    // Tính HMAC
    NSData *sec  = rv_secret();
    NSData *msg  = [canonical dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, sec.bytes, sec.length, msg.bytes, msg.length, digest);

    NSMutableString *computed = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++)
        [computed appendFormat:@"%02x", digest[i]];

    // Constant-time compare — tránh timing attack khi cracker so sánh token
    const char *a = computed.UTF8String;
    const char *b = rsig.UTF8String;
    // Cả 2 đều là 64-char hex → length cố định 64; kiểm tra thêm 1 lần để chắc chắn
    if (!a || !b || strlen(a) != 64 || strlen(b) != 64) return NO;
    volatile uint8_t diff = 0;
    for (int i = 0; i < 64; i++) diff |= ((uint8_t)a[i] ^ (uint8_t)b[i]);
    return (diff == 0);
}

@end
