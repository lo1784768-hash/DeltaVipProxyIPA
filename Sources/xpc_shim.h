/*
 * xpc_shim.h
 *
 * Minimal XPC type/function declarations cho bad_query.c.
 * Dùng thay vì <xpc/xpc.h> để tránh Clang module conflict
 * khi build với -fmodules -fno-implicit-modules.
 *
 * Các symbol này đều có trong libSystem (không cần link thêm).
 */

#ifndef xpc_shim_h
#define xpc_shim_h

typedef void *xpc_object_t;

extern xpc_object_t xpc_string_create(const char *string);
extern void         xpc_release(xpc_object_t object);

#endif /* xpc_shim_h */
