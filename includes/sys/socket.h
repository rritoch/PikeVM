/* ========================================================================== */
/*                                                                            */
/*   Filename.c                                                               */
/*   (c) 2001 Author                                                          */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */


#ifndef __SOCKET_H
#define __SOCKET_H

#ifndef LIBSOCKET
inherit libsocket;
#endif

#include <sys/types.h>
#include <sys/os_uio.h>

#define socklen_t int
#define sa_family_t int


// need iovec

class sockaddr {
 int    sa_family;    // address family, AF_xxx
 string sa_data;  // 14 bytes of protocol address
}

class msghdr {
 mixed msg_name; //       optional address
 socklen_t     msg_namelen; //    size of address
 iovec msg_iov; //         scatter/gather array
 int           msg_iovlen; //      members in msg_iov
 mixed         msg_control; //     ancillary data, see below
 socklen_t     msg_controllen; //  ancillary data buffer len
 int           msg_flags; //       flags on received message
}

class cmsghdr {
 socklen_t     cmsg_len; //        data byte count, including the cmsghdr
 int           cmsg_level; //      originating protocol
 int           cmsg_type; //       protocol-specific type
}

#define SCM_RIGHTS 1

//#define CMSG_DATA(cmsg) cmsg
//#define CMSG_NXTHDR(mhdr,cmsg)
//#define CMSG_FIRSTHDR(mhdr)

class linger {
 int l_onoff;
 int l_linger;
}


#define SOCK_DGRAM     1    
#define SOCK_STREAM    2
#define SOCK_SEQPACKET 3 
#define SOCK_RAW       4
#define SOCK_RDM       5
#define SOCK_PACKET    6

/* option name used in getsockopt or setsockopt */

#define SO_ACCEPTCONN 1
//    Socket is accepting connections.     
#define SO_BROADCAST 2
//    Transmission of broadcast messages is supported. 
#define SO_DEBUG 3
//    Debugging information is being recorded. 
#define SO_DONTROUTE 4
//    bypass normal routing 
#define SO_ERROR 5
//    Socket error status. 
#define SO_KEEPALIVE 6
//    Connections are kept alive with periodic messages. 
#define SO_LINGER 7
//    Socket lingers on close. 
#define SO_OOBINLINE 8
//    Out-of-band data is transmitted in line. 
#define SO_RCVBUF 9
//    Receive buffer size. 
#define SO_RCVLOWAT 10
//    receive "low water mark" 
#define SO_RCVTIMEO 11
//    receive timeout 
#define SO_REUSEADDR 12
//    Reuse of local addresses is supported. 
#define SO_SNDBUF 13
//    Send buffer size. 
#define SO_SNDLOWAT 14
//    send "low water mark" 
#define SO_SNDTIMEO 16
//    send timeout 
#define SO_TYPE 17
//    Socket type. 


#define MSG_CTRUNC 1
//    Control data truncated. 
#define MSG_DONTROUTE 2
//    Send without using routing tables. 
#define MSG_EOR 3
//    Terminates a record (if supported by the protocol). 
#define MSG_OOB 4
//    Out-of-band data. 
#define MSG_PEEK 5
//    Leave received data in queue. 
#define MSG_TRUNC 6
//    Normal data truncated. 
#define MSG_WAITALL 7
//    Wait for complete message.     


#define AF_UNIX 1
//    UNIX domain sockets 
#define AF_UNSPEC 127
//    Unspecified 
#define AF_INET 3
//    Internet domain sockets 


#define PF_UNIX      1
#define PF_LOCAL     2  
#define PF_INET      3 //IPv4 Internet protocols  ip(7)  
#define PF_INET6     4 //IPv6 Internet protocols  
#define PF_IPX       5 //IPX - Novell protocols  
#define PF_NETLINK   6 //Kernel user interface device  netlink(7)  
#define PF_X25       7 //ITU-T X.25 / ISO-8208 protocol  x25(7)  
#define PF_AX25      8//Amateur radio AX.25 protocol  
#define PF_ATMPVC    9// Access to raw ATM PVCs  
#define PF_APPLETALK 10//  Appletalk  ddp(7)  
#define PF_PACKET    11  


#define SOL_IP          0
#define SOL_ICMP        1  //     No-no-no! Due to Linux :-) we cannot use SOL_ICMP=1 */
#define SOL_TCP         6
#define SOL_UDP         17
#define SOL_IPV6        41
#define SOL_ICMPV6      58
#define SOL_SCTP        132
#define SOL_UDPLITE     136     /* UDP-Lite (RFC 3828) */
#define SOL_RAW         255
#define SOL_IPX         256
#define SOL_AX25        257
#define SOL_ATALK       258
#define SOL_NETROM      259
#define SOL_ROSE        260
#define SOL_DECNET      261
#define SOL_X25         262
#define SOL_PACKET      263
#define SOL_ATM         264     /* ATM layer (cell level) */
#define SOL_AAL         265     /* ATM Adaption Layer (packet level) */
#define SOL_IRDA        266
#define SOL_NETBEUI     267
#define SOL_LLC         268
#define SOL_DCCP        269
#define SOL_NETLINK     270
#define SOL_TIPC        271
#define SOL_RXRPC       272
#define SOL_PPPOL2TP    273
#define SOL_BLUETOOTH   274
#define SOL_PNPIPE      275
#define SOL_RDS         276
#define SOL_IUCV        277

#define SOL_SOCKET	0xffff


/*

int     accept(int socket, struct sockaddr *address,
             socklen_t *address_len);
int     bind(int socket, const struct sockaddr *address,
             socklen_t address_len);
int     connect(int socket, const struct sockaddr *address,
             socklen_t address_len);
int     getpeername(int socket, struct sockaddr *address,
             socklen_t *address_len);
int     getsockname(int socket, struct sockaddr *address,
             socklen_t *address_len);
int     getsockopt(int socket, int level, int option_name,
             void *option_value, socklen_t *option_len);
int     listen(int socket, int backlog);
ssize_t recv(int socket, void *buffer, size_t length, int flags);
ssize_t recvfrom(int socket, void *buffer, size_t length,
             int flags, struct sockaddr *address, socklen_t *address_len);
ssize_t recvmsg(int socket, struct msghdr *message, int flags);
ssize_t send(int socket, const void *message, size_t length, int flags);
ssize_t sendmsg(int socket, const struct msghdr *message, int flags);
ssize_t sendto(int socket, const void *message, size_t length, int flags,
             const struct sockaddr *dest_addr, socklen_t dest_len);
int     setsockopt(int socket, int level, int option_name,
             const void *option_value, socklen_t option_len);
int     shutdown(int socket, int how);
int     socket(int domain, int type, int protocol);
int     socketpair(int domain, int type, int protocol,
             int socket_vector[2]);

*/

#endif