#import "MCMFilzaIntegration.h"
#import "MCMBridge.h"
#import <Foundation/Foundation.h>

// ── Trạng thái global ────────────────────────────────────────────────────────

// YES sau khi sandbox escape (kexploit/) chạy xong.
// MCMFilzaSetUnrestrictedFilesystem(YES) được gọi từ AppDelegate trước MCMFilzaStart.
static BOOL gUnrestrictedFilesystem = NO;

void MCMFilzaSetUnrestrictedFilesystem(BOOL enabled) {
    gUnrestrictedFilesystem = enabled;
    NSLog(@"[MCMFilza] 🔧 gUnrestrictedFilesystem = %@", enabled ? @"YES" : @"NO");
}

BOOL MCMFilzaIsUnrestricted(void) {
    return gUnrestrictedFilesystem;
}

// ── MCMFilzaStart ─────────────────────────────────────────────────────────────

void MCMFilzaStart(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"[MCMFilza] 🚀 Initializing MCM (unrestricted=%@)...", gUnrestrictedFilesystem ? @"YES" : @"NO");
        // Load libsystem_containermanager.dylib + function ptrs
        MCMBridgeInitialize();
        NSLog(@"[MCMFilza] ✅ MCM init complete");
    });
}

// ── Virtual root ──────────────────────────────────────────────────────────────

NSString *MCMFilzaVirtualRoot(void) {
    NSString *homeDir = NSHomeDirectory();
    NSString *documentsDir = [homeDir stringByAppendingPathComponent:@"Documents"];
    NSString *virtualRoot  = [documentsDir stringByAppendingPathComponent:@"Device Storage"];
    NSLog(@"[MCMFilza] 📁 Virtual root: %@", virtualRoot);
    return virtualRoot;
}

// ── Helper: LSApplicationProxy fallback ───────────────────────────────────────

static NSString *_lsProxyContainerPath(NSString *appID) {
    @try {
        Class LSWs = NSClassFromString(@"LSApplicationWorkspace");
        if (!LSWs) return nil;

        SEL defaultSel = NSSelectorFromString(@"defaultWorkspace");
        if (![LSWs respondsToSelector:defaultSel]) return nil;
        id workspace = [LSWs performSelector:defaultSel];
        if (!workspace) return nil;

        SEL proxySel = NSSelectorFromString(@"applicationProxyForIdentifier:");
        if (![workspace respondsToSelector:proxySel]) return nil;
        id proxy = [workspace performSelector:proxySel withObject:appID];
        if (!proxy) return nil;

        // dataContainerURL: trả về URL của data container app (private API iOS 8+)
        SEL urlSel = NSSelectorFromString(@"dataContainerURL");
        if ([proxy respondsToSelector:urlSel]) {
            NSURL *url = [proxy performSelector:urlSel];
            NSString *path = [url path];
            if (path.length > 0) {
                NSLog(@"[MCMFilza] 📱 LSApplicationProxy container for %@: %@", appID, path);
                return path;
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[MCMFilza] ⚠️ LSProxy exception for %@: %@", appID, e);
    }
    return nil;
}

// ── MCMFilzaDataContainerPath ─────────────────────────────────────────────────

NSString *MCMFilzaDataContainerPath(NSString *appID, NSString **error) {
    if (!appID || appID.length == 0) {
        if (error) *error = @"appID is nil or empty";
        return nil;
    }

    // Đảm bảo MCM bridge đã load
    MCMFilzaStart();

    // ── Thử 1: MCM C API (cần sandbox extension activation trên iOS 18) ──────

    if (MCM_container_query_create) {
        @try {
            container_query_t query = NULL;
            int result = MCM_container_query_create(&query);
            if (result == 0 && query) {
                result = MCM_container_query_set_class(query, CONTAINER_CLASS_APP_DATA);
                if (result == 0) {
                    int count = 0;
                    container_object_t *results = NULL;
                    result = MCM_container_query_iterate_results_sync(query, &count, &results);
                    if (result == 0 && count > 0) {
                        for (int i = 0; i < count; i++) {
                            if (!results[i]) continue;
                            const char *identifier = MCM_container_object_identifier(results[i]);
                            if (!identifier) continue;
                            NSString *containerID = [NSString stringWithUTF8String:identifier];
                            if (![containerID isEqualToString:appID]) continue;

                            // iOS 18+: container_object_path cần sandbox extension activation trước.
                            // Gọi container_copy_sandbox_token + container_object_sandbox_extension_activate
                            // để mở rộng sandbox của process sang container này.
                            if (MCM_container_copy_sandbox_token && MCM_container_object_sandbox_extension_activate) {
                                void *token = NULL;
                                int tr = MCM_container_copy_sandbox_token(results[i], &token);
                                NSLog(@"[MCMFilza] 🔑 copy_sandbox_token %@: ret=%d token=%p", appID, tr, token);
                                if (token) {
                                    int ar = MCM_container_object_sandbox_extension_activate(results[i], token);
                                    NSLog(@"[MCMFilza] 🔓 sandbox_ext_activate %@: ret=%d", appID, ar);
                                }
                            }

                            // Sau khi activate, lấy path
                            const char *path = MCM_container_object_path(results[i]);
                            if (path) {
                                NSString *cp = [NSString stringWithUTF8String:path];
                                NSLog(@"[MCMFilza] ✅ MCM path for %@: %@", appID, cp);
                                MCM_container_query_release(query);
                                return cp;
                            }
                            NSLog(@"[MCMFilza] ⚠️ container_object_path nil for %@", appID);
                        }
                    } else {
                        NSLog(@"[MCMFilza] ⚠️ iterate_results: ret=%d count=%d", result, count);
                    }
                }
                MCM_container_query_release(query);
            } else {
                NSLog(@"[MCMFilza] ⚠️ container_query_create failed: %d", result);
            }
        } @catch (NSException *e) {
            NSLog(@"[MCMFilza] ❌ MCM exception for %@: %@", appID, e);
        }
    } else {
        NSLog(@"[MCMFilza] ⚠️ MCM functions not loaded, skip to LSProxy fallback");
    }

    // ── Thử 2: LSApplicationProxy.dataContainerURL (fallback iOS 18+) ─────────

    NSString *lsPath = _lsProxyContainerPath(appID);
    if (lsPath) {
        if (error) *error = nil;
        return lsPath;
    }

    // Cả hai đều thất bại
    if (error) *error = @"MCM + LSProxy đều thất bại (sandbox token không khả dụng trên iOS này)";
    NSLog(@"[MCMFilza] ❌ Both MCM and LSProxy failed for %@", appID);
    return nil;
}

// ── MCMFilzaGetSandboxToken ───────────────────────────────────────────────────

void *MCMFilzaGetSandboxToken(NSString *appID) {
    if (!appID || appID.length == 0) return NULL;
    if (!MCM_container_query_create) return NULL;

    @try {
        container_query_t query = NULL;
        int result = MCM_container_query_create(&query);
        if (result != 0 || !query) return NULL;

        MCM_container_query_set_class(query, CONTAINER_CLASS_APP_DATA);
        int count = 0;
        container_object_t *results = NULL;
        MCM_container_query_iterate_results_sync(query, &count, &results);

        void *token = NULL;
        for (int i = 0; i < count; i++) {
            if (!results[i]) continue;
            const char *identifier = MCM_container_object_identifier(results[i]);
            if (identifier && strcmp(identifier, [appID UTF8String]) == 0) {
                if (MCM_container_copy_sandbox_token)
                    MCM_container_copy_sandbox_token(results[i], &token);
                break;
            }
        }

        MCM_container_query_release(query);
        if (token) NSLog(@"[MCMFilza] ✅ Got sandbox token for %@", appID);
        return token;
    } @catch (NSException *e) {
        NSLog(@"[MCMFilza] ❌ Exception getting sandbox token: %@", e);
        return NULL;
    }
}
