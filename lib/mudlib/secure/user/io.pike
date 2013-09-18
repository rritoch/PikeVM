
#include <driver/function.h>

string query_userid();
void start_shell();
mixed query_privilege();

private mapping translations = (["RESET" : ""]);
private mapping colors;

#define INPUT_NORMAL 0
#define INPUT_AUTO_POP 1
#define INPUT_CHAR_MODE 2

class input_info
{
    function	input_func;
    array(mixed)|int input_func_args;
    mixed	prompt;
    int	secure;
    function|int	return_to_func;
    array(mixed)|int return_to_func_args;
    int	input_type;
    int lock;
}

private array(object) input_info_stack = ({});

private int	dispatching_to;

private void dispatch_modal_input(string str);

private int create_handler()
{

    start_shell();
    if ( !sizeof(input_info_stack) )
    {
        write("Error processing input, please log in and try again or send mail\n"
            +" to " + ADMIN_EMAIL + "if you continue to have problems.\n");
        destruct(this_object());
        return 1;
    }
    return 0;
}

private input_info get_top_handler(int require_handler)
{
    int popped = 0;
    input_info info;
            
    while ( sizeof(input_info_stack) )
    {        
        info = input_info_stack[-1];
        if (functionp(info->input_func)) {
            if ( popped > 0 && functionp(info->return_to_func)) {
                info->return_to_func();
            }
            return info;
        }
        input_info_stack = input_info_stack[0..<2];
        popped++;
    }

    // if we don't need a handler return 0 
    // otherwise create handler and return 0 if that fails    
    if ( !require_handler || create_handler() ) {
        return 0;    
    }
    
    // return created handler
    return input_info_stack[-1];
}

private object get_bottom_handler()
{
    while ( sizeof(input_info_stack) )
    {
        input_info info;

        info = input_info_stack[0];
        if ( !(functionp(info->input_func)) ) {
            return info;
        }

        input_info_stack = input_info_stack[1..];
    }

    if ( create_handler() ) {
        return 0;
    }

    return input_info_stack[0];
}

private final void push_handler(
    function input_func, 
    array(mixed) input_func_args, 
    mixed prompt, 
    int secure, 
    function|int return_to_func, 
    array(mixed)|int return_to_func_args, 
    int input_type,
    int|void lock)
{     
    input_info info;

    info = input_info();;
    info->input_func	= input_func;
    info->input_func_args = input_func_args;
    info->prompt	= prompt;
    info->secure	= secure;
    info->return_to_func	= return_to_func;
    info->return_to_func_args = return_to_func_args;
    info->input_type	= input_type;
    info->lock = lock;

    input_info_stack += ({ info });
    
#ifdef DEBUG_USER_IO
   write("%O: input_info_stack = %O\n",push_handler,input_info_stack);
   write("%O: input_type = %O secure = %O\n",push_handler,info->input_type, info->secure);
#endif    
        
    if ( info->input_type == INPUT_CHAR_MODE )
    {
        get_char(dispatch_modal_input, info->secure | 2);
    } else {
        input_to(dispatch_modal_input, info->secure/* | 2*/);
    }
}

final void modal_push(
    function input_func,
    array(mixed) input_func_args,
    mixed prompt,
    int secure,
    function return_to_func,
    array(mixed) return_to_func_args,
    int lock
)
{
#ifdef DEBUG_USER_IO
    write("%O(%O) called\n",modal_push,({input_func, input_func_args, prompt,secure,return_to_func,return_to_func_args}));
#endif
    push_handler(input_func, input_func_args, prompt, secure, return_to_func,
        return_to_func_args,INPUT_NORMAL,lock);
}

void modal_pop()
{
    input_info info;

    if (sizeof(input_info_stack)==1) {
        input_info_stack=({ }); 
    } else {
        input_info_stack = input_info_stack[0..<2];
    }

    if ( (info = get_top_handler(0)) && functionp(info->return_to_func) ) {
        info->return_to_func();
    }
}

void modal_func(
    function input_func,
    array(mixed) input_func_args,
    mixed prompt,
    int|void secure,
    int|void lock)
{
    input_info_stack[-1]->input_func = input_func;
    input_info_stack[-1]->input_func_args = input_func_args;
    
    if ( prompt ) {
        input_info_stack[-1]->prompt = prompt;
    }
    input_info_stack[-1]->secure = secure;
    input_info_stack[-1]->lock=lock;
}

protected void modal_recapture()
{
    input_info info;
    string prompt;
        
    if ( !(info = get_top_handler(1)) ) {
        return;
    }
    
    
    if ( info->input_type != INPUT_CHAR_MODE && info->prompt )
    {
        prompt = functionp(info->prompt) ? info->prompt() : info->prompt;
        if ( prompt ) {
            write(prompt);
        }
    }
    
    if ( info->input_type == INPUT_CHAR_MODE )
    {
        get_char(dispatch_modal_input, info->secure | 2);
    } else {
        input_to(dispatch_modal_input, info->secure/* | 2 */);
    }
}

void modal_simple(
    function input_func,
    array(mixed) input_func_args,
    mixed prompt,
    int secure,
    int lock)
{
    push_handler(input_func, input_func_args, prompt, secure, 0, ({}) , INPUT_AUTO_POP,lock);
}


void modal_pass(string str)
{
    input_info info;

    if ( !dispatching_to ) {
        error("no handlers");
    }
    
    info = input_info_stack[--dispatching_to - 1];
    info->input_func(str);
}

private void dispatch_to_bottom(mixed str) 
{
    input_info info;
    if (!(info = get_bottom_handler())) {
        return;
    }
    dispatching_to = 0;
    info->input_func(str);    
}


private void dispatch_modal_input(mixed str)
{
    input_info info;
    if( str[0] == '!'&& ! input_info_stack[-1]->lock)
    {
        dispatch_to_bottom(str[1..]);
    } else {
        if ( !(info = get_top_handler(1)) ) {
            return;
        }


         if ( info->input_type == INPUT_AUTO_POP ) {
             modal_pop();
         }

         dispatching_to = sizeof(input_info_stack);
         if (arrayp(info->input_func_args)) {
             info->input_func(@(info->input_func_args + ({ str })));
         } else {
             info->input_func(str);
         }         
    }

    if ( this_object() ) {
        modal_recapture();
    }
}

void modal_push_char(function input_func, array(mixed) input_func_args)
{
    push_handler(input_func,input_func_args, 0, 1, 0, INPUT_CHAR_MODE,0);
}

protected string process_input(string str)
{
    dispatch_modal_input(str);
}


void force_me(string str)
{
    dispatch_to_bottom(str);
}


string stat_me()
{
    return sprintf("INPUT STACK:\n%O\n", input_info_stack);
}

protected void clear_input_stack()
{
    input_info top;

    while (sizeof(input_info_stack))
    {
        if (catch {
            top = get_top_handler(1);
            modal_pop();
            top->input_func(-1);
        }) {
            write_file("/tmp/bad_handler",
            sprintf("Error in input_func(-1):\n\tinput_func: %O\n\tprompt: %O\n", top->input_func, top->prompt));
        }
    }
}

int modal_stack_size()
{
    return sizeof(input_info_stack);
}

void save_me();
object query_shell_ob();

int screen_width;

void set_screen_width( int width )
{
    screen_width = width;
    this_user()->save_me();
}

int query_screen_width()
{
    return screen_width ? screen_width : 79;
}

void update_translations() {

    string code;
    string value;
    int i;
    int i2;
    
    if (!colors) colors = ([]);
    colors = ANSI_D->defaults() + colors;
    
    if (query_shell_ob() && query_shell_ob()->get_variable("ansi")) {
        translations = ANSI_D->query_translations()[0];
    } else {
        translations = ANSI_D->query_translations()[1];
    }
    translations = copy(translations);
    
    for(i=0;i<sizeof(indices(colors));i++) {
        code = indices(colors)[i];
        value= colors[code];
    
        array(string) parts = map(explode(value, ","), upper_case);
        string val = "";

        for(i2=0;i2<sizeof(parts);i2++) {
           string item = parts[i2];
        
if (translations[item])
val += translations[item];
}
translations[code] = val;
    }
}

void set_colour(string which, string what) {
    colors[upper_case(which)] = what;
    update_translations();
    save_me();
}

string query_colour(string which) {
    return colors[which];
}

array query_colors() {
    return keys(colors);
}

void remove_colour(string which) {
    map_delete(colors, upper_case(which));
    /* just in case */
    map_delete(colors, lower_case(which));
    map_delete(colors, which);
    update_translations();
    save_me();
}

void do_receive(string msg, int msg_type) 
{
    if (msg_type & NO_ANSI) {
        if (msg_type & NO_WRAP) {
            receive(msg);
        } else {
            receive(wrap(msg, query_screen_width()));
        }
    } else {
        int indent = (msg_type & MSG_INDENT) ? 4 : 0;
        int wrap = (msg_type & NO_WRAP) ? 0 : query_screen_width();
        receive(terminal_color(msg + "%^RESET%^",
            translations, wrap, indent));
    }
}

void receive_inside_msg(string msg, array(object) exclude, int message_type,
  mixed other)
{
    do_receive(msg, message_type);
}

void receive_outside_msg(string msg, array(object) exclude, int message_type,
  mixed other)
{
    do_receive(msg, message_type);
}

void receive_remote_msg(string msg, array(object)|void exclude, int|void message_type,
  mixed|void other)
{
    do_receive(msg, message_type);
}

void receive_private_msg(string msg, int|void message_type, mixed|void other)
{
    do_receive(msg, message_type);
}

void receive_message (string msg, mixed|void msg_class)
{
    receive(msg);
} 

void catch_tell( string message ) 
{
    receive(message);
}