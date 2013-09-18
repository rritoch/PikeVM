/* Do not remove the headers from this file! see /USAGE for more info. */

#include "/includes/mudlib.h"
#include "/includes/mudlib/lpscript.h"
#include "/includes/log.h"

inherit CONTAINER;
inherit __DIR__ "/living/grammar.pike";
inherit __DIR__ "/living/messages.pike";
inherit __DIR__ "/living/misc.pike";
inherit __DIR__ "/living/effects.pike";

/* This is a pure 'living' object, not what is traditionally meant
* by a living object on LPmuds. Note that find_living() won't
* necessarily find it b/c the driver may not even know it's
* alive. (Why the driver keeps track of livings is beyond me ...)
* [ed note: it doesn't any more; find_living() doesn't exist]
* This is an object than can hold things and do actions. If you
* want it to be able to fight, inherit MONSTER instead.
*/

private string name;


void create()
{
  add_relation("on",100);
  set_default_relation("on");
  set_def_msgs("living-default");
  ::create();
}

string query_name() {	
    return name; 
}

void set_name(string n)
{
  string lc = lower_case(n);
  if (name)
    remove_id(lc);
  name = n;  
  add_id_no_plural(lower_case(n));
}

string in_room_desc() 
{ 
    return query_in_room_desc(); 
}

string introduce_contents()
{ 
    return capitalize(query_subjective()) + " is carrying:\n"; 
}

string invis_name() 
{ 
    return "someone"; 
}

int is_living() 
{ 
    return 1; 
}

string diagnose() 
{ 
    return "$N $vare in perfect health.\n"; 
}

mixed direct_cross_obj(object ob) 
{
    return "I don't think " + ob->the_short() + " would appreciate that.\n";
}

mixed indirect_give_obj_to_liv(object ob, object liv) 
{
    return capitalize(liv->the_short()) + " politely refuses.\n";
}

mixed direct_get_obj(object ob) 
{
    if (ob == this_body()) {
        return "#You find your presence uplifting.\n";
    }

    return "#I can't do everything. If you want to pick up someone, try using your social skills.\n";
}

mixed direct_whisper_liv_str() 
{ 
    return 1; 
}

mixed direct_whisper_str_to_liv() 
{ 
    return 1; 
}

mixed direct_whisper_to_liv_str() 
{ 
    return 1; 
}

mapping lpscript_attributes()
{
  return ([
    "name" : ({ LPSCRIPT_STRING, "setup", "set_name" }),
    "proper_name" : ({ LPSCRIPT_STRING, "setup", "set_proper_name" }),
    "gender" : ({ LPSCRIPT_GENDER }),
    ]);
}

string look_in( string relation )
{

    if( relation == "in" ) {
        return "With your X-Ray vision?";
    } else {
        return ::look_in( relation );
    }
}
