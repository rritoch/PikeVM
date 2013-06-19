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

#include "/includes/devices.h"
#include "/includes/master.h"

#define PORT 3333
#define BACKLOG 100

mapping(string:string) shell_env = ([]);

void debug(mixed msg) {
 //printf("[debug] %O %O\n",msg, backtrace()[-2]);
}

 int is_shell() {
  return 1;
 }

 void handle_call_out(function f, mixed ... args) {
  f(@args);
 }

string get_cwd() {
 if (!zero_type(shell_env["CWD"])) {
  return shell_env["CWD"];
 }
 return ".";
}

mapping(string:string) environment() {
 return copy_value(shell_env);
}

string set_env(string vname, string val) {
 shell_env[vname] = val;
 return val;
}

string get_env(string vname) {
 if (zero_type(shell_env[vname])) {
  return "";
 }
 return shell_env[vname];
}

 joinnode_t get_root_module(object|void current_handler) {
  string lib_path;
  string p;
  array(string) paths;
  string cwd;
  string clean_path;
  joinnode_t root_module;
 
#ifdef DEBUG_GET_ROOT_MODULE
  write("sh.pike: get_root_module(%O)",current_handler);
#endif  
  
  if (zero_type(shell_env["LIB_PATHS"])) {
   lib_path = "";
  } else {
   lib_path = shell_env["LIB_PATHS"];
  }
  
  // Cache!
  //if (last_root_module_path && last_root_module_path == lib_path) return root_module;
  
  // New Tree
  root_module = master()->joinnode(({}));
  
  // Init Vars
  paths = lib_path / ";";  
  cwd = get_cwd();
  
  // Build Tree
  foreach(paths,p) {
   clean_path = combine_path(cwd,p);
   // Can Read/Exec Check here????
   root_module->add_path(clean_path);
  }
  // Init Cache!
  //last_root_module_path = lib_path;
  // Done!
  return root_module; 
 } 



void handle_connect(int fd) { 
 program pty;
 object mypty;
 
 pty = (program)"/dev/pty.pike";
 mypty = pty(fd);
 
 kernel()->make_user(mypty->name(), mypty->name(), mypty->name(), 0);
  
}


private void telnetd() {
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

        close(new_fd);  // parent doesn't need this
    }

    return 0;
}

private int sockfd;

int main(int argc, array(string) argv, mixed env) {
    addrinfo hints, servinfo, p;
    //struct sigaction sa;
    shell_env = copy_value(env);
    int yes = 1;
    
    //char s[INET6_ADDRSTRLEN];
    
    int rv;

    //memset(&hints, 0, sizeof hints);
    
    debug("start");
    
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
