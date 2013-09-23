
#include <daemons.h>
#include <mudlib/verbs.h>

string verb = (split_path(file_name())[1] / ".")[0];
int flags = NEED_TO_SEE | NEED_TO_BE_ALIVE | NEED_TO_THINK;

protected void add_rules(array rules, array|void syns)
{
    LANGUAGE_D->parse_init();

    foreach (rules, string rule) {
        LANGUAGE_D->parse_add_rule(verb, rule);
        if (syns) {
            foreach (syns,string syn) {
                LANGUAGE_D->parse_add_synonym(syn, verb, rule);
            }
        }
    }
}

protected void set_flags(int f)
{ 
	flags = f; 
}

protected void add_flag(int f)
{ 
	flags |= f; 
}

protected void clear_flag(int f)
{ 
	flags &= ~f; 
}

string refer_to_object(object ob)
{
    return ob->query_primary_name();
}

mixed try_to_acquire(object ob)
{

    if (ob->always_usable()) {
        return 1;
    }

    if (environment(ob) == this_body()) {
        return 1;
    }
    
    write("(Taking " + ob->the_short());
    
    if (!environment(ob)) {
        write(" first)\n");
        write("What a quaint idea.\n");
        return 0;
    }

    if (environment(ob) != environment(this_body())) {
        write(" from " + environment(ob)->the_short());
    }
    
    write(" first)\n");
    this_body()->do_game_command("get " + refer_to_object(ob));
    return environment(ob) == this_body();
}

mixed check_ghost()
{
    if (this_body()->query_ghost()) {
        return "But you're a ghost!\n";
    }
    return 1;
}

mixed check_vision()
{
    if (environment(this_body())->query_light()) {
        return 1;
    }
    
    if (environment(this_body())->parent_environment_accessible()) {
        if (environment(environment(this_body()))->query_light()) {
            return 1;
        }
    }
    return "You can't see a thing!\n";
}

mixed check_condition()
{
    mixed tmp;

    if (tmp = this_body()->check_condition(0)) {
        return tmp;
    }
    return 1;
}

mixed default_checks()
{
    mixed tmp;

    if ((flags & NEED_TO_SEE) && (tmp = check_vision()) != 1) {
        return tmp;
    }

    if ((flags & NEED_TO_BE_ALIVE) && (tmp = check_ghost()) != 1) {
        return tmp;
    }


    if ((flags & NEED_TO_THINK)) {
        return check_condition();
    }

    return 1;
}

void handle_obs(array info, function callback, mixed ... extra)
{
    foreach (info, mixed ob) {
        if (stringp(ob)) {
            write(ob);
        } else {
            callback(ob, @extra);
        }
    }
}

mixed can_verb_rule(string verb, string rule)
{
    return default_checks();
}

int do_verb_one(string verb, object ob)
{
    if ((flags & TRY_TO_ACQUIRE) && !try_to_acquire(ob)) {
        return 0;
    }
    
    if(function_exists("do_" + verb, ob)) {
        call_other(ob, "do_" + verb);
        return 1;
    } else {
        write("Trying to " + verb + " " + ob->the_short() + " has no effect.\n");
        return 0;
    }
}

void do_verb_obj(string verb, object ob)
{
    if(do_verb_one(verb, ob)) {
        this_body()->simple_action("$N $v" + verb + " the $o.", ob);
    }
}

void do_verb_obs(string verb, array(object) obs)
{
    array(object) success = ({});
    foreach(obs,mixed ob) { 
        if(objectp(ob)) {
            if(do_verb_one(verb, ob)) {
                success += ({ ob });
            }
        }
    }
    if(sizeof(success)) {
        this_body()->simple_action("$N $v" + verb + " the $o.", success);
    }
}

void do_verb(string verb)
{
    write(sprintf("You can't just %s - you need to %s something.\n",verb, verb));
}
