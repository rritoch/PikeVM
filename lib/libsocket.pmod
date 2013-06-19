/* ========================================================================== */
/*                                                                            */
/*   libsocket.pmod                                                           */
/*   (c) 2010 Author                                                          */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */

#define LIBSOCKET

#include <sys/socket.h>
#include <sys/ioctl.h>

int getsockopt(int s, int level, int optname, pike_pointer optval, pike_pointer optlen) {
 return ioctl(s,IOC_STRING,"getsockopt",level,optname,optval,optlen);  
} 

int setsockopt(int s, int level, int optname, mixed optval, socklen_t optlen) {
 return ioctl(s,IOC_STRING,"setsockopt",level,optname,optval,optlen);
}
 
int bind(int sockfd, object my_addr, socklen_t addrlen) {
 return ioctl(sockfd,IOC_STRING,"bind",my_addr, addrlen);
}

int listen(int sockfd, int backlog) {
 return ioctl(sockfd,IOC_STRING,"listen",backlog);
}

int accept(int sockfd, object addr, socklen_t addrlen) {
 pike_pointer ret = pike_pointer(({ -1 }));
 int err;
 err = ioctl(sockfd, IOC_STRING,"accept", ret, addr,addrlen);
 if (err) return -1;
 return ret->value[0];
} 
