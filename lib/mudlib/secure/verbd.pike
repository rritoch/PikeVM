

#include <stdio.h>

protected void reload_verb(string file)
{
	
    object ob;
    mixed err;
    printf("[VERB_D] Loading %O\n",file);

    //kernel()->console_write("link = %O\n",this_link());
    
    if ( ob = find_object(file) ) {
    	printf("[VERB_D] Destructing old object %O.\n",ob);
        destruct(ob);
    }
    
    err = catch {
    	printf("[VERB_D] Creating new object %O.\n",file);
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




