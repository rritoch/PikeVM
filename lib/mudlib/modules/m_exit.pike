
#include "/includes/mudlib/hooks.h"
#include "/includes/mudlib/lpscript.h"

inherit "/lib/mudlib/classes/move.pike";

private mapping exits = ([]);
private array(string) hidden_exits = ({});
private string d_default_error;
//private string d_default_desc;
private mixed d_default_exit_message;
private mixed d_default_enter_message;
private mixed d_default_check;
private mixed d_default_desc;
private mixed base= base_f;

mixed base_f()
{
    return file_name(this_object())[0..strsrch(file_name(this_object()),'/',-1)] ;
}

 mixed call_hooks(string tag,mixed func,mixed start,mixed ... args);
mixed query_exit_check(string);
mapping debug_exits();
array(string) query_hidden_exits();

/*
* DEFAULTS AND ERRORS
*/

//:FUNCTION query_default_exit_message
//Return the default exit message
string query_default_exit_message() 
{
  return d_default_exit_message();
}

//:FUNCTION query_default_enter_message
//Return the default enter message
string query_default_enter_message() 
{
  return d_default_enter_message();
}

//:FUNCTION set_default_exit_message
//Set the default exit message for all exits.
//The argument can be a string, or function pointer
void set_default_exit_message(mixed arg) {
    d_default_exit_message = arg;
}

//:FUNCTION set_default_enter_message
//Set the default enter message for all exits
//The argument can be a string or function pointer
void set_default_enter_message(mixed arg) {
    d_default_enter_message = arg;
}

//:FUNCTION set_default_check
//Set the default check for all exits
//The argument can be a 0, 1, string, or function pointer returning one of
//those
void set_default_check(mixed arg) {
    d_default_check = arg;
}

//:FUNCTION query_default_check
//Return the defaut check
mixed query_default_check()
{
  return d_default_check();
}

private int f_is_obvious_exit(object ob) 
{	
	return ob->is_exit() && ob->query_obvious_description() ? 1 : 0;
}

//:FUNCTION set_default_error
//Set the default error message (the message given when someone goes a
//direction with no exit). This should be a string or a function ptr
//returning a string.
void set_default_error(mixed value) {
  d_default_error = value;
}

//:FUNCTION has_default_error
//Return true if the room has a default exit error
int has_default_error() {
  return !!d_default_error;
}

//:FUNCTION query_default_error
//Returns the error default error message.
string query_default_error()
{
  if (has_default_error())
    return d_default_error;
  return( "It doesn't appear possible to go that way.\n");
}

/*
* EXIT DIRECTIONS
*/

//:FUNCTION query_exit_directions
//Return all of the exit directions controlled by the exit object
//The optional argument determines whether hidden exits are included in this
//list. If nonnull, they are included
 array(string) query_exit_directions(int show_hidden)
{
  array(string) dirs = keys( exits );
  array(object) exit_obs=filter(all_inventory(this_object()),
f_is_obvious_exit );
  foreach(exit_obs,object exit_ob)
    {
      if(show_hidden||
!exit_ob->query_hidden() )
dirs+=({ exit_ob->query_direction() });
    }
  if (show_hidden)
    return dirs;
  else
    return dirs - hidden_exits;
}

//:FUNCTION show_exits
//Return a string giving the names of exits for the obvious exits line
string show_exits()
{
  string exit_str;
  array(string) exit_names;
  exit_names = query_exit_directions(0);
  exit_str = ((sizeof(exit_names)) ? implode(exit_names,", ") :"none");
#ifdef WIZARDS_SEE_HIDDEN_EXITS
  if ( wizardp(this_user()) && sizeof(query_hidden_exits()) )
    {
      exit_str += ", *" + implode(query_hidden_exits(), ", *");
    }
#endif
  return exit_str;
}

/*
* EXIT MESSAGES
*/

//:FUNCTION query_enter_msg
//Return the enter messages of a given exit
string query_enter_msg(string direction)
{
  object which=present(direction);
  int i;
  if(which && which->is_exit())
    return which->query_method_exit_messages("go");
  i=sizeof(exits[direction]->enter_messages);
  if(!i)
    return query_default_exit_message();
  return (exits[direction]->enter_messages[random(i)])();
}

//:FUNCTION set_enter_msg
//Set the enter message of a given exit.
//This message will be displayed in the destination room.
//The message can be a fucntion pointer or a string.
//If multiple messages are passed, a random one will be selected when invoked
void set_enter_msg(string direction, mixed ... message)
{
  object which=present(direction);
  if(which && which->is_exit())
  {
    which->set_method_enter_messages("go",@message);
    return;
  }
  exits[direction]->enter_messages = message;
}

//:FUNCTION add_enter_msg
//Add an additional enter message to a given exit.
//The message can be a function pointer or a string
//If multiple messages are passed, a random one will be selected when invoked
void add_enter_msg(string direction, mixed ... message)
{
  object which=present(direction);
  if(which && which->is_exit())
  {
    which->add_method_enter_messages("go",@message);
    return;
  }
  exits[direction]->enter_messages+=message;
}

//:FUNCTION remove_enter_msg
//Remove an enter emssage from a given exit.
void remove_enter_msg(string direction, mixed ... message)
{
  object which=present(direction);
  if(which && which->is_exit())
  {
    which->remove_method_enter_messages("go",@message);
    return;
  }
  exits[direction]->enter_messages-=message;
}

//:FUNCTION list_enter_msgs
//Return all possible enter messages for a given exit
array(mixed) list_enter_msgs(string direction)
{
  object which=present(direction);
  if(which && which->is_exit())
    return which->list_method_enter_messages("go");
  return exits[direction]->enter_messages;
}

//:FUNCTION query_exit_msg
//Return the exit messages of a given exit
string query_exit_msg(string direction)
{
  int i=sizeof(exits[direction]->exit_messages);
  object which=present(direction);
  if(which && which->is_exit())
    return which->query_method_exit_messages("go");
  if(i)
    return (exits[direction]->exit_messages[random(i)])();
  return query_default_exit_message();
}

//:FUNCTION set_exit_msg
//Set the exit message of a given exit.
//This message will be displayed in the room the body is leaving
void set_exit_msg(string direction, mixed ... message)
{
  object which=present(direction);
  if(which && which->is_exit())
  {
    which->set_method_exit_messages("go",@message);
    return;
  }
  exits[direction]->exit_messages = message;
}

//:FUNCTION add_exit_msg
//Add an additional exit message to a given exit.
//The message can be a function pointer or a string
void add_exit_msg(string direction, mixed ... message)
{
  object which=present(direction);
  if(which && which->is_exit())
  {
    which->add_method_exit_messages("go",@message);
    return;
  }
  exits[direction]->exit_messages+=message;
}

//:FUNCTION remove_exit_msg
//Remove an exit emssage from a given exit.
void remove_exit_msg(string direction, mixed ... message)
{
  object which=present(direction);
  if(which && which->is_exit())
  {
    which->remove_method_exit_messages("go",@message);
    return;
  }
  exits[direction]->exit_messages-=message;
}

//:FUNCTION list_exit_msgs
//List all of the possible exit messages for an exit
array(mixed) list_exit_msgs(string direction)
{
  object which=present(direction);
  if(which && which->is_exit())
    return which->list_method_exit_messages("go");
  return exits[direction]->exit_messages;
}

/*
* EXIT DESTINATIONS
*/

/* eval_dest() returns the full pathname of the destination of the exit, or an
* error. */
private string eval_dest(mixed arg)
{
  mixed tmp;
  if(!arg||arg=="")
    return 0;
  tmp= exits[arg]->destination;
  tmp = tmp();
  if (!stringp(tmp))
    return 0;
  if (tmp[0] == '#')
    return tmp;
  return absolute_path(tmp,base());
}

//:FUNCTION query_exit_destination
//Return the destination path of the given exit.
 string query_exit_destination(string arg)
{
  object which=present(arg);
  if(which && which->is_exit())
    return which->query_method_destination("go");
  return eval_dest(arg);
}

/*
* EXIT DESCRIPTIONS
*/

//:FUNCTION query_exit_description
//Returns the description of the given exit.
string query_exit_description(string direction)
{
  object which = present(direction);
  if(which && which->is_exit())
    return which->query_method_description("go");
  if(exits[direction])
    return (exits[direction]->description)();
  return 0;
}

//:FUNCTION set_exit_description
//Set the description of an exit.
void set_exit_description(string direction, mixed description)
{
  object which=present(direction);
  if(which && which->is_exit())
  {
    which->set_long(description);
    return;
  }
  exits[direction]->description = description;
}

/*
* EXIT CHECKS
*/

//:FUNCTION query_exit_check
//Return whether or not the exit can be passed through
mixed query_exit_check(string direction)
{
  if(member_array(direction,keys(exits))==-1) {
    return 0;
  }
  return exits[direction]->checks;
}

//:FUNCTION set_exit_check
//Function setting the check funciton for the exit
void set_exit_check(string direction, function f)
{
  object which=present(direction);
  if(which && which->is_exit())
  {
    which->set_method_check("go",f);
    return;
  }
  exits[direction]->checks = f;
}

/*
* EXIT ADDITION AND REMOVAL
*/

//:FUNCTION delete_exit
//Remove a single exit from the room. The direction should be an exit
//name.
void delete_exit(mixed direction)
{
  object which=present(direction);
  if(which && which->is_exit())
    destruct(which);
  map_delete(exits, direction);
}
 
//:FUNCTION add_exit
//Add an exit to the object with a destination. .
//Add the value should be a filename or a more complex structure as
//described in the exits doc.
 void add_exit(mixed direction, mixed destination)
{
#ifdef USE_COMPLEX_EXITS
  object exit_ob=new(COMPLEX_EXIT_OBJ);
  exit_ob->add_method(direction,destination);
  return;
#else
  move_data new_exit=move_data();
  new_exit->description=d_default_desc;
  new_exit->enter_messages=({});
  new_exit->exit_messages=({});
  new_exit->destination=destination;
  if (stringp(destination) && strlen(destination) == 0)
    error("Bogus exit passed into add_exit");
  if (stringp(destination) && destination[0] == '#')
    new_exit->checks = destination[1..];
  else
    new_exit->checks = 1;
  exits[direction] = new_exit;
#endif
}

//:FUNCTION set_exits
//Sets the exit mapping of a room. The keys should be exit names, the values
//should be either filenames or more complex structures described in the
//exits doc
void set_exits( mapping new_exits )
{
  
  if ( mappingp(new_exits) )
    foreach(new_exits;string direction;mixed destination)
      add_exit(direction,destination);
}

/*
* HIDDEN EXITS
*/

//:FUNCTION set_hidden_exits
//This is the list of exits to NOT be shown to the mortals in the room.
//If "all" is any of the arguements in exits_list all exits for the object
//will be marked as hidden regardless to the rest of the arguments.
void set_hidden_exits( string ... exits_list)
{
  if(member_array("all",exits_list)>-1)
    hidden_exits=keys(exits);
  else
    hidden_exits = exits_list;
}

//:FUNCTION add_hidden_exit
//Make a given exit direction a hidden exit. See set_hidden_exits
void add_hidden_exit( string ... exits_list )
{
  if( sizeof( exits_list ) == 1 && exits_list[0] == "all" )
    hidden_exits = query_exit_directions(1);
  else
    hidden_exits += exits_list;
}

//:FUNCTION remove_hidden_exit
//Make a given exit direction no longer a hidden exit. See set_hidden_exits
void remove_hidden_exit( string ... exits_list)
{
  if( sizeof( exits_list ) == 1 && exits_list[0] == "all" )
    hidden_exits = 0;
  else
    hidden_exits -= exits_list;
}

private int f_is_hidden_exit(mixed ob) 
{
	return ob->is_exit() && ob->query_hidden() ? 1 : 0;
}

array(string) query_hidden_exits() 
{
  array(object) exit_obs = filter(all_inventory(this_object()), f_is_hidden_exit);
  
  return hidden_exits + exit_obs->query_direction();
}


mixed can_go_str(string arg)
{
  mixed ret=(query_exit_check(arg))();
  if(!stringp(ret) && ret!=1 && is_normal_direction(arg))
    return query_default_error();
  return ret;
}


void do_go_str(string dir)
{
  move_data exit= move_data();
  if (call_hooks("block_" + dir, HOOK_LOR, 0, dir)
      || call_hooks("block_all", HOOK_LOR, 0, dir))
    return;
  exit->destination=query_exit_destination(dir);
  exit->exit_messages=query_exit_msg(dir);
  exit->enter_messages=query_enter_msg(dir);
  exit->exit_dir=dir;
  if (!this_body()->query_driving_vehicle())
  {
    if(!exit->exit_messages)
      exit->exit_messages=this_body()->query_msg("leave");
    if(!exit->enter_messages)
      exit->enter_messages=this_body()->query_msg("enter");
/* Normal movement, which should be the scope of this module should
* always send to the method "in" */
    exit->who = this_body();
    this_body()->move_to(exit);
  } else {
    exit->who = environment(this_body());
    environment(this_body())->move_to(exit);
  }
}
/*
* DEBUGGING
*/
//:FUNCTION debug_exits
//Return all of the exit info contained within the object
mapping debug_exits()
{
  return copy(exits);
}

//:FUNCTION query_base
//Return the evaluated string which is the directory the object is in.
string query_base()
{
  return base();
}

//:FUNCTION set_base
//Set the base directory to be used by the exits of the environment.
void set_base(mixed what)
{
  base=what;
}

private mixed f_set_enter_message(string arg1, string arg2) {
	
	return ({ "setup", "set_enter_msg(\""+arg1+"\",\""+arg2[0]+"\")" }); 
}

private mixed f_set_exit_message(string arg1, string arg2) 
{
    return ({ "setup", "set_exit_msg(\""+arg1+"\",\""+arg2[0]+"\")" }); 
}


private mixed f_set_exit_description(string arg1, string arg2) {
	return ({ "setup", "set_exit_description(\""+arg1+"\",\""+arg2[0]+"\")" });
}

mapping lpscript_attributes() {
  return (["exits" : ({ LPSCRIPT_MAPPING, "setup", "set_exits" }),
"hidden_exits" : ({ LPSCRIPT_LIST, "setup", "set_hidden_exits" }),
"default_exit_message" : ({ LPSCRIPT_STRING, "setup", "set_default_exit_message" }),
"default_enter_message" : ({ LPSCRIPT_STRING, "setup", "set_default_enter_message" }),
"wrong_exit" : ({ LPSCRIPT_STRING, "setup", "set_default_error"}),
"enter_msg" : ({ LPSCRIPT_TWO,  f_set_enter_message}),
"exit_msg" : ({ LPSCRIPT_TWO, f_set_exit_message }),
"exit_description" : ({ LPSCRIPT_TWO, f_set_exit_description }),
]);
}