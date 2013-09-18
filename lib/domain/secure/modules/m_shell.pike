 /**
  * Shell Module
  */

#include <master.h>
  
final int is_shell() 
{
    return 1;
}
 
 
 string get_cwd();
 string set_cwd(string x);
 
 mixed get_variable(string name);
 void set_variable(string name);
 int has_variable(string name);
 mapping(string:string) environment();


private string last_module_path;
private joinnode_t current_tree;

// NEED SECURITY???
//  Anyone can modify the module tree
//  Can we rebuild if it was modified?

 joinnode_t get_module_tree() 
 {
  string lib_path;
  string p;
  array(string) paths;
  string cwd;
  string clean_path;
lib_path = has_variable("LIB_PATHS") ? get_variable("LIB_PATHS"): "";
  
  // Cache!
  if (last_module_path && last_module_path == lib_path) return current_tree;
  
  // New Tree
  current_tree = master()->joinnode(({}));
  
  // Init Vars
  paths = lib_path / ";";  
  cwd = get_cwd();
  
  // Build Tree
  foreach(paths,p) {
   clean_path = master()->combine_path_with_cwd(p);
   // Can Read/Exec Check here????
   current_tree->add_path(clean_path);
  }
  // Init Cache!
  last_module_path = lib_path;
  // Done!
  return current_tree; 
 } 

     
 joinnode_t get_root_module(object|void current_handler) 
 {
    string lib_path;
    string p;
    array(string) paths;
    string cwd;
    string clean_path;
    
    joinnode_t root_module;
 
#ifdef DEBUG_GET_ROOT_MODULE
    write("%O (%O)",get_root_module, current_handler);
#endif  
    lib_path = has_variable("LIB_PATHS") ? get_variable("LIB_PATHS"): "";
        	
    
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

    return root_module; 
 }
 
void handle_call_out(function f, mixed ... args) 
{
    f(@args);
}
 
    