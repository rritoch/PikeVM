/* ========================================================================== */
/*                                                                            */
/*   vfs.pike                                                                 */
/*   (c) 2010 Ralph Ritoch                                                    */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */

//#define DEBUG_XLATE
#define STRICT_XLATE
//#define STRICT_XLATE_WARN
//#define DEBUG_SOCKETS
//#define DEBUG_MKDIR

#if __REAL_VERSION__ < 7.9
private constant Files = _static_modules.files;
#else
private constant Files = _static_modules._Stdio;
#endif

// These defines must be in <sys/socket.h>

#define LIBSOCKET

#include <netinet/in.h>
#include <sys/ioctl.h>

//#define DEBUG_SOCKET
#define DEBUG_PIPE
#define DEBUG_SELECT

// variables

private mapping(string:string) kvars;
private mapping(string:mixed) orig_constants;



class localstdio {
 int fh;
 
 public int is_open() {
  return 1;
 }

 public mixed read(pike_pointer ret, mixed ... args) {
  return __ioctl(fh,IOC_STRING,"read",ret, @args);
 }
 
 public mixed write(pike_pointer ret, mixed ... args) {
  return __ioctl(fh,IOC_STRING,"write",ret, @args);
 }
 
 public int close() {
  return __ioctl(fh,IOC_STRING,"close");
 }

 public int __ioctl(int cmd, mixed ... args) {
  array(object) fallbacks;
  array(mixed) link;
  mixed ob;
  
  fallbacks = ({});
  
  if (link = kernel()->_this_link()) {   
        fallbacks += ({ link });    
  }  
  
  if (kernel()->_this_user()) {
      object user = kernel()->_this_user();
      
      if (functionp(user->get_link)) {            
          link = user->get_link();        
          fallbacks += ({ link });           
      }      
  }
  
  if (kernel()->_this_shell()) {
   fallbacks += ({ kernel()->_this_shell() });
  }


  fallbacks += ({ kernel() });
 
  //werror(sprintf("\n\nvfs->stdio->fallbacks = %O bt=%O\n",fallbacks,backtrace()));
   
  foreach(fallbacks, ob) {
   if (objectp(ob) && !zero_type(ob)) {
    if (functionp(ob->handle_ioctl)) {
     return ob->handle_ioctl(fh,cmd,@args); 
    }
   }
  }
  
  return -1;
 }
 
 protected void create(int hand) {    
  fh = hand;
 }
 
}


class localfilehandle 
{
    private mixed fob;
    private int status;
    public int is_open() {
       return (status > 0);
    }

    public mixed read(pike_pointer ret, mixed ... args) {
        if (status < 1) {
            ret->value = ({ 0 });
            return -1;
        }  
        ret->value = ({ fob->read(@args) });  
        return 0;
    }
 
     public mixed seek(pike_pointer ret, int pos) {
        if (status < 1) {
            ret->value = ({ 0 });
            return -1;
        }  
        ret->value = ({ fob->seek(pos) });  
        return 0;
    }
 
    public mixed write(pike_pointer ret, mixed ... args) {
        if (status < 1) {
            ret->value = ({ -1 });
            return -1;
        }
        if (!objectp(ret)) {
        	return -2;
        }
        
        if (!objectp(fob)) {
        	return -3;
        }
        
        ret->value = ({ fob->write(@args) });
        return 0;
    }
 
 public int close() {
  if (status > 0) {
   fob->close();
   status = 0;
  }
  return 0;
 }

 public int __ioctl(int cmd, mixed ... args) {
  if (cmd == IOC_STRING) {
   string f = args[0];
   array(mixed) c_args = args[1..];
   
   switch(f) {
    case "write":
     return write(@c_args);
    case "read":
     return read(@c_args); 
    case "close":
     return close();
    default:
     return -1;
   }
  }
  return -1;
 }
 
 protected void create(mixed filename,mixed m) 
 {
     string mode;
     if ((m - "w") != m) {
         mode = "c" + m;
     } else {
         mode = m;
     }    
     fob=Files()->Fd();
     if ( ([function(string, string : int)]fob->open)(filename,mode) ) {  
         status = 1;   
     } else {   
         status = -1;    
     }
     }
 
}

/**
 * Local pipe
 */
 
class localpipe 
{
    private mixed fob;
    private int status;
    private int _flags;
    private mapping _stats;
        
    public int is_open() 
    {
       return (status > 0);
    }

    public mixed read(pike_pointer ret, mixed ... args) {
    	int not_at_all;
    	int len;
    	//int free;
        string str;
        if (status < 1) {
            ret->value = ({ 0 });
            return -1;
        }  
               
        if (sizeof(args) > 1) {
        	not_at_all = args[1] ? 1 : 0;
        } else {
        	not_at_all = 0;
        }
        
        if (sizeof(args) > 1) {
        	ret->value = ({ "" });
        	len = args[0];
        	while(len > 0) {
        	    if (len <= _stats["size"]) {
        	    	str = fob->read(len,not_at_all);
        	    } else {
        	    	str = fob->read(_stats["size"],not_at_all);        	    	
        	    }
        	    ret->value[0] += str;
        	    len -= sizeof(str);
        	    _stats["count"] -= sizeof(str);
        	}
        } else {
        	ret->value = ({ fob->read() });
        	_stats["count"] = 0;
        }  
        return 0;
    }
 
    public mixed write(pike_pointer ret, mixed ... args) 
    {
    	string data;
    	int free;
    	int tr;
#ifdef DEBUG_PIPE    	
    	kernel()->console_write(sprintf("[pipe] Begin write args=%O\n",args));
#endif
    	
        if (status < 1) {
            ret->value = ({ -1 });
            return -1;
        }
        if (!objectp(ret)) {
        	return -2;
        }
        
        if (!objectp(fob)) {
        	return -3;
        }
        
        if (sizeof(args) > 1) {
        	data = sprintf(@args);
        } else {
        	data = sprintf("%s",args[0]);
        }

#ifdef DEBUG_PIPE        
        kernel()->console_write(sprintf("[pipe] Writing %O\n",data));
 #endif
        
        ret->value = ({ sizeof(data) });
        
        while(sizeof(data) > 0) {
        	free = _stats["size"] - _stats["count"];
        	if (free > 0) {
        		if (sizeof(data) > free) {
        		    tr = fob->write(data[0..(free - 1)]);
        		    _stats["count"] += free;
        		    
        		    if (tr == -1) {
        		        ret->value[0] = -1;
        				data = "";
        		    } else {
        		    	data = data[(free)..];
        		    }	
        		} else {        			
        			tr = fob->write(data);
        			_stats["count"] += sizeof(data);
        			data = "";
        			if (tr == -1) {
        				ret->value[0] = -1;      				
        			}
        		}
        	}
        }
        return 0;
    }
 
    public int close() 
    {
        if (status > 0) {
            destruct(fob);
            fob =0;
            status = 0;
         }
         return 0;
     }

    public int __ioctl(int cmd, mixed ... args) 
    {
        if (cmd == IOC_STRING) {
            string f = args[0];
            array(mixed) c_args = args[1..];
   
            switch(f) {
                case "write":
                    return write(@c_args);
                case "read":
                    return read(@c_args); 
                case "close":
                    return close();
                default:
                    return -1;
            }
        }
        return -1;
    }
 
     int size() 
     {
     	return _stats["size"];
     }
     
     object create_clone() 
     {    	
     	 return localpipe(_stats["size"],_flags,fob,_stats);    	
     }
     
     int state() 
     {
     	int s = 0;
     	if (_stats["count"] > 0) {
     		s = s | READ_FL;
     	}
     	
     	if (_stats["count"] < _stats["size"]) {
     		s = s | WRITE_FL;
     	}
     	
     	return s;
     }
     protected void create(int|void size, int|void flags, object|void _fob, mapping|void stats) 
     {  	 
     	 if (zero_type(_fob)) {
 	         if (size > 0) {
 	             fob = Thread.Fifo(size);
 	         }  else {
 	 	        fob = Thread.Fifo();
 	         }
 	         _stats = ([]);
 	         _stats["size"] = size;
 	         _stats["count"] = 0;
     	 } else {
     	 	fob = _fob;
     	 	_stats = stats;
     	 }
     	     	 
 	     _flags = flags;
         status = 1;
    }
}

/**
 * Local Socket 
 *
 */
 
class localsocket 
{
    private mixed low_sock;
    private int status;
    private int s_family;
    private int s_type;
    private int s_protocol;
    private int s_backlog;
    private function alloc_fd;
    private function free_fd;
    private function assign_fd;
    private mapping(int:mixed) sock_options;
    private object s_addr;
    private int _state;
    private string _rbuff;
    
    protected void create(
        function fdalloc, 
        function fdfree, 
        function fdassign, 
        int socket_family, 
        int socket_type, 
        int protocol, 
        void|object fob) 
    {
 
        _rbuff = "";
        _state = 0;
        
        alloc_fd = fdalloc;
        free_fd = fdfree;
        assign_fd = fdassign;    
        sock_options = ([]);
        status = 0; 
        if (fob) {
            low_sock = fob;
            status = 1;
        }   
  
        s_family = socket_family;
        s_type = socket_type;
        s_protocol = protocol;
        
        register_callbacks();
    } 
    
    protected void on_read_cb(mixed id, string|int data) 
    {
#ifdef DEBUG_SOCKET    	
    	kernel()->console_write(sprintf("[localsocket] %O,%O\n","read_cb",data));
#endif
        _state = _state | READ_FL;
        if (stringp(data)) {
            _rbuff += data;
        }    	
    }
    
    protected void on_read_oob_cb(mixed id, string|int data) 
    {
#ifdef DEBUG_SOCKET 
    	kernel()->console_write(sprintf("[localsocket] %O,%O\n","read_oob_cb",data));
#endif    	
    }    
    
    protected void on_write_cb(mixed id, mixed data) 
    {
#ifdef DEBUG_SOCKET 
    	kernel()->console_write(sprintf("[localsocket] %O,%O\n","write_cb",data));
#endif
        _state = _state | WRITE_FL;    	
    }
    
    protected void on_write_oob_cb(mixed id, string|int data) 
    {
#ifdef DEBUG_SOCKET 
    	kernel()->console_write(sprintf("[localsocket] %O,%O\n","write_oob_cb",data));
#endif

    }
    
    protected void on_close_cb(mixed id, string|int data)
    {
#ifdef DEBUG_SOCKET
        kernel()->console_write(sprintf("[localsocket] %O,%O\n","close_cb",data));
#endif
        _state = _state | CLOSE_FL;    	
    }
    
    protected void register_callbacks() 
    {
    	if (objectp(low_sock)) {
    	    low_sock->set_callbacks(on_read_cb,on_write_cb,on_close_cb,on_read_oob_cb, on_write_oob_cb);	
    	}
    	
    }
    
// Stdio.UDP for UDP
// Stdio.PORT for Listening for TCP/IP
// Stdio.File for Connecting to TCP/IP

    public int is_open() 
    {
        return (status > 0);
    }

    public mixed read(pike_pointer ret, mixed ... args) {
        if (status < 1 || _state & CLOSE_FL) {
            ret->value = ({ 0 });
            return -1;
        }
        
        int not_at_all = sizeof(args) > 1 && args[1] ? 1 : 0;
        
        if (!not_at_all) {
           while(!_state & (READ_FL | CLOSE_FL)) {
              sleep(1);	
           }
           
           if (sizeof(args) > 0 && !(_state & CLOSE_FL)) {
               while(sizeof(_rbuff) < args[0]) {
                   sleep(1);
               } 
           }
        }
        
        string val = "";
        
        if (sizeof(args) > 0) {
        	if (args[0] > 0) {
        	    val = _rbuff[0..(args[0]-1)];
        	    _rbuff = _rbuff[args[0]..];
        	}
        } else {
        	val = _rbuff;
        	_rbuff = "";
        	
        }
        ret->value = ({ val });
        
        if (sizeof(_rbuff) < 1) {
        	_state = _state ^ (_state & READ_FL);
        }
        
        return 0;    
    }

    public mixed write(pike_pointer ret, mixed ... args) 
    {
        if (status < 1) {
            ret->value = ({ 0 });
            return -1;
        }  
        _state = _state ^ (_state & WRITE_FL);
        ret->value = ({ low_sock->write(@args) });
        return 0;    
    }

    public int close() 
    {
        if (status > 0) {
        //if (objectp(low_sock)) {        	
            low_sock->close();
            status = 0;
        }
    }
 
    int valid_socket() 
    {
        return 1;
    }
 


    int getsockopt(int level, int optname, pike_pointer optval, pike_pointer optlen) 
    {
        if (zero_type(sock_options[level])) {
            return -1;
        }
        if (zero_type(sock_options[level][optname])) {
            return -1;
        }
        optval->value = sock_options[level][optname];
        return 0;
    }
              
    int setsockopt(int level, int optname, mixed optval, socklen_t optlen) 
    {
        if (zero_type(sock_options[level])) {
            sock_options[level] = ([]);
        }
        sock_options[level][optname] = optval;
    }

    private string addr2str(int addr) 
    {
        int p1;
        int p2;
        int p3;
        int p4;
  
        int hold;
        hold = addr;
        p4 = hold & 255;
        hold = hold / 256;
        p3 = hold & 255;
        hold = hold / 256;
        p2 = hold & 255;
        hold = hold / 256;
        p1 = hold & 255;
        return sprintf("%d.%d.%d.%d",p1,p2,p3,p4);
    }
 
    int bind(object my_addr, socklen_t addrlen) 
    {
        int err;
        s_addr = my_addr;
  
        //ai_socktype
        if (s_type == SOCK_DGRAM) {
            low_sock = Stdio.UDP();
            err = catch {
                if (s_addr->sin_addr->s_addr == INADDR_ANY) {
                    low_sock = low_sock->bind(s_addr->sin_port);
                } else {
                    low_sock = low_sock->bind(s_addr->sin_port,addr2str(s_addr->sin_addr->s_addr));
                }
            };
            if (err) return -1;
            return 0;
        } 
  
        if (s_type == SOCK_STREAM) {
            if (s_addr->sin_addr->s_addr == INADDR_ANY) {
                low_sock = Stdio.Port(s_addr->sin_port);
            } else {    
                low_sock = Stdio.File();
            }
            return 0;
        }
        return -1;
    }
    
    int getpeername(pike_pointer ret, pike_pointer name, pike_pointer namelen) 
    {
        int err;
        string|int rawaddr;
        array(string) parts;
        object addr;
        
        //ai_socktype
        if (s_type == SOCK_DGRAM) {
        	rawaddr = low_sock.query_address();
        	if (rawaddr != 0) {
       	        parts = rawaddr/ " ";
        	    addr = sockaddr_in();
        	    addr->sin_family = AF_INET;
        	    addr->sin_port = (int)parts[1];
        	    addr->sin_addr = in_addr();
        	    addr->sin_addr->s_addr = _inet_addr(parts[0]);
        	    namelen->value = ({ 0 });
        	    name->value = ({ addr });
        	    ret->value = ({ 0 });
        	    return 0;
        	} else {
        		err = low_sock->errno();
        	}          	
        } 
  
        if (s_type == SOCK_STREAM) {
        	rawaddr = low_sock.query_address();
        	if (rawaddr != 0) {
       	        parts = rawaddr/ " ";
        	    addr = sockaddr_in();
        	    addr->sin_family = AF_INET;
        	    addr->sin_port = (int)parts[1];
        	    addr->sin_addr = in_addr();
        	    addr->sin_addr->s_addr = _inet_addr(parts[0]);
        	    namelen->value = ({ 0 });
        	    name->value = ({ addr });
        	    return 0;
        	} else {
        		err = low_sock->errno();
        	}     	
        }
        
        ret->value = ({ -1 });
        return -1;    	
    }
    
    int state() 
    {
    	return _state;
    }
    
    int getsockname(pike_pointer ret, pike_pointer name, pike_pointer namelen) 
    {
        int err;
        string|int rawaddr;
        array(string) parts;
        object addr;
        
        //ai_socktype
        if (s_type == SOCK_DGRAM) {
        	rawaddr = low_sock.query_address(1);
        	if (rawaddr != 0) {
       	        parts = rawaddr/ " ";
        	    addr = sockaddr_in();
        	    addr->sin_family = AF_INET;
        	    addr->sin_port = (int)parts[1];
        	    addr->sin_addr = in_addr();
        	    addr->sin_addr->s_addr = _inet_addr(parts[0]);
        	    namelen->value = ({ 0 });
        	    name->value = ({ addr });
        	    ret->value = ({ 0 });
        	    return 0;
        	} else {
        		err = low_sock->errno();
        	}          	
        } 
  
        if (s_type == SOCK_STREAM) {
        	rawaddr = low_sock.query_address(1);
        	if (rawaddr != 0) {
       	        parts = rawaddr/ " ";
        	    addr = sockaddr_in();
        	    addr->sin_family = AF_INET;
        	    addr->sin_port = (int)parts[1];
        	    addr->sin_addr = in_addr();
        	    addr->sin_addr->s_addr = _inet_addr(parts[0]);
        	    namelen->value = ({ 0 });
        	    name->value = ({ addr });
        	    return 0;
        	} else {
        		err = low_sock->errno();
        	}     	
        }
        
        ret->value = ({ -1 });
        return -1;    	
    }    
    
    int connect(pike_pointer ret, object addr, socklen_t addrlen) 
    {
        int err;
        s_addr = addr;
            	    	    	
        string str_addr;
        
        //ai_socktype
        if (s_type == SOCK_DGRAM) {
            low_sock = Stdio.UDP();
            
            if (!low_sock->connect(addr2str(s_addr->sin_addr->s_addr),s_addr->sin_port)) {
                err = low_sock->errno();
                ret->value = ({-1});
            } else {
            	status = 1;
            	ret->value = ({0});
            }                            
            if (err) return -1;
            return 0;
        } 
  
  
        if (s_type == SOCK_STREAM) {
        	low_sock = Stdio.File();
        	
        	//TODO: How to we handle explicit from/to?
        	//if (s_addr->sin_addr->s_addr == INADDR_ANY) {        	
        	        	
        	str_addr = addr2str(s_addr->sin_addr->s_addr);
        	if (!low_sock->connect(str_addr,s_addr->sin_port)) {
                err = low_sock->errno();
                ret->value = ({-1});
            } else {
            	ret->value =({0});
            	status = 1;
            }
            
        	//} else {
        	//	low_sock = low_sock->connect(,addr2str(s_addr->sin_addr->s_addr),s_addr->sin_port);
        	//}
            if (err) return -1;
            return 0;
        }
                
        return -1;    	
    }


 int listen(int backlog) {
  if (objectp(low_sock)) {
   s_backlog = backlog;
   return 0;
  }
  return -1;
 }


private int _inet_addr(string addr) 
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


 int accept(pike_pointer ret, object addr, socklen_t addrlen) {
  object fob;
  int fd;
  
  if (functionp(low_sock->accept)) {
   fob = low_sock->accept();
   if (fob) {
    fd = alloc_fd();
    assign_fd(fd,localsocket(  
     alloc_fd, 
     free_fd, 
     assign_fd,
     s_family, 
     s_type, 
     s_protocol, 
     fob    
    ));
    ret->value = ({ fd });
    return 0;
   }
   ret->value = ({ -2 });
   return -1;
  }
  
  ret->value = ({ -1 });
  return -1;
 } 

 public int __ioctl(int cmd, mixed ... args) {
 
  if (cmd == IOC_STRING) {
   array(mixed) c_args = args[1..];  
   string fn = args[0];
   
   switch(fn) {
    case "getsockopt":
     return getsockopt(@c_args);     
     break;
    case "setsockopt":
     return setsockopt(@c_args);
     break;
    case "listen":
     return listen(@c_args);
     break;
    case "getpeername":
        return getpeername(@c_args);
    case "getsockname":
    return getsockname(@c_args);
    case "connect":
     return connect(@c_args);
    case "accept":
     return accept(@c_args);
     break;
    case "bind":
     return bind(@c_args);
     break;
    case "read":
     return read(@c_args);
     break;
    case "write":
     return write(@c_args);
     break;
     case "close":
         return close();
         break;
     
   }
  }
  return -1;
    }
 
}


/* Body Starts here */

#ifdef DEBUG_SOCKETS

void debug_socket(void|string msg, mixed ... args) {
 string errmsg = "";
 if (msg) {
  errmsg = sprintf(msg,@args);
 }
 write("[debug_socket] %s: %O\n", errmsg, backtrace()[-2]);
}

#endif

private string xlate_proc_path(string pth) {
 int idx;
 string s;
 string ret;
 
 s = "";
 if (sscanf(pth,"proc://kernel/master/modules/%d%s",idx,s)) {
  ret = kernel_module_path_stack[idx] + s;
#ifdef DEBUG_XLATE  
  kwrite(sprintf("xlate_proc_path result %O as %O",pth,ret));
#endif  
  return ret;
 }
 
 if (sscanf(pth,"proc://kernel/boot/%s",s)) {
  ret = combine_path(kvars["boot_path"],s);
#ifdef DEBUG_XLATE  
  kwrite(sprintf("xlate result %O as %O",pth,ret));
#endif  
  return ret;   
 }
#ifdef DEBUG_XLATE  
  kwrite(sprintf("xlate result %O failed",pth));
#endif  
 
#ifndef STRICT_XLATE
 if (sscanf(pth,"proc:/kernel/master/modules/%d%s",idx,s)) {

#ifdef STRICT_XLATE_WARN 
  //kwrite(sprintf("Warning: xlatepath %s has invalid format. %O",pth,backtrace()));  
  warn(sprintf("->xlatepath(%s) has invalid format.",pth));
#endif  
  ret = kernel_module_path_stack[idx] + s;
#ifdef DEBUG_XLATE  
  kwrite(sprintf("xlate result %O as %O",pth,ret));
#endif  
  return ret;
 }
 
 if (sscanf(pth,"proc:/kernel/boot/%s",s)) {
#ifdef STRICT_XLATE_WARN 
   warn(sprintf("xlatepath %s has invalid format",pth));
#endif   
  ret = combine_path(kvars["boot_path"],s);
#ifdef DEBUG_XLATE  
  kwrite(sprintf("xlate result %O as %O",pth,ret));
#endif  
  return ret;   
 } 
#endif
  
 return 0;
}

private string xlatepath(string pth) 
{
    string newpath;
    array(string) splitpath;
    string e;
    if (has_prefix(pth,"proc:")) {
        return xlate_proc_path(pth);
    }
    newpath = kvars["init_root_path"];
    splitpath = pth / "/";
 
    foreach(splitpath,e) {
        newpath = combine_path(newpath,e);
    }
    return newpath;
}

protected void kwrite(mixed msg) 
{
   write(sprintf("[%O] %s\n",object_program(this),msg));
}

#ifdef STRICT_XLATE_WARN
private void warn(mixed msg) {   
   werror(sprintf("Warning: [%O] %s\n\t%O\n\n",object_program(this),msg,backtrace()[..<1]));
}
#endif
 
 private mapping(int:mixed) fdlist;
 private array(string) module_path_stack;
 private array(string) include_path_stack;
 private array(string) kernel_module_path_stack;
 
 int nextfd;

 //TODO: Change this function to prevent system crashes! 
 
 protected int assign_fd(int fd, mixed ob) {
  fdlist[fd] = ob;
 }
 
 protected int alloc_fd() {
  int ret;
  ret = nextfd++;
  fdlist[ret] = 1;
  return ret;
 }

 protected void free_fd(int fh) {
  fdlist[fh] = 0;
  return;
 }

 public int fopen(string path, string mode) {
  object fob;
  int fh;
  string newpath;
    
  newpath = xlatepath(path);
  fob = localfilehandle(newpath,mode);  
  //fob->open(newpath, mode);  
  if (fob->is_open()) {
   fh = alloc_fd();   
   assign_fd(fh,fob);   
  } else {   
   fh = -1;
  }
  return fh;
 }

public int rm(string fn) 
{
    string newpath;    
    newpath = xlatepath(fn);
    return predef::rm(newpath);
}

public array(string) _get_dir(string|void x) 
{
    function gd;
 
    array(string) d;
 
    //gd = master()->_get_dir;
    gd = orig_constants["get_dir"];
    if (stringp(x)) { 	
        d = gd(xlatepath(x));
    } else { 
        d = gd();
    }
    
    d -= ({ "." });
    d -= ({ ".." });
    return ({".",".."}) + d; 
}

public int _is_directory(string dir) 
{
    if (dir == ""){
        return 0;
    }
    mixed s = _file_stat(dir);
    if (!s) {
        return 0;
    }
    return s->isdir;
}

public int _mkdir(string newpath, void|int mode) 
{
	int ret;
	string p = xlatepath(newpath);
	
#ifdef DEBUG_MKDIR	
	kwrite(sprintf("Debug mkdir(%O,%O) to %O",newpath,mode,p));
#endif
	
	if (mode) {
		ret = mkdir(p,mode);
	}  else {
		ret = mkdir(p);
	}
	
    return ret;
}

public mixed _file_stat(string x,void|int(0..1) symlink) {  
    return predef::file_stat(xlatepath(x),symlink);
}

string _combine_path(string path, string ... paths) {

    string ret;
    string p; 
    ret = path;
 
      foreach(paths,p) {
        if (has_prefix(p,"proc:")) {
            ret = "proc:/" + orig_constants["combine_path_unix"](p[6..]);
         } else {
            if (has_prefix(ret,"proc:")) {
                ret = "proc:/" + orig_constants["combine_path_unix"](ret[6..],p);
            } else {
                ret = orig_constants["combine_path_unix"](ret,p);
            }
        }
    }
  
    return ret;
}

public int|string fread(int fh,mixed ... args) { 
		
  object fob;
  int err;  
  pike_pointer ret = pike_pointer(-1);
            
  fob = fdlist[fh];    
  if (sizeof(args) > 0) {
   err = fob->read(ret,@args);   
  } else {     
   err = fob->read(ret);   
  }
  if (err) {
   return 0;
  }
  if (stringp(ret->value[0])) return ret->value[0];
  return 0;  
}

public int fwrite(int fh,mixed ... args) 
{
   object fob;
   mixed err;
   mixed r;

   pike_pointer rv = pike_pointer();
                            
   fob = fdlist[fh];
   
   if (sizeof(args) == 1) {     
       err = catch {
           r = fob->write(rv, "%s",args[0]);
       };
   } else {
       err = catch {
           r = fob->write(rv,@args);
       };
   }
   
      
   if (r < 0) {   	
       return 0;
   }
      
   if (objectp(err)) {
   	   kernel()->console_write(sprintf("WRITE %O,%O\r\n",err,err->backtrace()));
       return 0;              
   }
                    
   return err  ? 0 : 1;   
}  
  
  
public string|int read_bytes(string fn, int ... args)
{
    string newpath = xlatepath(fn);
    mixed s = predef::file_stat(newpath);
             
    mixed ret;
    mixed fob;
    int err;
    int fh;
    
    pike_pointer rret = pike_pointer(-1);
    
    ret = -1;
    if (s != 0 &&
        (sizeof(args) != 1 || 
            (args[0] >= 0 && args[0] <= s->size)
        ) &&
        (sizeof(args) != 2 || 
            (args[0] >= 0 && args[1] >= 0 && (args[0] + args[1]) <= s->size)
         )
    ) {
             
        
        fob = localfilehandle(newpath,"r");      
        if (fob->is_open()) {
            fh = alloc_fd();   
            assign_fd(fh,fob);
            if (sizeof(args) > 0 && args[0] > 0) {
                //fob->read(rret,args[0]);
                fob->seek(rret,args[0]);
            }
              
            if (sizeof(args) > 1) {
                err = fob->read(rret,args[1]);
            } else {
                err = fob->read(rret);
            }
              
            if (!err) {
                if (stringp(rret->value[0])) {
                    ret = rret->value[0];
                }
            }
            
            fob->close();
            free_fd(fh);                                                
        }        
    }
    return ret;
}  
    
public string|int write_bytes(string fn, int start, string series )
{
    string newpath = xlatepath(fn);
    mixed s = predef::file_stat(newpath);
             
    mixed ret;
    mixed fob;
    int err;
    int fh;
    
    pike_pointer rret = pike_pointer(-1);
                         
        fob = localfilehandle(newpath,"wc");      
        if (fob->is_open()) {
            fh = alloc_fd();   
            assign_fd(fh,fob);
            
            fob->seek(rret,start);
                                      
            err = fob->write(rret,"%s",series);
            
              
            if (!err) {
                if (stringp(rret->value[0])) {
                    ret = rret->value[0];
                }
            }
            
            fob->close();
            free_fd(fh);                                                
        }        
    
    return ret;
}  
 
 int fclose(int fh) 
 {
    object fob;
    if ((!zero_type(fdlist[fh])) && objectp(fdlist[fh])) {
        fob = fdlist[fh];
        fob->close();
        free_fd(fh);
    }
    return 1;
 }


string basefilename(string x) {
 array(string) tmp= x / "/";
 return tmp[-1];
}

int is_absolute_path(string p) {
 return has_prefix(p,"/") || has_prefix(p,"proc:");
}

program _load_module(string module_name) {
 function loadm = orig_constants["load_module"];
 return loadm(xlatepath(module_name));
}

array(string) explode_path(string p) {
    array(string) r;
    array(string) sp;
    array(string) ret;
    string pp;

    if (!p) return ({});
    
    sp = p / "://";
    
    if (sizeof(sp) > 1) {        
        r = ({ sp[0] + ":/"}) + ((sp[1..]*"://")/"/");    
    } else {      
        r = p / "/";
        if(r[0] == "" && sizeof(p)) {
            r[0] = "/";
        }        
    }

    ret = ({});
    foreach(r,pp) {
        if (sizeof(pp)) {
            ret += ({ pp });
        }
    }
    return ret;
}

string dirname(string x) {
  if (!x) return "";
  if(x=="") return "";
  array(string) tmp=explode_path(x);
  
  if (x[0] == '/') {
   if(sizeof(tmp)<3) return "/";
   return "/" + tmp[1..<1]*"/";
  }
  return tmp[..<1]*"/";
}

public int _ioctl(int d, int request, mixed ... args) {
 if (zero_type(fdlist[d])) {
  return -1;
 }
 return fdlist[d]->__ioctl(request, @args);
}

public program ___empty_program(int|void line, string|void file) 
{
 
    int argc;
 
    function f = orig_constants["__empty_program"];
 
    argc = query_num_arg();
    if (argc > 1) {
        return f(line,xlatepath(file));
    } else {
        if (argc == 1)
            return f(line); 
    }
    return f();
}

public int _pipe2(pike_pointer pipefd, int flags) 
{
 
    object fob1, fob2;
    int fh1,fh2;   
    
    fh1 = alloc_fd();
    fh2 = alloc_fd();

    fob1 = localpipe(4096,flags);
    fob2 = fob1->create_clone();
    
    assign_fd(fh1,fob1);
    assign_fd(fh2,fob2);
    
    pipefd->value = ({ fh1, fh2 });
    return 0;
}

public int _socket(int socket_family, int socket_type, int protocol) 
{
 
    object fob;
    int fh;

#ifdef DEBUG_SOCKETS
    debug_socket("_socket(%O,%O,%O)",socket_family, socket_type, protocol);
#endif
 
 switch(socket_family) {
  case AF_UNSPEC:
  case PF_INET:
#ifdef DEBUG_SOCKETS
   debug_socket("identified socket family");
#endif  
   if ((socket_type != SOCK_STREAM) &&
      (socket_type != SOCK_DGRAM)) return -1; //unsupported

#ifdef DEBUG_SOCKETS
    debug_socket("identified socket type");
#endif
   
   fob = localsocket(alloc_fd,free_fd, assign_fd, socket_family,socket_type,protocol);
   if (!fob->valid_socket()) {
#ifdef DEBUG_SOCKETS
    debug_socket("invalid socket");
#endif   
    return -1;
   }
   fh = alloc_fd();   
   assign_fd(fh,fob);
#ifdef DEBUG_SOCKETS
   debug_socket("allocated socket(%O)",fh);
#endif      
   break;
  default:
#ifdef DEBUG_SOCKETS
 debug_socket("socket family unidentified!");
#endif    
  return -1; // family unsupported 
 }
#ifdef DEBUG_SOCKETS
   debug_socket("returning socket(%O)",fh);
#endif   
 return fh;
}

int kernel_registered = 0;

void register_kernel() {
    int idx;
    string path;
 
    if (kernel_registered) return;
    kernel()->klog(kernel()->LOG_LEVEL_INFO,"Flushing kernel stacks.");
    //kernel_module_path_stack = copy_value(module_path_stack);
 for (idx = 0; idx < sizeof(kernel_module_path_stack); idx++) {    
  master()->remove_module_path(kernel_module_path_stack[idx]);   
 }

 for (idx = 0; idx < sizeof(include_path_stack); idx++) {    
  master()->remove_include_path(include_path_stack[idx]);   
 }

 
 kernel()->klog(kernel()->LOG_LEVEL_INFO,"Registering Kernel.");
 master()->register_kernel();
 kernel()->klog(kernel()->LOG_LEVEL_INFO,"Loading new module paths.");
 for(idx = 0; idx < sizeof(kernel_module_path_stack);idx++) {
  path = sprintf("proc://kernel/master/modules/%O",idx);
  //kwrite(sprintf("master()->add_module_path(%O)",path));  
  kernel()->_add_module_path(path);
 } 
 //kwrite(sprintf("module_paths = %O",module_path_stack)); 
}

int _select(int nfds, pike_pointer readfds, pike_pointer writefds,
                  pike_pointer exceptfds, pike_pointer timeout) {

// check timeout, check readfds, check writefds, check exceptfds, 
    object caller = function_object(backtrace()[-2][2]);

#ifdef DEBUG_SELECT
	kernel()->console_write("[select] nfds = %O, readfds = %O, writefds = %O, exceptfds = %O, timeout = %O\n",
    nfds, 
    readfds->value,
    writefds->value,
    exceptfds->value,
    timeout->value);
#endif

    mixed readers = readfds->value;
    mixed writers = writefds->value;
    mixed err_checkers = exceptfds->value;
    
    int expire;
    
    int fd,r_state;
    // int w_state;
    // int e_state;
    
    array(int) _rr = ({});
    array(int) _rw = ({});
    array(int) _re= ({});
    
    if (timeout && timeout->value[0] > 0) {
    	expire = timeout->value[0];
    	
    	while(expire > 0) {
            if (arrayp(readers))	{
              foreach(readers, fd) {
                  if (functionp(fdlist[fd]->state)) {
                  	  r_state = fdlist[fd]->state();
 #ifdef DEBUG_SELECT
                      kernel()->console_write(sprintf("[select] fd(%O), r_state = %O\n",fd,r_state));
 #endif                 	  
                      if (r_state & READ_FL) {
                          _rr += ({ fd });
                          
 #ifdef DEBUG_SELECT
                          kernel()->console_write(sprintf("[select] active readers = %O\n",_rr));
 #endif                           
                      }
                  }
              }
           }
           
           if (arrayp(writers))	{
              foreach(writers, fd) {
                  if (functionp(fdlist[fd]->state)) {
                      if (fdlist[fd]->state() & WRITE_FL) {
                          _rw += ({ fd });
                      }
                  }
              }
           }
           
           if (arrayp(err_checkers))	{
              foreach(err_checkers, fd) {
                  if (functionp(fdlist[fd]->state)) {
                      if (fdlist[fd]->state() & CLOSE_FL) {
                          _re += ({ fd });
                      }
                  } else {
                      _re += ({ fd });
                  }	
              }
           }
           
           if (sizeof(_rr) + sizeof(_rw) + sizeof(_re) > 0) {          	   
               break;
           }
           if (!caller) {
              break; // caller has been destructed
           }
           sleep(1); 
           expire -= 1;		
    	}
    } else {
        while(1) {
           if (arrayp(readers))	{
              foreach(readers, fd) {
                  if (functionp(fdlist[fd]->state)) {
                      if (fdlist[fd]->state() & READ_FL) {
                          _rr += ({ fd });
                      }
                  }
              }
           }
           
           if (arrayp(writers))	{
              foreach(writers, fd) {
                  if (functionp(fdlist[fd]->state)) {
                      if (fdlist[fd]->state() & WRITE_FL) {
                          _rw += ({ fd });
                      }
                  }
              }
           }
           
           if (arrayp(err_checkers))	{
              foreach(err_checkers, fd) {
                  if (functionp(fdlist[fd]->state)) {
                      if (fdlist[fd]->state() & CLOSE_FL) {
                          _re += ({ fd });
                      }
                  } else {
                      _re += ({ fd });
                  }	
              }
           }
           
           if (sizeof(_re) + sizeof(_rw) + sizeof(_re) > 0) {
               break;
           }
           if (!caller) {
              break; // caller has been destructed
           }
           sleep(1);
        }
        
        
        	
    }
      
    readfds->value = ({ _rr });
    writefds->value = ({ _rw });
    exceptfds->value = ({ _re });
    
    if (sizeof(_re) > sizeof(_rw)) {
    	return sizeof(_re) > sizeof(_rr) ? sizeof(_re) : sizeof(_rr);
    } else {
    	return sizeof(_rw) > sizeof(_rr) ? sizeof(_rw) : sizeof(_rr);
    }        	
}

static void create(mixed orig_mod_paths, mixed orig_inc_paths,mapping(string:string) kconfig_vars, mapping(string:mixed) orig_const) {
 string fsroot;

 orig_constants = copy_value(orig_const);
 
 kvars = kconfig_vars;  
 module_path_stack = orig_mod_paths;
 kernel_module_path_stack = copy_value(orig_mod_paths);
 include_path_stack = orig_inc_paths; 
 nextfd = 10;
 
 fdlist = ([]);
 fdlist[0] = localstdio(0);
 fdlist[1] = localstdio(1);
 fdlist[2] = localstdio(2);
 
 kernel()->klog(kernel()->LOG_LEVEL_INFO,"VFS Loaded");
 
 fsroot = kvars["init_root_path"];
 //kwrite(sprintf("fsroot = %O",fsroot));
 
}
