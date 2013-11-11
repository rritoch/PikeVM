

#include <stdio.h>

protected void reload_verb(string file)
{
	
    object ob;
    mixed err;
    
#ifdef DEBUG_VERBD
    printf("[VERB_D] Loading %O\n",file);
#endif

    //kernel()->console_write("link = %O\n",this_link());
    
    if ( ob = find_object(file) ) {
#ifdef DEBUG_VERBD
    	printf("[VERB_D] Destructing old object %O.\n",ob);
#endif
        destruct(ob);
    }
    
    err = catch {
#ifdef DEBUG_VERBD
    	printf("[VERB_D] Creating new object %O.\n",file);
#endif    	
        load_object(file);
    };
    
    if (err != 0) {
    	if (objectp(err)) {
    		printf("%O\n%O\n[VERB_D] failed to load: %s\n",err,err->backtrace(), file);
    	} else {
            printf("%O\n[VERB_D] failed to load: %s\n",err, file);
    	}
    }
}

