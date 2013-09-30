
#include "/includes/security.h"
#include "/includes/clean_up.h"
#include "/includes/commands.h"
#include "/includes/mudlib/move.h"
#include "/includes/mudlib/size.h"
#include "/includes/mudlib/flags.h"
#include "/includes/mudlib/msgtypes.h"

inherit LIVING;

inherit __DIR__ "/body/start.pike";
inherit __DIR__ "/body/cmd.pike";

private object link;
private mixed saved_items;

int is_body() 
{ 
    return 1; 
}

final object query_link()
{
    return link;
}

void mudlib_setup(mixed ... args)
{
}


protected void update_for_new_body(mapping tmp) 
{
    /* nothing for now; can be overloaded for races that need it */
}

private final void update_container(object ob)
{
	object inv;
  foreach(all_inventory(ob),inv)
  {
    if(inv->is_container())
      update_container(inv);
    ob->receive_object(inv);
  }
}

// Added to complete initialisation of stuff loaded
private final void init_stuff()
{
	object inv;
  foreach(all_inventory(),inv)
  {
#ifdef WIELD_SINGLE
    if(inv->test_flag(F_WIELDED))
      do_wield(inv);
#else
    if( inv->query_wielding() && sizeof(inv->query_wielding()) )
       this_object()->wield(inv, inv->query_wielding()[0]);
#endif
    if(inv->test_flag(F_WORN))
      inv->do_wear();
  }
  update_container(this_object());  
}

/* initialize various internal things */
//### needs a new name
private final void init_cmd_hook()
{
    link = previous_object();
    //naming_init_ids();

#ifdef USE_MASS
    set_mass(100);
#endif
#ifdef USE_SIZE
    set_size(VERY_LARGE);
#endif
    set_max_capacity(VERY_LARGE);

    if (saved_items) {
//string e;

/*
if (e = catch(load_from_string(saved_items, 1))) {
mapping tmp = restore_variable(saved_items);

if (tmp["#base_name#"] != base_name(this_object())) {
update_for_new_body(tmp);
tmp["#base_name#"] = base_name(this_object());
load_from_string(save_variable(tmp), 1);
} else
error("Rethrown: " + e);
}
*/

saved_items = 0;
    }
  init_stuff();
}

final void su_enter_game(object where)
{
    init_cmd_hook();
    move(where);
}

void enter_game(int state)
{
    switch (state) {
    case 1:

/* FALLTHROUGH */
    case 0:
/* existing user */
init_cmd_hook();
CHANNEL_D->deliver_emote("announce", query_name(),
sprintf("enters %s.", mud_name()));
/* move the body. make sure this comes before the simple_action */
if ( !move_to_start() ) {
write("Uh-oh, you have no environment.\n");
} else {
/* we don't want other people to get the extra newlines */
write("\n");
if(is_visible())
simple_action("$N $venter "+mud_name()+".");
write("\n");
}
/* FALLTHROUGH */
    case 2:
//do_game_command("look");
//update_health();
    }
}

//:FUNCTION save_me
//Saves us :-)
void save_me()
{
    object shell_ob = link && link->query_shell_ob();
    //string userid = query_userid();

    /* save the shell information */
    if ( shell_ob )
shell_ob->save_me();

    //### This check is bogus. What should it be?
    // This check also doesn't work for su's -- John
    // if (previous_object()==this_object())
    //saved_items = save_to_string(1); // 1 meaning it is recursive.

    //unguarded( 1, (: save_object , USER_PATH(userid) :) );    
    saved_items = 0;
}

//:FUNCTION remove
//Handle mailboxes and the last login daemon, as well as the normal stuff
void remove()
{
    //object ob;

    if ( !clonep() )
    {
::remove();
return;
    }

#ifdef PLAYERS_START_WHERE_THEY_QUIT
    if (environment() && !adminp(link))
set_start_location(file_name(environment()));
#endif

    save_me();

#ifdef LAST_LOGIN_D
    LAST_LOGIN_D->register_last(query_userid());
#endif
#ifdef SNOOP_D    
    SNOOP_D->bye();
#endif    
    ::remove();
}

//### This should be protected.
//:FUNCTION quit
//Quit the game.
void quit()
{
    if ( !clonep() )
    {
::remove();
return;
    }

    if (is_visible())
simple_action("$N $vhave left "+mud_name()+".");

    CHANNEL_D->deliver_emote("announce", query_name(),
      sprintf("has left %s.", mud_name()));


    remove();
}

void catch_tell(string msg) 
{
	do_receive(msg,PRIVATE_MSG);
}

void do_receive(string msg, int msg_type) {
    if ( link )
link->do_receive(msg, msg_type);
}


//:FUNCTION net_dead
//This function is called when we lose our link
void net_dead()
{
    //### add security here?

    if ( is_visible() )
simple_action("$N $vhave gone link-dead.");

    CHANNEL_D->deliver_emote("announce", query_name(),
      sprintf("has gone link-dead."));
#ifdef SNOOP_D
    SNOOP_D->bye(this_object());
#endif    
}

void reconnect(object new_link)
{

    link = new_link;
    if(is_visible()) {
        simple_action("$N $vhave reconnected.");
    }

    CHANNEL_D->deliver_emote("announce", query_name(),
      sprintf("has reconnected."));
}

protected void die()
{
    if ( adminp(link) )
    {
        if(is_visible()) {
            simple_action("If $n $vwere mortal, $n would now no longer be mortal.");
        }      
        //call_out(reincarnate, 1);
        return;
    }
    
    if(is_visible())
simple_action("$N $vhave kicked the bucket, and $vare now pushing up the daisies.");

/*
    receive_private_msg("\n\n **** You have died ****\n\n"
      "A pity, really. Way too many people dying these days for me to just patch\n"
      "everyone up. Oh well, you'll live.\n",0,0);
  */    
    //rack_up_a_death();
    //drop_corpse();

#ifdef DEATH_MESSAGES
    {
// another option is to choose the message here based on player level
// or something, instead of just letting action() pick at random.
// something like:
// action(({ this_object()}),
// (MESSAGES_D->get_messages("player_death"))[query_level()/5])[1];
string msg = action(({this_object()}),
MESSAGES_D->get_messages("player-death"))[1];
tell( bodies() - ({ this_body() }), msg );
    }
#endif
}

int clean_up() {
    return NEVER_AGAIN;
}

//:FUNCTION id
//id(s) returns 1 if we respond to the name 's'
/*
int id(string arg)
{

    if(!is_visible() && arg == lower_case(query_invis_name()))
return 1;

    return ::id(arg);
}
*/

string stat_me()
{
    string result = short() + "\n" +
    //"Userid: " + query_userid() + "\n" +
    ::stat_me();

    if ( link )
result += link->stat_me();

    return result;
}

void create(string userid)
{
	/*
    if ( !clonep() )
return;
*/

/*
    if ( base_name(previous_object()) != USER_OB )
error("security violation: illegal attempt to change name\n");
*/
    messages = ([]);

    

    /*
** Make some of the flags non-persistent (they won't be saved).
*/
    configure_set(PLAYER_NP_FLAGS, 1);

    //set_long( our_description );
    set_name(userid);

    //unguarded(1, (: restore_object, USER_PATH(userid), 1 :));

    // up to the player
    //set_attack_speed(0);
    
    ::create();
}

//### temp hack. be both user and body
final object query_body()
{
    return this_object();
}


/* verb interaction */
mixed indirect_give_obj_to_liv(object ob, object liv) {
    if( previous_object() == liv && ob->is_in( liv ))
return "You already have that.";
    return 1;
}

string inventory_header()
{
    return query_name() + " is carrying:\n";
}

int ob_state()
{
    return -1;
}


void force_look(int force_long_desc)
{
    environment(this_object())->do_looking(force_long_desc, this_object());
}

void move_or_destruct(object suggested_dest) {
    mixed err;
    object dested_env = environment();
    mixed destination;
    
    if ( !query_link() ) {
        return;
    }
    
    foreach (({ suggested_dest, VOID_ROOM, this_body()->query_start_location(), START, WIZARD_START }),destination) {
err = catch {
if (stringp(destination))
destination = load_object(destination);
if (destination != dested_env) {
err = move(destination);
if (stringp(err))
throw(err);
} else
throw("Being destructed.\n");
};
if (destination && !err) {
//receive_private_msg(dested_env->short() + " being destructed: You have been moved to " + destination->short() + ".\n");
return;
} else {
	/*
if (destination)
receive_private_msg("Cannot move to " + destination->short() + ": " + err);
*/
}
    }
  //  receive_private_msg("Uh oh..., couldn't move you anywhere. Goodbye.\n");
    (this_object()->query_link())->remove();
}


string living_query_name() {
    return ::query_name();
}

/*
string query_name()
{
    return naming::adjust_name(::query_name());
}
*/

string short() 
{ 
    return query_name(); 
}

string a_short() 
{ 
   return query_name(); 
}

string the_short() 
{ 
    return query_name(); 
}

string in_room_desc() 
{ 
    //return base_in_room_desc() + query_idle_string();
    return ""; 
}


int allow(string what)
{
    return this_body() == this_object() ? 1 : 0;
}

