/* ========================================================================== */
/*                                                                            */
/*   telnetd.pike                                                             */
/*   (c) 2010 Ralph Ritoch                                                    */
/*                                                                            */
/*   Description                                                              */
/*    Telnet System                                                           */
/* ========================================================================== */

#include <netinet/in.h>
#include <netdb.h>
#include <stdio.h>
#include <unistd.h>

#include <devices.h>

#include <daemons/telnet.h>


inherit "/lib/domain/secure/modules/m_shell.pike";
inherit "/lib/domain/secure/modules/m_shellvars.pike";

private int sockfd;

void debug(mixed msg) 
{
    //printf("[debug] %O %O\n",msg, backtrace()[-2]);
}

void handle_connect(int fd) 
{ 
    program pty;
    object mypty; 
    pty = (program)"/dev/pty.pike";
    mypty = pty(fd); 
    kernel()->make_user(mypty->name(), mypty->name(), mypty->name(), 0,TELNET_LOGIN_OB);
  
}


private void telnetd() 
{
    sockaddr_storage their_addr; // connector's address information
    socklen_t sin_size;
    int new_fd;
    string s;
    
    printf("server: waiting for connections...\n");
    
    while(1) {  // main accept() loop
        sin_size = _SS_SIZE; // this means nothing... oh well... orig: sizeof their_addr;
        their_addr = sockaddr_storage();        
        new_fd = accept(sockfd, their_addr, sin_size);
        if (new_fd == -1) {
            perror("accept");
            continue;
        }
        
        s = "somewhere!";
        /*
        inet_ntop(their_addr->ss_family,
            get_in_addr((struct sockaddr *)&their_addr),
            s, sizeof s);
        */
        printf("server: got connection from %s on %O\n", s, new_fd);
        
        
        handle_connect(new_fd);

        //close(new_fd);  // parent doesn't need this
    }

    return 0;
}

private void init_shell() 
{
    set_variable("INCLUDE_PATHS","/includes");
    set_variable("LIB_PATHS","/lib");        	
}

int main(int argc, array(string) argv, mixed env) 
{
	
    addrinfo hints, servinfo, p;
    //struct sigaction sa;
    
    if (mappingp(env)) {
    	foreach(env; string k; mixed v) {
    		set_variable(k,v);
    	}
    }
    
    int yes = 1;
    
    //char s[INET6_ADDRSTRLEN];
    
    int rv;

    //memset(&hints, 0, sizeof hints);
        
    debug("start");
    init_shell();
    
    hints = addrinfo();
    
    hints->ai_family = AF_UNSPEC;
    hints->ai_socktype = SOCK_STREAM;
    hints->ai_flags = AI_PASSIVE; // use my IP
    
    debug("have hints");
    servinfo = addrinfo();
    debug("have serverinfo object");
    
    if ((rv = getaddrinfo(NULL, PORT, hints, servinfo)) != 0) {
        debug("getaddrinfo exit");
        fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(rv));
        return 1;
    }
    
    debug("Have getaddrinfo");
    
    // loop through all the results and bind to the first we can
    for(p = servinfo; p != NULL; p = p->ai_next) {
        if ((sockfd = socket(p->ai_family, p->ai_socktype,
                p->ai_protocol)) == -1) {
            perror("server: socket");
            continue;
        }

        if (setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, ({ yes }),
                sizeof(({ yes }))) == -1) {
            perror("setsockopt");
            return 1;//exit(1);
        }

        if (bind(sockfd, p->ai_addr, p->ai_addrlen) == -1) {
            close(sockfd);
            perror("server: bind");
            continue;
        }

        break;
    }

    if (p == NULL)  {
        fprintf(stderr, "server: failed to bind\n");
        return 2;
    }
    debug("Socket is bound!");
    
    freeaddrinfo(servinfo); // all done with this structure

    if (listen(sockfd, BACKLOG) == -1) {
        perror("listen");
        return 1; //exit(1);
    }

/*
    sa.sa_handler = sigchld_handler; // reap all dead processes
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_RESTART;
    if (sigaction(SIGCHLD, &sa, NULL) == -1) {
        perror("sigaction");
        return 1; //exit(1);
    }
*/

  Thread.Thread thread; 
  thread = Thread.Thread(telnetd);
  return 0;
}
