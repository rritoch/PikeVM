
#include "/includes/config.h"
#include "/includes/domain/save.h"

inherit "user/io.pike";
inherit "user/sw_body.pike";
inherit "user/sw_shell.pike";
inherit "user/sw_user.pike";
inherit "user/login.pike";
inherit "user/userinfo.pike";

inherit "/lib/domain/modules//m_save.pike";

inherit "user/channels.pike";

private string|int	userid;

string query_userid()
{
    return userid;
}

protected void set_userid(string new_userid)
{
    userid = new_userid;
}

void remove()
{
    object body = query_body();

    if ( body ) {  
        destruct(body);
    }

    remove_call_out();
    stop_shell();
    destruct();
}

void quit()
{
    object body = query_body();

    if ( body ) {
        body->quit();
    }

    remove();
}

void save_me()
{    
    if (stringp(userid)) {
    	
    	if (!is_directory(dirname(LINK_PATH(userid)))) {
    	   mkdir(dirname(LINK_PATH(userid)),1);	
    	}
        save_object(LINK_PATH(userid) + __SAVE_EXTENSION__,F_SAVE_NULL);
    }      
}

private mapping(string:mixed) save_core(int flags) 
{
	mapping(string:mixed) data = ([]);	
	if (stringp(userid) || F_SAVE_NULL) {
	    data["userid"] = userid;
	}
	return data;
}

private void restore_core( mapping(string:mixed) data,int flags) 
{		
	if ((!(stringp(userid)))  || (flags & F_OVERWRITE_VARS)) {
	    userid = data["userid"];	
	} 	
}

protected final void restore_me(string some_userid, int|void preserve_vars)
{
	restore_object(LINK_PATH(some_userid) + __SAVE_EXTENSION__, preserve_vars);               
}

/**
 * Called when link is broken..
 */

void net_dead() 
{
    object body = query_body();

    if ( body )
    {
        body->net_dead();
        call_out(remove, 300);
    } else {
        remove();
    }
}

void create() 
{
	add_save_hooks(save_userinfo,save_login,save_core);
	add_restore_hooks(restore_userinfo,restore_login,restore_core);   
}

protected void destroy() 
{
	object link = this_link();
	kernel()->console_write("Breaking link %O\n",link);
	destruct(link);
	destruct();
}