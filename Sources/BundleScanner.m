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

@end
