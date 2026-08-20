//
// bad_query.h
// Adapted from forcequitOS/bad_query (MIT-compatible, unmodified logic)
//

#ifndef bad_query_h
#define bad_query_h

#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>

/**
 * bad_query — Sandbox escape via containermanager path traversal.
 *
 * @param path            Absolute path to gain access to (e.g. "/var/mobile/Containers/Data/Application")
 * @param create          YES = skip lstat() check (use when path may not exist yet)
 * @param group_identifier NULL = SystemGroup route (class 13); non-NULL = AppGroup route (class 7)
 * @param is_group        YES = use App Group flags (iOS 26 only); NO otherwise
 *
 * Return values:
 *   > 0   : sandbox extension handle (success — keep alive until bad_query_release)
 *   -1    : dlopen/dlsym failed (libsystem_containermanager not found)
 *   -2    : container_query_create failed
 *   -3    : containermanager rejected query (iOS version not vulnerable)
 *   -4    : kernel refused to issue sandbox extension token (patched)
 *   -5    : asprintf failed
 *   -254  : lstat() failed — path not found (create=false)
 *   -255  : path is not absolute
 */
int64_t bad_query(char *path, bool create, char *group_identifier, bool is_group);

/**
 * Release a sandbox extension handle previously returned by bad_query.
 * Safe to call with a negative handle (no-op).
 */
void bad_query_release(int64_t handle);

/**
 * Enumerate all immediate children of path via inode scan (fsgetpath).
 * Works even without directory read access. Returns newline-delimited
 * list of full paths. Caller must free() the result.
 *
 * @param path       Directory to enumerate (must have a sandbox extension active)
 * @param max_inode  Upper inode bound to scan (use ~200000 for /var/mobile/Containers)
 */
char *bad_query_list(char *path, int64_t max_inode);

#endif /* bad_query_h */
