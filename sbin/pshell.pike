
#include <mudlib.h>
#include <daemons.h>
#include <commands.h>

inherit SHELL;
inherit M_COMPLETE;

string array query_path() 
{
    return ({ CMD_DIR_PLAYER "/" });
}

string query_shellname()
{ 
   return "User Shell"; 
}

private mapping shell_vars = ([]);

void set_variable(string name, mixed value)
{
    if(!shell_vars) {
        shell_vars = ([]);
    }
    
  switch(name)
  {
    case "ansi":
    case "status":
    case "MORE":
      shell_vars[name] = value;
      return;
    default:
      error("Bad user shell variable.");
  }
}

void unset_variable(string name, mixed value)
{
    if(!shell_vars) {
        shell_vars = ([]);
    }
    
    switch(name) {
        case "ansi":
        case "status":
        case "MORE":
            map_delete(shell_vars,name);
            return;
        default:
            error("Bad user shell variable.");
    }
}

mixed get_variable(string name)
{
    if(!shell_vars) {
        shell_vars = ([]);
    }
    return shell_vars[name];
}

private string expand_one_argument(string arg)
{
    mixed expansion;

    if ( strlen(arg) <= 1 || arg[-1] != '*' ) {
        return arg;
    }

    expansion = complete_user(arg[0..<2]);
    if ( stringp(expansion) ) {
        return expansion;
    }

    return arg;
}

protected void execute_command(string original_input)
{
    array(string) argv = explode(original_input, " ");
    mixed tmp;
    array winner;
    string argument;
    
#ifdef CHANNEL_D    
    string channel_name;
#endif    
    
    argv = map(argv, (: expand_one_argument :));
    if(!argv) {
        return;
    }
    
    argv -= ({ "" });

    // Local CMD
    
    if (functionp(dispatch[argv[0]])) {
        dispatch[argv[0]](argv);  
        return;
    }

    // User CMD
    winner = CMD_D->find_cmd_in_path(argv[0], ({ CMD_DIR_PLAYER "/" }));                
    if (arrayp(winner)) {
    
        if ( sizeof(argv) > 1 ) {
            argument = implode(argv[1..], " ");
        }

        winner[0]->call_main(argument,0,0,0,0,0,argument);    
        return;
    }
    
    // Domain Command
    if ( this_body()->do_domain_command(original_input)) {
        return;
    }

#ifdef CHANNEL_D
    // Channel Command        
    channel_name = CHANNEL_D->is_valid_channel(argv[0], this_user()->query_channel_list());
    if ( channel_name )  {            
        int chan_type = channel_name[0..4] == "imud_";
        CHANNEL_D->cmd_channel(channel_name,implode(argv[1..], " "),chan_type);
        return;
    }
#endif    

    // Fail response    
    if(is_file(CMD_DIR_VERBS "/" + argv[0] + ".c")) {
        write(this_body()->nonsense());
    } else {
        printf("I don't know the word: %s.\n", argv[0]);
    }          
}

protected string query_save_path(string userid)
{
    return PSHELL_PATH(userid);
}