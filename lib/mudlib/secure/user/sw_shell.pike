
#include <mudlib.h>

string query_userid();
void force_me(string what);
void update_translations();

private object	shell_ob;


final object query_shell_ob()
{
    return shell_ob;
}

protected final void start_shell()
{
    program shell_p;
    
    if ( !shell_ob )
    {
            
        shell_p = adminp(query_userid()) ? ADMIN_SHELL : USER_SHELL;
        
        if (shell_p) {
           shell_ob = shell_p();
        }
    }

    if (shell_ob) {
        shell_ob->start_shell();
    }
    update_translations();
}

protected final void stop_shell()
{
    if ( shell_ob )
shell_ob->remove();
}

protected final void run_login_script()
{
    //string login_file;

    if ( !adminp(query_userid()) )
return;

    // do .login stuff
    /*
    login_file = wiz_dir(this_object()) + "/.login";
    if ( file_size(login_file) > 0)
    {
        map_array(explode(read_file(login_file), "\n"), force_me);
    }
    */
}