
#include <mudlib/verbs.h>

inherit VERB_OB;
inherit M_GRAMMAR;

void create() 
{
	
    clear_flag(NEED_TO_BE_ALIVE);

    add_rules( 
        ({ 
    	    "", 
    	    "STR OBJ",
    	    "STR",
    	    "WRD OBJ",
    	    "at OBJ", 
    	    "for OBS",
            "at OBS with OBJ"     
        })
    );

    add_rules( 
        ({ 
        	"OBS", 
        	"OBS with OBJ" 
        }), 
        ({ 
        	"examine" 
        }) 
    );
}

mixed can_look() 
{
	return 1;
}
mixed can_look_str(string str) 
{
    return "That doesn't seem to be possible.\n";
}

void do_look() 
{
    this_body()->force_look(1);
}

void do_look_at_obj(object ob, string name) 
{
    string str;

    if (!(str = ob->get_item_desc(name))) {
        str = ob->long();
    }

    if (sizeof(str) && str[-1] != '\n') {
    	str += "\n";
    }
    
    write(str);
}

void do_look_at_obs(array info, string name) 
{
    handle_obs(info, do_look_at_obj, name);
}

void do_look_str_obj(string prep, object ob) 
{
    write(ob->look_in(prep)+"\n");
}

void do_look_obj(object ob, string name) 
{
    do_look_at_obj(ob, name);
}

void do_look_obs(array info, string name) 
{
    handle_obs(info, do_look_at_obj, name);
}

void do_look_at_obj_with_obj(object o1, object o2) 
{
    o2->use("look", o1);
}

void do_look_at_obs_with_obj(array info, object o2) 
{
    handle_obs(info, do_look_at_obj_with_obj, o2);
}

void do_look_obj_with_obj(object o1, object o2) 
{
    do_look_at_obj_with_obj(o1, o2);
}

void do_look_obs_with_obj(array info, object o2) 
{
    handle_obs(info, do_look_at_obj_with_obj, o2);
}

void do_look_for_obj(object ob) 
{
    object env = environment(ob);
    string relation;

    if (!env) {
        write("You're on it!\n");
        return;
    }
    
    if (ob == this_body()) {
        write("Trying to find yourself?\n");
        return;
    }
    
    if (environment(this_body()) == env) {
        this_body()->my_action("The $o0 is right here!", ob);
        return;
    }
    if(env->is_living()) {
        this_body()->my_action("$O $vis carrying it.", env);
        return;
    } else {
        relation = env->query_prep(ob);

        this_body()->my_action("The $o0 is " + relation + " the $o1.", ob, env);
    }
}

string look_for_phrase(object ob) 
{
    object env = environment(ob);

    if (env == environment(this_body())) {
        return "on the ground";
    }
    if(env->is_living()) {
        return "carried by " + env->the_short();
    }
    return env->query_prep(ob) + " " + env->the_short();
}

void do_look_for_obs(array info) 
{
    mixed ua;
    int i, n;
    string res;
    
    info = filter(info, objectp);
    ua = collate_array(info, look_for_phrase);

    n = sizeof(ua);
    res = "There " + (sizeof(ua[0]) > 1 ? "are " : "is ");
    for (i = 0; i < n; i++) {
        if (i != 0) {
            if (i == n - 1){
                res += " and ";
            } else {
                res += ", ";
            }
        }
        res += number_word(sizeof(ua[i])) + " " + look_for_phrase(ua[i][0]);
    }
    write(res + ".\n");
}

mixed do_look_wrd_obj(string wrd, object ob)
{
    ob->look(wrd);
}
