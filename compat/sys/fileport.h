/*
 * compat/sys/fileport.h — stub for sys/fileport.h (private XNU header).
 * Provides declarations used by kexploit_opa334.m.
 */
#ifndef _SYS_FILEPORT_H
#define _SYS_FILEPORT_H

#include <sys/types.h>
#include <mach/port.h>

__BEGIN_DECLS

/* Convert a file descriptor to a Mach send right (fileport). */
int fileport_makeport(int fd, mach_port_t *portname);

/* Convert a fileport Mach port back to a file descriptor. */
int fileport_makefd(mach_port_t port);

__END_DECLS

#endif /* _SYS_FILEPORT_H */
