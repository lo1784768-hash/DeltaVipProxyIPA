#import "SecurityGuard.h"
#import "KeyManager.h"
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <sys/types.h>
#import <sys/stat.h>
#import <sys/proc.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <mach-o/loader.h>
#import <mach-o/getsect.h>
#import <objc/runtime.h>
#import <CommonCrypto/CommonDigest.h>
#import <string.h>
#import <stdlib.h>
#import <unistd.h>
#import <signal.h>
#import <time.h>
#import <fcntl.h>

// sys/codesign.h không có trong public iOS SDK — khai báo thủ công
#ifndef CS_OPS_STATUS
#define CS_OPS_STATUS    0   // return status
#endif
#ifndef CS_VALID
#define CS_VALID         0x00000001
#endif
#ifndef CS_DEBUGGED
#define CS_DEBUGGED      0x10000000
#endif
#ifndef CS_KILL
#define CS_KILL          0x00000200
#endif
extern int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);

typedef int (*ptrace_t)(int request, pid_t pid, caddr_t addr, int data);
#define PTRACE_DENY_ATTACH 31

// ─── XOR-obfuscated strings ──────────────────────────────────────────────────
// key = {0xAB,0xCD,0xEF,0x13,0x57,0x9B,0xDF,0x24,0x68,0xAC,0xF0}
// decode("DELTA PROXY"):
static const uint8_t kDNXor[11] = {0xAB,0xCD,0xEF,0x13,0x57,0x9B,0xDF,0x24,0x68,0xAC,0xF0};
static const uint8_t kDNEnc[11] = {0xEF,0x88,0xA3,0x47,0x16,0xBB,0x8F,0x76,0x27,0xF4,0xA9};
// decode("com.apple.mobile.MobileHouseArrest"):
static const uint8_t kBIDXor[8]  = {0x5E,0xC1,0x2B,0x7A,0xD4,0x9F,0x38,0xE6};
static const uint8_t kBIDEnc[34] = {
    0x3D,0xAE,0x46,0x54,0xB5,0xEF,0x48,0x8A,
    0x3B,0xEF,0x46,0x15,0xB6,0xF6,0x54,0x83,
    0x70,0x8C,0x44,0x18,0xBD,0xF3,0x5D,0xAE,
    0x31,0xB4,0x58,0x1F,0x95,0xED,0x4A,0x83,
    0x2D,0xB5
};

static void sg_decode_dn(char out[12]) {
    for (int i = 0; i < 11; i++) out[i] = (char)(kDNEnc[i] ^ kDNXor[i]);
    out[11] = '\0';
}
static void sg_decode_bid(char out[35]) {
    for (int i = 0; i < 34; i++) out[i] = (char)(kBIDEnc[i] ^ kBIDXor[i % 8]);
    out[34] = '\0';
}

// ─── Blacklist tên dylib độc hại (vẫn giữ làm lớp nhanh) ────────────────────
static const char *kBadLibs[] = {
    "FridaGadget", "frida-agent", "frida", "gum-js-loop", "gadget",
    "cynject", "cycript", "libcycript",
    "libhooker", "substrate", "substitute", "ellekit",
    "TweakInject", "libdyld_sim", "RevealServer",
    "iSpy", "SSLKillSwitch", "killswitch",
    "trolldecrypt", "flexdecrypt",
    NULL
};

// ─── Whitelist path prefix dylib hợp lệ ──────────────────────────────────────
// Chỉ cho phép dylib từ các prefix system Apple hoặc chính binary của app.
// Bất kỳ dylib nào nằm ngoài các prefix này → inject lạ → bail.
// Phân tích IPA đã ký bằng eSign: không có dylib nào ngoài /System + /usr/lib.
static const char *kAllowedPrefixes[] = {
    "/System/Library/Frameworks/",
    "/System/Library/PrivateFrameworks/",
    "/System/Library/SubFrameworks/",     // UIUtilities và các sub-framework iOS
    "/System/Library/AccessibilityBundles/",
    "/System/Library/Extensions/",
    "/usr/lib/",
    "/usr/lib/swift/",
    "/private/preboot/",
    "/var/containers/Bundle/",
    "/private/var/containers/Bundle/",
    NULL
};

// ─── Đường dẫn jailbreak filesystem ─────────────────────────────────────────
static const char *kJBPaths[] = {
    "/var/jb/usr/lib/ellekit",
    "/var/jb/.installed_dopamine",
    "/var/jb/.installed_unc0ver",
    "/var/jb/usr/lib/TweakInject",
    "/var/jb/usr/lib/libhooker.dylib",
    "/bootstrap/.installed_palera1n",
    "/usr/lib/libhooker.dylib",
    "/usr/lib/substrate",
    "/Library/MobileSubstrate",
    NULL
};

// ─── Bail: nhiều lớp, khó NOP hết ────────────────────────────────────────────
__attribute__((noinline, noreturn))
static void sg_bail(void) {
    raise(SIGKILL);
    __asm__ volatile(
        "mov x0, #0\n\t"
        "mov sp, x0\n\t"
        "ret"
        ::: "x0"
    );
    volatile int *p = NULL; *p = 0xDEAD;
    _Exit(1);
    __builtin_unreachable();
}

typedef void(*BailFn)(void);
static volatile BailFn _bailFn = NULL;

static void sg_init_bail(void) {
    _bailFn = sg_bail;
}

__attribute__((noinline))
static void sg_trigger(void) {
    if (_bailFn) _bailFn();
    else sg_bail();
}

// ─── ARM64 first-instruction hook detection ───────────────────────────────────
static BOOL sg_is_hooked_imp(IMP imp) {
    if (!imp) return YES;
    const uint32_t *code = (const uint32_t *)imp;
    uint32_t first  = code[0];
    uint32_t second = code[1];
    uint32_t op26_0 = first >> 26;
    uint32_t op26_1 = second >> 26;
    // Branch unconditional (B/BL) hoặc BRK → hook
    if (op26_0 == 0x05 || op26_0 == 0x25) return YES;
    if (first  == 0xD4200000)              return YES; // BRK #0 (Frida)
    if (first  == 0xD43E0000)              return YES; // BRK #0xF000 (Substrate)
    // Kiểm tra cả instruction thứ 2 (một số hook tricky dùng NOP + B)
    if (first == 0xD503201F) { // NOP → nghi ngờ, check next
        if (op26_1 == 0x05 || op26_1 == 0x25) return YES;
    }
    return NO;
}

// ─── __TEXT checksum — SHA256 của toàn bộ __text section ────────────────────
// Giá trị này được embed lúc BUILD bằng build script, không phải hardcode thủ công.
// Format: first 8 bytes của SHA256, lưu dưới dạng uint64 để khó tìm bằng hex editor.
// Build script chạy sau link: tính SHA256(__text), ghi vào kSGTextHash.
// Nếu cracker patch 1 byte bất kỳ trong __TEXT → hash khác → bail.
//
// QUAN TRỌNG: giá trị 0 = chưa embed (debug build / build script chưa chạy) → skip check
static const uint64_t kSGTextHash = 0; // BUILD SCRIPT GHI VÀO ĐÂY

__attribute__((noinline, optnone))
static BOOL sg_check_text_hash(void) {
    if (kSGTextHash == 0) return YES; // debug/unsigned build → skip

    // Tìm __TEXT,__text section
    unsigned long text_size = 0;
    const uint8_t *text_ptr = (const uint8_t *)getsectiondata(
        (const struct mach_header_64 *)_dyld_get_image_header(0),
        "__TEXT", "__text", &text_size);
    if (!text_ptr || text_size == 0) return NO; // không tìm được → nghi ngờ

    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(text_ptr, (CC_LONG)text_size, digest);

    // Lấy 8 byte đầu làm fingerprint
    uint64_t computed = 0;
    memcpy(&computed, digest, sizeof(computed));

    return (computed == kSGTextHash);
}

// ─── CS_VALID / CS_DEBUGGED flag từ kernel ───────────────────────────────────
// Kể cả không bị debug, nếu code signature bị invalidate (patch binary không resign)
// kernel sẽ set CS_VALID=0 → detect.
// Nếu họ dùng ldid/zsign để resign sau khi patch → CS_VALID=1 nhưng CS_DEBUGGED=0,
// nhưng hash check ở trên đã catch rồi.
__attribute__((noinline, optnone))
static BOOL sg_check_codesign(void) {
    // CS_VALID bị clear khi binary bị patch NHƯNG CHƯA resign.
    // Sau khi resign bằng eSign/AltStore/Sideloadly: CS_VALID=1 nhưng
    // CS_DEBUGGED có thể được set tùy công cụ → false-positive crash.
    // Chỉ check CS_VALID (đủ để bắt binary patch chưa resign).
    // CS_DEBUGGED và CS_KILL bỏ qua — quá nhạy với resign tools hợp lệ.
    uint32_t flags = 0;
    int ret = csops(getpid(), CS_OPS_STATUS, &flags, sizeof(flags));
    if (ret != 0) return YES; // csops không hoạt động trên thiết bị này → skip
    if (!(flags & CS_VALID)) return NO; // binary patch chưa resign → bail
    // CS_DEBUGGED: bỏ qua — resign tools set bit này, không đáng tin
    return YES;
}

// ─── dylib count guard ───────────────────────────────────────────────────────
// Snapshot sau khi app đã ổn định (lazy framework đã load xong).
// Baseline = 0 nghĩa là chưa chốt → check đầu tiên sẽ chốt baseline,
// check thứ 2 trở đi mới so sánh thật sự.
static uint32_t sg_image_count_baseline = 0;

__attribute__((noinline, optnone))
static void sg_snapshot_image_count(void) {
    sg_image_count_baseline = _dyld_image_count();
}

__attribute__((noinline, optnone))
static BOOL sg_check_image_count(void) {
    // Baseline được chốt bởi sg_snapshot_image_count() sau delay 8s trong activate.
    // Sau đó mỗi lần check: nếu tăng > 8 image → nghi inject runtime.
    // Threshold cao (8) vì lazy framework có thể load thêm vài cái nữa sau baseline.
    if (sg_image_count_baseline == 0) return YES; // chưa chốt → skip
    uint32_t current = _dyld_image_count();
    return (current <= sg_image_count_baseline + 8);
}

@implementation SecurityGuard

#pragma mark - Activate

+ (void)activate {
    sg_init_bail();
    [self denyDebugger];

    // Check ngay lúc start (chưa có baseline → sg_check_image_count skip)
    if ([self isTampered]) { sg_trigger(); return; }

    // Sau 8s: lazy framework đã load xong → chốt baseline image count
    // Sau đó timer check mỗi ~6s
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)),
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sg_snapshot_image_count(); // chốt baseline khi app đã stable

        static dispatch_source_t timer = nil;
        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
                                       dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
        dispatch_source_set_timer(timer,
            dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
            (uint64_t)(6 * NSEC_PER_SEC),
            (uint64_t)(arc4random_uniform(2000000000))); // jitter 0–2s
        dispatch_source_set_event_handler(timer, ^{
            if ([self isTampered]) { sg_trigger(); }
        });
        dispatch_resume(timer);
    });
}

+ (BOOL)isEnvironmentTrusted {
    return ![self isTampered];
}

+ (void)bailOut {
    sg_trigger();
}

#pragma mark - Master tamper check

+ (BOOL)isTampered {
    // Thứ tự: nhẹ → nặng
    if ([self isBeingDebugged])         return YES; // ptrace P_TRACED
    if (!sg_check_codesign())           return YES; // CS_VALID=0
    if ([self hasInsertedLibraries])    return YES; // DYLD env var
    if (!sg_check_image_count())        return YES; // image count tăng đột biến
    if ([self hasInjectionTools])       return YES; // blacklist tên (Frida/Substrate/...)
    if ([self hasUnknownDylib])         return YES; // whitelist path — bắt dylib tên random
    if ([self hasJailbreakPaths])       return YES; // filesystem jailbreak
    if ([self hasBundleIDMismatch])     return YES; // repackage
    if ([self hasDisplayNameMismatch])  return YES; // repackage
    if ([self hasCriticalMethodHooked]) return YES; // IMP hook
    if (!sg_check_text_hash())          return YES; // binary patch
    if ([self isTimingAnomalous])       return YES; // debugger overhead
    return NO;
}

#pragma mark - Anti-debug

+ (void)denyDebugger {
    void *handle = dlopen(0, RTLD_GLOBAL | RTLD_NOW);
    if (!handle) return;
    ptrace_t p = (ptrace_t)dlsym(handle, "ptrace");
    if (p) p(PTRACE_DENY_ATTACH, 0, 0, 0);
}

+ (BOOL)isBeingDebugged {
    // sysctl P_TRACED — reliable, không false-positive với eSign/resign tools
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() };
    struct kinfo_proc info; info.kp_proc.p_flag = 0;
    size_t sz = sizeof(info);
    if (sysctl(mib, 4, &info, &sz, NULL, 0) == 0) {
        if ((info.kp_proc.p_flag & P_TRACED) != 0) return YES;
    }
    // NOTE: task_get_exception_ports bị bỏ — iOS system services tự đăng ký
    // exception handler → false-positive trên thiết bị thường (không phải debugger).
    return NO;
}

#pragma mark - Anti-inject / Anti-hook env

+ (BOOL)hasInsertedLibraries {
    // DYLD_INSERT_LIBRARIES — cũ, nhưng vẫn check
    if (getenv("DYLD_INSERT_LIBRARIES") != NULL) return YES;
    // DYLD_* bất kỳ → nghi ngờ môi trường bị thao túng
    if (getenv("DYLD_FRAMEWORK_PATH") != NULL) return YES;
    if (getenv("DYLD_LIBRARY_PATH")   != NULL) return YES;
    return NO;
}

+ (BOOL)hasInjectionTools {
    // Blacklist tên (nhanh, bắt tool phổ biến)
    uint32_t n = _dyld_image_count();
    for (uint32_t i = 0; i < n; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        for (int j = 0; kBadLibs[j] != NULL; j++) {
            if (strcasestr(name, kBadLibs[j]) != NULL) return YES;
        }
    }
    return NO;
}

+ (BOOL)hasUnknownDylib {
    // Whitelist path prefix — bắt dylib tên random do cracker tự inject.
    // Bất kỳ dylib nào không bắt đầu bằng prefix hợp lệ → bail.
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *logPath = [docs stringByAppendingPathComponent:@"dylibs_unknown.txt"];
    NSMutableString *logOut = [NSMutableString string];

    uint32_t n = _dyld_image_count();
    for (uint32_t i = 0; i < n; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        BOOL allowed = NO;
        for (int j = 0; kAllowedPrefixes[j] != NULL; j++) {
            if (strncmp(name, kAllowedPrefixes[j], strlen(kAllowedPrefixes[j])) == 0) {
                allowed = YES;
                break;
            }
        }
        if (!allowed) {
            [logOut appendFormat:@"UNKNOWN: %s\n", name];
        }
    }
    if (logOut.length > 0) {
        [logOut writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        return YES;
    }
    return NO;
}

+ (BOOL)hasJailbreakPaths {
    for (int i = 0; kJBPaths[i] != NULL; i++) {
        // Dùng open() thay access() — bypass một số hook trên access()
        int fd = open(kJBPaths[i], O_RDONLY);
        if (fd >= 0) { close(fd); return YES; }
    }
    return NO;
}

#pragma mark - Anti-repackage

+ (BOOL)hasBundleIDMismatch {
    NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
    if (!bid) return YES;
    char expected[35]; sg_decode_bid(expected);
    return (strcmp(bid.UTF8String, expected) != 0);
}

+ (BOOL)hasDisplayNameMismatch {
    NSBundle *mb = [NSBundle mainBundle];
    NSString *display = [mb objectForInfoDictionaryKey:@"CFBundleDisplayName"]
                     ?: [mb objectForInfoDictionaryKey:@"CFBundleName"];
    if (!display) return YES;
    char expected[12]; sg_decode_dn(expected);
    return (strcmp(display.UTF8String, expected) != 0);
}

#pragma mark - Anti-hook (method IMP check)

+ (BOOL)hasCriticalMethodHooked {
    Class km = [KeyManager class];
    SEL selectors[] = {
        @selector(postKey:confirm:completion:),
        @selector(activateKey:completion:),
        @selector(deviceUDID),
        NULL
    };
    for (int i = 0; selectors[i] != NULL; i++) {
        Method m = class_getInstanceMethod(km, selectors[i]);
        if (!m) return YES;
        if (sg_is_hooked_imp(method_getImplementation(m))) return YES;
    }
    Method sg = class_getClassMethod([SecurityGuard class], @selector(isTampered));
    if (!sg || sg_is_hooked_imp(method_getImplementation(sg))) return YES;

    // Check thêm NSURLSession dataTaskWithRequest: — attack vector phổ biến để mock response
    Class sessionClass = [NSURLSession class];
    SEL dtSel = @selector(dataTaskWithRequest:completionHandler:);
    Method dtMethod = class_getInstanceMethod(sessionClass, dtSel);
    if (dtMethod && sg_is_hooked_imp(method_getImplementation(dtMethod))) return YES;

    // Check SecItemCopyMatching — hook để fake Keychain expiry
    IMP secImp = (IMP)dlsym(RTLD_DEFAULT, "SecItemCopyMatching");
    if (secImp && sg_is_hooked_imp(secImp)) return YES;

    return NO;
}

#pragma mark - Timing-based debugger detection

// Debugger tạo ra thêm overhead khi step/breakpoint → loop đơn giản mất lâu bất thường
+ (BOOL)isTimingAnomalous {
    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    // Busy-loop nhỏ — không thể tối ưu đi bởi compiler nhờ volatile
    volatile uint64_t acc = 0;
    for (volatile int i = 0; i < 5000; i++) acc += (uint64_t)i * i;
    clock_gettime(CLOCK_MONOTONIC, &t1);
    // Chênh lệch nanoseconds
    int64_t diff = ((int64_t)t1.tv_sec - t0.tv_sec) * 1000000000LL
                 + ((int64_t)t1.tv_nsec - t0.tv_nsec);
    // Trên thiết bị thật: < 1ms (< 1_000_000 ns)
    // Dưới debugger với tracing: thường > 5ms
    // Ngưỡng 80ms — bảo thủ để không false-positive trên máy chậm
    return (diff > 80000000LL);
}

@end
