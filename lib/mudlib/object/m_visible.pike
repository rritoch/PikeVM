
#include "/includes/mudlib/setbit.h"
#include "/includes/mudlib/move.h"

int test_flag(mixed);
void set_flag(mixed);
void clear_flag(mixed);
void set_id(string);
void remove_id(string ... args);

void resync_visibility() {
    //parse_refresh();
}


final int visible_is_visible() {
    object ob;

    if( test_flag( INVIS ))
return 0;

    if( ( ob = environment( this_object() ) ) &&
      ( this_body() && ob == environment( this_body() ) ) )
return 1;

    if(ob)
      return ob->is_visible() && ob->inventory_visible();

    return 1;
	
}

int is_visible()
{
	return visible_is_visible();
}



string invis_name() {
    return "something";
}


void set_visibility(int x)
{
    if (x) {
clear_flag(INVIS);
    } else {
set_flag(INVIS);
    }
    resync_visibility();
}


int get_visibility()
{
  return !test_flag(INVIS);
}