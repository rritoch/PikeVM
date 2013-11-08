
#include "/includes/daemons.h"
#include "/includes/mudlib/move.h"
#include "/includes/mudlib/setbit.h"
#include "/includes/mudlib/hooks.h"
#include "/includes/mudlib/size.h"
#include "/includes/mudlib/lpscript.h"
#include "/includes/clean_up.h"


/*
* INHERIT
*/
inherit OBJ : m_obj;

//inherit "/std/container/vsupport";


class relation_data
{
  array(object) contents;
  int max_capacity;
  int hidden;
  int attached;

  mixed hidden_func;
  mapping create_on_reset; 
  mapping create_unique_on_reset;
}


private mapping relations = ([ ]);
private mapping relation_aliases=([]);
private string default_relation; 

int contained_light;
int contained_light_added;
mixed all_hidden_func;
 string introduce_contents(string relation);


string simple_long();
int inventory_visible();

private final int valid_relation(string relation)
{
  relation=PREPOSITION_D->translate_preposition(relation);
  if(member_array(relation,keys(relations))==-1)
    return 0;
  return 1;
}


string|int query_relation(object ob)
{
    string test;
    relation_data values;
    
    foreach(indices(relations),test) {
    	values = relations[test];
        if (member_array(ob,values->contents)>-1) {
            return test;
        }
    }
    return 0;
}

//:FUNCTION add_relation
//Add a relation to the complex container.
 void add_relation(string relation,int max_capacity,int|void hidden)
{
  relation_data new_relation=relation_data();
  relation=PREPOSITION_D->translate_preposition(relation);
  new_relation->max_capacity=max_capacity;
  new_relation->hidden=hidden;
  new_relation->contents=({});
  new_relation->create_on_reset=([]);
  new_relation->create_unique_on_reset=([]);
  relations[relation]=new_relation;
}

//:FUNCTION remove_relations
//Remove relations from an object. Relations can only successfully be removed
//if they are unoccupied.
void remove_relations(string ... rels)
{
    string rel;
    
  foreach(rels,rel)
  {
    rel=PREPOSITION_D->translate_preposition(rel);
    if(sizeof(relations[rel]->contents))
      continue;
    map_delete(relations,rel);
  }
}

void set_relations(string ... rels)
{
    string rel;
    remove_relations(@rels);
  foreach(rels,rel) {
      add_relation(rel,VERY_LARGE);
  }
}


array(string)  get_relations()
{ 
	return indices(relations); 
}


string|int is_relation_alias(string test)
{
    string relation;
    mixed aliases;
    foreach(indices(relation_aliases),relation) {
    	aliases = relation_aliases[relation];
  
    if(member_array(test,aliases)>-1) {
      return relation;
    }
  }
  return 0;
}

void set_relation_alias(string relation,string ... aliases)
{
  string aliased_to;
  relation=PREPOSITION_D->translate_preposition(relation);
  aliased_to=is_relation_alias(relation);
  if(!valid_relation(relation))
  {
    if(!aliased_to)
      error("Cannot set a relation alias to a nonexistant relation");
    relation=aliased_to;
  }
  relation_aliases[relation]=flatten_array(aliases);
}


void add_relation_alias(string relation,string ... aliases)
{
  string aliased_to;
  relation=PREPOSITION_D->translate_preposition(relation);
  aliased_to=is_relation_alias(relation);
  if(!valid_relation(relation))
  {
    if(!aliased_to)
      error("Cannot add a relation alias to a nonexistant relation");
    relation=aliased_to;
  }
  if(!sizeof(relation_aliases[relation]))
    set_relation_alias(relation,@aliases);
  else
    relation_aliases[relation]=flatten_array(relation_aliases[relation]+aliases);
}


void remove_relation_alias(string relation,string ... aliases)
{
  relation_aliases[relation]-=aliases;
  if(!sizeof(relation_aliases))
    map_delete(relation_aliases,relation);
}

array(string) query_relation_aliases(string relation)
{
  return relation_aliases[relation];
}

//:FUNCTION list_relation_aliases
//List all of the relation alias information
mapping list_relation_aliases()
{
  return relation_aliases;
}

//:FUNCTION set_default_relation
//Sets the default relation for the container. This relation is used if no
//relation is specified on many functions
void set_default_relation(string set)
{
  string aliased_to;
  set=PREPOSITION_D->translate_preposition(set);
  aliased_to=is_relation_alias(set);
  if(!valid_relation(set))
  {
    if(!aliased_to)
      error("Cannot set a nonexistant relation as default");
    default_relation=aliased_to;
  }
  default_relation=set;
}


string query_default_relation()
{ 
	return default_relation; 
}


 int query_capacity(string relation)
{
	object ob;
  int cap;
  string aliased_to;
/* Need a little special handling for #CLONE# */
  if(!relation||relation==""||relation=="#CLONE#")
    relation=query_default_relation();
  relation=PREPOSITION_D->translate_preposition(relation);
  aliased_to=is_relation_alias(relation);
  if(!valid_relation(relation))
  {
    if(!aliased_to)
      return 0;
    relation=aliased_to;
  }
  foreach(relations[relation]->contents,ob)
  {
    if(!ob)
    {
      relations[relation]->contents-=({ob});
      continue;
    }
#ifdef USE_SIZE
    cap+=ob->query_size();
#else
    //cap+=ob->query_mass();
    cap += 10;
#endif
  }
  return cap;
}


void set_max_capacity(int|void cap, string|void relation)
{
    string aliased_to;
    if(!relation||relation=="") {
        relation=query_default_relation();
    }
    
    relation=PREPOSITION_D->translate_preposition(relation);
    aliased_to = is_relation_alias(relation);
    if(!valid_relation(relation))
    {
        if(!aliased_to) {
            error("Invalid relation");
        }
        relation=aliased_to;
    }
    relations[relation]->max_capacity=cap;
}

//:FUNCTION query_max_capacity
//Returns the maximum capacity for a given relation
 int query_max_capacity(string relation)
{
    string aliased_to;
    if(!relation||relation=="")
relation=query_default_relation();
    relation=PREPOSITION_D->translate_preposition(relation);
    aliased_to=is_relation_alias(relation);
    if(!valid_relation(relation))
    {
if(!aliased_to)
return 0;
relation=aliased_to;
    }
    return relations[relation]->max_capacity;
}

//### Yo! finish this -- Tigran
//:FUNCTION query_total_capacity
//Returns the capacity directly attributed to the container. This should
//normally include anything attached or within the container.
int query_total_capacity()
{

}
#ifdef USE_MASS
//:FUNCTION query_mass
int query_mass()
{
    return query_total_capacity() + ::query_mass();
}
#endif

#ifdef USE_SIZE
int query_aggregate_size()
{
    return query_total_capacity() + ::query_size();
}
#endif


//:FUNCTION receive_object
//Determine whether we will accept having an object moved into us;
//returns a value from <move.h> if there is an error
mixed receive_object( object target, string relation )
{
    int x, m;
    string aliased_to;
    if(!relation||relation==""||relation=="#CLONE#")
relation=query_default_relation();
    relation=PREPOSITION_D->translate_preposition(relation);
    aliased_to=is_relation_alias(relation);
    if( target == this_object() )
return "You can't move an object inside itself.\n";

    /* Have to be a bit stricter here to keep relations[] sane */
    if (!valid_relation(relation))
    {
if(!aliased_to)
return "You can't put things " + relation + " that.\n";
relation=aliased_to;
    }

    x = 1;
#ifdef USE_SIZE
    x = target->query_size();
#else
    if (functionp(target->query_mass)) {
        x=target->query_mass();
    }    
#endif

    if ( (m=(query_capacity(relation))+x) > query_max_capacity(relation) )
    {
return MOVE_NO_ROOM;
    }
    relations[relation]->contents += ({ target });
    return 1;
}

//:FUNCTION release_object
//Prepare for an object to be moved out of us; the object isn't allowed
//to leave if we return zero or a string (error message)
 mixed release_object( object target, int force )
{
    string relation;
    if(!target||force)
return 1;
    relation=query_relation(target);
    if(!relation&&!force)
return 0;
    relations[relation]->contents-=({target});
    return 1;
}


void reinsert_object( object target, string relation )
{
    if(!relation)
relation = query_default_relation();
    relations[relation]->contents += ({ target });
}


/******** Descriptions ********/

string long()
{
  string res;
  string contents;
  string rel;
  relation_data data;
  
  res = simple_long();
  if (!inventory_visible())
    return res;

  foreach(indices(relations),rel) {
  	    data = relations[rel];
    contents = inv_list(data->contents, 1);
    if (contents)
    {
res += introduce_contents(rel) + contents;
    }
  }
  return res;
}

//:FUNCTION look_in
//returns a string containing the result of looking inside (or optionally
//a different relation) of the object
string look_in( string relation )
{
    string inv;
    mixed ex;
    string aliased_to;
    if(!relation||relation=="")
relation=query_default_relation();
    relation=PREPOSITION_D->translate_preposition(relation);
    aliased_to=is_relation_alias(relation);
    // if (!relation) relation = query_prep();

    //:HOOK prevent_look
    //A set of yes/no/error hooks which can prevent looking <relation> OBJ
    //The actual hook is prevent_look_<relation>, so to prevent looking
    //in something use prevent_look_in.
    ex = call_hooks("prevent_look_" + relation, HOOK_YES_NO_ERROR);
    if(!ex)
ex = call_hooks("prevent_look_all", HOOK_YES_NO_ERROR);
    if (!ex) ex = "That doesn't seem possible.";
    if (stringp(ex))
return ex;

    if (!valid_relation(relation))
    {
if(!aliased_to)
return "There is nothing there.\n";
relation=aliased_to;
    }

    inv = inv_list(relations[relation]->contents);
    if ( !inv )
inv = " nothing";

    return (sprintf( "%s %s you see: \n%s\n",
capitalize(relation),
short(),
inv ));
}

array(object) filter_clones(array(object) obs) {
	
	array(object) ret = ({});
	object ob;
	foreach(obs,ob) {
		if (clonep(ob)) {
			ret += ({ ob });
		}
	}
	return ret;
}

 void set_hide_contents( mixed hide, string relation )
{
    string aliased_to;
    if(hide)
    {
if(!relation)
{
all_hidden_func=hide;
add_hook( "prevent_look_all", all_hidden_func );
}
else
{
relation=PREPOSITION_D->translate_preposition(relation);
aliased_to=is_relation_alias(relation);
if(!valid_relation(relation))
{
if(!aliased_to)
error("Attempted to hide contents of a container with a "
"nonexistant relation.");
relation=aliased_to;
}
relations[relation]->hidden_func=hide;
add_hook ("prevent_look_"+relation,relations[relation]->hidden_func);
}
    }
    else
    {
if(!relation)
{
remove_hook( "prevent_look_all", all_hidden_func );
all_hidden_func=0;
}
relation=PREPOSITION_D->translate_preposition(relation);
if(!valid_relation(relation))
{
if(!aliased_to)
error("Attempted to unhide contents of a container with a nonexistant "
"relation");
relation=aliased_to;
}
remove_hook( "prevent_look_"+relation, relations[relation]->hidden_func );
relations[relation]->hidden_func=0;
    }
}

mixed query_hide_contents(string relation)
{
    string aliased_to;
    if(!relation)
return all_hidden_func;
    relation=PREPOSITION_D->translate_preposition(relation);
    aliased_to=is_relation_alias(relation);
    if(!valid_relation(relation))
    {
if(!aliased_to)
return 0;
relation=aliased_to;
    }
    return relations[relation]->hidden_func;
}


//:FUNCTION simple_long
//Return the long description without the inventory list.
string simple_long() {
    return ::long();
}


//:FUNCTION ob_state
//Determine whether an object should be grouped with other objects of the
//same kind as it. -1 is unique, otherwise if objects will be grouped
//according to the return value of the function.
mixed ob_state() {
    /* if we have an inventory, and it can be seen, we should be unique */
    if (first_inventory(this_object()) && inventory_visible()) return -1;
    //### hack
    //if (this_object()->query_closed()) return "#closed#";
    return ::ob_state();
}


//:FUNCTION parent_environment_accessible
//Return 1 if the parser should include the outside world in its
//decisions, overloaded in non_room descendants
int parent_environment_accessible() {
    return 0;
}


/******** Inventory ********/


//:FUNCTION inventory_visible
//Return 1 if the contents of this object can be seen, zero otherwise
int inventory_visible()
{
    if ( !is_visible() )
return 0;

    //### this should go!! short() should never return 0
    if (!short()) return 0;

    if ( test_flag(TRANSPARENT) )
return 1;

    //return !this_object()->query_closed();
    return 1;
}

private array(mixed) match_cannonical_form(string file,array(object) check) {
	array(mixed) ret = ({});
	mixed k;
	foreach(check,k) {
		if (cannonical_form(k)==file) {
			ret += ({ check[k] });
		}
	}
	return ret;
}

/* Function which creates objects on reset if they are needed. */

array(mixed) make_objects_if_needed()
{
    array(mixed) objs = ({});
    string relation;
    string file;
    mixed parameters;
    
    relation_data object_data;
    
    foreach(indices(relations),relation) {
    	object_data = relations[relation];
/* Loop through each element of the mapping */
object_data->contents-=({0});
foreach(indices(object_data->create_on_reset),file) {
	
    parameters = object_data->create_on_reset[file];

int num=1;
array(mixed) rest=({});
array(object) matches=({});
/* Allow use of relative paths, relative to the container. */
file = absolute_path(file, this_object());
/* If the only parameter is an integer, it is the quantity of the
* object that needs to be in this relation */
if (intp(parameters))
num = parameters;
else
if (arrayp(parameters))
{
/* Check the first argument for an integer value, if it is
* then it is the quantity fo the object to be in the
* relation */
if(intp(parameters[0]))
{
num = parameters[0];
rest = parameters[1..];
}
/* Everything else is parameters passed to create() */
else
rest = parameters;
}
else
continue;
if(sizeof(object_data->contents))
{
matches=  match_cannonical_form(file,object_data->contents);
}
while(sizeof(matches)<num)
{
int ret;
program p = (program)absolute_path(file);
object ob = p(@rest);
if(!ob)
error("Couldn't find file '" + file + "' to clone!\n");
ret = ob->move(this_object(), "#CLONE#");
if ( ret != MOVE_OK )
error("Initial clone failed for '" + file +"': " + ret + "\n");
ob->on_clone(@rest);
matches+=({ob});
}
objs+=matches;
}
    }
    return objs;
}

array(mixed) make_unique_objects_if_needed()
{
    array(mixed) objs=({});

    string relation;
    relation_data object_data;
    string file;
    mixed parameters;
    

    /* Loop through each relation */
    foreach(indices(relations),relation) {
    	object_data = relations[relation];

foreach(indices(relations[relation]->create_unique_on_reset),file) {
    parameters = relations[relation]->create_unique_on_reset[file];
array(mixed) rest=({});
int num;
array(object) matches=({});
/* Allow use of relative paths, relative to the container. */
file = absolute_path(file, this_object());
/* If the only parameter is an integer, it is the quantity of the
* object that needs to be in this relation */
if (intp(parameters))
num = parameters;
else
if (arrayp(parameters))
{
/* Check the first argument for an integer value, if it is
* then it is the quantity for the object to be in the
* relation */
if(intp(parameters[0]))
{
num = parameters[0];
rest = parameters[1..];
}
/* Everything else is parameters passed to create() */
else
rest = parameters;
}
else
continue;
matches=children(file);
matches = filter_clones(matches);
/* Clone x of the object to catch it up to the number of objects
* requested by the mapping */
while(sizeof(matches)<num)
{
int ret;
program p = (program)absolute_path(file);
object ob = p(@rest);
if(!ob)
error("Couldn't find file '" + file + "' to clone!\n");
/* Test for uniqueness in the object by calling test_unique() */
if(ob->test_unique())
break;
ret = ob->move(this_object(), "#CLONE#");
if ( ret != MOVE_OK )
error("Initial clone failed for '" + file +"': " + ret + "\n");
ob->on_clone( @rest );
matches+=({ob});
}
objs+=matches;
}
    }
    return objs;
}

 array(mixed) set_objects(mapping m,string|void relation) {
    if(!relation||relation=="")
relation=query_default_relation();
    relation=PREPOSITION_D->translate_preposition(relation);
    relations[relation]->create_on_reset = m;
    return make_objects_if_needed();
}


 array(mixed) set_unique_objects(mapping m,string relation) {
    if(!relation||relation=="")
relation=query_default_relation();
    relation=PREPOSITION_D->translate_preposition(relation);
    relations[relation]->create_unique_on_reset = m;
    return make_unique_objects_if_needed();
}


 string introduce_contents(string relation)
{
  if(!relation||relation=="")
    relation=query_default_relation();
  relation=PREPOSITION_D->translate_preposition(relation);
  switch (relation)
  {
    case "in":
      return capitalize(the_short()) + " contains:\n";
    case "on":
      return "Sitting on "+the_short()+" you see:\n";
    default:
      return capitalize(relation)+" "+the_short()+" you see:\n";
  }
}

 string inventory_recurse(int|void depth, mixed|void avoid)
{
  string res;
  object ob;
  array(object) obs;
  int i;
  string str="";
  string tmp;
  string key;
  mixed data;

  if (avoid)
  {
    if(!arrayp(avoid))
      avoid = ({ avoid });
  } else
    avoid = ({});


  if (!this_object()->is_living())
  {
    obs = all_inventory() - avoid;
    foreach (obs,ob)
    {
      if (!(ob->is_visible()))
        continue;
if (!ob->test_flag(TOUCHED) && ob->untouched_long())
{
        str += ob->untouched_long()+"\n";
        if (ob->inventory_visible())
          if (!ob->is_living())
            str += ob->inventory_recurse(0, avoid);
      }
    }
  }
  if (!this_object()->is_living())
  {
    foreach(indices(relations),key) 
    {
    	data = relations[key];
    	
res = introduce_contents(key);
tmp = inv_list(data->contents-avoid, 1, depth);
      if (tmp)
      {
        for (i=0; i<depth; i++)
          str += " ";
        str += res + tmp;
      }
    }
  }
  return str;
}

string show_contents()
{
    return inventory_recurse();
}


int inventory_accessible() {
    return 1;
    /* if (!is_visible()) return 0; */
    /* if (!short()) return 0; */
    /* return !this_object()->query_closed(); */
}


int contents_can_hear()
{
    return 1;
}

int internal_sounds_carry()
{
    return 1;
}

int environment_can_hear()
{
    object env = environment();
    return (internal_sounds_carry() && env && (!env->cant_hear_contents()));
}


void do_receive(string msg, int msg_type) {
    receive(msg);
}


 void
receive_inside_msg(string msg, array(object) exclude, int message_type,
  mixed other)
{
    object env;
    array(object) contents;

    do_receive(msg, message_type);


    if(contents_can_hear())
    {
contents = all_inventory(this_object());
if(arrayp(exclude))
contents -= exclude;
contents->receive_outside_msg(msg, exclude, message_type, other);
    }


    if(environment_can_hear() && (env = environment()) && (!arrayp(exclude) ||
member_array(env, exclude) == -1))
    {
env->receive_inside_msg(msg, arrayp(exclude) ? exclude +
({this_object()}) : ({this_object()}),
message_type, other);
    }
}

 void
receive_outside_msg(string msg, array(object) exclude, int message_type,
  mixed other)
{
    array(object) contents;

    do_receive(msg, message_type);

    if(contents_can_hear())
    {
contents = all_inventory(this_object());
if(arrayp(exclude))
contents -= exclude;
contents->receive_outside_msg(msg, exclude, message_type, other);
    }
}

 void
receive_remote_msg(string msg, array(object) exclude, int message_type,
  mixed other)
{
    receive_inside_msg(msg, exclude, message_type, other);
}

 void
receive_private_msg(string msg, int message_type, mixed other)
{
    do_receive(msg, message_type);
}

void containee_light_changed(int adjustment)
{
    contained_light += adjustment;
    if ( inventory_visible() )
adjust_light(adjustment);
}

void resync_visibility()
{
    int new_state;

    ::resync_visibility();

    new_state = inventory_visible();

    if ( new_state == contained_light_added )
return;

    contained_light_added = new_state;

    if ( new_state )
adjust_light(contained_light);
    else
adjust_light(-contained_light);
}

int destruct_if_useless() {
	object ob;
	foreach(deep_inventory(this_object()),ob) {
    
object link = ob->query_link();

if (link && userp(link))
return ASK_AGAIN;
    }
    return ::destruct_if_useless();
}

mapping lpscript_attributes()
{
  return ([
    "objects" : ({ LPSCRIPT_OBJECTS }),
    "capacity" : ({ LPSCRIPT_INT, "setup", "set_max_capacity" }),
    "relations" : ({ LPSCRIPT_LIST, "setup", "set_relations" }),
    "default_relation" : ({ LPSCRIPT_STRING, "setup", "set_default_relation" }),
    ]);
}


int is_container() { return 1; }

final string container_stat_me() {
    return
    "Prepositions: " + implode(keys(relations), ",") + "\n" +
    "It contains:\n"+ show_contents() + "\n" +
    ::stat_me();
}    

string stat_me()
{
    return container_stat_me();
}

void reset()
{
    make_objects_if_needed();
    make_unique_objects_if_needed();
}

protected void create() 
{
	m_obj::create();
}