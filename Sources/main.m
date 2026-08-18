// ── main.m — DELTA PROXY ───────────────────────────────────────────────────────
// MÃ NÀY THỰC THI TRƯỚC main() QUA __attribute__((constructor))
// → ptrace PT_DENY_ATTACH được gọi TRƯỚC khi Obj-C runtime, TRƯỚC +load,
//   TRƯỚC bất kỳ hook nào có thể inject vào (frida attach timing window bị đóng)

#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#include <dlfcn.h>
#include <unistd.h>
#include <sys/sysctl.h>
#include <mach/mach.h>

// ─── Lớp 1: ptrace PT_DENY_ATTACH ────────────────────────────────────────────
// Không import <sys/ptrace.h> trực tiếp — tránh symbol rõ ràng trong binary.
// dlsym tại runtime → không xuất hiện trong import table khi dùng `otool -L`.
typedef int (*ptrace_fn)(int request, pid_t pid, caddr_t addr, int data);
#define PT_DENY_ATTACH 31

// ─── Constructor: chạy trước main() ──────────────────────────────────────────
__attribute__((constructor))
static void __delta_early_security(void) {
    // Ptrace
    ptrace_fn _ptrace = (ptrace_fn)dlsym(RTLD_DEFAULT, "ptrace");
    if (_ptrace) _ptrace(PT_DENY_ATTACH, 0, 0, 0);

    // Nếu vẫn bị trace sau ptrace (patch ptrace bị NOP) → kill bằng mach exception
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() };
    struct kinfo_proc info; info.kp_proc.p_flag = 0;
    size_t sz = sizeof(info);
    if (sysctl(mib, 4, &info, &sz, NULL, 0) == 0) {
        if ((info.kp_proc.p_flag & P_TRACED) != 0) {
            // Corrupt stack — crash không thể catch
            volatile uintptr_t *null_ptr = 0;
            *null_ptr = 0xDEADC0DEDEADC0DE;
        }
    }
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
