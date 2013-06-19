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



// These defines must be in <sys/socket.h>

#define LIBSOCKET

#include <netinet/in.h>
#include <sys/ioctl.h>

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
  
  if (kernel()->_this_user()) {
      object user = kernel()->_this_user();
      link = user->get_link();
      if (sizeof(link) > fh) {
          fallbacks += ({ link[fh] }); 
      }      
  }
  
  if (kernel()->_this_shell()) {
   fallbacks += ({ kernel()->_this_shell() });
  }

  if (link = kernel()->_this_link()) {
   if (sizeof(link) > fh) {
    fallbacks += ({ link[fh] }); 
   }
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
 
    public mixed write(pike_pointer ret, mixed ... args) {
        if (status < 1) {
   ret->value = ({ -1 });
   return -1;
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
     fob=_static_modules.files()->Fd();  
     if ( ([function(string, string : int)]fob->open)(filename,mode) ) {  
         status = 1;   
     } else {   
         status = -1;    
     }
     }
 
}


class localsocket {
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
 
// Stdio.UDP for UDP
// Stdio.PORT for Listening for TCP/IP
// Stdio.File for Connecting to TCP/IP

 public int is_open() {
  return (status > 0);
 }

 public mixed read(pike_pointer ret, mixed ... args) {
  if (status < 1) {
   ret->value = ({ 0 });
   return -1;
  }  
  ret->value = ({ low_sock->read(@args) });
  return 0;    
 }

 public mixed write(pike_pointer ret, mixed ... args) {
  if (status < 1) {
   ret->value = ({ 0 });
   return -1;
  }  
  ret->value = ({ low_sock->write(@args) });
  return 0;    
 }

 public int close() {
  if (status > 0) {
   low_sock->close();
   status = 0;
  }
 }
 
 int valid_socket() {
  return 1;
 }
 
 protected void create(function fdalloc, function fdfree, function fdassign, int socket_family, int socket_type, int protocol, void|object fob) {
 
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
 }

 int getsockopt(int level, int optname, pike_pointer optval, pike_pointer optlen) {
  if (zero_type(sock_options[level])) {
   return -1;
  }
  if (zero_type(sock_options[level][optname])) {
   return -1;
  }
  optval->value = sock_options[level][optname];
  return 0;
 }
              
 int setsockopt(int level, int optname, mixed optval, socklen_t optlen) {
  if (zero_type(sock_options[level])) {
   sock_options[level] = ([]);
  }
  sock_options[level][optname] = optval;
 }

 private string addr2str(int addr) {
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
 
 int bind(object my_addr, socklen_t addrlen) {
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

 int listen(int backlog) {
  if (objectp(low_sock)) {
   s_backlog = backlog;
   return 0;
  }
  return -1;
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

private void kwrite(mixed msg) {
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


public array(string) _get_dir(string|void x) {
 function gd;
 //gd = master()->_get_dir;
 gd = orig_constants["get_dir"];
 if (stringp(x)) return gd(xlatepath(x)); 
 return gd();
}

public int _mkdir(string newpath, void|int mode) {
 return(mkdir(xlatepath(newpath),mode));
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
   fob = fdlist[fh];
   
   if (sizeof(args) == 1) {     
       err = catch {
           fob->write("%s",args[0]);
       };
   } else {
       fob->write(@args);
   }                 
   return 0;   
}  
  
    

 
 int fclose(int fh) {
  object fob;
  fob = fdlist[fh];
  fob->close();
  free_fd(fh);
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

public int _socket(int socket_family, int socket_type, int protocol) {
 
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
 kwrite("Flushing kernel stacks.");
 //kernel_module_path_stack = copy_value(module_path_stack);
 for (idx = 0; idx < sizeof(kernel_module_path_stack); idx++) {    
  master()->remove_module_path(kernel_module_path_stack[idx]);   
 }

 for (idx = 0; idx < sizeof(include_path_stack); idx++) {    
  master()->remove_include_path(include_path_stack[idx]);   
 }

 
 kwrite("Registering Kernel.");
 master()->register_kernel();
 kwrite("Loading new module paths.");
 for(idx = 0; idx < sizeof(kernel_module_path_stack);idx++) {
  path = sprintf("proc://kernel/master/modules/%O",idx);
  //kwrite(sprintf("master()->add_module_path(%O)",path));  
  kernel()->_add_module_path(path);
 } 
 //kwrite(sprintf("module_paths = %O",module_path_stack)); 
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
 
 kwrite("VFS Loaded");
 
 fsroot = kvars["init_root_path"];
 //kwrite(sprintf("fsroot = %O",fsroot));
 
}
