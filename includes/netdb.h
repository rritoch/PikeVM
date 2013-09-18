/* ========================================================================== */
/*                                                                            */
/*   Filename.c                                                               */
/*   (c) 2001 Author                                                          */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */

#ifndef __NETDB_H
#define __NETDB_H

#ifndef LIBNETDB
inherit libnetdb;
#endif

#include <addrinfo.h>

class hostent {
//char  *h_name      Official name of the host.
//char **h_aliases   A pointer to an array of pointers to alternative host names,                   terminated by a null pointer.
//int    h_addrtype  Address type.
//int    h_length    The length, in bytes, of the address.
//char **h_addr_list A pointer to an array of pointers to network addresses (in
//                   network byte order) for the host, terminated by a null pointer.
 string h_name;
 array(string) h_aliases;
 int h_addrtype; 
 int h_length;
 array(string) h_addr_list;
}


class netent {
/*
 char  *n_name      Official, fully-qualified (including the domain) name of the host.
 char **n_aliases   A pointer to an array of pointers to alternative network names,
                   terminated by a null pointer.
*/
 string n_name;
 array(string) n_aliases;
 int n_addrtype; // The address type of the network.
 uint32_t n_net; //The network number, in host byte order.
}


class protoent {

/*char  *p_name      Official name of the protocol.
char **p_aliases   A pointer to an array of pointers to alternative protocol names,
                   terminated by a null pointer.
*/

 string p_name;
 array(string) p_aliases;
 int p_proto; // The protocol number.
}

class servent {
 /*
  char  *s_name      Official name of the service.
  char **s_aliases   A pointer to an array of pointers to alternative service names,
                     terminated by a null pointer.
  char  *s_proto     The name of the protocol to use when contacting the service.
*/

 string s_name;
 array(string) s_aliases;
 int    s_port; //      The port number at which the service resides, in network byte order. 
 string s_proto;
}

// extern int h_errno;

#define IPPORT_RESERVED 1024

#define HOST_NOT_FOUND 1
#define NO_DATA 2
#define NO_RECOVERY 3
#define TRY_AGAIN 4


/*
void             endhostent(void);
void             endnetent(void);
void             endprotoent(void);
void             endservent(void);
struct hostent  *gethostbyaddr(const void *addr, size_t len, int type);
struct hostent  *gethostbyname(const char *name);
struct hostent  *gethostent(void);
struct netent   *getnetbyaddr(uint32_t net, int type);
struct netent   *getnetbyname(const char *name);
struct netent   *getnetent(void);
struct protoent *getprotobyname(const char *name);
struct protoent *getprotobynumber(int proto);
struct protoent *getprotoent(void);
struct servent  *getservbyname(const char *name, const char *proto);
struct servent  *getservbyport(int port, const char *proto);
struct servent  *getservent(void);
void             sethostent(int stayopen);
void             setnetent(int stayopen);
void             setprotoent(int stayopen);
void             setservent(int stayopen);


*/

#endif
