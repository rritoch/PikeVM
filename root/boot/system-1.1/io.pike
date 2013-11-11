/* ========================================================================== */
/*                                                                            */
/*   Filename.c                                                               */
/*   (c) 2001 Author                                                          */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */

//#define DEBUG_IO

class link {

    private object orig_stdin;
    private object orig_stdout;
    private object orig_stderr;
    
    array(mixed) stack = ({}); 
    
    void reset() 
    {              
       stack = ({ ({ orig_stdin, orig_stdout, orig_stderr}) });      
    }
    
    void open(string stdin, string stdout, string stderr) 
    {
        ({ get_device(stdin),
           get_device(stdout),
           orig_stderr = get_device(stderr)
        });        
    }
    
    void close() 
    {
        if (sizeof(stack) > 1) {
            array(object) curr = stack[-1];
            stack = stack[0..<1];
            return;
        }
                        
        destruct(orig_stdin);
        destruct(orig_stdout);
        destruct(orig_stderr);
        destruct();                                    
    }
    
    void destroy() {
    	destruct(orig_stdin);
        destruct(orig_stdout);
        destruct(orig_stderr);
        destruct();
    }
    int query_stack_size() 
    {
        return sizeof(stack);
    }
    
    int handle_ioctl(int fh, string cmd, mixed ... args) {
                        
        switch(cmd) {
           case "read":
               return orig_stdin->handle_ioctl(fh,cmd,@args);
           default:
               break;      
        }
        
        return orig_stdout->handle_ioctl(fh,cmd,@args);       
    }
    
    private void handle_input_to_response(string str, mixed shell, function func, mixed ... args) 
    {
    
        //write("%O(%O) called\n",handle_input_to_response,({str,func,args}));        
                
        if (functionp(func)) {
        	if (objectp(shell) && functionp(shell->handle_call_out)) {
        		shell->handle_call_out(func,str,@args);
        	} else {
                func(str,@args);
        	}
        } // otherwise our listener was destroyed *sniff*
        
    }
    
    void input_to(function func, mixed flag, mixed ...args) {
    
        //write("%O(%O) called from %O\n",input_to,({func,flag, args}),backtrace());
        mixed prompt;
        
        mixed shell = kernel()->_this_shell();
        
        if (flag & 4) {
            prompt = args[0];
            args = args[1..];
            
            orig_stdin->input_to(
                handle_input_to_response, 
                flag,
                prompt,
                shell,
                func, 
                @args);        
        } else {
        orig_stdin->input_to(
            handle_input_to_response, 
            flag,
            shell,
            func, 
            @args);
        
        }   
    }
    
    void create(string stdin, string stdout, string stderr) 
    {        
        orig_stdin = get_device(stdin);
        orig_stdout = get_device(stdout);
        orig_stderr = get_device(stderr);
        reset();
    }
    
    
}

mapping(string:mixed) devices = ([]);

void input_to(string|function fun, 
              void|int flag, 
              mixed ... args) {
 
    function f;
    object caller;
    
    if (stringp(fun)) {
         mixed bt = backtrace();
         if (sizeof(bt) > 1) {
             caller = function_object(bt[-2][2]);
             if (functionp(caller[fun])) {
                 f = caller[fun];
#ifdef DEBUG_IO                 
                 kwrite("%O cast to %O\n",fun,f);
#endif                                  
             } else {
#ifdef DEBUG_IO             
                 kwrite("%O is not a function\n",fun);
#endif                 
             }
         }
    } else {
        f = fun;
    }
    
    
    if (kernel()->_this_link()) {        
        //this_user()->handle_input_to(f,flag,prompt,args);
        kernel()->_this_link()->input_to(f,flag,@args);
    }
    return;  
}

void get_char(string|function fun, 
              void|int flag, 
              void|string|function prompt, mixed ... args) {
 
    function f;
    object caller;
    
    if (stringp(fun)) {
         mixed bt = backtrace();
         if (sizeof(bt) > 1) {
             caller = function_object(bt[-2][2]);
             if (functionp(caller[fun])) {
                 f = caller[fun];
#ifdef DEBUG_IO                 
                 kwrite("%O cast to %O\n",fun,f);
#endif                                  
             } else {
#ifdef DEBUG_IO             
                 kwrite("%O is not a function\n",fun);
#endif                 
             }
         }
    } else {
        f = fun;
    }
    if (kernel()->_this_user()) {
        this_user()->handle_input_to(f,flag,prompt,args);
    }
    return;  
}


int add_device(string name, object dev) {
 if (!zero_type(devices[name])) {
  return -1;
 }
 devices[name] = dev;
 return 0;
}

object get_device(string name) {
 return devices[name];
}

protected void kwrite(mixed ... msg) { 
 write(sprintf("[%s] %s\n",kernel()->describe_program(object_program(this)),sprintf(@msg)));
}

void create() {
    kernel()->klog(kernel()->LOG_LEVEL_INFO,"Loading devices...");
    add_constant("input_to",this->input_to);
    add_constant("get_char",this->get_char); 
    program console = (program)"/dev/console.pike";
    devices["console"] = console();
    kernel()->klog(kernel()->LOG_LEVEL_INFO,"Loading devices complete.");
}
