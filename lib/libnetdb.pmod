/* ========================================================================== */
/*                                                                            */
/*   libnetdb.pmod                                                            */
/*   (c) 2010 Ralph Ritoch                                                    */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */

#ifndef LIBNETDB
#define LIBNETDB
#endif

#include <netdb.h>


int getaddrinfo(string node, 
                int|string service,
                addrinfo hints,
                addrinfo res) {

 addrinfo cur;
 int port;
 
 string canonname;
 
 canonname = node;
 if (hints->ai_canonname) {
  canonname = hints->ai_canonname;
 }
   
 if (!canonname && hints->ai_flags == AI_PASSIVE) {
  canonname = gethostname();
 }

 if (intp(service)) {
  port = service;
 }
 
 if (!node) {
  /* Seems we are opening a port */
           
  cur = res;  
  cur->ai_flags = hints->ai_flags;
  cur->ai_family = hints->ai_family;
  cur->ai_socktype = hints->ai_socktype;
  cur->ai_protocol = IPPROTO_TCP;
  cur->ai_addrlen = 6; 
  cur->ai_canonname = canonname;
  cur->ai_addr = sockaddr_in();
  cur->ai_addr->sin_port = port; 
  cur->ai_addr->sin_family = hints->ai_family;
  cur->ai_addr->sin_addr = in_addr();
  cur->ai_addr->sin_addr->s_addr = INADDR_ANY;    
  cur->ai_next = NULL;
    
 } else {
 
 }
 
 return 0;
}


void freeaddrinfo(addrinfo res) {
 object next;
 object prev;
 
 next = res;
 while(next) {
  prev = next;
  destruct(prev->ai_addr);
  next = res->ai_next;
  destruct(prev);
 }
}

string gai_strerror(int errcode) {

}
