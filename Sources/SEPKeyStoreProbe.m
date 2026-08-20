/*
 * SEPKeyStoreProbe.m
 *
 * Probe xem sandboxed app có thể connect tới AppleKeyStore IOKit service không.
 * Liên quan: CVE-2026-20637 (IOCommandGate UAF, patched iOS 26.3, chưa backport iOS 18.7.x)
 *
 * Các error codes quan trọng:
 *   kIOReturnNotPermitted (0xe00002c1) = sandbox block  → không exploit được
 *   kIOReturnSuccess      (0x00000000) = open được      → CVE có thể dùng
 *   kIOReturnExclusiveAccess           = service bận    → vẫn tồn tại, thử lại
 *   MACH_SEND_INVALID_DEST             = service không tồn tại trên iOS version này
 */

#import "SEPKeyStoreProbe.h"
#import <UIKit/UIKit.h>
#import <IOKit/IOKitLib.h>
#include <mach/mach.h>
#include <errno.h>

// Các connection type thử lần lượt (từ PoC CVE-2026-20637)
static const uint32_t kConnectionTypes[] = {
    0,          // default
    1,
    2,
    0x2022,     // từ PoC gốc
    0xbeef,     // từ PoC gốc
    0x1337,     // từ PoC gốc
    0x4141,     // từ PoC gốc
};
static const int kConnectionTypeCount = 7;

// Selectors thử (từ PoC: 0–15)
static const uint32_t kSelectors[] = { 0, 1, 2, 3, 6, 10, 15 };
static const int kSelectorCount = 7;

// Service names thử
static const char * const kServiceNames[] = {
    "AppleKeyStore",
    "AppleSEPKeyStore",
    "com.apple.driver.AppleKeyStore",
    NULL
};

@implementation SEPKeyStoreProbe

+ (NSString *)runProbe {
    NSMutableString *log = [NSMutableString string];
    NSString *ver = [[UIDevice currentDevice] systemVersion];
    NSString *model = [[UIDevice currentDevice] model];

    void (^add)(NSString *) = ^(NSString *line) {
        [log appendFormat:@"%@\n", line];
        NSLog(@"[SEPProbe] %@", line);
    };

    add([NSString stringWithFormat:@"=== SEPKeyStore Probe — iOS %@ (%@) ===", ver, model]);
    add(@"");

    // ── Step 1: IOServiceGetMatchingService ───────────────────────────────────
    add(@"── Step 1: IOServiceGetMatchingService ──");

    io_service_t service = IO_OBJECT_NULL;
    const char *foundServiceName = NULL;

    for (int i = 0; kServiceNames[i] != NULL; i++) {
        const char *name = kServiceNames[i];
        io_service_t s = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching(name)
        );
        if (s != IO_OBJECT_NULL) {
            add([NSString stringWithFormat:@"  ✅ Found: %s (port=%u)", name, s]);
            service = s;
            foundServiceName = name;
            break;
        } else {
            add([NSString stringWithFormat:@"  ❌ Not found: %s", name]);
        }
    }

    if (service == IO_OBJECT_NULL) {
        add(@"");
        add(@"⛔ Service không tồn tại hoặc sandbox block IOServiceGetMatchingService");
        add(@"Kết luận: CVE-2026-20637 KHÔNG exploit được từ app này");
        return [log copy];
    }

    add(@"");

    // ── Step 2: IOServiceOpen với nhiều connection types ──────────────────────
    add(@"── Step 2: IOServiceOpen (connection types) ──");

    io_connect_t successConnect = IO_OBJECT_NULL;
    uint32_t successType = 0;

    for (int i = 0; i < kConnectionTypeCount; i++) {
        uint32_t ctype = kConnectionTypes[i];
        io_connect_t conn = IO_OBJECT_NULL;
        kern_return_t kr = IOServiceOpen(service, mach_task_self(), ctype, &conn);

        NSString *krStr = [SEPKeyStoreProbe _describeKernReturn:kr];

        if (kr == KERN_SUCCESS) {
            add([NSString stringWithFormat:@"  ✅ type=0x%04x → SUCCESS conn=%u", ctype, conn]);
            if (successConnect == IO_OBJECT_NULL) {
                successConnect = conn;
                successType = ctype;
            } else {
                IOServiceClose(conn);
            }
        } else {
            add([NSString stringWithFormat:@"  ❌ type=0x%04x → 0x%08x (%@)", ctype, kr, krStr]);
        }
    }

    IOObjectRelease(service);

    if (successConnect == IO_OBJECT_NULL) {
        add(@"");
        add(@"⛔ IOServiceOpen thất bại tất cả connection types");
        add(@"Kết luận: CVE-2026-20637 KHÔNG exploit được (sandbox block open)");
        return [log copy];
    }

    add(@"");

    // ── Step 3: IOConnectCallMethod trên các selectors ────────────────────────
    add([NSString stringWithFormat:@"── Step 3: IOConnectCallMethod (conn=0x%x, type=0x%04x) ──",
         successConnect, successType]);

    int callableCount = 0;
    for (int i = 0; i < kSelectorCount; i++) {
        uint32_t sel = kSelectors[i];

        // Call với input/output rỗng
        kern_return_t kr = IOConnectCallMethod(
            successConnect,
            sel,
            NULL, 0,    // input scalars
            NULL, 0,    // input struct
            NULL, NULL, // output scalars
            NULL, NULL  // output struct
        );

        NSString *krStr = [SEPKeyStoreProbe _describeKernReturn:kr];

        if (kr == KERN_SUCCESS || kr == kIOReturnBadArgument) {
            // BadArgument = method exists, wrong args — vẫn tính là accessible
            add([NSString stringWithFormat:@"  ✅ selector %2u → 0x%08x (%@)", sel, kr, krStr]);
            callableCount++;
        } else {
            add([NSString stringWithFormat:@"  ❌ selector %2u → 0x%08x (%@)", sel, kr, krStr]);
        }
    }

    IOServiceClose(successConnect);
    add(@"");

    // ── Kết luận ──────────────────────────────────────────────────────────────
    add(@"── Kết luận ──");
    if (callableCount > 0) {
        add([NSString stringWithFormat:
             @"✅✅ AppleKeyStore ACCESSIBLE từ sandboxed app!",
             foundServiceName ? [NSString stringWithUTF8String:foundServiceName] : @"?"]);
        add([NSString stringWithFormat:@"   %d/%d selectors callable", callableCount, kSelectorCount]);
        add(@"   → CVE-2026-20637 có thể exploit từ IMGUIDELTA");
        add(@"   → Cần develop: panic PoC → heap groom → IOCommandGate fake → kernel r/w");
    } else {
        add(@"⚠️  Service accessible nhưng không gọi được method nào");
        add(@"   → Sandbox block ở method level");
        add(@"   → CVE-2026-20637 khó exploit trực tiếp");
    }

    add(@"");
    add(@"=== end ===");
    return [log copy];
}

// ── helpers ───────────────────────────────────────────────────────────────────

+ (NSString *)_describeKernReturn:(kern_return_t)kr {
    switch (kr) {
        case KERN_SUCCESS:              return @"SUCCESS";
        case kIOReturnNotPermitted:     return @"NOT_PERMITTED (sandbox)";
        case kIOReturnExclusiveAccess:  return @"EXCLUSIVE_ACCESS";
        case kIOReturnBadArgument:      return @"BAD_ARGUMENT (method exists)";
        case kIOReturnUnsupported:      return @"UNSUPPORTED";
        case kIOReturnError:            return @"ERROR";
        case kIOReturnNoDevice:         return @"NO_DEVICE";
        case kIOReturnBusy:             return @"BUSY";
        case KERN_INVALID_ARGUMENT:     return @"INVALID_ARGUMENT";
        case MACH_SEND_INVALID_DEST:    return @"INVALID_DEST (not found)";
        default:
            return [NSString stringWithFormat:@"0x%08x", kr];
    }
}

@end
