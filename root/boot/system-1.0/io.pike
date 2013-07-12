/* ========================================================================== */
/*                                                                            */
/*   Filename.c                                                               */
/*   (c) 2001 Author                                                          */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */


mapping(string:mixed) devices = ([]);

void input_to(string|function fun, 
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

private void kwrite(mixed ... msg) { 
 write(sprintf("[%s] %s\n",kernel()->describe_program(object_program(this)),sprintf(@msg)));
}

void create() {
    kwrite("Loading devices...");
    add_constant("input_to",this->input_to); 
    program console = (program)"/dev/console.pike";
    devices["console"] = console();
    kwrite("Loading devices complete.");
}
