/* ========================================================================== */
/*                                                                            */
/*   Filename.c                                                               */
/*   (c) 2001 Author                                                          */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */

//#define DEBUG_SHELL

#include "/includes/devices.h"
#include "/includes/master.h"


private mapping(string:mixed) shell_env;

#ifdef OVERRIDE_HANDLE_IMPORT
 
private string last_module_path;
private joinnode_t current_tree;

// NEED SECURITY???
//  Anyone can modify the module tree
//  Can we rebuild if it was modified?

 joinnode_t get_module_tree() {
  string lib_path;
  string p;
  array(string) paths;
  string cwd;
  string clean_path;
  if (zero_type(shell_env["LIB_PATH"])) {
   lib_path = "";
  } else {
   lib_path = shell_env["LIB_PATH"];
  }
  
  // Cache!
  if (last_module_path && last_module_path == lib_path) return current_tree;
  
  // New Tree
  current_tree = master()->joinnode(({}));
  
  // Init Vars
  paths = lib_path / ";";  
  cwd = get_cwd();
  
  // Build Tree
  foreach(paths,p) {
   clean_path = master->combine_path_with_cwd(p);
   // Can Read/Exec Check here????
   current_tree->add_path(clean_path);
  }
  // Init Cache!
  last_module_path = lib_path;
  // Done!
  return current_tree; 
 } 

#endif



//private string last_root_module_path;
//private joinnode_t root_module;

// NEED SECURITY???
//  Anyone can modify the module tree
//  Can we rebuild if it was modified?

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
   clean_path = master()->combine_path_with_cwd(p);
   // Can Read/Exec Check here????
   root_module->add_path(clean_path);
  }
  // Init Cache!
  //last_root_module_path = lib_path;
  // Done!
  return root_module; 
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

void set_cwd(string path) 
{
    shell_env["CWD"] = path;
}

mapping(string:string) environment() {
 return copy_value(shell_env);
}

string set_env(string vname, mixed val) {
 shell_env[vname] = val;
 return val;
}

mixed get_env(string vname) {
 if (zero_type(shell_env[vname])) {
  return "";
 }
 return shell_env[vname];
}

mixed get_variable(string vname) {
    return get_env(vname);
}

void set_variable(string vname, mixed value) {
    set_env(vname,value);
}

string shell_combine_path(string path1, string path2) {
 string pth1;
 string pth2;
 
 pth1 = "";
 pth2 = "";
 
 if (path1) {
  pth1 = path1;
 }
 if (path2) {
  pth2 = path2;
 }
 return combine_path(pth1,pth2);
}

int execute(string cmd_line) {
 
 //kernel()->console_write(sprintf("execute %O\n",cmd_line));
 string cur_path;
 string path;
 string cur_cmd;
 string cur_file;

 array(string) pths;
 array(string) args;
 array(string) files;
 
 args = cmd_line / " ";
  
 string cmd_path = dirname(args[0]); 
 string cmd = explode_path(args[0])[-1];
 
 if (kernel()->_is_absolute_path(args[0])) {
  cur_cmd = args[0];  
  if (!file_stat(cur_cmd)) {
   if (file_stat(cur_cmd + ".pike")) {
    cur_cmd = cur_cmd + ".pike";   
   } else {
    cur_cmd = "";
   }
  } 
 } else {

  pths = shell_env["PATH"] / ";";
  
  cur_cmd = "";
  foreach(pths, path) {
   if (!sizeof(cur_cmd)) {
    cur_path =shell_combine_path(shell_env["CWD"],shell_combine_path(path,cmd_path));     
    files = get_dir(cur_path);    
    if (files && sizeof(files)) {
     foreach (files, cur_file) {
      if (basename(cur_file) == cmd) {
       cur_cmd = shell_combine_path(cur_path,cur_file);
      }
     }
     
     if (!sizeof(cur_cmd)) {
      foreach (files, cur_file) {
       if (basename(cur_file) == (cmd + ".pike")) {
        cur_cmd = shell_combine_path(cur_path,cur_file);
       }
      }
     }                  
    }
   }      
  }
 }
 
 if (sizeof(cur_cmd)) { 
  return kernel()->shell_exec(cur_cmd,args,shell_env);
 } else {
  write("Command %O not found!\n",args[0]);
 }
 return 1; 
}

void shell_loop(string raw_cmd) {
 
 int do_exit;
 int ret;
 mixed err;
 array(string) split_cmd;
 string cmd;
  
 if (has_prefix(raw_cmd,"@")) {
  program p;
  object ob;
  
  input_to(shell_loop,INPUT_PROMPT,shell_env["prompt"]);
  p = compile_string(sprintf("mixed foo() { return %s; }",raw_cmd[1..]));
  if (programp(p)) {
  ob = p();
  err = catch {
   write("\nReturned: %O\n",ob->foo());
  };
  if (err) {
     if (objectp(err)) {
          write("\nError: %O %O\n",err,err->backtrace());
      } else {
          write("\nError: %O\n",err);
      }
     
  }
  destruct(ob);
  } else {
   write("Syntax Error!\n");
  }    
  return;
 }
  
 cmd = "";
 if (sizeof(raw_cmd)) {
  cmd = raw_cmd;
  if (raw_cmd[-1] == '\n') {
   cmd = raw_cmd[0..<2];
  }
 }
 
 if (!cmd) cmd = ""; 
 split_cmd = cmd / " ";

 
 if (sizeof(split_cmd)) {
 
  if (sizeof(cmd)) {
   if (split_cmd[0] == "exit") {
    do_exit = 1;
   }
  }
  if (!do_exit) input_to(shell_loop,INPUT_PROMPT,shell_env["prompt"]);
 
  if (sizeof(split_cmd)) {
   switch(split_cmd[0]) {
    case "exit":
     write("Done!\n");
     destruct();
     break;
    default:
     ret = execute(cmd);
     break;
    };    
  }
 } 
}

int main(int argc, array(string) argv, mapping(string:string) env) {

#ifdef DEBUG_SHELL
 write("main(%O,%O,%O)\n",argc,argv,env);
#endif 
 shell_env = env;
 if (zero_type(shell_env["prompt"])) {
  shell_env["prompt"] = "# ";
 }

 if (zero_type(shell_env["CWD"])) {
  shell_env["CWD"] = "/";
 }

 if (zero_type(shell_env["PATH"])) {
  shell_env["PATH"] = "/bin;.";
 }
 
 if (zero_type(shell_env["INCLUDE_PATHS"])) {
  shell_env["INCLUDE_PATHS"] = "/includes";
 }

 if (zero_type(shell_env["LIB_PATHS"])) {
     shell_env["LIB_PATHS"] = "/lib;proc://kernel/master/modules/0";
 }
  
 if (argc < 2) {
  write("Shell v1.0\n");  
  input_to(shell_loop,INPUT_PROMPT,shell_env["prompt"]); 
 } else {
  execute(argv[1..] * " ");  
 }
}
