/* ========================================================================== */
/*                                                                            */
/*   Kernel.pike                                                              */
/*   (c) 2010 Ralph Ritoch                                                    */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */

#define VERSION "1.0"

#define SECURITY_KEY "xxx123"

class k_pointer {
 array(mixed) value; 
 protected void create(mixed ... args) {
  value = ({ @args });
 }
}

//#define DEBUG_CONFIG
//#define DEBUG_DESCRIBE
//#define DEBUG_VFS
//#define DEBUG_SECURITY
//#define DEBUG_INCLUDE
//#define DEBUG_IMPORT
//#define DEBUG_GET_ROOT_MODULE

//#define OVERRIDE_HANDLE_IMPORT

#define IOC_STRING 1024

#ifdef DEBUG_VFS
#define VFS_RETURN(X) mixed vfs_return = X; kwrite("%s called by %O on line %O returned %O",sprintf("%s(" + sprintf("%s", (({ "%O" }) * sizeof(backtrace()[-1][3..])) * ",") + ")",function_name(backtrace()[-1][2]),@(backtrace()[-1][3..])), backtrace()[-2 - (function_object(backtrace()[-2][2]) == master()) ][2], backtrace()[-2 - (function_object(backtrace()[-2][2]) == master()) ][1],vfs_return); return vfs_return
#else
#define VFS_RETURN(X) return (X)
#endif

#ifdef DEBUG_VFS
#define VFS_RETURN2(X) mixed vfs_return = X; kwrite("%s called by %O on line %O ",sprintf("%s(" + sprintf("%s", (({ "%O" }) * sizeof(backtrace()[-1][3..])) * ",") + ")",function_name(backtrace()[-1][2]),@(backtrace()[-1][3..])), backtrace()[-2 - (function_object(backtrace()[-2][2]) == master()) ][2], backtrace()[-2 - (function_object(backtrace()[-2][2]) == master()) ][1]); return vfs_return
#else
#define VFS_RETURN2(X) return (X)
#endif

#define NEED_VFS(X) if (!objectp(vfs)) return X  

constant no_value = (<>);
constant NoValue = typeof (no_value);

#if __REAL_VERSION__ < 7.9
private constant Files = _static_modules.files;
#else
private constant Files = _static_modules._Stdio;
#endif

private string boot_path;
private program fs;
private mixed vfs;
private mapping(string:string) config_vars;
private mapping(string:mixed) programs;
private mapping(program:string) rev_programs = ([]);
private mapping(string:object|NoValue) fc=([]);
private mapping(mixed:string) rev_fc = ([]);

private mapping(string:object) systems = ([]);
private mapping(string:mixed) orig_constants;
private array(object) pinit = ({});
private int init_called;
private mapping(program:mixed) p_objects = ([]);

private mapping(object:mixed) users = ([]);
private int kernel_registered;

private object root_modules;
private object securityd;

private array(string) default_module_path = ({});

/* Needed from Kernel */

  protected mapping(string:mixed) instantiate_static_modules(object|mapping static_modules)
  {
    mapping(string:mixed) res = ([]), joins = ([]);
    foreach(indices(static_modules), string name) {
      mixed val = static_modules[name];
      if (!val->_module_value)
	val = val();
      if(mixed tmp=val->_module_value) val=tmp;
      if(!has_value(name, '.'))
	res[name] = val;
      else {
	mapping(string:mixed) level = joins;
	string pfx;
	while(2 == sscanf(name, "%s.%s", pfx, name))
	  level = (level[pfx] || (level[pfx] = ([])));
	level[name] = val;
      }
    }
    //joinnode joinify(mapping m)
    object joinify(mapping m)
    {
      foreach(m; string n; mixed v)
	if(mappingp(v))
	  m[n]=joinify(v);
      //return joinnode(({m}));
      return master()->joinnode(({m}));
    };
    foreach(joins; string n; mixed v) {
      if(mappingp(v))
	v = joinify(v);
      if(res[n])
	//res[n] = joinnode(({res[n], v}));
	res[n] = master()->joinnode(({res[n], v}));
      else
	res[n] = v;
    }
    return res;
  }

/* Virtual File System */

public string _basename(string x) {
 NEED_VFS(x);
 VFS_RETURN(vfs->basefilename(x));
}

public string _combine_path(string path, string ... paths) {
 NEED_VFS(combine_path(path,@paths));
 VFS_RETURN(vfs->_combine_path(path,@paths));
}

public int _is_absolute_path(string p) {
 NEED_VFS(-1);
 VFS_RETURN(vfs->is_absolute_path(p));
}

public array(string) _explode_path(string p) {
 NEED_VFS(predef::explode_path(p));
 VFS_RETURN(vfs->explode_path(p));
}

public string _dirname(string p) {
 NEED_VFS(predef::dirname(p)); 
 VFS_RETURN(vfs->dirname(p));
}

public program _load_module(string module_name) {
 NEED_VFS(0); 
 object caller;
 mixed bt = backtrace();
 if (sizeof(bt) > 1) caller = function_object(bt[-2][2]);  
 if (!valid("load_module",caller,module_name)) {
  VFS_RETURN(0);
 }  
 VFS_RETURN(vfs->_load_module(module_name));
}

public array(string) _get_dir(string|void x) {
 array(string) ret;
 NEED_VFS(0);
 
 object caller;
 mixed bt = backtrace();
 if (sizeof(bt) > 1) caller = function_object(bt[-2][2]);  
 if (!valid("read_dir",caller,x)) {
  VFS_RETURN(0);
 }   
 if (stringp(x)) { 
  ret = vfs->_get_dir(x);
 } else {
  ret = vfs->_get_dir();
 }
 VFS_RETURN(ret);
}

public mixed _file_stat(string x,void|int(0..1) symlink) 
{
    mixed ret;
    NEED_VFS(0);

    object caller;
    mixed bt = backtrace();
    if (sizeof(bt) > 1) caller = function_object(bt[-2][2]);  
    if (!valid("stat",caller,x,symlink)) {
        VFS_RETURN(0);
    }
   
    ret = vfs->_file_stat(x,symlink);
    VFS_RETURN(ret); 
}

 private mapping(int:mixed) fdlist = ([ ]);
 
 private mixed io_read(object fob,object ret, mixed ... args) {
  ret->value = ({ fob->read(@args) });  
  return 0;
 }
 
 private mixed io_write(object fob,object ret, mixed ... args) {
  //werror("***io_write(%O,%O,%O)\n",fob,ret,args);
  ret->value = ({ fob->write(@args) });
  return 0;
 }

 public mixed security() {
     return securityd;
 }
 
 public int handle_ioctl(int dev, int cmd, mixed ... args) {
  if (!zero_type(fdlist[dev])) {
   if (cmd == IOC_STRING) {
    string f = args[0];
    array(mixed) c_args = args[1..];
    
    switch(f) {
     case "read":
      io_read(fdlist[dev],@c_args);
     case "write":
      io_write(fdlist[dev],@c_args);
     default:
      return -1;
      break;
    }
   }  
  }
  return -1;
 }

public int _write(string fmt, mixed ... args) {
 if (!kernel_registered) return write(fmt,@args);
  //fdlist[1]->write("#%O\n",backtrace());
  k_pointer ret = k_pointer(-1);
  
  if (_ioctl(1,IOC_STRING,"write",ret,sprintf(fmt,@args)) < 0) {
   return -1;
  }
  return ret->value[0];
}

public void console_write(mixed ... args) {
    write(@args);
}

public int _socket(int socket_family, int socket_type, int protocol) {
 int ret;
 NEED_VFS(-1);
 
 object caller;
 mixed bt = backtrace();
 if (sizeof(bt) > 1) caller = function_object(bt[-2][2]);
 if (!valid("create_socket",caller,socket_family, socket_type, protocol)) {
  VFS_RETURN(-1);
 }
 ret = vfs->_socket(socket_family, socket_type, protocol);
 VFS_RETURN(ret);  
} 

public int _ioctl(int d, int request, mixed ... args) {
 int ret;
 if ((d == -1) && (request == -1)) {
  return systems["io"]->add_device(@args);
 } 
 NEED_VFS(-1); 
 ret = vfs->_ioctl(d, request, @args);
 VFS_RETURN(ret);
}

public int _fopen(string fn, string mode) {
 int ret;
 
 NEED_VFS(0);
 
 object caller;
 mixed bt = backtrace();
 if (sizeof(bt) > 1) caller = function_object(bt[-2][2]);
  
 string m;
 m = mode - "w" - "a" - "c" - "t";
 if (mode != m) {
  if (!valid("write",caller,fn)) return 0;   
 } else {
  if (!valid("read",caller,fn)) return 0;  
 }
 
 ret = vfs->fopen(fn,mode);
 VFS_RETURN(ret);
}


public int _fclose(int fh) 
{
    int ret; 
    NEED_VFS(0);
    ret = vfs->fclose(fh);
    VFS_RETURN(ret);
}


public int|string _read_file(string fn, int ... args) 
{
    int fh;
    int|string data = 0;
    int|string buffer;
    array(string) line_buffer;
  
    NEED_VFS(0); 

    object caller;
    mixed bt = backtrace();
    if (sizeof(bt) > 1) caller = function_object(bt[-2][2]);  
    if (!valid("read",caller,fn)) {
        VFS_RETURN(0);
    }
  
    if ((fh = _fopen(fn,"r")) < 0) {
        VFS_RETURN(0);
    } 

    if (sizeof(args) < 1) {
        data = vfs->fread(fh);
    } else {
        if (sizeof(args) == 1 && args[0] >= 0) {            
            buffer = vfs->fread(fh);                        
            line_buffer = buffer / "\n";
            if (sizeof(line_buffer) >= args[0]) {
                data = line_buffer[(args[0])..] * "\n";
            }             
        } else if (sizeof(args) == 2 && args[0] >= 0 && args[1] > 0) {
            buffer = vfs->fread(fh);                        
            line_buffer = buffer / "\n";
            
            if (sizeof(line_buffer) >= (args[0] + args[1])) {
                if (sizeof(line_buffer) > (args[0] + args[1])) { 
                    data = (line_buffer[(args[0])..(-1+args[0]+args[1])] * "\n") + "\n";
                } else {
                    data = (line_buffer[(args[0])..(-1+args[0]+args[1])] * "\n");
                }
            }            
        }
    }    
    vfs->fclose(fh);
    VFS_RETURN2(data);
}

public string|int _read_bytes(string fn, int ... args)
{

    NEED_VFS(0);
 
    mixed ret = 0;
    
    object caller;
    mixed bt = backtrace();
    if (sizeof(bt) > 1) caller = function_object(bt[-2][2]);
  
    if (valid("read",caller,fn)) {  
        if (sizeof(args) > 0) {
            ret = vfs->read_bytes(fn,@args);
        } else {
            ret  = vfs->read_bytes(fn);
        }
    }
            
    VFS_RETURN(ret);
} 




public int _write_file(string fn, string data) {
 int fh;
 int ret;
 
 NEED_VFS(0); 

 object caller;
 mixed bt = backtrace();
 if (sizeof(bt) > 1) caller = function_object(bt[-2][2]);  
 if (!valid("write",caller,fn)) {
  VFS_RETURN(0);
 }
  
 if ((fh = _fopen(fn,"cw")) < 0) {
  VFS_RETURN(0);
 } 
 
 ret = vfs->fwrite(fh,data);    
 vfs->fclose(fh);
 
 VFS_RETURN2(ret);
}

public int _mkdir(string dirname, void|int mode) {
 NEED_VFS(0);
 string fn;
 fn = _dirname(dirname);
 object caller;
 mixed bt = backtrace();
 if (sizeof(bt) > 1) caller = function_object(bt[-2][2]);  
 if (!valid("write",caller,fn)) {
  VFS_RETURN(0);
 } 
 vfs->_mkdir(dirname,mode); 
 return 0;
}


program ___empty_program(int|void line, string|void file) {
 NEED_VFS(0);
 int argc;
 
 object caller;
 mixed bt = backtrace();
 if (sizeof(bt) > 1) caller = function_object(bt[-2][2]);  
 
 argc = query_num_arg();
 if (argc > 1) {
  VFS_RETURN(vfs->___empty_program(line,file));
 } else {
  if (argc == 1)
   VFS_RETURN(vfs->___empty_program(line)); 
 }
 VFS_RETURN(vfs->___empty_program());
}

public mapping(string:int) _filesystem_stat(string path) {
 return ([]);
}


public int _rm(string f) {
 return 0;
}

public int _exece(string file, array(string) args, 
   void |mapping(string:string) env) {
 return 0;  
}

public string _normalize_path(string path) {

}


public int _mv(string from, string to) {
 return 0;
}


void _utime(string path, int atime, int mtime, void|int e) {
 
 if (!objectp(vfs)) return 0;
 
 object caller;
 mixed bt = backtrace();
 if (sizeof(bt) > 1) caller = function_object(bt[-2][2]);
 if (!valid("write",caller,path)) {
  throw( ({ sprintf("Write Access to %O denied!",path),backtrace()[..<1]}));
  return;
 }
 if (query_num_arg() < 4) {
  vfs->utime(path,atime,mtime);
 } else {
  vfs->utime(path,atime,mtime,e);
 }
 return;
}

/* Shell System */


/*

 putenv() ??
 getenv() ??

*/

object _this_shell() {
 
 array(mixed) bt; 
 mixed ent;
 object ob;
 bt = backtrace();
 
 int idx;
 
 for(idx=sizeof(bt)-1;idx>=0;idx--) {
 
   ent = bt[idx];
  ob = function_object(ent[2]);
  if (ob) {
   if (functionp(ob->is_shell)) {
    if (ob->is_shell()) {
     return ob;
    }
   }  
  }
 }
 return 0;
}

string _getcwd() {
 object sh;
 string cwd;
 
 if (sh = _this_shell()) {
  if (sh->get_shell) {
   cwd = sh->get_cwd();
   return cwd; 
  }
 }
 return ".";
}



/* Windows Registry Overrides */

array(string) _RegGetKeyNames(int hkey, string key) {
 if (!zero_type(orig_constants["RegGetKeyNames"])) {
  object caller;
  mixed bt = backtrace();
  if (sizeof(bt) > 1) caller = function_object(bt[-2][2]);
  if (valid("read_registry",caller)) {
   function f = orig_constants["RegGetValue"];
   return copy_value(f(hkey,key));
  }
 }
 return 0;
}

string|int|array(string) _RegGetValue(int hkey, string key, string index) {
 if (!zero_type(orig_constants["RegGetValue"])) {
  object caller;
  mixed bt = backtrace();
  if (sizeof(bt) > 1) caller = function_object(bt[-2][2]);
  if (valid("read_registry",caller)) {
   function f = orig_constants["RegGetValue"];
   return copy_value(f(hkey,key,index));
  }
 }
 return 0;
}

mapping(string:string|int|array(string)) _RegGetValues(int hkey, string key) {
 if (!zero_type(orig_constants["RegGetValues"])) {
  object caller;
  mixed bt = backtrace();
  if (sizeof(bt) > 1) caller = function_object(bt[-2][2]); 
  if (valid("read_registry",caller)) {
   function f = orig_constants["RegGetValues"];
   return copy_value(f(hkey,key));
  }
 }
 return ([]);
}


/* Signal Overrides */

public int _alarm(int seconds) {
 return 0;
}

public int _ualarm(int useconds) {
 return 0;
}

int _kill(int pid, int signal) {
 return 0;
}

void _signal(int sig, void|function(int|void:void) callback) {
 return;
}


/* System Overrides */


public void __verify_internals() {
 // if we don't override this can cause the system to crash!
}
 
/* __automap__  (???) */

public object __disable_threads() {
 object caller;
 mixed bt = backtrace();
 if (sizeof(bt) > 1) caller = function_object(bt[-2][2]); 
 if (valid("_disable_threads",caller)) {   
  return _disable_threads();
 }
 return 0;
}

public array(object) _all_threads() {
 object caller;
 mixed bt = backtrace();
 if (sizeof(bt) > 1) caller = function_object(bt[-2][2]); 
 if (valid("all_threads",caller)) {   
  return all_threads();
 }
 return ({ this_thread() });
}

/*

__joinnode ??
__dirnode ??

*/


/* Compiler Overrides */


/*

 add_include_path()
 remove_include_path()
 Note: No need to override these since they are
       unused now that we are using handle_include.
       Maybe override to call shell func?
*/

string handle_include(string f,
			string current_file,
			int local_include) {

 string cwd;
 string p;
 string fn;
 object sh_obj;
 array(string) ipaths;
 string ret;
 string cur_path = _dirname(current_file); 
 
 NEED_VFS(0);
 		
 if (local_include) {
  if (_is_absolute_path(f)) {
#ifdef DEBUG_INCLUDE
   kwrite("handle_include(%O,%O,%O) returned %O",f,current_file,local_include,f);
#endif   
   return f;
  }
  cwd = "";
  if ((sh_obj = _this_shell()) && functionp(sh_obj->get_cwd)) {
   cwd = sh_obj->get_cwd();  
  }
  ret = vfs->_combine_path(cwd,cur_path,f);
#ifdef DEBUG_INCLUDE
   kwrite("handle_include(%O,%O,%O) returned %O",f,current_file,local_include,ret);
#endif     
  return ret;
 }
 
 
 sh_obj = _this_shell();
 if ((!sh_obj) || (!functionp(sh_obj->get_env))) {
  ret = vfs->_combine_path(cur_path,f);
#ifdef DEBUG_INCLUDE
  kwrite("handle_include(%O,%O,%O) returned %O",f,current_file,local_include,ret);
#endif
  return ret;
 }

 cwd = "";
 if (functionp(sh_obj->get_cwd)) {
  cwd = sh_obj->get_cwd();  
 }
 
 ipaths = sh_obj->get_env("INCLUDE_PATHS") / ";";
 foreach(ipaths,p) {
  fn = vfs->_combine_path(cwd,p,f);
  if (vfs->_file_stat(fn)) {
#ifdef DEBUG_INCLUDE
   kwrite("handle_include(%O,%O,%O) returned %O",f,current_file,local_include,fn);
#endif  
   return fn;
  } 
 }
 ret = vfs->_combine_path(cur_path,f);
#ifdef DEBUG_INCLUDE
   kwrite("handle_include(%O,%O,%O) returned %O",f,current_file,local_include,ret);
#endif  
 return ret;
}

/*
 remove_program_path() ??
 add_program_path() ??
*/

/*
 add_module_path() ??
 remove_module_path() ??
*/

void _add_module_path(string path) {
 object caller;
 mixed bt = backtrace();
 if (sizeof(bt) > 1) caller = function_object(bt[-2][2]); 
 if (!valid("modify_module_path",caller)) return;   


 path=_combine_path("/",path);
 //write(sprintf("add_module_path %O\n",path));      
 root_modules->add_path(path);      
 default_module_path = ({ path }) + (default_module_path - ({ path }));      
}

void _remove_module_path(string path) {
 object caller;
 mixed bt = backtrace();
 if (sizeof(bt) > 1) caller = function_object(bt[-2][2]); 
 if (!valid("modify_module_path",caller)) return;
 
 path=_combine_path("/",path);
 root_modules->rem_path(path);
 default_module_path -= ({ path });
}    

#ifdef OVERRIDE_HANDLE_IMPORT


object handle_import(string path, string|void current_file,
		       object|void current_handler) {

 object ret;
 
#ifdef DEBUG_IMPORT
 kwrite("handle_import(%O, %O,%O)",path,current_file,current_handler);
 /* Backtrace USELESS!!! 
    Can only find if we are in a shell and 
    if we were called by kernel
 */
  
 //kwrite("backtrace = %O\n",backtrace());
#endif


/*

 Conditions:
  Inside Current File
  Inside LIB_PATH
  Inside Current Directory
  
*/           


//  Inside Current File
//  Inside LIB_PATH

 object sh_obj;
 sh_obj = _this_shell();
 if (sh_obj) {
  ret = sh_obj->get_module_tree();
  ret = ret[path];
  return ret;  
 } else {
  if (current_file) {
   ret = master()->joinnode(({}));
   ret->add_path(_dirname(_combine_path(current_file,path))); 
   return ret;
  }
 }

//  Inside Current Directory           

 return 0;          
} 

#endif


object get_root_module(object|void current_handler) 
{
    object shell_ob;
#ifdef DEBUG_GET_ROOT_MODULE
   kwrite("get_root_module(%O)",current_handler);
#endif
 
 shell_ob = _this_shell();
 if (shell_ob && functionp(shell_ob->get_root_module)) {
  return shell_ob->get_root_module(current_handler);   
 } else {
  return root_modules;
 }
  
}


/*
gethostbyaddr, gethhostname, gethostbyname
*/

/*
 Q: Can filter() be used to bypass call function?
*/


public mapping _uname() {

 object caller;
 mixed bt = backtrace();
 if (sizeof(bt) > 1) caller = function_object(bt[-2][2]);  

 if (valid("uname",caller)) {
  return uname(); 
 }
 return ([]);
}

public mapping(string:mixed) __gc_status() {
 return copy_value(_gc_status());
}



int _set_priority(string level, int|void pid) {
 return 0;
}

int _trace(int level, void|string facility, void|int all_threads) {
 return 0;
}

void __exit(int returncode) {

}

void _exit(int returncode, void|string fmt, mixed ... extra) {

}

void __do_call_outs() {
 // only allow init to do this???
}

mapping(string:mixed) _all_constants() {
 return copy_value(all_constants());
}

program _compile_file(string filename, object|void handler, 
 void|program p, void|object o) {
 // why let master do this? When we do it we can enforce
 // execute privilages?
}

int _getpid() {
 return 0;
}

int _remove_call_out(function id) {
 return 0;
}

void _replace_master(object o) {

}


array(array) _call_out_info() {
 return ({});
}



/* Kernel System */

private mixed start_init(mixed argv, mixed env) {
 program p;
 string fn;
 mixed err; 
 
 err = 0;
 
  fn = argv[0];
        
  p = (program)fn;
  
  
  if (!programp(p)) {
   kwrite(sprintf("kexec error: Failed to load program %O.",fn));
   return 1;
  }
  
  err = catch {
   pinit = ({ p() }); 
  };

  if (err) {
   kwrite(sprintf("kexec error:2: %O",err));
   return err;
  }  
   
  err = catch { 
   pinit[0]->main(sizeof(argv),argv,env);
  };
  
  if (err) {
   kwrite(sprintf("kexec runtime error: %O",err));
  }
  
  return 0;  
}

int shell_exec(string cmd, mixed argv, mixed env) {
 program p;
 string fn;
 object ob;
 mixed err; 
 int ret;
 
 err = 0;
 
  fn = cmd;
        
  if (!programp(p = (program)fn)) {
   unload_program(p);
   p = (program)fn;
  }
  
  
  if (!programp(p)) {
   kwrite(sprintf("shell_exec error: Failed to load program %O.",fn));
   return 1;
  }
  
  err = catch {
   ob = p(); 
  };

  if (err) {
   kwrite(sprintf("shell_exec error: Unable to load object. %O",err));
   return 1;
  }  

  if (zero_type(ob)) {
   kwrite("shell_exec error: Object Self-Destructed!");
   return 1;
  }

  if (!ob->main) {
   destruct(ob);
   kwrite("shell_exec error: Program %O has no entry point!",fn);
   return 1;
  }
   
  err = catch { 
   ret = ob->main(sizeof(argv),argv,env);
  };
  
  if (err) {
   kwrite("shell_exec runtime error: %O",err);
   return 1;
  }
  
  return ret;  
}


mixed spawn(mixed argv, mixed env) {
 program p;
 string fn;
 object ob; 
 mixed err; 
 
  fn = argv[0];
    
  err = catch {
   p = (program)fn;
  };
  
  if (err) {
   kwrite("spawn error: %O",err);
   return err;
  }
  if (!p) {
   kwrite("spawn error: Program not found!");
   return -1;
  }
  
  err = catch {
   ob = p(); 
  };

  if (err) {
   kwrite("spawn error: %O",err);
   return err;
  }
  
  err = ob;  
  call_out(ob->main,1,sizeof(argv),argv,env);
 
 return err;
}

private void kwrite(mixed ... msg) { 
 write(sprintf("[%s] %s\n",describe_program(object_program(this)),sprintf(@msg)));
}

private string ktrim(string s) {
 string ret;
 string whitespace; 
 whitespace = " \r\n\t";
 ret = s;
 while ((sizeof(ret) > 0) && (search(whitespace,ret[0]) > -1)) {
  ret = ret[1..];
 }
 while ((sizeof(ret) > 0) && (search(whitespace,ret[-1]) > -1)) {
  ret = ret[0..(sizeof(ret) - 2)];
 }
 return ret;
}

private void welcome() {
 kwrite(sprintf("Kernel v%s",VERSION));
}

public object kernel() {
 return this;
}

/*

string programs_reverse_lookup (program prog) {
  if (!rev_programs) return UNDEFINED;
  if (sizeof (rev_programs) < sizeof (programs)) {
    foreach (programs; string path; program|NoValue prog)
      if (prog == no_value)
	m_delete (programs, path);
      else
	rev_programs[prog] = path;
  }
  return rev_programs[prog];
}
*/

/*
string clean_program_name(string pname) {

 string newname;
 string tmp;
 string rname;
 array(string) mod_ext = ({ ".pmod" });

 newname = 0; 
 foreach(mod_ext, tmp) {
  if (!newname) if (sizeof(pname) > sizeof(tmp)) {
   rname = reverse(pname);    
   if (rname[0..(sizeof(tmp) - 1)] == reverse(tmp)) {
    newname = reverse(rname[sizeof(tmp)..]);
   }
  }
 }
 
 if (newname) return newname;
 return pname;
}
*/

private string seed_program_name(program p) {
 string pname;
 mixed tmp;
 
 if (pname = _static_modules.Builtin()->program_defined(p)) {
  tmp = predef::explode_path(pname);
  return tmp[-1];
 }
 return 0;
}

string resolve_program(program p, void | int d) {
 string r;
 mixed tmp;
 
 if (rev_programs[p]) return rev_programs[p];
 foreach(indices(programs),tmp) {
  if (programs[tmp] == p) {
   programs[tmp] = m_delete(programs,tmp);
   rev_programs[p] = tmp;
   return tmp;
  }
 }
 
 //kwrite("resolve_program(%O,%O)",p,d);
/* if (p == _static_modules) {
  return "proc:/kernel/modules/static";
 }*/
 
 if (d > 255) return 0; // can we loop forever?
  
 if (function_program(p)) {
  r = resolve_program(function_program(p),d+1);  
  if (r) {
   if (function_name(p)) {
   return r + "#" + function_name(p);
   } else {    
    if (tmp = seed_program_name(p)) {     
     return r + "#" + tmp;
    } else {     
     return "proc://tmp/2";
    }
   }
  }    
 } else {  
  if (tmp = seed_program_name(p)) {        
   return "proc://kernel/modules/sys/" + tmp;
  } else {
   return "proc://tmp/1"; 
  }
 }
 return 0;
}

string describe_program(program|function p) {
  string s;
  
  //return "(*kernel->describe_program*)";
  //write(sprintf("describe_program: backtrace() = %O",backtrace()));
#ifdef DEBUG_DESCRIBE
  if (rev_programs[p]) {
   write("[x] describe_program(" + rev_programs[p] + ")\n");
  } else {
   write("[x] describe_program(#)\n");
  }
  if(!p) {
   write("[x] No program/function provided. Returned unresolved\n");
   return 0;
  }
#else
 if(!p) return 0;
#endif



/*
  if (p == object_program (_static_modules))
    return "object_program(_static_modules)";
*/    
  
  if (programp(p)) {
   if (s = resolve_program(p)) {
#ifdef DEBUG_DESCRIBE   
    write("[x] Returned " + s + "\n");
#endif
    if (objectp(p)) {
     return s + "(OBJ)";
    }    
    return s;
   } else {
#ifdef DEBUG_DESCRIBE   
    write("[x] Returned unresolved\n");
#endif    
   }  
  } 

  // TODO: function_object();
  
  if (function_program(p)) {
   if (function_name(p)) {
    if (s = resolve_program(function_program(p))) {
     return s + "->" + function_name(p);;
    }
   } else {
    if (s = resolve_program(function_program(p))) {
     return s + "->()";
    }   
   }
  }
  
  return search(all_constants(), p);
}

string describe(mixed m, int maxlen) {
 return "(*kernel->describe*)";
}


//private mapping(program:mixed) p_objects = ([]);

mapping(string:program) all_programs() {
 return copy_value(programs);
}

string describe_object(object o) {
 program p;
 string pname;
 mapping(object:int) ent;
 array(int) id_list;
 array(object) o_list;
 object ob;
 int newid;
  
 if(zero_type (o)) return 0;	// Destructed.
 
 
 p = object_program(o);
 
 
 if (!p) {
  return "proc://kernel/zombie(ORPHAN)";
 }
 pname = describe_program(p);
 if (!pname) {
  return "proc://kernel/zombie(OBJECT)";
 }
 
 if (zero_type(p_objects[p])) {
  ent = ([ o : 1 ]);
  p_objects[p] = ent;
  return pname + "(1)";
 }
 
 ent = p_objects[p];
 if (!zero_type(ent[o])) {
  return sprintf("%s(%d)",pname,ent[o]);
 }
 
 id_list = ({});
 
 o_list = indices(ent);
 foreach(o_list, ob) {
  id_list += ({ ent[ob] });
 }
 sort(id_list);
 
 newid = -1;
 int idx;
 
 for(idx = 0;idx < sizeof(id_list); idx++) {
  if ((newid < 0) && (id_list[idx] != idx + 1)) {
   newid = idx + 1;
  }
 }
 if (newid < 0) {
  newid = sizeof(id_list) + 1;
 }
 ent[o] = newid; 
 return sprintf("%s(%d)",pname,newid);  
}

mixed object_name(object o) {
    program p;
    string pname;
    int id;
    
    p = object_program(o);
    pname = describe_program(p);
        
    if (pname && !zero_type(p_objects[p])) {                
        id = p_objects[p][o];
        return sprintf("%s(%d)",pname,id);
    }    
    return 0;
}

object find_object(string oname, void|string cur_file) {
 string obname;
 program tmpp; 
 object testob;
 object ret;
  
 ret = 0;
 
 obname = oname;
 if (!_is_absolute_path(obname) && stringp(cur_file)) {
  NEED_VFS(0);
  obname = vfs->_combine_path(cur_file,oname);
 }
 
 foreach(indices(p_objects),tmpp) {
  foreach(indices(p_objects[tmpp]),testob) {
   if (zero_type(testob)) {
    m_delete(p_objects[tmpp],testob);
   } else {
    if (obname == describe_object(testob)) {
     ret = testob;  
    }
   }
  }
 }
 
 return ret; 
}


mixed find_program(string pname, void|string cur_file) {
 string progname;
 program|int ret;
 program testp; 

 ret = -1;
 
 progname = pname;
 if (!_is_absolute_path(progname) && stringp(cur_file)) {
  NEED_VFS(0);
  progname = vfs->_combine_path(cur_file,pname);
 }

 if (zero_type(programs[progname])) {
  foreach(indices(rev_programs),testp) {
   if (rev_programs[testp] == progname) {
    ret = testp;
   }
  }
 } else {
  ret = programs[progname];
 } 
 return ret;
}

void unload_program(program|int p) {
 string pname;  
 if (programp(p)) m_delete(rev_programs,p);
 foreach(indices(programs),pname) {
  if (programs[pname] == p) {
    m_delete(programs,pname);
  }
 }
}

string describe_module(object|program mod, array(object)|void ret_obj) {
 object ob;
 
 if (ret_obj) {
  if (objectp(mod)) {
   ret_obj[0] = mod;
  } else {
   if (programp(mod)) {
    ob = next_object();
    while(ob) {
     if (object_program(ob) == mod) {
      ret_obj[0] = ob; 
      ob = 0;
     } else {
      ob = next_object(ob);
     }
    }  
   }
  }
 }
 
 if (programp(mod)) {  
  return describe_program(mod) + ".";
 }
 
 if (objectp(mod)) {
  return describe_object(mod) + "->";
 }
 //write(sprintf("[kernel->describe_module] %O",backtrace()));
 //return sprintf("(*kernel->describe_module(%O)*)",ret_obj);
 
 return "UNDEFINED_MODULE";
}

void _destruct(mixed ... args) {
 mixed bt;
 object caller;
 object v;
 
 bt = backtrace();
 if (sizeof(bt) > 1) {
  caller = function_object(bt[-2][2]);
 } 
 
 if (sizeof(args)) {  
  if (objectp(args[0])) {
   v = args[0];
   if (functionp(v->remove)) {
    v->remove();   
    if (!zero_type(v)) {
     if (valid("destruct",caller,v)) {
      destruct(v);
     }
    }
   } else {
    if (valid("destruct",caller,v)) {
     destruct(v);  
    }
   }
  }
 } else {
  if (caller) destruct(caller);
 }
}

int valid(string msg, mixed ... args) {
#ifdef DEBUG_SECURITY
    write("kernel:valid(%O,%O)\n",msg,args);
#endif
   if (objectp(securityd) && !destructedp(securityd)) 
   return securityd->valid(msg,@args); 
   return 1;
}

private void reload_program_tables() {
 object ob;
 mapping(program:mixed) new_progs;
 array(string) prog_names;
 array(program) prog_list; 
 string pname;
 program cur_prog;
 
 new_progs = ([]);
  
 // Scan objects for new programs
 
 ob = next_object();   
 while(ob) {   
  new_progs[object_program(ob)] = 1;         
  ob = next_object(ob);
 }
   
 prog_names = indices(programs);
 
 foreach (prog_names,pname) {
  m_delete(new_progs,programs[pname]);
  rev_programs[programs[pname]] = pname;    
 }
  
 prog_list = indices(new_progs);
  
 foreach(prog_list, cur_prog) {   
  if (pname = resolve_program(cur_prog)) {
   programs[pname] = cur_prog;
   rev_programs[cur_prog] = pname;    
  }
 }
}

private void kregister_efuns() {
 add_constant("kernel",this->kernel);
 add_constant("spawn",this->spawn);
 orig_constants = copy_value(all_constants());
}
 
void register_efuns() {
 program p;
 object ob;
 string tmp;
 
 //  add_constant("file_stat",this->_file_stat2);
 p = (program)"simul_efuns.pike";
 tmp = sprintf("%O\n",p); // odd bug fix?  
 m_delete(programs,rev_programs[p]);  
 programs["proc://kernel/simul_efuns"] = p;
 rev_programs[programs["proc://kernel/simul_efuns"]] = "proc://kernel/simul_efuns";
 ob = p();
 ob->load_simul_efuns(pinit,orig_constants);
}

void add_include_path(string path) {
 master()->add_include_path(path);
}

/* User System */

object _this_user() {

 array(mixed) bt; 
 mixed ent;
 object ob;
 bt = backtrace();
 
 int idx;
 
 for(idx=sizeof(bt)-1;idx>=0;idx--) {
 
   ent = bt[idx];
  ob = function_object(ent[2]);
  if (ob) {
      if (!zero_type(users[ob])) {
      return ob;
      }  
  }
 }
 return 0;
}

object _this_player() 
{
    return _this_user();
}

int _in_edit(object user) {
    return 0;
}

int _in_input(object user) 
{
    return 0;
}

int _query_idle(object user) 
{
    return -1;
}

array(object) _users() 
{
    return indices(users);
}

object _this_link() {
 object ob;
 mixed bt = backtrace(); 
 if (sizeof(bt) > 2) {
  ob = function_object(bt[1][2]);
  if (!zero_type(users[ob])) {
   return users[ob];
  }
 }
 return 0; 
}

mixed _call_out(function p,float|int delay, mixed ... args) {
 object user_ob;
 object shell_ob;
 user_ob  = _this_user();
 shell_ob = _this_shell();
 
 if (!sizeof(pinit) || zero_type(pinit[0])) {
  call_out(p,delay,@args);
 }
 
 if (user_ob && !zero_type(user_ob) && functionp(user_ob->handle_call_out)) {
  return call_out(user_ob->handle_call_out,delay,shell_ob,p,@args);  
 }

 if (shell_ob && !zero_type(shell_ob) && functionp(shell_ob->handle_call_out)) {
  return call_out(shell_ob->handle_call_out,delay,p,@args);  
 }

 return call_out(p,delay,@args);
 
}

int make_user(string my_stdin, string my_stdout, string my_stderr, void|int persistent, void|string login_app) {
 array(object) link;
 program p;
 object u;
 mixed err;

 string lapp;
 
 lapp = login_app ? login_app : "/sbin/login.pike";
    
 if (!my_stdin) my_stdin = "";
 if (!my_stdout) my_stdout = "";
 if (!my_stderr) my_stderr = my_stdout;
 
 link = ({ systems["io"]->get_device(my_stdin),
           systems["io"]->get_device(my_stdout),
           systems["io"]->get_device(my_stderr) });

 
 err = catch {
     p = (program)lapp;
 };

 if (err) {
  kwrite("make_user failed: unable to compile login object!");
  return 0;
 }
 //kwrite("Program Compiled %O",p);
 
 err = catch {
  u = p(link,persistent);
 };
 
 if (err) {
  kwrite("make_user failed: unable to create login object!");
  return 0;
 } 
 
 
 if (zero_type(u)) {
  kwrite("make_user failed: login object self-destructed!");
  return 0;
 }
 
 users[u] = link;
 err = catch {
 u->main( 4,
          ({ lapp , my_stdin, my_stdout, my_stderr }),
          ([ "stdin" : "/dev/console", "stdout" : "/dev/console", "stderr" : "/dev/console" ])
         );
 };
 
 if (err) {
  kwrite("make_user: Login Died! %O",err);
  return 0;
 }
  
 return 1;
}

int register_security(string sec_key) {
 if (sec_key == SECURITY_KEY) {
  if (objectp(securityd) && !destructedp(securityd)) {
   return 0;
  }
  securityd = function_object(backtrace()[-2][2]);
  return 1;
 }
 return 0;
}

int unregister_security() {
 if (securityd == function_object(backtrace()[-2][2])) {
  securityd = 0;
 }
}

private void reresolve_all_programs(mixed module_path_stack)
{
    array(string) name_list;
    array(mixed) m_list;
    
    int idx;      
    int path_id;
    string use_path;    
    string new_name;    
    string pname;        
    mixed tmp;  
         
    name_list = indices(programs);           
    foreach (name_list,pname) {       
        use_path = "";
        path_id = -1;
   
        for (idx = 0; idx < sizeof(module_path_stack);idx++) {
            if (has_prefix(pname,module_path_stack[idx])) {                
                if (sizeof(module_path_stack[idx]) > sizeof(use_path)) {
                    use_path = module_path_stack[tmp];
                    path_id = idx;
                }
            }
        }      
        if (path_id > -1) {    
            new_name = pname[sizeof(use_path)..];
            if (!has_prefix(new_name,"/")) new_name = "/" + new_name;
            new_name = sprintf("proc://kernel/master/modules/%O",path_id) + new_name;                        
            programs[new_name] = m_delete(programs,pname);
            rev_programs[programs[new_name]] = new_name;
        }
    }
    
    name_list = indices(fc);
        
    foreach (name_list,pname) {       
        use_path = "";
        path_id = -1;
   
        for (idx = 0; idx < sizeof(module_path_stack);idx++) {
            if (has_prefix(pname,module_path_stack[idx])) {                
                if (sizeof(module_path_stack[idx]) > sizeof(use_path)) {
                    use_path = module_path_stack[tmp];
                    path_id = idx;
                }
            }
        }      
        if (path_id > -1) {    
            m_delete(fc,pname);
        }
    }    

    m_list = indices(rev_programs);
    foreach (name_list,tmp) {
        m_delete(rev_programs,tmp);
    }
    
    m_list = indices(rev_fc);    
    foreach (name_list,tmp) {
        m_delete(rev_fc,tmp);
    }
                 
}

/* Entry Point */

int kernel_init(int argc, 
                mixed argv,
                mixed env, 
                mixed orig_constants, 
                mapping(string:mixed) prog_stack, 
                mapping(program:string) rev_prog_stack,
                mapping(string:object|NoValue) fc_stack,
                mapping(mixed:string) rev_fc_stack,
                mixed module_path_stack,
                mixed include_path_stack) 
{

    //int idx;  
    int linen;
    //int path_id;
    //string use_path;
    string clean_line;
    //string new_name;
    string line;
    //string pname;
    string vname;      
    array(string) init_argv;
        
    mixed tmp;  
    mixed err;
    mixed cfg;
    mixed lines;
  
    if (init_called) return 0;
    init_called = 1;
  
  
    root_modules = master()->joinnode(({instantiate_static_modules(predef::_static_modules)}));
  
    programs = prog_stack;
    rev_programs = rev_prog_stack;  
    fc =  fc_stack;
    rev_fc = rev_fc_stack;
    programs["proc://kernel"] = m_delete(programs,sprintf("%O",object_program(this)));
    rev_programs[programs["proc://kernel"]] = "proc://kernel";
  
    kwrite("Loading program tables.");
      
    /* Init Program Tables */
    
    programs["proc://kernel/master"] = m_delete(programs,sprintf("%O",object_program(master())));
    rev_programs[programs["proc://kernel/master"]] = "proc://kernel/master";

    programs["proc://kernel/modules/static"] = object_program(_static_modules);
    rev_programs[object_program(_static_modules)] = "proc://kernel/modules/static";
  
    programs["proc://kernel/modules/CompilerEnvironment"] = CompilerEnvironment;
    rev_programs[CompilerEnvironment] = "proc://kernel/modules/CompilerEnvironment";
   
   
    //reresolve_all_programs(module_path_stack);
    /*
    prog_names = indices(programs);
           
    foreach (prog_names,pname) {       
        use_path = "";
        path_id = -1;
   
        for (idx = 0; idx < sizeof(module_path_stack);idx++) {
            if (has_prefix(pname,module_path_stack[idx])) {                
                if (sizeof(module_path_stack[idx]) > sizeof(use_path)) {
                    use_path = module_path_stack[tmp];
                    path_id = idx;
                }
            }
        }      
        if (path_id > -1) {    
            new_name = pname[sizeof(use_path)..];
            if (!has_prefix(new_name,"/")) new_name = "/" + new_name;
            new_name = sprintf("proc://kernel/master/modules/%O",path_id) + new_name;                        
            programs[new_name] = m_delete(programs,pname);
            rev_programs[programs[new_name]] = new_name;
        }
    }
    */
    
    
   
  reload_program_tables();
      
  welcome();
    
  kregister_efuns();
      
  //werror(sprintf("Constants (%O)\n",all_constants()));
  
//  boot_path = dirname(argv[0]);

  if(argv[0]=="") {
   boot_path = "";
  } else {
#ifdef __amigaos__
   tmp=argv[0]/":";
   array(string) tmp2=tmp[-1]/"/";
   tmp[-1]=tmp2[..<1]*"/";
   if(sizeof(tmp2) >= 2 && tmp2[-2]=="") tmp[-1]+="/";
   boot_path = tmp*":";
#else  
#ifdef __NT__
   tmp = (replace((argv[0]),"\\","/")/"/");
#else
   tmp = ((argv[0])/"/");
#endif
   if(tmp[0] == "" && sizeof(argv[0])) tmp[0] = "/";  
   if (argv[0][0]=='/' && sizeof(tmp)<3) {
    boot_path = "/";
   } else {
    boot_path = tmp[..<1]*"/";
   }
#endif
  }
    
  
  //kwrite(sprintf("boot_path = %O",boot_path));
  
  kwrite("Loading configuration variables.");
  config_vars = ([]);
  
  tmp=Files()->Fd();
  
  if ( ([function(string, string : int)]tmp->open)(combine_path(boot_path,"kernel.conf"),"r") ) {
    cfg = ([function(void : string)]tmp->read)();
    lines = cfg / "\n";
    linen = 0;
    foreach(lines,line) {
     linen = linen + 1;
     clean_line = ktrim(line);
     if ((sizeof(clean_line) > 0) && (clean_line[0..0] != "#")) {
      tmp = clean_line / "=";
      if (sizeof(tmp) > 1) {
       vname = ktrim(tmp[0]);
       tmp = ktrim(tmp[1..] * "=");
       config_vars[vname] = tmp;
#ifdef DEBUG_CONFIG
       kwrite(sprintf("config_vars[%O] = %O",vname,tmp));
#endif                  
      } else {
       kwrite(sprintf("Error in configuration file on line %O.",linen));
      }
     }
    }
  } else {
   kwrite("Configuration file not found!");
  }
  
  array(string) inc_paths;
  inc_paths = config_vars["include_path"] / ";";
  foreach(inc_paths, tmp) {
   //kwrite("add_include_path %O",tmp);
   master()->add_include_path(tmp);
  }
  
  kwrite("Loading filesystem.");
  tmp = combine_path(boot_path,"vfs.pike");
  
  fs = (program)tmp;
  if (!programp(fs)) {
   kwrite("Filesystem failed to load.");
   return 1;
  }
  
  m_delete(programs,tmp);
  programs["proc://kernel/boot/vfs"] = fs;
  
  err = catch {   
   vfs = fs(module_path_stack,include_path_stack,config_vars,orig_constants);
  };
  
  if (err) {   
   kwrite("Error loading filesystem");
   kwrite(sprintf("%O",err));
   return 1;
  }
  //reload_program_tables();
    
  register_efuns();
  reresolve_all_programs(module_path_stack); 
  vfs->register_kernel();
      
  kernel_registered = 1;
  fdlist[0] = Files()->_stdin;
  fdlist[1] = Files()->_stdout;   
  fdlist[2] = Files()->_stderr;

             
  mapping(string:program) systemp = ([]);
  systemp["io"]= (program)"proc://kernel/boot/io.pike";
         
  foreach(indices(systemp), tmp) {
   systems[(string)tmp] = systemp[(string)tmp]();
  }
  
  //master()->register_kernel();
      
  //kwrite("programs = %O",programs);
  //kwrite("rev_programs = %O",rev_programs);  

  
  kwrite("Starting init.");
  
  
  /*
  mixed fh;
  string data;
  fh = vfs->fopen("/sbin/init","r");
  data = vfs->fread(fh,5);
  kwrite(data);
  data = vfs->fread(fh);
  kwrite(data);
  
  vfs->fclose(fh);
  */
   
  init_argv = ({"/sbin/init"});      
  err = start_init(init_argv,env);
  if (err) {
   kwrite("Unable to start init. System Halted!");
   return 1;
  } else {
   kwrite("Init process ended. System Restart!");
  }
  
  return -1;
}

