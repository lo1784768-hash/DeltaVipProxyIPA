//
//  BundleScanner.m
//

#import "BundleScanner.h"
#import "bad_query.h"

// Đường dẫn gốc Bundle container của tất cả app
static NSString * const kBundleRoot = @"/var/containers/Bundle/Application/";

@implementation BundleScanner

#pragma mark - Public API

+ (nullable NSString *)findAppBundlePath:(NSString *)bundleID
                               outHandle:(int64_t *)outHandle {
    if (outHandle) *outHandle = -1;

    // ── Step 1: Acquire sandbox extension cho bundle root ──────────────────
    // create=true để skip lstat() check vì sandbox chặn stat trước khi có extension
    static char bundleRootC[] = "/var/containers/Bundle/Application/";
    int64_t handle = bad_query(bundleRootC, /*create=*/true, /*group=*/NULL, /*is_group=*/false);

    if (handle < 0) {
        NSLog(@"[BundleScanner] bad_query failed: %lld", (long long)handle);
        NSLog(@"[BundleScanner] Codes: -1=dlsym -2=query -3=outside sandbox -4=kernel rejected");
        return nil;
    }

    NSLog(@"[BundleScanner] sandbox extension acquired: handle=%lld", (long long)handle);

    // ── Step 2: Enumerate UUID directories ────────────────────────────────
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *err = nil;
    NSArray<NSString *> *uuids = [fm contentsOfDirectoryAtPath:kBundleRoot error:&err];
    if (!uuids) {
        NSLog(@"[BundleScanner] enum root failed: %@", err);
        bad_query_release(handle);
        return nil;
    }

    NSLog(@"[BundleScanner] found %lu containers in bundle root", (unsigned long)uuids.count);

    // ── Step 3: Tìm đúng app theo bundle ID ───────────────────────────────
    NSString *foundPath = nil;
    for (NSString *uuid in uuids) {
        NSString *containerPath = [kBundleRoot stringByAppendingPathComponent:uuid];
        NSArray<NSString *> *items = [fm contentsOfDirectoryAtPath:containerPath error:nil];
        for (NSString *item in items) {
            if (![item hasSuffix:@".app"]) continue;
            NSString *appPath = [containerPath stringByAppendingPathComponent:item];
            NSString *infoPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
            NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
            NSString *bid = info[@"CFBundleIdentifier"];
            NSLog(@"[BundleScanner] checked: %@ → %@", item, bid ?: @"(nil)");
            if ([bid isEqualToString:bundleID]) {
                foundPath = appPath;
                NSLog(@"[BundleScanner] ✅ found: %@", foundPath);
                break;
            }
        }
        if (foundPath) break;
    }

    if (!foundPath) {
        NSLog(@"[BundleScanner] app not found for bundleID: %@", bundleID);
        bad_query_release(handle);
        return nil;
    }

    // Trả handle cho caller — caller PHẢI gọi releaseHandle: khi xong
    if (outHandle) *outHandle = handle;
    return foundPath;
}

+ (nullable NSData *)readFileAtPath:(NSString *)absolutePath {
    if (!absolutePath.length) return nil;

    // Acquire extension cho đường dẫn cụ thể
    char *pathC = strdup(absolutePath.fileSystemRepresentation);
    int64_t handle = bad_query(pathC, /*create=*/true, /*group=*/NULL, /*is_group=*/false);
    free(pathC);

    if (handle < 0) {
        NSLog(@"[BundleScanner] readFileAtPath bad_query failed (%lld): %@", (long long)handle, absolutePath);
        return nil;
    }

    NSData *data = [NSData dataWithContentsOfFile:absolutePath];
    bad_query_release(handle);

    if (!data) {
        NSLog(@"[BundleScanner] read failed (file exists but can't read): %@", absolutePath);
    } else {
        NSLog(@"[BundleScanner] ✅ read %lu bytes from: %@", (unsigned long)data.length, absolutePath);
    }
    return data;
}

+ (nullable NSString *)findFile:(NSString *)fileName inBundleForApp:(NSString *)bundleID {
    if (!fileName.length || !bundleID.length) return nil;

    int64_t handle = -1;
    NSString *appPath = [self findAppBundlePath:bundleID outHandle:&handle];
    if (!appPath) return nil;

    // Tìm đệ quy file trong .app bundle
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *found = nil;
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:appPath];
    for (NSString *sub in enumerator) {
        if ([[sub lastPathComponent] isEqualToString:fileName]) {
            found = [appPath stringByAppendingPathComponent:sub];
            NSLog(@"[BundleScanner] ✅ found file: %@", found);
            break;
        }
    }

    if (!found) {
        NSLog(@"[BundleScanner] file '%@' not found in bundle: %@", fileName, appPath);
    }

    bad_query_release(handle);
    return found;
}

+ (void)releaseHandle:(int64_t)handle {
    bad_query_release(handle);
}

#pragma mark - Diagnostic

+ (NSString *)diagnosticForFile:(NSString *)fileName bundleID:(NSString *)bundleID {
    NSMutableString *log = [NSMutableString string];
    [log appendFormat:@"═══ BundleScanner Diagnostic ═══\n"];
    [log appendFormat:@"Target: %@  BundleID: %@\n\n", fileName, bundleID];

    NSFileManager *fm = [NSFileManager defaultManager];

    // Helper block để log kết quả bad_query
    int64_t (^tryBadQuery)(const char *, NSString *) = ^int64_t(const char *path, NSString *label) {
        [log appendFormat:@"[bad_query] %@\n", label];
        char *mutablePath = strdup(path);
        int64_t h = bad_query(mutablePath, true, NULL, false);
        free(mutablePath);
        if (h < 0) {
            NSString *reason;
            switch (h) {
                case -1:   reason = @"dlopen/dlsym failed"; break;
                case -2:   reason = @"query_create failed"; break;
                case -3:   reason = @"containermanager rejected"; break;
                case -4:   reason = @"kernel rejected token"; break;
                case -5:   reason = @"asprintf failed"; break;
                case -254: reason = @"lstat: not found"; break;
                case -255: reason = @"path not absolute"; break;
                default:   reason = [NSString stringWithFormat:@"code %lld", (long long)h];
            }
            [log appendFormat:@"    ❌ %@\n\n", reason];
        } else {
            [log appendFormat:@"    ✅ handle=%lld\n\n", (long long)h];
        }
        return h;
    };

    // ── Test 1: Bundle container (expected to fail — kernel blocks it) ───
    int64_t hBundle = tryBadQuery("/var/containers/Bundle/Application/",
                                  @"Bundle (/var/containers/Bundle/Application/)");

    // ── Test 2: Data container (what bad_query was designed for) ─────────
    static char dataRootC[] = "/var/mobile/Containers/Data/Application/";
    int64_t hData = tryBadQuery(dataRootC,
                                @"Data (/var/mobile/Containers/Data/Application/)");

    // ── Test 3: SystemGroup (original demo target) ────────────────────────
    static char sysGroupC[] = "/var/containers/Shared/SystemGroup/";
    int64_t hSys = tryBadQuery(sysGroupC,
                               @"SystemGroup (/var/containers/Shared/SystemGroup/)");

    // ── Test 4: App Group của app mình ───────────────────────────────────
    static char appGroupC[] = "/var/mobile/Containers/Shared/AppGroup/";
    int64_t hGroup = tryBadQuery(appGroupC,
                                 @"AppGroup (/var/mobile/Containers/Shared/AppGroup/)");

    // ── Summary ──────────────────────────────────────────────────────────
    [log appendFormat:@"─── Summary ───\n"];
    [log appendFormat:@"Bundle:      %@\n", hBundle >= 0 ? @"✅" : @"❌"];
    [log appendFormat:@"Data:        %@\n", hData   >= 0 ? @"✅" : @"❌"];
    [log appendFormat:@"SystemGroup: %@\n", hSys    >= 0 ? @"✅" : @"❌"];
    [log appendFormat:@"AppGroup:    %@\n", hGroup  >= 0 ? @"✅" : @"❌"];

    // ── Nếu Data OK, tìm game Data Container ─────────────────────────────
    if (hData >= 0) {
        [log appendFormat:@"\n─── Scanning Data containers ───\n"];
        NSArray<NSString *> *uuids = [fm contentsOfDirectoryAtPath:@"/var/mobile/Containers/Data/Application/" error:nil];
        [log appendFormat:@"Containers found: %lu\n", (unsigned long)uuids.count];

        for (NSString *uuid in uuids) {
            NSString *base = [@"/var/mobile/Containers/Data/Application/" stringByAppendingPathComponent:uuid];
            // Đọc .com.apple.mobile_container_manager.metadata.plist để tìm bundleID
            NSString *metaPlist = [base stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
            NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:metaPlist];
            NSString *bid = meta[@"MCMMetadataIdentifier"];
            if ([bid isEqualToString:bundleID]) {
                [log appendFormat:@"\n✅ Data container: %@\n", base];
                // List top-level contents
                NSArray *contents = [fm contentsOfDirectoryAtPath:base error:nil];
                [log appendFormat:@"Contents: %@\n", [contents componentsJoinedByString:@", "]];
                // Tìm file target trong data container
                NSDirectoryEnumerator *en = [fm enumeratorAtPath:base];
                for (NSString *sub in en) {
                    if ([[sub lastPathComponent] isEqualToString:fileName]) {
                        [log appendFormat:@"🎉 FOUND: %@/%@\n", base, sub];
                    }
                }
                break;
            }
        }
        bad_query_release(hData);
    }

    if (hBundle >= 0) bad_query_release(hBundle);
    if (hSys    >= 0) bad_query_release(hSys);
    if (hGroup  >= 0) bad_query_release(hGroup);

    return log;
}

@end
