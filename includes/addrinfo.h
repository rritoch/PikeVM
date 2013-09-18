/* ========================================================================== */
/*                                                                            */
/*   Filename.c                                                               */
/*   (c) 2001 Author                                                          */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */

#ifndef	__addrinfo_h
#define	__addrinfo_h

#include <netinet/in.h>

/*
 * Everything here really belongs in <netdb.h>.
 * These defines are separate for now, to avoid having to modify the
 * system's header.
 */


			/* following for getaddrinfo() */
#define	AI_PASSIVE		 1	/* socket is intended for bind() + listen() */
#define	AI_CANONNAME	 2	/* return canonical name */

			/* following for getnameinfo() */
#define	NI_MAXHOST	  1025	/* max hostname returned */
#define	NI_MAXSERV	    32	/* max service name returned */

#define	NI_NOFQDN	     1	/* do not return FQDN */
#define	NI_NUMERICHOST   2	/* return numeric form of hostname */
#define	NI_NAMEREQD	     4	/* return error if hostname not found */
#define	NI_NUMERICSERV   8	/* return numeric form of service name */
#define	NI_DGRAM	    16	/* datagram service for getservbyname() */

			/* error returns */
#define	EAI_ADDRFAMILY	 1	/* address family for host not supported */
#define	EAI_AGAIN		 2	/* temporary failure in name resolution */
#define	EAI_BADFLAGS	 3	/* invalid value for ai_flags */
#define	EAI_FAIL		 4	/* non-recoverable failure in name resolution */
#define	EAI_FAMILY		 5	/* ai_family not supported */
#define	EAI_MEMORY		 6	/* memory allocation failure */
#define	EAI_NODATA		 7	/* no address associated with host */
#define	EAI_NONAME		 8	/* host nor service provided, or not known */
#define	EAI_SERVICE		 9	/* service not supported for ai_socktype */
#define	EAI_SOCKTYPE	10	/* ai_socktype not supported */
#define	EAI_SYSTEM		11	/* system error returned in errno */


class addrinfo {
  int		ai_flags;			/* AI_PASSIVE, AI_CANONNAME */
  int		ai_family;			/* PF_xxx */
  int		ai_socktype;		/* SOCK_xxx */
  int		ai_protocol;		/* IPPROTO_xxx for IPv4 and IPv6 */
  size_t	ai_addrlen;			/* length of ai_addr */
  //char		*ai_canonname;		/* canonical name for host */
  string ai_canonname;
  //sockaddr	ai_addr;	/* binary address */
  mixed ai_addr;
  addrinfo	ai_next;	/* next structure in linked list */
 
  string _sprintf(int t) {
   if (t == 'O') {
    string t_flags;
    t_flags = sprintf("ai_flags = %O,",ai_flags);
    if (ai_flags == AI_PASSIVE) {
     t_flags = "ai_flags = AI_PASSIVE,";
    }
    if (ai_flags == AI_CANONNAME) {
     t_flags = "ai_flags = AI_CANONNAME,";
    }
     
    return "addrinfo(" +
            t_flags +
           sprintf("ai_family = %O,",ai_family) + 
           sprintf("ai_socktype = %O,",ai_socktype) +
           sprintf("ai_protocol = %O,",ai_protocol) +
           sprintf("ai_addrlen = %O,",ai_addrlen) +
           sprintf("ai_canonname = %O,",ai_canonname) +
           sprintf("ai_addr = %O\n",ai_addr) +
           sprintf("ai_next = %O",ai_next) +
           ")";
    
   }
   return 0;
  } 
  
}


#endif	/* __addrinfo_h */
