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
#include <addrinfo.h>

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

int connect(int socket, object address, socklen_t address_len) {
     pike_pointer ret = pike_pointer(({ -1 }));
     int err;
     err = ioctl(socket, IOC_STRING,"connect", ret, address, address_len);
     if (err) return -1;
     return ret->value[0];	
}

int accept(int sockfd, object addr, socklen_t addrlen) {
 pike_pointer ret = pike_pointer(({ -1 }));
 int err;
 err = ioctl(sockfd, IOC_STRING,"accept", ret, addr,addrlen);
 if (err) return -1;
 return ret->value[0];
} 

int getpeername(int s, pike_pointer name, pike_pointer namelen) 
{
    pike_pointer ret = pike_pointer(({ -1 }));
    int err;
    err = ioctl(s, IOC_STRING,"getpeername", ret, name,namelen);
    if (err) return -1;
    return ret->value[0];	
}

int getsockname(int s, pike_pointer name, pike_pointer namelen) 
{
    pike_pointer ret = pike_pointer(({ -1 }));
    int err;
    err = ioctl(s, IOC_STRING,"getsockname", ret, name,namelen);
    if (err) return -1;
    return ret->value[0];	
}


string inet_ntoa(in_addr in) 
{
	
	int hold = in->s_addr;
	array(string) parts = ({ 0,0,0,0 });	
	parts[3] = (string)(hold & 255);
    hold = hold / 256;
    parts[2] = (string)(hold & 255);
    hold = hold / 256;
    parts[1] = (string)(hold & 255);
    hold = hold / 256;
    parts[0] = (string)(hold & 255);
	
	return parts * ".";
}

int inet_addr(string addr) 
{
    array(string) parts = addr / ".";
    
    if (sizeof(parts) != 4) {
    	return -1;
    }
            	
    int p4 = ((int)parts[0]) & 255;
    int p3 = ((int)parts[1]) & 255;
    int p2 = ((int)parts[2]) & 255;
    int p1 = ((int)parts[3]) & 255;

    return p1 + (p2 * 256) + (p3 * 65536) + (p4 * 16777216);
}