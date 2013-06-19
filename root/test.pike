/* ========================================================================== */
/*                                                                            */
/*   Filename.c                                                               */
/*   (c) 2001 Author                                                          */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */


#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>

int main() {

 addrinfo hints = addrinfo();
 
 addrinfo res = addrinfo();
 
 hints.ai_family = AF_UNSPEC;
 hints.ai_socktype = SOCK_STREAM;
 hints.ai_flags = AI_PASSIVE; // use my IP
 
 int ret;
 ret = getaddrinfo(NULL, 
                3333,
                hints,
                res); 
 write("ret = %O res = %O\n",ret,res);
}

