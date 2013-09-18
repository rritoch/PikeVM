
#include "/includes/mudlib/flags.h"

void call_hooks(mixed ... args);
void set_light(int x);
void assign_flag(int which, int state);
int test_flag(int which);

int remove()
{
    if (environment()) {
        environment()->release_object(this_object(), 1);
    }



    call_hooks("remove", HOOK_IGNORE);
    set_light(0);
    
    destruct();
}

mixed receive_object( object target, string relation )
{
    return MOVE_NOT_ALLOWED;
}

mixed release_object( object target, int force )
{
    return 1;
}


void set_attached(int a)
{
    if (undefinedp(a))
        a = 1;
    assign_flag(ATTACHED, a);
}

int is_attached()
{
    return test_flag(ATTACHED);
}
