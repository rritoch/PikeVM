private mapping hooks = ([]);

final void add_hook(string id, function handler, mixed ... args) 
{
	if (functionp(handler)) {	
	    if (zero_type(hooks[id])) {
	        hooks[id] = ({ });
	    }
	
	    if (!arrayp(args)) {
		    args = ({});
	    }		
	    hooks[id] +=  ({ ({ handler, @args }) });
	}		
}

final void call_hooks(string id, mixed ... args) 
{		
	array c_args;
	object caller = previous_object();
		
		
	if (!zero_type(hooks[id])) {
	    foreach(hooks[id], array hook) {
	    	c_args = args + ({ caller }) + hook[1..];
	    	hook[0](@c_args);
	    }
	}
}

public final void remove_hook(string id, function handler) 
{
	array handlers = ({});
	array hook;
	if (!zero_type(hooks[id])) {
	    foreach(hooks[id], hook) {
	    	if (handler != hook[0]) {
	    		handlers += ({ hook });
	    	}	    		    
	    }
	    
	    if (sizeof(handlers)) {
	    	hooks[id] = handlers;
	    } else {
	    	m_delete(hooks,id);
	    }
	}	
}
