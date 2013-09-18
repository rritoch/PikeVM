
#include <config.h>
#include <daemons.h>
#include <security.h>

string query_userid();

void save_me();
void remove();
void initialize_user();
void report_login_failures();

void modal_simple(function input_func,
    array(mixed)|int input_func_args, 
    mixed prompt, 
    int|void secure,
    int|void lock);
void modal_push(function input_func,
                        mixed prompt,
                        int secure,
                        function return_to_func);
void modal_pop();

//fake!
int interactive(mixed i);

//void set_privilege(mixed priv);	// from M_ACCESS
//mixed unguarded(mixed priv, function fp);

void start_shell();
void run_login_script();

int query_n_gen();

/*
** The file name for the body object
*/
private string body_fname;

/*
** The body object once it has been instantiated
*/
private object body;

string query_body_fname()
{
   return body_fname;
}

object query_body()
{
   return body;
}

protected void set_body_fname(string new_body_fname)
{
   body_fname = new_body_fname;
}

final void switch_body(string new_body_fname, int permanent)
{
   object where;
   object old_body;

   if(previous_object() != body && this_body() != body) {
      error("security violation: bad body switch attempt\n");
   }

   where = body ? environment(body) : VOID_ROOM;

   if(permanent && new_body_fname)
   {
      body_fname = new_body_fname;
      save_me();
   }

   if(!new_body_fname)
      new_body_fname = body_fname;

   old_body = body;
   body = ((program)new_body_fname)(query_userid());
   
   if(old_body)
   {
      old_body->move(VOID_ROOM);
      if(old_body)
           catch(destruct(old_body));
   }
   
   report_login_failures();
   
   body->su_enter_game(where);
}


/*
** Functions to get the body set up and the user into the game.
*/
private void incarnate(int is_new, string bfn)
{
    if (!stringp(body_fname)) {
    	body_fname = "/lib/mudlib/body.pike";
    }
    
   if(bfn)
      body_fname = bfn;

   body = ((program)body_fname)(query_userid());
   
#ifdef LAST_LOGIN_D
   LAST_LOGIN_D->register_last(query_userid(), query_ip_name(this_object()));
#endif
   
   if(query_n_gen() != -1)
      body->set_gender(query_n_gen());
   save_me();

   start_shell();
   body->enter_game(is_new);
   run_login_script();

   if(is_new)
   {
#ifdef USE_STATS
      this_body()->init_stats();
#endif
      body->save_me();
      
      initialize_user();
   }
}

void sw_body_handle_existing_logon(int);

private void rcv_try_to_boot(object who, string answer)
{
   answer = lower_case(answer);
   if( answer == "yes" || answer == "y" )
   {

     if(who) {
         who->receive_private_msg("You are taken over by yourself, or something.\n");
         body=who->query_body();
         who->steal_body();
         start_shell();
         body->reconnect(this_object());
         return;
     }
     sw_body_handle_existing_logon(0);
     return;
   }
   if(answer == "n" || answer == "no")
   {
      if(adminp(query_userid()))
      {
         sw_body_handle_existing_logon(1);
         return;
      }

      write("Try another time then.\n");
      destruct(this_object());
   }

   write("please type 'y' or 'n' >");
   modal_simple(rcv_try_to_boot, ({ who }),0,0,1);
}

protected void sw_body_handle_existing_logon(int enter_now)
{
   remove_call_out(); /* all call outs */

   if(!enter_now)
   {

      array(object) users;
      array(string) ids;
      int idx;
      object the_user;

      users = children(USER_OB) - ({ this_object() });
      ids = users->query_userid();
      if((idx = member_array(query_userid(), ids)) != -1)
      {
         if(!interactive(the_user = users[idx]))
         {
            if(body = the_user->query_body())
            {
               master()->refresh_parse_info();
               the_user->steal_body();
               start_shell();
               body->reconnect(this_object());
               return;
            }
         }
         else
         {
            write("\nYou are already logged in!\nThrow yourself off? ");
            modal_simple(the_user->rcv_try_to_boot,0,0,1);
            return;
         }
      }
   }
   
   write("\n"+read_file(MOTD_FILE));

   report_login_failures();
   
   incarnate(0, 0);
}

/* when a user reconnects, this is used to steal the body back */
void steal_body()
{
   /* only USER_OB can steal the body. */
   if(object_program(previous_object()) != USER_OB ) {
      error("illegal attempt to steal a body\n");
   }

   body = 0;
   remove();
}

void create_body()
{
   //array(string) races = RACE_D->query_races();
   function when_done = incarnate;
   array(mixed) when_done_args = ({ 1 });
   int width = 0;
            
   incarnate(1,BODY_OB);
}

protected void sw_body_handle_new_logon()
{
   int autoadm = 0;
   int superadm = 0;
   
   remove_call_out(); /* all call outs */

   save_me();
   
#ifdef AUTO_ADMIN
    /* auto-wiz everybody as they are created */
    autoadm = 1;
#endif

    
    /* auto-admin the first user if there are no admins */
    array(string) members = SECURE_D->query_group_members("developer");
    if(!sizeof(members)) {
        autoadm = 1;
        superadm = 1;              
    }

    if (autoadm) {
      
        SECURE_D->add_user_to_group(query_userid(),"developers");
        if(!adminp(query_userid())) {
            SECURE_D->create_admin(query_userid());
        }                                                                             
                
        write(">>>>> You've been granted automatic guest developer status. <<<<<\n");        

        if (superadm) {
            SECURE_D->add_user_to_group(query_userid(),1);
            if(!superadminp(query_userid())) {
                SECURE_D->create_superadmin(query_userid());
            }        
            write( ">>>>> You have been made super admin. <<<<<\n");
        }                                     
    }
    
   /* adjust the privilege of the user ob */
   
   /*
   if(adminp(query_userid()))
      set_privilege(1);
   else
      set_privilege(query_userid());
   */
   
   create_body();
}