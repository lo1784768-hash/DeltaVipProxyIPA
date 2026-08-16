#import "SecurityGuard.h"
#import "KeyManager.h"
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <sys/types.h>
#import <sys/proc.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <objc/runtime.h>
#import <string.h>
#import <stdlib.h>
#import <unistd.h>
#import <signal.h>

typedef int (*ptrace_t)(int request, pid_t pid, caddr_t addr, int data);
#define PTRACE_DENY_ATTACH 31

// ─── Tên app hợp lệ (khớp INFOPLIST_KEY_CFBundleDisplayName trong project.yml) ───
static const char kValidDisplayName[] = "DELTA PROXY";
static const char kValidBundleID[]    = "com.apple.mobile.MobileHouseArrest";

// ─── Danh sách dylib độc hại ─────────────────────────────────────────────────
static const char *kBadLibs[] = {
    "FridaGadget", "frida", "gum-js-loop", "gadget",
    "cynject", "cycript", "libcycript",
    "libhooker", "substrate", "substitute", "ellekit",
    "TweakInject", "libdyld_sim", "RevealServer",
    "iSpy", "SSLKillSwitch", "killswitch",
    NULL
};

// ─── Bail: nhiều lớp, khó NOP hết ────────────────────────────────────────────
__attribute__((noinline, noreturn))
static void sg_bail(void) {
    // Lớp 1: SIGKILL – không thể bắt/bỏ qua
    raise(SIGKILL);
    // Lớp 2: corrupt stack pointer → crash ngay
    __asm__ volatile("mov sp, #0\n\t" "ret\n\t");
    // Lớp 3: write to null → SIGSEGV
    volatile int *p = NULL; *p = 0xDEAD;
    // Lớp 4: exit cuối cùng
    _Exit(1);
    __builtin_unreachable();
}

// ─── Gọi bail qua pointer để khó trace tĩnh ──────────────────────────────────
typedef void(*BailFn)(void);
static BailFn _bailFn = NULL;

static void sg_init_bail(void) {
    // Gán lúc runtime để tránh disassembler nhìn thấy trực tiếp
    _bailFn = sg_bail;
}

static void sg_trigger(void) {
    if (_bailFn) _bailFn();
    else sg_bail(); // fallback
}

@implementation SecurityGuard

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - Activate
// ─────────────────────────────────────────────────────────────────────────────

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
        (uint64_t)(1 * NSEC_PER_SEC));
    dispatch_source_set_event_handler(timer, ^{
        if ([self isTampered]) { sg_trigger(); }
    });
    dispatch_resume(timer);
}

+ (BOOL)isEnvironmentTrusted {
    return ![self isTampered];
}

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - Master tamper check
// ─────────────────────────────────────────────────────────────────────────────

+ (BOOL)isTampered {
    // Kiểm tra theo thứ tự từ nhanh → chậm
    return [self isBeingDebugged]
        || [self hasInsertedLibraries]
        || [self hasInjectionTools]
        || [self hasBundleIDMismatch]
        || [self hasDisplayNameMismatch]
        || [self hasCriticalMethodHooked];
}

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - Anti-debug
// ─────────────────────────────────────────────────────────────────────────────

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
    // Check 2: exception port (lldb dùng exception port)
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

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - Anti-inject
// ─────────────────────────────────────────────────────────────────────────────

+ (BOOL)hasInsertedLibraries {
    return getenv("DYLD_INSERT_LIBRARIES") != NULL;
}

+ (BOOL)hasInjectionTools {
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

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - Anti-repackage / rebranding
// ─────────────────────────────────────────────────────────────────────────────

// Nếu ai đổi CFBundleIdentifier → phát hiện
+ (BOOL)hasBundleIDMismatch {
    NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
    if (!bid) return YES;
    return (strcmp(bid.UTF8String, kValidBundleID) != 0);
}

// Nếu ai đổi CFBundleDisplayName ("HQUAN CRACK VN"...) → phát hiện
+ (BOOL)hasDisplayNameMismatch {
    NSBundle *mb = [NSBundle mainBundle];
    NSString *display = [mb objectForInfoDictionaryKey:@"CFBundleDisplayName"]
                     ?: [mb objectForInfoDictionaryKey:@"CFBundleName"];
    if (!display) return YES;
    return (strcmp(display.UTF8String, kValidDisplayName) != 0);
}

// ─────────────────────────────────────────────────────────────────────────────
#pragma mark - Anti-hook (ARM64)
// ─────────────────────────────────────────────────────────────────────────────
//
// Substrate / fishhook / Frida thường replace byte đầu của method bằng:
//   B  (branch)    : bits[31:26] = 000101 → (instr >> 26) = 0x05
//   BL (branch+lr) : bits[31:26] = 100101 → (instr >> 26) = 0x25
//   BRK            : 0xD4200000 (Frida software breakpoint)
// Prologue hợp lệ thường là STP/SUB/MOV → bits[31:26] khác 0x05/0x25.

static BOOL sg_is_hooked_imp(IMP imp) {
    if (!imp) return YES;
    const uint32_t *code = (const uint32_t *)imp;
    uint32_t first = code[0];
    uint32_t op26  = first >> 26;
    // Branch unconditional hoặc BRK → nghi ngờ hook
    if (op26 == 0x05 || op26 == 0x25) return YES;
    if (first == 0xD4200000)           return YES; // BRK #0 (Frida)
    return NO;
}

+ (BOOL)hasCriticalMethodHooked {
    // Kiểm tra các method quan trọng của KeyManager
    Class km = [KeyManager class];
    SEL selectors[] = {
        @selector(postKey:confirm:completion:),
        @selector(activateKey:completion:),
        @selector(deviceUDID),
        NULL
    };
    for (int i = 0; selectors[i] != NULL; i++) {
        Method m = class_getInstanceMethod(km, selectors[i]);
        if (!m) return YES; // method không tồn tại → swizzle đã xoá
        if (sg_is_hooked_imp(method_getImplementation(m))) return YES;
    }

    // Kiểm tra chính SecurityGuard.isTampered không bị swizzle
    Method sg = class_getClassMethod([SecurityGuard class], @selector(isTampered));
    if (!sg || sg_is_hooked_imp(method_getImplementation(sg))) return YES;

    return NO;
}

@end
