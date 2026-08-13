#import "SecurityGuard.h"
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <sys/types.h>
#import <sys/proc.h>
#import <mach-o/dyld.h>
#import <string.h>
#import <stdlib.h>
#import <unistd.h>

typedef int (*ptrace_t)(int request, pid_t pid, caddr_t addr, int data);
#define PTRACE_DENY_ATTACH 31

@implementation SecurityGuard

+ (void)activate {
    [self denyDebugger];

    // Kiểm tra ngay + giám sát định kỳ (Frida/inject/debug có thể gắn sau)
    if ([self isTampered]) { [self bail]; return; }

    static dispatch_source_t timer = nil;
    timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer,
                              dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                              (uint64_t)(3 * NSEC_PER_SEC),
                              (uint64_t)(1 * NSEC_PER_SEC));
    dispatch_source_set_event_handler(timer, ^{
        if ([self isTampered]) { [self bail]; }
    });
    dispatch_resume(timer);
}

+ (BOOL)isEnvironmentTrusted {
    return ![self isTampered];
}

// Chặn gắn debugger (ptrace PT_DENY_ATTACH), gọi động để tránh lộ symbol
+ (void)denyDebugger {
    void *handle = dlopen(0, RTLD_GLOBAL | RTLD_NOW);
    if (!handle) return;
    ptrace_t p = (ptrace_t)dlsym(handle, "ptrace");
    if (p) p(PTRACE_DENY_ATTACH, 0, 0, 0);
}

#pragma mark - Checks

+ (BOOL)isTampered {
    return [self isBeingDebugged]
        || [self hasInsertedLibraries]
        || [self hasInjectionTools];
}

// Chống debug: cờ P_TRACED trong sysctl
+ (BOOL)isBeingDebugged {
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() };
    struct kinfo_proc info;
    size_t size = sizeof(info);
    info.kp_proc.p_flag = 0;
    if (sysctl(mib, 4, &info, &size, NULL, 0) != 0) return NO;
    return (info.kp_proc.p_flag & P_TRACED) != 0;
}

// Chống tiêm qua biến môi trường
+ (BOOL)hasInsertedLibraries {
    return getenv("DYLD_INSERT_LIBRARIES") != NULL;
}

// Chống Frida / Cycript / tweak-loader: quét tên các dylib đã nạp
+ (BOOL)hasInjectionTools {
    static const char *bad[] = {
        "FridaGadget", "frida", "gum-js-loop", "gadget",
        "cynject", "cycript", "libcycript",
        "libhooker", "substrate", "substitute", "ellekit", "TweakInject",
        NULL
    };
    uint32_t n = _dyld_image_count();
    for (uint32_t i = 0; i < n; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        for (int j = 0; bad[j] != NULL; j++) {
            if (strcasestr(name, bad[j]) != NULL) return YES;
        }
    }
    return NO;
}

#pragma mark - React

+ (void)bail {
    // Phát hiện can thiệp → thoát ngay
    exit(0);
}

@end
