/* Do not remove the headers from this file! see /USAGE for more info. */

#include <mudlib/move.h>

inherit VERB_OB;

mixed can_drop_obj() {
    // give a better message for this case, since all the errors generated
    // will be nonsense.
    if (!first_inventory(this_body()))
return "You don't have anything.\n";
    return default_checks();
}

private final void drop_one(object ob)
{
    mixed tmp = ob->drop();

    if (!tmp) tmp = "You aren't able to drop it.\n";
    if (stringp(tmp)) {
write(tmp);
return;
    }

    tmp = ob->move(environment(this_body()),environment(this_body())->query_relation(this_body()));
    if (tmp == MOVE_OK) {
write("Done.\n");
        if(ob)
   this_body()->other_action("$N $vdrop a $o.", ob);
    } else
write(tmp);
}

void do_drop_obj(object ob)
{
    drop_one(ob);
}

void do_drop_obs(array info)
{
    foreach (info, mixed item)
    {
if (stringp(item))
write(item);
else
{
write(item->short() + ": ");
drop_one(item);
}
    }
}

mixed can_drop_wrd_str(string amount, string str) {
    int z;
    string s1, s2;
    
    sscanf(amount, "%d%s", z, s1);
    if (s1 != "" && amount != "all")
        return 0;
    sscanf(str, "%s %s", s1, s2);
    
#ifdef MONEY_D
    if (s2) {
if (s2 != "coin" && s2 != "coins")
return 0;

return MONEY_D->is_denomination(s1);
    }
    return MONEY_D->is_denomination(str);
    
#else
    return 0;
#endif
}

void do_drop_wrd_str(string amount_str, string type)
{
    string s;
    object ob;
    int amount;

    sscanf(type, "%s %s", type, s);
#ifdef MONEY_D
    type = MONEY_D->singular_name(type);
#endif
    if (amount_str == "all")
        amount = this_body()->query_amt_money(type);
    else
        amount = (int)amount_str;
    if (amount < 0) {
        write("Nice try.\n");
        return;
    }
    

    if(this_body()->query_amt_money(type) < amount) {
#ifdef MONEY_D
write("You don't have "
+MONEY_D->denomination_to_string(amount, type)+".\n");
return;
#endif
    } else {
        this_body()->subtract_money(type, amount);
        if(ob = present("money", environment(this_body())))
#ifdef USE_MONEY
ob->merge_money(amount, type);
else
new(MONEY, amount, type)->move(environment(this_body()));
#else
ob->merge_coins(amount, type);

#ifdef COINS
else
    COINS(amount,type)->move(environment(this_body()));
    
#endif
#endif

#ifdef MONEY_D
    this_body()->simple_action("$N $vdrop "
        +MONEY_D->denomination_to_string(amount, type)+".");
#endif
    }
}

void create()
{
    add_rules( ({ "OBS", "WRD STR" }), ({ "put down" }) );
}