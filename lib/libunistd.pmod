/* ========================================================================== */
/*                                                                            */
/*   Filename.c                                                               */
/*   (c) 2001 Author                                                          */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */

#define LIBUNISTD

#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/types.h>

int close(int fd) 
{
	return ioctl(fd,IOC_STRING,"close"); 
}

int select(int nfds, pike_pointer readfds, pike_pointer writefds,
                  pike_pointer exceptfds, pike_pointer timeout) 
{
    return kernel()->select(nfds, readfds, writefds, exceptfds, timeout);             	
}
