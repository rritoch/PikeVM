/**
 * Body Commands
 */

#include <mudlib/commands.h>
#include <daemons.h>

object query_link();
void force_look(int force_long_desc);
string move(object location);

private array(string) nonsense_msgs;

string nonsense()
{
    if (!arrayp(nonsense_msgs)) {
        nonsense_msgs = (MESSAGES_D)->get_messages("nonsense");
    }

    return choice(nonsense_msgs) + "\n";
}

array(mixed) debug_ids(object ob) 
{
    return ({ ob, ob->query_id() });
}

final int do_command(string str, int|void debug)
{
    mixed result;
    mixed go_result;
    array(object) objs;
    
    object rootenv;
    mixed items;

    if ( !environment(this_object()) )
    {
        write("Oops! You're lost. Moving to the void...\n");
        move(VOID_ROOM);
        force_look(0);
    }

    rootenv = LANGUAGE_D->parser_root_environment(environment(this_object()) );
    
    items = LANGUAGE_D->deep_useful_inv_parser_formatted(rootenv);
    
     
    objs = ({ rootenv });
    
    if (arrayp(items)) {
    	objs += items;
    }
        
    result = LANGUAGE_D->parse_sentence(str, debug, objs);

    if ( stringp(result) ) {
        if(debug) {
            return result;
        }
        if( result[-1] != '\n') {
            result += "\n";
        }
        write( result );
        return 1;
    }


    switch(result) {
        case 0:
            break;
        case 1:
            return 1;
        case -1:
            write(nonsense());
            return 1;
        case -2:
            write("You aren't able to do that.\n");
            return 1;
        default:
            write("This parser code should never be reached. If it is, let "
                "someone know how you got here.\n");
            if( undefinedp( result )) {
            	write("Result was undefined.\n");
            } else {
                write( "Error was: " );
                write(result); write("\n");
            }
            return 1;
    }

    if (debug) {
    	return 1;
    }

    go_result = LANGUAGE_D->parse_sentence("go " + str);
    if (go_result == 1) {
        return 1;
    }
    if (!result) {
        result = go_result;
    }

    if (stringp(result) &&
     (result[0..12] != "You can't go " && result[0..11] != "There is no ")) {
        write(result);
        return 1;
    }
    return 0;
}

final void force_command(string str)
{    
    if (!query_link()->call(do_command,str)) {
        write(nonsense());
    }
}
