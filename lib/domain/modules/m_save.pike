/**
 * Object Save Module
 */
 
#include "/includes/domain/save.h"

//#define DEBUG_SAVE_OBJECT
//#define DEBUG_RESTORE_OBJECT

private array(function) m_save_hooks = ({});
private array(function) m_restore_hooks = ({});

protected final void add_save_hooks(function ... save_hooks) 
{	
	m_save_hooks += save_hooks;
}

protected final void add_restore_hooks(function ... restore_hooks) 
{	
	m_restore_hooks += restore_hooks;
}

protected final int save_object(string name, int|void flags) 
{
	mixed tmpdata;
	mapping save_data = ([]);
	string data;
	mixed err;
	string k;
	int ret;
	int fh;
	function f;
	
	
#ifdef DEBUG_SAVE_OBJECT
            kernel()->console_write("%O\n",m_save_hooks);
#endif 	
		
	if (flags & F_USE_COMPRESSION) {
		error("Compression not supported");
	}
		

    foreach(m_save_hooks, f) {    	
        err = catch {
            tmpdata = f(flags);
#ifdef DEBUG_SAVE_OBJECT
            kernel()->console_write("%O returned %O\n",f,tmpdata);
#endif            
            foreach(indices(tmpdata), k) {
                if (zero_type(save_data[k])) {
                	if (tmpdata[k] || (flags & F_SAVE_NULL)) {
                		save_data[k] = tmpdata[k];
                	}                
                } 	
            } 
        };
        
        if (err) {
        	if (objectp(err)) {
        		write("save_object: %O %O\n",err,err->backtrace());
        	} else {
        		write ("save_object: %O",err);
        	}
        }    	    	    	
    }
    
#ifdef DEBUG_SAVE_OBJECT    
    kernel()->console_write("Writing %O\n",save_data);
#endif
           
    data = encode_value(save_data);
    fh = kernel()->_fopen(name,"wc");
    ret = kernel()->_fwrite(fh,data);
    kernel()->_fclose(fh);        		
}

protected final int restore_object(string name, int|void flags) 
{
	string encdata;
	function f;
	
	encdata = kernel()->_read_file(name);
#ifdef DEBUG_RESTORE_OBJECT	
	kernel()->console_write(sprintf("Restored %O",encdata));
#endif	
	
	mapping data = decode_value(encdata);
#ifdef DEBUG_RESTORE_OBJECT	
	kernel()->console_write(sprintf("Restored %O",data));
#endif	
	foreach(m_restore_hooks, f) {
		f(copy_value(data),flags);
	}
		
	return 1;
}
