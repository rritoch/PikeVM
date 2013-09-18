/**
 * FTPD
 */
 
#include <netinet/in.h>
#include <netdb.h>
#include <stdio.h>
#include <unistd.h>


#include <devices.h>
#include <daemons/ftp.h>

private int sockfd;

private  mapping sessions = ([]);
private  mapping dataports = ([]);
private  mapping(object:object) passives = ([]);
private string iphost;
private int lastport = MIN_PORT;
private mixed idlecall;

//inherit M_ACCESS;

inherit "/lib/domain/secure/modules/m_shell.pike";
inherit "/lib/domain/secure/modules/m_shellvars.pike";

class ftp_session 
{
   int	connected;
   string	user;
   mixed	priv;
   string	pwd;
   object	dataPipe;
   int	cmdfd;
   int	idleTime;
   int	binary;   
   string	targetFile;
   string command;
   int filepos;
   string renamefrom;

   private array(mixed) _address;
   
   protected void destroy() 
   {
   	   if (dataPipe){
   	       destruct(dataPipe);
   	   }
       close(cmdfd);
   }
   
   array(mixed) address() 
   {
   	      	   
   	   if (!arrayp(_address)) {   	   	   
   	   	    _address = ({"x.x.x.x",0});   	   	    
   	   	    pike_pointer name = pike_pointer();
   	   	    pike_pointer namelen = pike_pointer();
            if(getpeername(cmdfd, name,namelen) != -1) {                
                 _address[0] = inet_ntoa(name->value[0]->sin_addr);
                 _address[1] = name->value[0]->sin_port;
            }               	   
   	   }
       return _address;	
   }
}

class data_socket 
{
	int local_port;
	object session;
	int socket = -1;
	int has_socket = 0;
	int listen_socket = -1;
	int has_listen_socket = 0;
	int binary;
		   
    function close_cb;
    function read_cb;
    function write_cb;
   
    void remove_clean() 
    {
		if (has_listen_socket) {
			close(listen_socket);
		}
		if (has_socket) {
			close(socket);			
		}		    	
        close_cb();
    }	
	
    private void get_connection() 
    {
    	socket = -1;
    	
        sockaddr_storage their_addr; // connector's address information
        socklen_t sin_size;        
        string s;
                
        while(socket == -1) {  // main accept() loop
            sin_size = _SS_SIZE; // this means nothing... oh well... orig: sizeof their_addr;
            their_addr = sockaddr_storage();        
            socket = accept(listen_socket, their_addr, sin_size);
            if (socket == -1) {
                perror("accept");
                continue;
            }
        
            has_socket = 1;            
            s = "somewhere!";
            /*
                inet_ntop(their_addr->ss_family,
                    get_in_addr((struct sockaddr *)&their_addr),
                    s, sizeof s);
            */
            printf("server: got pasv connection from %s on %O\n", s, socket);
            close(listen_socket);
            
                    

        }

        return 0;
    }
    
    void do_read() {
    	
        mixed read_ptr = pike_pointer();
        int blocks_read = 1;       	
        while(this && has_socket && blocks_read > 0) {            
            blocks_read = fread(read_ptr, FTP_BLOCK_SIZE, 1, socket);                                    
            if (blocks_read > 0 && sizeof(read_ptr->value) && sizeof(read_ptr->value[0])) { 
              if (functionp(read_cb)) {              	
                read_cb(read_ptr->value[0]);
              }             
            } else {
            	blocks_read = 0;
            }            	
        }
        remove_clean();    	
    }	
		
	void start_pasv() 
	{
		if (has_listen_socket && socket == -1) {
		    Thread.Thread thread; 
            thread = Thread.Thread(get_connection);           
		}
	}
	
	void send(string format, mixed ... args) 
	{
		mixed r;
		
		if (has_listen_socket) {
		    while (!has_socket) {
			    // sleep?
		    }
		}
					
		fprintf(socket,format,@args);
						
		if (functionp(write_cb)) {
			
			r = write_cb();
			while(r != 0) {
				
				r = write_cb();
			}
			
		}
	}
	
	void destroy() 
	{

		if (has_listen_socket) {
			close(listen_socket);		    
		}
		if (has_socket) {
			close(socket);
			has_socket = 0;			
		}
		
		destruct();
	}
		
}

int next_port() 
{
#ifdef RESTRICT_PORTS
  lastport ++;
  if(lastport>MAX_PORT+1)
    lastport = MIN_PORT+1;
  return lastport - 1;
#endif
  return 0;
}

int query_lastport() 
{ 
	return lastport; 
}

private void FTP_handle_idlers()
{
	
	mixed user;
	
    map_delete(sessions,0);
    if(!sizeof(sessions)) {
        return;
    }
    
    foreach(sessions; user ; ftp_session info) {        
        if(info->dataPipe) {
            info->idleTime = 0;
            continue;
        }        
        info->idleTime += 60;        
        user->anti_idle();
    }
    
    if(sizeof(indices(sessions))) 
    {
        idlecall=call_out(FTP_handle_idlers, 60);
    }   
}

object|int create_pasv_socket(int binary, function read_f, function close_f) 
{
	
    addrinfo hints, servinfo, p;                        
    object peer_addr;
        
    int tries;
    int rv;	
	object|int listen_socket = 0;
	int sock_fd;
	int yes = 1;
	object caller = previous_object();
	
    switch(binary) {
        case 0:
            // create ASCII data socket
                    
            tries = 0;
            while(!listen_socket && tries < MAX_TRIES) { 
            	
                hints = addrinfo();
    
                hints->ai_family = AF_UNSPEC;
                hints->ai_socktype = SOCK_STREAM;
                hints->ai_flags = AI_PASSIVE; // use my IP        
                servinfo = addrinfo();            	
            	
                if ((rv = getaddrinfo(NULL, next_port(), hints, servinfo)) == 0) {

                    for(p = servinfo; p != NULL; p = p->ai_next) {
                        if ((sock_fd = socket(p->ai_family, p->ai_socktype,
                            p->ai_protocol)) == -1) {             
                            continue;
                        }

                        if (setsockopt(sock_fd, SOL_SOCKET, SO_REUSEADDR, ({ yes }),
                            sizeof(({ yes }))) == -1) {
                            continue;
                        }
                         
                        if (bind(sock_fd, p->ai_addr, p->ai_addrlen) == -1) {
                            close(sock_fd);
                            perror("server: bind");
                            continue;
                        }                        
                        break; // bound
                    }

                    if (p != NULL)  {
                        if (listen(sock_fd, BACKLOG) != -1) {
                    	    listen_socket = data_socket();
                    	    listen_socket->binary  = 0;
                    	    listen_socket->listen_socket = sock_fd;
                    	    listen_socket->has_listen_socket = 1;
                    	    listen_socket->read_cb =read_f;
                    	    listen_socket->close_cb = close_f;                        
                        }
                    }    
    
                    freeaddrinfo(servinfo);                    
                    tries++;
                }
            }             	
            break;
        case 1:        
        	// create BINARY data socket
            
            tries = 0;
            while(!listen_socket && tries < MAX_TRIES) { 
            	// create ASCII data socket
            	
                hints = addrinfo();
    
                hints->ai_family = AF_UNSPEC;
                hints->ai_socktype = SOCK_STREAM;
                hints->ai_flags = AI_PASSIVE; // use my IP        
                servinfo = addrinfo();            	

            
                if ((rv = getaddrinfo(NULL, next_port(), hints, servinfo)) == 0) {

                    for(p = servinfo; p != NULL; p = p->ai_next) {
                        if ((sock_fd = socket(p->ai_family, p->ai_socktype,
                            p->ai_protocol)) == -1) {             
                            continue;
                        }

                        if (setsockopt(sock_fd, SOL_SOCKET, SO_REUSEADDR, ({ yes }),
                            sizeof(({ yes }))) == -1) {
                            continue;
                        }
                         
                        if (bind(sock_fd, p->ai_addr, p->ai_addrlen) == -1) {
                            close(sock_fd);
                            perror("server: bind");
                            continue;
                        }
                        
                        if (listen(sock_fd, BACKLOG) == -1) {
                        	close(sock_fd);
                        	continue;
                        }
                                               
                        break; // bound
                    }

                    if (p != NULL)  {                                                       
                        listen_socket = data_socket();
                    	listen_socket->binary  = 1;
                    	listen_socket->listen_socket = sock_fd;
                    	listen_socket->has_listen_socket = 1;
                    	listen_socket->read_cb =read_f;
                    	listen_socket->close_cb = close_f;                    	 
                    }    
    
                    freeaddrinfo(servinfo);                    
                    tries++;
                }
            } 
            break;
        default:
            return listen_socket;
    }
                   
    if(member_array(caller, indices(passives)) >-1) {
        destruct(passives[caller]);
    }      
    
    //TODO: Kill duplicate logins here....

    pike_pointer name = pike_pointer();
    pike_pointer namelen = pike_pointer();    
                
    if(getsockname(listen_socket->listen_socket, name,namelen) != -1) {
        peer_addr = name->value[0];                            
        //iphost = inet_ntoa(peer_addr->sin_addr);
        listen_socket->local_port = peer_addr->sin_port;
    }
        
                
    passives[caller]=listen_socket;
    
    listen_socket->start_pasv();
            
    return listen_socket;
}


object|int create_port_socket(string ip, int port, int binary, function f_read, function f_close) 
{
			
	object sock;
	object caller = previous_object();
	int rv;
	int yes = 1;
	int sock_fd;
	
	addrinfo hints, servinfo, p;
		
    sockaddr_in their_addr; // connector's address information
    socklen_t sin_size = 6; // this is not used
    		
	their_addr = sockaddr_in();
	their_addr->sin_family = AF_INET;
	their_addr->sin_addr = in_addr();		
	their_addr->sin_addr->s_addr =  inet_addr(ip);
	their_addr->sin_port = port;		
    
    hints = addrinfo();
    	
    switch(binary) {
        case 0:
        
            hints->ai_family = AF_UNSPEC;
            hints->ai_socktype = SOCK_STREAM;
            hints->ai_flags = AI_PASSIVE; // use my IP        
            servinfo = addrinfo();          
        
            if ((rv = getaddrinfo(NULL, next_port(), hints, servinfo)) == 0) {

                for(p = servinfo; p != NULL; p = p->ai_next) {        
                    if ((sock_fd = socket(p->ai_family, p->ai_socktype,
                        p->ai_protocol)) == -1) {                                    
                        continue;
                    }
                    
                    if (setsockopt(sock_fd, SOL_SOCKET, SO_REUSEADDR, ({ yes }),
                        sizeof(({ yes }))) == -1) {                        	
                        continue;
                    }
                                                                                
                    if (connect(sock_fd,their_addr, sin_size) == -1) {                    	
                  	    continue;
                    }
                    
                    break;                                                            
                }
                    

                                                            
            }
                                           
            if (p != NULL)  {
            	                
                sock = data_socket();
                sock->binary  = 0;
                sock->socket = sock_fd;
                sock->has_socket = 1;
                sock->read_cb = f_read;
                sock->close_cb = f_close;                        
                
            }    
    
            freeaddrinfo(servinfo);
            break;
       case 1:
           hints->ai_family = AF_UNSPEC;
           hints->ai_socktype = SOCK_STREAM;
           hints->ai_flags = AI_PASSIVE; // use my IP        
           servinfo = addrinfo();          
        
           if ((rv = getaddrinfo(NULL, next_port(), hints, servinfo)) == 0) {

               for(p = servinfo; p != NULL; p = p->ai_next) {        
                    if ((sock_fd = socket(p->ai_family, p->ai_socktype,
                        p->ai_protocol)) == -1) {             
                            continue;
                    }
               
                    
                   if (setsockopt(sock_fd, SOL_SOCKET, SO_REUSEADDR, ({ yes }),
                        sizeof(({ yes }))) == -1) {
                        continue;
                   }
                                                            
                   if (connect(sock_fd,their_addr, sin_size) == -1) {
                       continue;
                   }
                    
                   break;                                            
               }
                
           } 
           if (p != NULL)  {
               
               sock = data_socket();
               sock->binary  = 1;
               sock->socket = sock_fd;
               sock->has_socket = 1;
               sock->read_cb = f_read;
               sock->close_cb = f_close;                        
               
           }    
    
           freeaddrinfo(servinfo);
           break;
        default:
            return 0;            
    }

    dataports[sock] = caller;    
    return sock;
}

void debug(mixed msg) 
{
    printf("[debug] %O %O\n",msg, backtrace()[-2]);
}


void handle_connect(int fd) 
{ 
    program pty;
    object mypty;
    object user;
    object peer_addr;
         
    pty = (program)"/dev/pty.pike";
    mypty = pty(fd); 
    user = kernel()->make_user(mypty->name(), mypty->name(), mypty->name(), 0,FTP_LOGON_OB);    
    object session = ftp_session();
    session->cmdfd = fd;
    
    
    map_delete(sessions,0);
    if(!sizeof(sessions)) {
          idlecall=call_out(FTP_handle_idlers , 60);
    }    
    
    sessions[user] = session;
      
    pike_pointer name = pike_pointer();
    pike_pointer namelen = pike_pointer();
        
    if(getsockname(fd, name,namelen) != -1) {
        peer_addr = name->value[0];                            
        iphost = inet_ntoa(peer_addr->sin_addr);
    } else {
        //iphost = "0.0.0.0";
    }
                      
    user->register_session(this_object(), session, iphost);   
}


private void ftpd() 
{
    sockaddr_storage their_addr; // connector's address information
    socklen_t sin_size;
    int new_fd;
    string s;
    object peer_addr;
    
    printf("ftp server: waiting for connections...\n");
    
    while(1) {  // main accept() loop
        sin_size = _SS_SIZE; // this means nothing... oh well... orig: sizeof their_addr;
        their_addr = sockaddr_storage();        
        new_fd = accept(sockfd, their_addr, sin_size);
        if (new_fd == -1) {
            perror("accept");
            continue;
        }
        
        pike_pointer name = pike_pointer();
        pike_pointer namelen = pike_pointer();
        
        if(getpeername(new_fd, name,namelen) != -1) {
             peer_addr = name->value[0];                            
             s = inet_ntoa(peer_addr->sin_addr);
        } else {
            s = "somewhere!";
        }
        
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
    
    if ((rv = getaddrinfo(NULL, FTP_CMD_PORT, hints, servinfo)) != 0) {
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
  thread = Thread.Thread(ftpd);
  return 0;
}



mapping query_passives() 
{ 
    return copy(passives); 
}

mapping query_sessions() 
{ 
    return copy(sessions); 
}

mapping query_dataports() 
{ 
	return copy(dataports); 
}

void goodbye() 
{
	object caller = previous_object();
	map_delete(sessions,caller);
	map_delete(passives,caller);
}

void removePassive(object caller) 
{
	map_delete(passives,caller);
}


private string session_user(object session) 
{
	return session->connected ? session->user : "(login)";
} 

array(string) list_users()
{
  return map(values(sessions), session_user);
}

void destroy() 
{
    remove_call_out(idlecall);	
}
