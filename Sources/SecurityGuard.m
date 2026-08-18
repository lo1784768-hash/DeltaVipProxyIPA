#import "SecurityGuard.h"
#import "KeyManager.h"
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <sys/types.h>
#import <sys/stat.h>
#import <sys/proc.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <objc/runtime.h>
#import <string.h>
#import <stdlib.h>
#import <unistd.h>
#import <signal.h>
#import <time.h>
#import <fcntl.h>

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

// ─── Danh sách dylib độc hại ─────────────────────────────────────────────────
static const char *kBadLibs[] = {
    "FridaGadget", "frida-agent", "frida", "gum-js-loop", "gadget",
    "cynject", "cycript", "libcycript",
    "libhooker", "substrate", "substitute", "ellekit",
    "TweakInject", "libdyld_sim", "RevealServer",
    "iSpy", "SSLKillSwitch", "killswitch",
    "trolldecrypt", "flexdecrypt",
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

@implementation SecurityGuard

#pragma mark - Activate

+ (void)activate {
    sg_init_bail();
    [self denyDebugger];

    if ([self isTampered]) { sg_trigger(); return; }

    // Timer với jitter ngẫu nhiên → khó patch interval cố định
    static dispatch_source_t timer = nil;
    timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
                                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    dispatch_source_set_timer(timer,
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)),
        (uint64_t)(4 * NSEC_PER_SEC),
        (uint64_t)(arc4random_uniform(2000000000)));   // jitter 0–2s
    dispatch_source_set_event_handler(timer, ^{
        if ([self isTampered]) { sg_trigger(); }
    });
    dispatch_resume(timer);
}

+ (BOOL)isEnvironmentTrusted {
    return ![self isTampered];
}

+ (void)bailOut {
    sg_trigger();
}

#pragma mark - Master tamper check

+ (BOOL)isTampered {
    return [self isBeingDebugged]
        || [self hasInsertedLibraries]
        || [self hasInjectionTools]
        || [self hasJailbreakPaths]
        || [self hasBundleIDMismatch]
        || [self hasDisplayNameMismatch]
        || [self hasCriticalMethodHooked]
        || [self isTimingAnomalous];
}

#pragma mark - Anti-debug

+ (void)denyDebugger {
    void *handle = dlopen(0, RTLD_GLOBAL | RTLD_NOW);
    if (!handle) return;
    ptrace_t p = (ptrace_t)dlsym(handle, "ptrace");
    if (p) p(PTRACE_DENY_ATTACH, 0, 0, 0);
}

+ (BOOL)isBeingDebugged {
    // Check 1: sysctl P_TRACED flag
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() };
    struct kinfo_proc info; info.kp_proc.p_flag = 0;
    size_t sz = sizeof(info);
    if (sysctl(mib, 4, &info, &sz, NULL, 0) == 0) {
        if ((info.kp_proc.p_flag & P_TRACED) != 0) return YES;
    }
    // Check 2: exception port — lldb đăng ký exception handler
    mach_port_t task = mach_task_self();
    exception_mask_t masks[EXC_TYPES_COUNT];
    mach_msg_type_number_t count = 0;
    exception_handler_t handlers[EXC_TYPES_COUNT];
    exception_behavior_t behaviors[EXC_TYPES_COUNT];
    thread_state_flavor_t flavors[EXC_TYPES_COUNT];
    kern_return_t kr = task_get_exception_ports(task,
        EXC_MASK_ALL, masks, &count, handlers, behaviors, flavors);
    if (kr == KERN_SUCCESS) {
        for (mach_msg_type_number_t i = 0; i < count; i++) {
            if (MACH_PORT_VALID(handlers[i])) return YES;
        }
    }
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
    // Check 1: dylib names trong image list
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
