/**
 * Base Object
 */

#include "/includes/mudlib.h" 

inherit M_GRAMMAR;
inherit __DIR__ "/object/m_name.pike";
inherit __DIR__ "/object/m_description.pike";
inherit __DIR__ "/object/m_flags.pike";
inherit __DIR__ "/object/m_behavior.pike";
inherit __DIR__ "/object/m_verbs.pike";
inherit __DIR__ "/object/m_attributes.pike";

protected void base_obj_create() 
{
    name_create();
    flags_create();
}

void create()
{
    base_obj_create();
}

string stat_me()
{
    return implode(({
        "Short: "+short(),        
        "IDs: "+implode(parse_command_id_list(),", "),
        "Plurals: "+implode(parse_command_plural_id_list(),", "),
        "Adjectives: "+implode(parse_command_adjectiv_id_list(),", "),
        "Long: \n"+long()
    }),"\n") + "\n";
}

int is_visible()
{
    return 1;
}

mixed call_hooks(mixed ... s)
{
}

void set_light(int x)
{
}

/* EOF */