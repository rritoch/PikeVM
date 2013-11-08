
#include "/includes/mudlib.h"
//#include <driver/origin.h>
#include "/includes/security.h"
#include "/includes/master.h"

//inherit M_ACCESS;
inherit M_INPUT;
//inherit M_HISTORY;
//inherit M_ALIAS;
inherit M_SHELLFUNCS;
//inherit M_SAVE;
//inherit M_SCROLLBACK;

private object owner;

void execute_command(mixed ... args);
string query_shellname();
string query_save_path(string userid);

int is_variable(string var);
mixed get_variable(string var);

string get_cwd();

protected function arg_to_words_func = arg_to_words_func_default;



private string last_module_path;
private joinnode_t current_tree;

joinnode_t get_module_tree() 
{
  string lib_path;
  string p;
  array(string) paths;
  string cwd;
  string clean_path;
  if (!is_variable("LIB_PATHS")) {
      lib_path = "";
  } else {
      lib_path = get_variable("LIB_PATHS");
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
   clean_path = master()->combine_path_with_cwd(p);
   // Can Read/Exec Check here????
   current_tree->add_path(clean_path);
  }
  // Init Cache!
  last_module_path = lib_path;
  // Done!
  return current_tree; 
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
  
  if (!is_variable("LIB_PATHS")) {
      lib_path = "";
  } else {
      lib_path = get_variable("LIB_PATHS");
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



final int is_shell() 
{
	return 1;
}

array(string) arg_to_words_func_default(string args) {
   return args / " ";
}

//### goofy fucking hack cuz the shell doesn't save for shit. only M_SAVE,
//### even though in the alias code it professes to "not require it to be
//### bound to M_SAVE" ... this is bunk...
private string save_info;

void setup_for_save()
{
    /*
** This object has no variables to save, but many of the moduless do,
** so we must dispatch to them.
*/
    //alias::setup_for_save();
    shellfuncs_setup_for_save();
}

void save_me()
{
    if ( !owner )	/* probably the blueprint */
return;

    setup_for_save();
    //save_info = save_to_string();
    //unguarded(1, (: save_object, query_save_path(owner->query_userid()) :));
}
protected void restore_me(string userid)
{
    //unguarded(1, (: restore_object, query_save_path(userid) :));
    if ( save_info )
    {
//load_from_string(save_info, 0);
save_info = 0;
    }
}

void remove()
{
   /*
    if ( origin() != ORIGIN_LOCAL && owner && previous_object() != owner )
error("illegal attempt to remove shell object\n");
    */
    save_me();
    destruct();
}

protected void shell_input(mixed input)
{
    if ( input == -1 )
    {
remove();
return;
    }

    /* we can safely remove leading and trailing whitespace */
    input = trim_spaces(input);
    if ( input == "" )
return;

/*
    if ( input[0] == HISTORY_CHAR )
    {
input = history_command(input);
if ( !input )
return;
    }


    add_history_item(input);
*/
    if ( input[0] == '\\' ) {
        input = input[1..];
    } else { 
        //input = expand_alias(input);
    }

    if ( input != "" )
execute_command(input);
}

private void cmd_exit()
{
    if(modal_stack_size() == 1)
    {
//### I think we could just issue the quit command rather than force it
this_user()->force_me("quit");
return;
    }
    printf("Exiting %s\n", query_shellname());
    modal_pop();
    remove();
}


protected void create() {

    if ( !clonep() ) {
        return;
    }

    //owner = previous_object();
    
    owner = this_user();
    
    /*
       Need to make previous object more cool!!!!
           
    if ( owner != this_user() )
    {
        destruct();
        error(sprintf("illegal shell object creation\n");
    }
    */
    
    if ( owner )
restore_me(owner->query_userid());

    //alias::create();
    //history::create();
}

/*
function cmd_remove_alias_x(mixed arg) {
   return cmd_remove_alias(arg,1);
}
*/

/*
** This function is used internally to prepare a shell for operation.
** Subclasses will typically override to set up bindings and variables
** with shell_bind_if_undefined() or set_if_undefined(), respectively.
*/
protected void prepare_shell()
{
    //shell_bind_if_undefined("alias",	cmd_alias );
    //shell_bind_if_undefined("unalias",	cmd_remove_alias_x );
    //shell_bind_if_undefined("history",	cmd_history );
    //shell_bind_if_undefined("scrollback", cmd_scrollback );
    shell_bind_if_undefined("exit", cmd_exit );
}

protected mixed what_prompt()
{
    return "> ";
}

void start_shell()
{
    if ( owner != this_user() || previous_object() != owner )
error("illegal attempt to take over shell\n");

    modal_push( shell_input , ({}), what_prompt());

    prepare_shell();
}


final object query_owner()
{
    return owner;
} 