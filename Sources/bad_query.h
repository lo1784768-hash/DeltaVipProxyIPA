//
//  bad_query.h
//  Originally by Taj C (forcequitOS/bad_query) — iOS 26.0-26.6.1 / 27.0b4
//  Integrated for bundle container read access
//

#ifndef bad_query_h
#define bad_query_h

#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>

// Acquires a sandbox extension for the given absolute path by exploiting
// containermanager's path traversal. Returns a handle >= 0 on success.
// Error codes: -1 (dlopen/dlsym), -2 (query create), -3 (outside sandbox),
//              -4 (kernel rejected), -5 (asprintf), -254 (file not found),
//              -255 (not absolute path)
// Pass create=true to skip the initial lstat() check (needed when sandbox
// blocks stat on the target path before extension is consumed).
int64_t bad_query(char* path, bool create, char *group_identifier, bool is_group);

// Enumerate direct subdirectories of 'path' using fsgetpath + inode scan.
// Returns newline-separated list of paths. Caller must free().
// max_inode: scan up to this inode number (try 500000 as a starting point).
char *bad_query_list(char *path, int64_t max_inode);

// Release a previously consumed sandbox extension.
void bad_query_release(int64_t handle);

#endif /* bad_query_h */
