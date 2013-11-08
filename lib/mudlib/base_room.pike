
#include "/includes/mudlib/setbit.h"
#include "/includes/mudlib/move.h"
#include "/includes/mudlib/hooks.h"
#include "/includes/mudlib/lpscript.h"

inherit CONTAINER;
inherit M_ITEMS;
inherit M_GETTABLE;
inherit M_EXIT;

inherit __DIR__ "/room/roomdesc.pike";
inherit __DIR__ "/room/state.pike";


private  array(string) area_names = ({ });
private string listen, smell;
private  mixed chat_msg;
private  int chat_period = 15;
private  int tag;

//:FUNCTION stat_me
//Returns some debugging info about the object. Shows the container info,
//as well as the short and exits.
string stat_me()
{
    return sprintf("Room: %s [ %s ]\n\n",
      short(), implode(query_exit_directions(1), ", ")) +
      container_stat_me();
}

//:FUNCTION set_brief
//Set the name of the room seen at the top of the description and in brief mode
void set_brief(string str) {
    set_proper_name(str);
}

//:FUNCTION can_hold_water
//Return 1 if the object can hold water.
/* by default, rooms can hold water */
int can_hold_water()
{
    return 1;
}

void create(mixed ... args)
{

   //name_create();
   #"object/m_name"::create();
   
   
#if 0
if( !clonep() )
{
#endif
// initialize the mudlib (default) stuff, then the area coder's
mudlib_setup();

if (functionp(this_object()->internal_setup)) {
    this_object()->internal_setup();
}

setup(@args);
#if 0
}
#endif
}

void mudlib_setup()
{
    ::mudlib_setup();
    set_light(DEFAULT_LIGHT_LEVEL);
    /* First add the relation 'in'. */
    add_relation("in",1000000);
    /* Make it the default relation for all rooms */
    set_default_relation("in");
    add_id_no_plural("here");
    add_id("environment");
    set_gettable( -1 );
    set_flag( ATTACHED );
}

//:FUNCTION set_area
//Used by m_wander to prevent monsters from wandering to far.
//Can either be a string, or an array of strings
void set_area(string ... names)
{
    area_names = names;
}

//:FUNCTION query_area
//Find out what 'areas' the room belongs to. See set_area.
array(string) query_area()
{
    return area_names;
}

string query_name()
{
    return "the ground";
}

string get_brief()
{
    return short();
}

void possible_light_change(int old_light, int new_light) {
    if (old_light && !new_light) {
tell_from_inside(this_object(), "The room goes dark.\n");
    } else
    if (!old_light && new_light) {
tell_from_inside(this_object(), "You can see again.\n");
    }
}

void set_light(int x) {
    int old = query_light();

    ::set_light(x);

    possible_light_change(old, query_light());
}

void adjust_light(int x) {
    int old = query_light();

    ::adjust_light(x);

    possible_light_change(old, query_light());
}

mixed direct_get_obj(object ob)
{
    if( this_object() == environment( this_body()))
return "#A surreal idea.";
    return ::direct_get_obj(ob);
}

private mixed f_set_state_description(mixed arg1, mixed arg2) {
    return ({ "setup", "set_state_description(\"" + arg1 + "\", \"" + arg2[0] + "\")" }) ;
}

private mixed f_add_item(mixed arg1) {
	return ({ "setup", "add_item(\"" + arg1[0] + "\", \"" + implode(arg1[1..], " ") + "\")" }) ;
}
mapping lpscript_attributes() {
    return ([
      "area" : ({ LPSCRIPT_STRING, "setup", "set_area" }),
      "brief" : ({ LPSCRIPT_STRING, "setup", "set_brief" }),
      "exits" : ({ LPSCRIPT_MAPPING, "setup", "set_exits" }),
      "state" : ({ LPSCRIPT_TWO,  f_set_state_description}),
      "item" : ({ LPSCRIPT_SPECIAL, f_add_item })
    ]);
}

/* tweak the base long description to add the state stuff */
string get_base_long()
{
    string base = ::get_base_long();
    array fmt;
    int i;
    
    fmt = reg_assoc(base, ({ "\\$[A-Za-z_]*" }), ({ 1 }))[0];

    for (i = 1; i < sizeof(fmt); i++) {
string tmp;

if (tmp = query_state_desc(fmt[i][1..]))
fmt[i] = tmp;
    }

    base = implode(fmt, "");
    if (base[-1] != '\n') base += "\n";
    return base;
}


string long()
{
#ifdef OBVIOUS_EXITS_BOTTOM
    string objtally = show_objects();
    if( sizeof(objtally))
objtally = "You also see:\n" + objtally;
    return sprintf("%sObvious Exits: %%^ROOM_EXIT%%^%s%%^RESET%%^\n%s",
      (dont_show_long() ? "" : simple_long()),
      show_exits(),
      objtally);
#else
    return sprintf("%s%s",
      (dont_show_long() ? "" : simple_long()),
      show_objects());
#endif
}

//:FUNCTION long_without_object
//This is used by things like furniture, so the furniture can use the
//same long as the room, but not see itself in the description.
string long_without_object(object o)
{
#ifdef OBVIOUS_EXITS_BOTTOM
    return sprintf("%sObvious Exits: %%^ROOM_EXIT%%^%s%%^RESET%%^\n%s",
      simple_long(),
      show_exits(),
      show_objects(o));
#else
    return sprintf("%s%s",
      simple_long(),
      show_objects(o));
#endif
}

void set_listen(string str) { listen = str; }

string query_listen() { return listen; }

void set_smell(string str) { smell = str; }

string query_smell() { return smell; }

void do_listen()
{
  if(listen)
    write(listen);
  else
    write( "You hear nothing unusual.\n" );
}

void do_pray() { write( "Nothing special happens.\n" ); }

void do_smell()
{
  if(smell)
    write(smell);
  else
    write( "You smell nothing unusual.\n" );
}

private mixed f_query_link(mixed ob) {
    return ob->query_link();
}	

int listeners()
{
    array(object) inv = all_inventory(this_object());
    return sizeof(filter(inv, f_query_link ) );
}

void check_anybody_here()
{
  if(listeners())
  {
    tag = call_out(room_chat, chat_period, chat_msg);
  } else {
    remove_call_out(tag);
    tag = 0;
  }
}

void room_chat()
{
  if(stringp(chat_msg))
    tell_from_outside(this_object(), chat_msg + "\n");
  else if(arrayp(chat_msg))
    tell_from_outside(this_object(), choice(chat_msg) + "\n");
  else if(functionp(chat_msg))
    tell_from_outside(this_object(),chat_msg() + "\n");
  check_anybody_here();
}

void departure(object who)
{
  call_out(check_anybody_here,0);
}

void arrival(object who)
{
  if(!listeners())
    tag = call_out(room_chat, chat_period, chat_msg);
}

void set_room_chat(mixed chat, int interval)
{
  chat_msg = chat;
  chat_period = interval;

  add_hook("object_arrived", arrival  );
  add_hook("object_left", departure );

  if(tag)
  {
    remove_call_out(tag);
    tag = 0;
  }

  call_out(check_anybody_here,0);
}

