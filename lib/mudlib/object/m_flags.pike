#include "/includes/mudlib/flags.h"

private class flag_set_info
{
    int is_non_persistent;
    function change_func;
}


private mapping flag_sets;

private mapping non_persist_flags;
private mapping persist_flags;


#define BITMASK(w) (1 << ((w) & 0x1F))

private void init_vars()
{
    flag_sets = ([ ]);
    non_persist_flags = ([ ]);
    persist_flags = ([ ]);
}

final int get_flags(int set_key)
{
    flag_set_info set_info;

    if ( !flag_sets ) init_vars();

    set_info = flag_sets[set_key];
    if ( !set_info )
set_info = flag_set_info();

    if ( set_info->is_non_persistent )
return non_persist_flags[set_key];
    return persist_flags[set_key];
}


private void set_flags(int which, int state)
{
    int set_key;
    flag_set_info set_info;
    int value;

    if ( !flag_sets ) init_vars();

    set_key = FlagSet(which);
    set_info = flag_sets[set_key];
    if ( !set_info )
set_info = flag_sets[set_key] = flag_set_info();

    value = get_flags(set_key);
    if ( state )
value |= BITMASK(which);
    else
value &= ~BITMASK(which);

    if ( set_info->is_non_persistent )
non_persist_flags[set_key] = value;
    else
persist_flags[set_key] = value;


    if ( set_info->change_func )
       set_info->change_func(which, state);
}


void configure_set(
  int set_key,
  int is_non_persistent,
  function|void change_func
)
{
    if ( !flag_sets ) init_vars();

    flag_sets[set_key] = flag_set_info();
    flag_sets[set_key]->is_non_persistent = is_non_persistent;    
    flag_sets[set_key]->change_func = change_func;
}


final int test_flag(int which)
{
    return (get_flags(FlagSet(which)) & BITMASK(which)) != 0;
}


final void set_flag(int which)
{
    set_flags(which, 1);
}


final void clear_flag(int which)
{
    set_flags(which, 0);
}


final void assign_flag(int which, int state)
{
    set_flags(which, state);
}


protected void create()
{
    init_vars();
}
