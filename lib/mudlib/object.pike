
#include "/includes/mudlib.h"
#include "/includes/mudlib/lpscript.h"
#include "/includes/mudlib/flags.h"
#include "/includes/clean_up.h"

inherit BASE_OBJ;

inherit __DIR__ "/object/m_light.pike";
inherit __DIR__ "/object/m_properties.pike";
inherit __DIR__ "/object/m_move.pike";
inherit __DIR__ "/object/m_visible.pike";
inherit __DIR__ "/object/m_hooks.pike";
inherit __DIR__ "/object/m_msg_recipient.pike";

mapping _lpscript_attributes;

//:FUNCTION stat_me
//return some debugging info about the state of the object
string stat_me()
{
  string result = ::stat_me() +
    "Short: "+short()+"\n";
  return result;
}


void setup(mixed ... args)
{

}

void mudlib_setup(mixed ... args)
{

}

final void object_create(mixed ... args) {
  base_obj_create();
  configure_set(STD_FLAGS, 0, resync_visibility);

  if ( clonep(this_object()) )
  {
    mudlib_setup(@args);

    if (functionp(this_object()->internal_setup)) {
        this_object()->internal_setup(@args);
    }

    setup(@args);
  }	
}

void create(mixed ... args)
{
    object_create(@args);
}


mixed call_hooks( mixed ... args)
{
    return hooks_call_hooks(@args);
}

int is_visible()
{
  return visible_is_visible();
}

void set_light(int x)
{
    light_set_light(x);
}

int allow(string what)
{
      return 1;
}

int destruct_if_useless() 
{
    destruct(this_object());
}


int clean_up(int instances)
{
    if ( environment() ) {
        return NEVER_AGAIN;
    }


  if(base_name(this_object())[0..1] != "/d") {
    return NEVER_AGAIN;
  }
  if(sizeof(children(base_name(this_object())))>1) {
    return ASK_AGAIN;
  }

  return destruct_if_useless();
}

void on_clone( mixed ... args)
{
}

void set_lpscript_attributes(mapping attributes)
{
#ifdef LPSCRIPT_D	
  if(base_name(previous_object())!=LPSCRIPT_D)
    error("Access violation: Illegal attempt to set_lpscript_attributes");
#endif    
      _lpscript_attributes=attributes;
}

array(string) list_lpscript_attributes()
{
  return copy(keys(_lpscript_attributes));
}

mapping dump_lpscript_attributes()
{
  return copy(_lpscript_attributes);
}
mapping lpscript_attributes() {
  return ([
    "adj" : ({ LPSCRIPT_LIST, "setup", "add_adj" }),
    "id" : ({ LPSCRIPT_LIST, "setup", "add_id" }),
    "primary_adj" : ({ LPSCRIPT_STRING, "setup", "set_adj" }),
    "primary_id" : ({ LPSCRIPT_STRING, "setup", "set_id" }),
    "in_room_desc" : ({ LPSCRIPT_STRING, "setup", "set_in_room_desc" }),
    "long" : ({ LPSCRIPT_STRING, "setup", "set_long" }),
    "flag" : ({ LPSCRIPT_FLAGS }),
    "light" : ({ LPSCRIPT_INT, "setup", "set_light" }),
#ifdef USE_MASS
    "mass" : ({ LPSCRIPT_INT, "setup", "set_mass" }),
    "weight" : ({ LPSCRIPT_INT, "setup", "set_mass" }),
#else
      "mass" : ({ LPSCRIPT_INT, "setup", "set_size" }),
      "weight" : ({ LPSCRIPT_INT, "setup", "set_size" }),
#endif
    ]);
}