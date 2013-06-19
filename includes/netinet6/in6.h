/* ========================================================================== */
/*                                                                            */
/*   Filename.c                                                               */
/*   (c) 2001 Author                                                          */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */

#ifndef NETINET6_IN_H
#define NETINET6_IN_H


#include <sys/types.h>
#include <sys/socket.h>

#define in_port_t uint16_t
#define in_addr_t uint32_t


// IPv6 AF_INET6 sockets:

class sockaddr_in6 {
 sa_family_t       sin6_family;   // address family, AF_INET6
 in_port_t       sin6_port;     // port number, Network Byte Order
 uint_32_t       sin6_flowinfo; // IPv6 flow information
 in6_addr  sin6_addr;     // IPv6 address
 uint_32_t       sin6_scope_id; // Scope ID
}

class in6_addr {
 string s6_addr;   // load with inet_pton()
 //uint8_t s6_addr[16]
}

// const struct in6_addr in6addr_any
// const struct in6_addr in6addr_loopback

class ipv6_mreq {
 in6_addr ipv6mr_multiaddr;
 unsigned ipv6mr_interface;
}

#define INET6_ADDRSTRLEN 46



//The <netinet/in.h> header shall define the following macros, with distinct integer values, for use in the option_name argument in the getsockopt() or setsockopt() functions at protocol level IPPROTO_IPV6:

#define IPV6_JOIN_GROUP 1
//    Join a multicast group.
#define IPV6_LEAVE_GROUP 2
//    Quit a multicast group.
#define IPV6_MULTICAST_HOPS 3
//    Multicast hop limit.
#define IPV6_MULTICAST_IF 4
//    Interface to use for outgoing multicast packets.
#define IPV6_MULTICAST_LOOP 5
//    Multicast packets are delivered back to the local application.

#define IPV6_UNICAST_HOPS 100
//    Unicast hop limit.
#define IPV6_V6ONLY 0
//    Restrict AF_INET6 socket to IPv6 communications only.

//The <netinet/in.h> header shall define the following macros that test for special IPv6 addresses. Each macro is of type int and takes a single argument of type const struct in6_addr *:

#define IN6_IS_ADDR_UNSPECIFIED 1
//    Unspecified address.
#define IN6_IS_ADDR_LOOPBACK 2 // this is wrong
//    Loopback address.

#define IN6_IS_ADDR_MULTICAST 2 // this is wrong
//    Multicast address.
#define IN6_IS_ADDR_LINKLOCAL 3
//    Unicast link-local address.
#define IN6_IS_ADDR_SITELOCAL 4

//    Unicast site-local address.
#define IN6_IS_ADDR_V4MAPPED 5

//    IPv4 mapped address.
#define IN6_IS_ADDR_V4COMPAT 6

//    IPv4-compatible address.
#define IN6_IS_ADDR_MC_NODELOCAL 7

//    Multicast node-local address.
#define IN6_IS_ADDR_MC_LINKLOCAL 8

//    Multicast link-local address.

#define IN6_IS_ADDR_MC_SITELOCAL 9

//    Multicast site-local address.
#define IN6_IS_ADDR_MC_ORGLOCAL 10

//    Multicast organization-local address.
#define IN6_IS_ADDR_MC_GLOBAL 11

//    Multicast global address. [Option End] 

#endif
