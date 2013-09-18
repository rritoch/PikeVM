#include <mudlib.h>

inherit BASE_OBJ;

private  mapping msgs = ([]);

 void create(mapping long, array(string) ids, object dest)
{
    if (!clonep()) return;
    ::create();

    set_attached(1);
    msgs = long;

    if(msgs["look"])
set_long(msgs["look"][-1] == '\n' ? msgs["look"] :
msgs["look"]+"\n");
    if(msgs["adjs"])
    {
if ( arrayp(msgs["adjs"]) )
add_adj(@msgs["adjs"]);
else
add_adj(msgs["adjs"]);
map_delete(msgs, "adjs");
    }

    set_id(@ids);
      
    //parse_refresh();

    move_object(previous_object());
}

// respond to all interaction with self as a direct object of the verb
mixed direct_verb_rule(string verb, string rule, mixed args)
{
    string s = msgs[verb];
    if(s)
return s[-1] == '\n' ? s : s+"\n";

    /* can't use that verb on us... */
    return 0;
}

// some special cases because of /std/object/vsupport.c
mixed direct_get_obj(object ob) {
    if (msgs["get"])
        return msgs["get"];
    else
        return ::direct_get_obj(ob);
}

mixed direct_pull_obj(object ob) {
    if (msgs["pull"])
        return msgs["pull"];
    else
        return ::direct_pull_obj(ob);
}

mixed direct_press_obj(object ob) {
    if (msgs["press"])
        return msgs["press"];
    else
        return ::direct_press_obj(ob);
}

mixed direct_search_obj(object ob) {
    if (msgs["search"])
        return msgs["search"];
    else
        return ::direct_search_obj(ob);
}