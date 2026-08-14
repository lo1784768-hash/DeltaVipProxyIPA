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

/*
 * HAI CƠ CHẾ truy cập filesystem theo phiên bản iOS:
 *
 * Cơ chế A — iOS 26.1 trở lên:
 *   MCM + sandbox extension activation hoạt động trực tiếp với bundle ID
 *   com.apple.mobile.MobileHouseArrest. Không cần kernel exploit.
 *   (container_copy_sandbox_token + container_object_sandbox_extension_activate)
 *
 * Cơ chế B — iOS 17.0 → 26.0.x:
 *   Cần kexploit_opa334 (OPA334/ICMPv6 kernel exploit) để escape sandbox
 *   trước, sau đó scan metadata plist trực tiếp lấy container paths.
 *   MCM không đủ quyền trên iOS 17–26.0.x mà không có exploit.
 */

// Cơ chế A: iOS 26.1 trở lên — MCM trực tiếp, không cần exploit
static BOOL _isMechanismA(void) {
    NSString *ver = [[UIDevice currentDevice] systemVersion];
    // iOS >= 26.1
    return [ver compare:@"26.1" options:NSNumericSearch] != NSOrderedAscending;
}

// Cơ chế B: iOS 17.0 → 26.0.x — cần kexploit_opa334
// offsets_init() sẽ gọi exit() nếu iOS ngoài khoảng này → phải guard trước
static BOOL _isMechanismB(void) {
    NSString *ver = [[UIDevice currentDevice] systemVersion];
    NSComparisonResult low  = [ver compare:@"17.0" options:NSNumericSearch];
    NSComparisonResult high = [ver compare:@"26.1" options:NSNumericSearch];
    return (low != NSOrderedAscending) && (high == NSOrderedAscending);
}

+ (void)runEscapeWithCompletion:(void (^)(BOOL))completion {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSString *ver = [[UIDevice currentDevice] systemVersion];
            NSLog(@"[SEM] 🚀 Kiểm tra cơ chế cho iOS %@...", ver);

            // Cơ chế A (iOS 26.1+): MCM hoạt động trực tiếp — không cần exploit
            if (_isMechanismA()) {
                NSLog(@"[SEM] 📋 Cơ chế A (iOS 26.1+) → MCM không cần kernel exploit");
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(NO); });
                return;
            }

            // Ngoài cả hai cơ chế (iOS < 17.0)
            if (!_isMechanismB()) {
                NSLog(@"[SEM] ⚠️ iOS %@ < 17.0 — nằm ngoài cả 2 cơ chế", ver);
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(NO); });
                return;
            }

            // Cơ chế B (iOS 17.0–26.0.x): chạy kexploit_opa334
            NSLog(@"[SEM] 📋 Cơ chế B (iOS 17.0–26.0.x) → kexploit_opa334");

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

+ (NSDictionary<NSString *, NSString *> *)allContainerPaths {
    NSString *dataDir = @"/var/mobile/Containers/Data/Application";
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *uuids = [fm contentsOfDirectoryAtPath:dataDir error:nil];

    if (!uuids || uuids.count == 0) {
        NSLog(@"[SEM] ⚠️ allContainerPaths: không đọc được %@ (sandbox escaped=%d)", dataDir, gEscaped);
        return @{};
    }

    NSMutableDictionary<NSString *, NSString *> *result = [NSMutableDictionary dictionary];
    for (NSString *uuid in uuids) {
        NSString *uuidPath = [dataDir stringByAppendingPathComponent:uuid];
        NSString *metaPath = [uuidPath stringByAppendingPathComponent:
                              @".com.apple.mobile_container_manager.metadata.plist"];
        NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:metaPath];
        NSString *bid = meta[@"MCMMetadataIdentifier"];
        if (bid.length > 0) {
            result[bid] = uuidPath;
        }
    }

    NSLog(@"[SEM] 📦 allContainerPaths: tìm thấy %lu app", (unsigned long)result.count);
    return [result copy];
}

@end
