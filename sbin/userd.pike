
//#include <mudlib.h>
//#include <security.h>
#include "/includes/mudlib.h"
#include "/includes/security.h"

//inherit M_ACCESS;

 private array(string)	legal_user_query =
({
    "failures",
    "email",
    "real_name",
    "password",
    "url",
});
 private array(string)	legal_user_set =
({
    "failures",
    "password",
});

 private array(string)	legal_body_query =
({
    "nickname",
    "plan",	/* only when EVERYONE_HAS_A_PLAN */
    "wiz_position",
    "title",	/* only when USE_TITLES */
});
 private array(string)	legal_body_set =
({
    "plan",	/* only when EVERYONE_HAS_A_PLAN */
    "wiz_position",
});

class var_info
{
    object	ob;
    string	fname;
    string	lines;
}

void create() {
    //set_privilege(1);
}

private final mixed query_online_object(object ob, string varname)
{
    //return evaluate(bind((: fetch_variable, varname :), ob));
    return ob[varname];
}

private final mixed set_online_object(object ob, string varname, mixed value)
{
    //evaluate(bind((: store_variable, varname, value :), ob));
    return ob[varname] = value;
}

private final mixed query_filed_object(string lines, string varname)
{	
	mapping data = decode_value(lines);	
	return zero_type(data[varname]) ? 0 : data[varname];
}

final array(mixed) query_variable(string userid, array(string) vlist)
{
    var_info user;
    var_info body;
    var_info which;
    array(mixed) results;
    string var;

/*
    if ( !check_privilege(1) )
error("insufficient privilege to query variables\n");
*/
    results = ({ });
    
    foreach (vlist, var )
    {
        if ( member_array(var, legal_user_query) != -1 ) {
            if ( !user ) {
                user = var_info();
                user->ob = find_user(userid);
                user->fname = LINK_PATH(userid) + __SAVE_EXTENSION__;
            }

            which = user;
        } else if ( member_array(var, legal_body_query) != -1 ) {
            if ( !body ) {
                body = var_info();
                body->ob = find_body(userid);
                body->fname = USER_PATH(userid) + __SAVE_EXTENSION__;
            }

            which = body;
        } else {
            error("illegal variable request\n");
        }

        if ( false && which->ob ) {
            results += ({ query_online_object(which->ob, var) });
        } else {
            if ( !which->lines ) {
                if ( !is_file(which->fname) ) {
                   /* no such player */
                   return 0;
                }

                which->lines = read_file(which->fname);
            }

            results += ({ query_filed_object(which->lines, var) });
        }
    }

    return results;
}

final void set_variable(string userid, string varname, mixed value)
{
    string fname;
    object ob;
    array(mixed) lines;
/*
    if ( !check_privilege(1) )
error("insufficient privilege to set variables\n");
*/
    if ( member_array(varname, legal_user_set) != -1 )
    {
fname = LINK_PATH(userid);
ob = find_user(userid);
    }
    else if ( member_array(varname, legal_body_set) != -1 )
    {
fname = USER_PATH(userid);
ob = find_body(userid);
    }

    if ( !fname )
error("illegal variable assignment\n");

    if ( ob ) {
        set_online_object(ob, varname, value);
    }

    fname += __SAVE_EXTENSION__;
    
    if ( !is_file(fname) )
error("no such user\n");

    lines = regexp(explode(read_file(fname), "\n"),
"^" + varname + " ",
2);

/*
    write_file(fname, implode(lines, "\n") +
sprintf("\n%s %s\n", varname, save_variable(value)),
1);
*/

}

final int user_exists(string s)
{
  return is_file(LINK_PATH(s) + __SAVE_EXTENSION__);
}