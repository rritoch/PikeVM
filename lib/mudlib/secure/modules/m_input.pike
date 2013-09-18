
private object	input_user;

protected final void modal_push(
    function input_func,
    array(mixed) input_func_args,
    mixed prompt_func,
    function|void secure,
    function|void return_to_func,
    array(mixed)|void return_to_func_args
    )
{
    if ( input_user && this_user() != input_user ) {
        error("user mismatch");
    }

    input_user = this_user();
    input_user->modal_push(input_func, input_func_args, prompt_func, secure, return_to_func,return_to_func_args);
}

protected final void modal_push_char(function callback)
{
    input_user->modal_push_char(callback);
}

protected final void modal_pop()
{
    input_user->modal_pop();
    input_user = 0;
}

protected final void modal_func(
    function input_func,
    mixed prompt_func,
    int secure
    )
{
    input_user->modal_func(input_func, prompt_func, secure);
}

protected final void modal_simple(
    function input_func,
    array(mixed) input_func_args,
    mixed prompt,
    int|void secure
    )
{
    this_user()->modal_simple(input_func, input_func_args,prompt, secure);
}

protected final void modal_pass(string str)
{
    input_user->modal_pass(str);
}

protected final int modal_stack_size()
{
    return input_user->modal_stack_size();
}


protected final void input_one_arg(
    string arg_prompt,
    function fp,
    array(mixed)|int fp_args,
    string arg
    )
{    
    if ( !arg )
    {
        modal_simple(fp, fp_args,arg_prompt);
        return;
    }
    fp(arg);    
}

private final void rcv_first_of_two(string arg2_prompt,
function fp,
string arg1)
{
    string arg2;

    if ( arg1 == "" )
    {
        write("Aborted.\n");
        return;
    }

    if ( sscanf(arg1, "%s %s", arg1, arg2) == 2 )
    {
        fp(arg1,arg2);
    } else {      
        modal_simple(fp, ({ arg1 }), sprintf(arg2_prompt, arg1));
    }
}

protected final void input_two_args(
    string arg1_prompt,
    string arg2_prompt,
    function fp,
    string arg
    )
{
    if ( arg ) {
        string arg2;

        if ( sscanf(arg, "%s %s", arg, arg2) == 2 ) {
            fp(arg,arg2);
        } else {
            rcv_first_of_two(arg2_prompt, fp, arg);
        }
    } else {
        modal_simple(rcv_first_of_two, ({arg2_prompt, fp }), arg1_prompt);
    }
}

private final void rcv_last_of_three(string arg3_prompt,
    function fp,
    string arg1,
    string arg2
)
{
    string arg3;
  
    if ( arg1 == "" ) {
        write("Aborted.\n");
        return;
    }

    if ( sscanf(arg2, "%s %s", arg2, arg3) == 2 ) {
        fp(arg1, arg2, arg3);
    } else {
        modal_simple(fp, ({arg1, arg2 }),
        sprintf(arg3_prompt, arg2));
    }
}

private final void rcv_second_of_three(string arg2_prompt,
    string arg3_prompt,
    function fp,
    string arg)
{
    string arg1, arg2, arg3;

    if ( sscanf(arg, "%s %s %s", arg1, arg2, arg3) == 3 )
    {
        fp(arg1, arg2, arg3);
    }
    else if ( sscanf(arg, "%s %s", arg1, arg2) == 2 )
    {
        rcv_last_of_three(arg3_prompt, fp, arg1, arg2);
    }
    else
    {
        modal_simple(rcv_last_of_three, ({arg3_prompt, fp, arg }),
        sprintf(arg2_prompt, arg1));
    }
}

protected final void input_three_args(
    string arg1_prompt,
    string arg2_prompt,
    string arg3_prompt,
    function fp,
    string arg
    )
{
    string arg1, arg2, arg3;

    if ( arg ) {
        if ( sscanf(arg, "%s %s %s", arg1, arg2, arg3) == 3 ) {
            fp(arg1, arg2, arg3);
        } else if ( sscanf(arg, "%s %s", arg1, arg2) == 2 ) {
            rcv_last_of_three(arg3_prompt, fp, arg1, arg2);
        } else {
            rcv_second_of_three(arg2_prompt, arg3_prompt, fp, arg);
        }
    } else {
        modal_simple(rcv_second_of_three, ({arg2_prompt, arg3_prompt, fp }),
            arg1_prompt);
    }
}