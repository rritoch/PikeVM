
#include <daemons.h>
#include <config.h>
#include <commands.h>
#include <security.h>

string query_userid();

void set_userid(string new_name);
void save_me();
void restore_me(string some_name, int preserve_vars);
void userinfo_handle_logon();
void sw_body_handle_existing_logon(int);

void modal_push(function input_func,
                        array(mixed) input_func_args,
                        mixed prompt,
                        int|void secure,
                        function|void return_to_func,
                        array(mixed)|void return_to_func_args
                        );
void modal_func(function input_func,
                        array(mixed) input_func_args,
                        mixed prompt,
                        int|void secure,
                        int|void lock);
void modal_pop();
void modal_recapture();
mixed unguarded(mixed priv, function fp);
void initialize_channels();
//void display_didlog();

/* Login modes */
#define TIMEOUT -1
#define INITIAL_PROMPT 0
#define NAME_PROMPT 1
#define CONFIRM_NEW_NAME 2
#define NEW_PASSWORD 3
#define CONFIRM_PASSWORD 4
#define GET_PASSWORD 10

private string password;


/* Do not remove the headers from this file! see /USAGE for more info. */

/*
** loginfail.c -- record/manage login/su failure information
**
** 10-Jun-95. Deathblade. Created.
*/

#include <log.h>


string query_userid();
void save_me();

private array(mixed) failures = ({ });
private int notify_time;


protected final void register_failure(string addr)
{
    string s;

    if(!arrayp(failures))
      failures = ({});
    failures += ({ ({ time(), addr }) });
    save_me();

    s = sprintf("%O: %O from %O\n", query_userid(), ctime(time()), addr);
    //LOG_D->log(LOG_LOGIN_FAILURE, s);
}

final array(mixed) query_failures()
{
    return copy_value(failures);
}

final void clear_failures()
{
#ifdef NEED_UNRESTRICTED_PLAYER_CMD
    if ( !check_privilege(query_userid()) )
#endif
    if ( this_user() != this_object() )
    {
error("* Security violation: you cannot clear this info\n");
    }

    failures = ({ });
    save_me();
}

private mixed check_time(mixed arg) 
{
	return arg[0] > notify_time;
}

protected final void report_login_failures()
{
    int count;

    if ( !sizeof(failures) )
return;

    count = sizeof(filter_array(failures, check_time));
    if ( !count )
return;

/*
    printf("You had " +
M_GRAMMAR->number_of(count, "failed login attempt") +
" since your last login.\n");
*/

    printf("You had %O failed login attempts since your last long\n",count);

    
    notify_time = time();
    save_me();
}

private final void get_lost_now()
{
   destruct();
}

private int noop() 
{
   return 1;
}

private final void get_lost()
{
    remove_call_out();
    modal_func(noop,({}), "");
    call_out(get_lost_now, 2);
}

final int matches_password(string str)
{
   return crypt(str,password);
}

final void set_password(string str)
{
    
    //if(base_name(previous_object()) != CMD_OB_PASSWD) {
        error("illegal attempt to set a password\n");
    //}
  

   password = crypt(str);
   save_me();
}

private final int check_site(string|void name)
{

#ifdef BANISH_D
   if(BANISH_D->check_site())
   {
      if(BANISH_D->check_registered(0,name))
         return 1;
      return 0;
   }
#endif   

   return 1;
}

private final int valid_name(string str)
{
   int len;

#ifdef BANISH_D
   if(BANISH_D->check_name(str))
   {
      write("Sorry, that name is forbidden by the implementors. Please choose another.\n");
      return 0;
   }
#endif
   
   if(!check_site(str))
   {
      printf("Sorry, your site has been banished. To ask for\n"
             "a character, please mail %s.\n",             
             ADMIN_EMAIL);
      get_lost();
      return 0;
   }

   len = strlen(str);
   if(len > 12)
   {
      write("Sorry, that name's too long. Try again.\n> ");
      return 0;
   }

   
   if(!regexp(str, "^[a-z]+$"))
   {
      write("Sorry, that name is forbidden by the implementors. Please\n"
            "choose a name containing only letters.\n");
      return 0;
   }
   

   return 1;
}

private final void initialize_user() 
{
    initialize_channels();
    //display_didlog();
}

private final int check_special_commands(string arg)
{
   array(string) b;

   switch(arg)
   {
      case "who":
         b = bodies()->query_name();
         b -= ({ "Someone" });
         b -= ({ });
         b-= ({ 0 });
         switch(sizeof(b))
{
            case 0:
               write("No one appears to be logged on.\n");
               break;

            case 1:
               printf("Only %s is currently on.\n", b[0]);
               break;

            default:
               printf("The following people are logged on:\n%s\n",
implode(b,", "));
               break;
         }

         return 0;

      case "":
      case "quit":
      case "exit":
      case "leave":
         write("Bye.\n");
         get_lost();
         return 0;

      default:
         return 1;
   }
}

private final void modify_guest_userid()
{
   array(string) userids = users()->query_userid();

   for(int i = 1; ; ++i)
   {
      if(member_array("guest" + i, userids) == -1)
      {
         set_userid("guest" + i);
         save_me();
         return;
      }
   }
}


private final void login_handle_logon(int state, mixed extra, string|void arg)
{

#ifdef DEBUG_LOGIN
write(sprintf("%O(%O) called\n",login_handle_logon,({ state, extra, arg })));
#endif

    arg = rtrim(arg);
   switch (state)
   {
#ifdef WELCOME_DIR   
      array(string) foo;
#endif

      case INITIAL_PROMPT:
      
#ifdef DEBUG_LOGIN
write(sprintf("%O: INITIAL_PROMPT\n",login_handle_logon));
#endif
      
/* setup timeout */
call_out(login_handle_logon,  LOGIN_NAME_WAIT, TIMEOUT );

write("");
#ifdef WELCOME_DIR
         foo = get_dir(WELCOME_DIR + "/");
         if(sizeof(foo))
           write(read_file(absolute_path(WELCOME_DIR + "/" + choice(foo))));
#else
         //write(read_file(WELCOME_FILE));
#endif

         printf("System is running %s on %s\n\n",
                "PikeVM", version());


         write("Hello,\n");

         modal_push(login_handle_logon, ({ NAME_PROMPT, 0 }), LOGIN_PROMPT);
        
         modal_recapture();
         break;

        /******************* NAME PROMPT **********************/
      case NAME_PROMPT:
                  
         if(!arg || arg == "")
         {
            write("Sorry, everybody needs a name here. Please try again.\n");
            return;
         }

         arg = lower_case(arg);
         if(!check_special_commands(arg))
            return;
         if(!valid_name(arg))
            return;
         if(file_size(LINK_PATH(arg) + __SAVE_EXTENSION__ ) <= 0)
         {
            modal_func(login_handle_logon, ({ CONFIRM_NEW_NAME, arg }),
                          "Is '" + capitalize(arg) + "' correct? ");
            return;
         }

         if(arg == "guest" && !check_site()) {
            return;
         }

         restore_me(arg, 0);

         if(arg == "guest")
         {
            modify_guest_userid();
            modal_pop();
            sw_body_handle_existing_logon(1);
            return;
         }

         modal_func(login_handle_logon, ({ GET_PASSWORD, 0 }), "Password: ", 1);

         remove_call_out(); /* all call outs */
         call_out(login_handle_logon, LOGIN_PASSWORD_WAIT,-1);
         break;

        /************ IS 'NAME' CORRECT? ************/
      case CONFIRM_NEW_NAME:
         arg = lower_case(arg);
         switch(arg)
         {
            case "n":
            case "no":
            case "nay":
               modal_func( login_handle_logon, ({ NAME_PROMPT, 0 }),
                             "Please enter your name (preferably correctly this time): ");
               break;

            case "y":
            case "yes":
            case "aye":
#ifdef NO_NEW_PLAYERS

#ifdef GUEST_D
               if(GUEST_D->guest_exists(extra))
               {
                  write("Access granted.\n");
                  GUEST_D->remove_guest(extra);
               }
               else
               {
#endif               
                  write("Unfortunately, "+mud_name()+" is still in the "
                        "developmental stage, and is not accepting new users. "
                        "If it is urgent, please use the guest character.\n");
                  get_lost();
                  return;
#ifdef GUEST_ID                  
               }
#endif               
#endif /* NO_NEW_PLAYERS */

               set_userid(extra);

               write("\nA new player in our midst!\n");

               modal_func(login_handle_logon, ({ NEW_PASSWORD, 0 }),
                          "Please enter your password: ", 1);
               break;

            case "maybe":
            case "possibly":
            case "mu":
            case "perhaps":
               write("You can play games later. ");
               break;
            default:
               write("Please answer Yes or No.\n");
               break;
         }
         break;

      /************ NEW PASSWORD *****************/
      case NEW_PASSWORD:
         if(strlen(arg) < 5)
         {
            write("Your password must have at least 5 characters in it.\n");
            return;
         }

         write("\n"); /* needed after a no-echo input */

         modal_func(login_handle_logon, ({ CONFIRM_PASSWORD, crypt(arg) }),
                       "Again to confirm: ", 1);
         break;

         /************ CONFIRM PASSWORD *************/
      case CONFIRM_PASSWORD:
         if(!crypt(arg,extra))
         {
            write("\nPasswords have to match.\n");

            modal_func(login_handle_logon, ({ NEW_PASSWORD, 0 }),
                          "Password: ", 1);
            return;
         }

         password = extra;
         write("\n");

         modal_pop();

         userinfo_handle_logon();
         break;

         /************ PASSWORD PROMPT **************/
      case GET_PASSWORD:
         if(matches_password(arg))
         {

            modal_pop();
            
            initialize_user();
            sw_body_handle_existing_logon(0);
            return;
         }

         register_failure(query_ip_name(this_object()));
         if(extra == 2)
         {
            write("\nYou're just too much for me.\nSorry.\n");

            get_lost();
            return;
         }

         write("%s","\nHmmm.....\nI'll give you another chance.\n");
#ifdef DEBUG_LOGIN
         write("password = %O\n",password);
#endif
         modal_func( login_handle_logon, ({ GET_PASSWORD, extra + 1 }),
                       "Password: ", 1);
         break;

      case TIMEOUT: /* The timer has expired */
         write("\nSorry, you've taken too long.\n");
         get_lost();
         break;
   }
}

final void logon()
{
#ifdef DEBUG_LOGIN
    kernel()->console_write(sprintf("%O: %O called by %O\n",this_object(),logon,previous_object()));
#endif        
    if (previous_object() == kernel()) {
        login_handle_logon(INITIAL_PROMPT, 0);
    }
}

protected final mapping save_login(int|void flags) 
{
	mapping data = ([]);
    data["password"] = password;
    return data;
}

void restore_login(mapping data, int|void flags) 
{
     password = data["password"];
}

