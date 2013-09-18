

#include "/includes/mudlib.h"
#include "/includes/mudlib/hooks.h"

private mapping hooks = ([]);


void add_hook(string tag, function hook) 
{
    array tmp = ({ hook });
    if (hooks[tag]) {

        hooks[tag] -= tmp;
        hooks[tag] += tmp;
    } else {
        hooks[tag] = tmp;
    }
}

void remove_hook(string tag, function hook) 
{
    if (hooks[tag]) {
        hooks[tag] -= ({ hook });
    }
    
    if(!sizeof(hooks[tag])) {
         map_delete(hooks,tag);
    }
}

void hook_state(string tag, mixed hook, int state) 
{
    if (state) {
        add_hook(tag, hook);
    } else {
        remove_hook(tag, hook);
    }
}


private mixed m_relay(function f, mixed ... args) 
{	
	return f(@args);
}

final mixed hooks_call_hooks(string tag, mixed func, mixed|void start, mixed ... args) {
    array hooks_to_call;
    mixed tmp;
    function hook;

    if (hooks_to_call = hooks[tag]) {
        hooks_to_call = filter(hooks_to_call, functionp);
        hooks[tag] = hooks_to_call;
        if (!intp(func)) {
            return implode(                        
                map_array(hooks_to_call, m_relay, @args),
                func, 
                start);
        }
        switch (func) {
            case HOOK_IGNORE:
                map_array(hooks_to_call, m_relay,@args);
                return 0;
            case HOOK_SUM:
                foreach (hooks_to_call,hook) {
                    tmp += hook(@args);
                }
                return tmp;
            case HOOK_LAND:
                foreach (hooks_to_call, hook) {
                    if (!hook(@args)) {
                    	return 0;                    	
                    }
                }
                return 1;
            case HOOK_LOR:
                foreach (hooks_to_call, hook) {
                    if (tmp = hook(@args)) {
                        return tmp;
                    }
                }
                return 0;
            case HOOK_YES_NO_ERROR:
                foreach (hooks_to_call,hook) {
                tmp = hook(@args);
                if (!tmp || stringp(tmp)) return tmp;
                }
                return (start || 1);
            default:
                error("Unknown hook type in call_hooks.\n");
        }
    } else {
if (!intp(func))
return start;

switch (func) {
case HOOK_IGNORE:
case HOOK_SUM:
case HOOK_LOR:
return 0;
case HOOK_LAND:
return 1;
case HOOK_YES_NO_ERROR:
return (start || 1);
default:
error("Unknown hook type in call_hooks.\n");
}
    }
}

mixed call_hooks(string tag, mixed func, mixed|void start, mixed ... args) {
	hooks_call_hooks(tag, func,start, @args);
}

mapping debug_hooks()
{
    return copy(hooks);
}