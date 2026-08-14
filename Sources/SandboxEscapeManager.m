/*
 * SandboxEscapeManager.m
 *
 * Wrapper cho kexploit_opa334 + sandbox_escape để dùng trong standalone app
 * (không cần Substrate / Theos — gọi trực tiếp từ AppDelegate).
 *
 * Sau khi escape thành công, process có thể đọc trực tiếp
 * /var/mobile/Containers/Data/Application/ → dùng containerPathForBundleID:
 * để tìm container game mà KHÔNG cần MCM / private entitlements.
 */

#import "SandboxEscapeManager.h"
#import <Foundation/Foundation.h>
#import <fcntl.h>
#import <unistd.h>

// Exploit API (từ kexploit/ + sandbox_escape.h)
#include "kexploit/kexploit_opa334.h"
#include "kexploit/kutils.h"
#include "sandbox_escape.h"

// ── Private ──────────────────────────────────────────────────────────────────

static BOOL gEscaped = NO;

static BOOL _isSandboxAlreadyEscaped(void) {
    // Thử ghi vào /var/mobile/ — chỉ hoạt động sau khi sandbox bị bypass
    int fd = open("/var/mobile/.delta_sbx_check", O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd >= 0) {
        close(fd);
        unlink("/var/mobile/.delta_sbx_check");
        return YES;
    }
    return NO;
}

// ── SandboxEscapeManager ─────────────────────────────────────────────────────

@implementation SandboxEscapeManager

+ (BOOL)escaped { return gEscaped; }

// Kiểm tra iOS có nằm trong khoảng exploit hỗ trợ không (17.0 – 26.0.x)
// offsets_init() sẽ gọi exit() nếu iOS ngoài khoảng này → phải guard trước khi gọi exploit
static BOOL _isExploitCompatibleOS(void) {
    NSString *ver = [[UIDevice currentDevice] systemVersion];
    NSComparisonResult low  = [ver compare:@"17.0" options:NSNumericSearch];
    NSComparisonResult high = [ver compare:@"26.1" options:NSNumericSearch];
    return (low != NSOrderedAscending) && (high == NSOrderedAscending);
}

+ (void)runEscapeWithCompletion:(void (^)(BOOL))completion {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSLog(@"[SEM] 🚀 Bắt đầu kernel exploit...");

            // Kiểm tra iOS có được hỗ trợ bởi kexploit_opa334 không
            // offsets_init() bên trong exploit gọi exit() nếu iOS không nằm trong 17.0-26.0.x
            // → PHẢI kiểm tra trước, không được gọi thẳng trên iOS 27+ hoặc iOS 16-
            if (!_isExploitCompatibleOS()) {
                NSString *ver = [[UIDevice currentDevice] systemVersion];
                NSLog(@"[SEM] ⚠️ iOS %@ nằm ngoài khoảng exploit hỗ trợ (17.0–26.0.x) — bỏ qua kexploit, dùng MCM fallback", ver);
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(NO); });
                return;
            }

            // Kiểm tra sandbox đã escape sẵn chưa (vd: tái khởi động mà state còn)
            if (_isSandboxAlreadyEscaped()) {
                NSLog(@"[SEM] ✅ Sandbox đã escaped từ trước");
                gEscaped = YES;
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(YES); });
                return;
            }

            // Bước 1: Kernel exploit OPA334
            int kret = kexploit_opa334();
            if (kret != 0) {
                NSLog(@"[SEM] ❌ kexploit_opa334 thất bại: %d (iOS này có thể chưa hỗ trợ)", kret);
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(NO); });
                return;
            }
            NSLog(@"[SEM] ✅ kexploit_opa334 thành công");

            // Bước 2: Sandbox escape (patch kernel memory)
            uint64_t self_proc = proc_self();
            NSLog(@"[SEM] proc_self = 0x%llx", self_proc);

            int sret = sandbox_escape(self_proc);
            if (sret != 0) {
                NSLog(@"[SEM] ❌ sandbox_escape thất bại: %d", sret);
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(NO); });
                return;
            }

            gEscaped = YES;
            NSLog(@"[SEM] ✅ Sandbox escaped thành công!");
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(YES); });
        });
    });
}

+ (NSString *)containerPathForBundleID:(NSString *)bundleID {
    if (!bundleID.length) return nil;

    // Đọc trực tiếp /var/mobile/Containers/Data/Application/{UUID}/.metadata.plist
    // Cần sandbox escaped trước khi gọi hàm này.
    NSString *dataDir = @"/var/mobile/Containers/Data/Application";
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *uuids = [fm contentsOfDirectoryAtPath:dataDir error:nil];

    if (!uuids || uuids.count == 0) {
        NSLog(@"[SEM] ⚠️ Không đọc được %@ (sandbox chưa escaped?)", dataDir);
        return nil;
    }

    for (NSString *uuid in uuids) {
        NSString *uuidPath = [dataDir stringByAppendingPathComponent:uuid];
        // Tên file metadata
        NSString *metaPath = [uuidPath stringByAppendingPathComponent:
                              @".com.apple.mobile_container_manager.metadata.plist"];
        NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:metaPath];
        NSString *bid = meta[@"MCMMetadataIdentifier"];
        if ([bid isEqualToString:bundleID]) {
            NSLog(@"[SEM] ✅ Container %@: %@", bundleID, uuidPath);
            return uuidPath;
        }
    }

    NSLog(@"[SEM] ⚠️ Không tìm thấy container cho %@", bundleID);
    return nil;
}

@end
