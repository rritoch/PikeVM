
#include "/includes/mudlib.h"
#include "/includes/daemons.h"
#include "/includes/mudlib/setbit.h"

private  mixed long_value;
private  mixed in_room_desc;
private  string plural_in_room_desc;

private string untouched_long_value;

int test_flag(int);
int is_visible();
int is_attached();
string the_short();
string short();
string plural_short();
string a_short();
 mixed call_hooks();


string query_in_room_desc();

final void set_long(mixed str)
{
    long_value = str;
    if ( functionp(long_value) ) return;
    if ( long_value == "" || long_value[-1] != '\n' ) long_value += "\n";
}

string get_base_long()
{
    string res;

    if(!is_visible())
      return "Funny, you don't see anything at all.";

    res = functionp(long_value) ? long_value() : long_value;
    if (!res)
return "You see nothing special about " + the_short() + ".\n";

    return res;
}


string long()
{
  string ret = get_base_long() + get_extra_long();
  
#ifdef ANNOTATION_D  
  if(this_user() && adminp(this_user())) {
    if(sizeof(ANNOTATION_D->retrieve_annotations(base_name(this_object()))))
      ret += "%^YELLOW%^Attached to it is a yellow sticky note, "
          "bearing the word \"discuss\".\n%^RESET%^";
  }
#endif
  
  return ret;
}

string get_extra_long()
{
    // WTF is this?
    //return call_hooks("extra_long", (: $1 + $2 :), "") || "";
    return "";
}


protected array(string) discarded_message, plural_discarded_message;

string untouched_long() 
{
    return untouched_long_value;
}

string show_in_room()
{
    string str;
    int our_count;
    if(!is_visible()) return 0;
    if (is_attached()) return 0;
    our_count = count();
    
    
    if (our_count > 4) {
        if (plural_in_room_desc) {
            return sprintf( plural_in_room_desc, "many");
        }

        str = short();
        if (!str) return 0;

        return "There are many "+plural_short()+" here.\n";
    }
    
    if (our_count > 1 )
    {
if( plural_in_room_desc )
return sprintf( plural_in_room_desc, our_count+"");

str = short();
if( !str )
return 0;

if (!plural_discarded_message)
plural_discarded_message = MESSAGES_D->get_messages("discarded-plural");

return capitalize(sprintf( choice(plural_discarded_message),
sprintf("%d %s", our_count, plural_short())));
    }

    if (!test_flag(TOUCHED) && (str = untouched_long()))
return str;

    if( str = query_in_room_desc() )
return str;

    str = a_short();

    if( !str )
return 0;

    if (!discarded_message)
discarded_message = MESSAGES_D->get_messages("discarded");
    
    return capitalize(sprintf( choice(discarded_message), str ));
}

protected void set_in_room_desc( string arg )
{
  in_room_desc = arg;
}

void set_plural_in_room_desc( string arg ){ plural_in_room_desc = arg; }

string query_possessive(){ return "its"; }

void set_untouched_desc(string arg){
    if(stringp(arg)) untouched_long_value = arg;
}

string query_in_room_desc()
{
    if(!is_visible()){
      return "";
    }
    return (string)(functionp(in_room_desc) ? in_room_desc() : in_room_desc);
}

