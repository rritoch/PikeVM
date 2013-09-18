
#include <config.h>
#include <mudlib.h>
#include <security.h>

void sw_body_handle_new_logon();
object query_body();
void save_me();

void modal_push(function input_func,
                array(mixed) input_func_args,
                        mixed prompt,
                        int|void secure,
                        function|void return_to_func,
                        array(mixed)|void return_to_func_args);
void modal_func(function input_func,
               array(mixed) input_func_args,
                        mixed prompt,
                        int|void secure,
                        int|void lock);
void modal_pop();

/* Modes */
#define GENDER_QUERY 0
#define GOT_GENDER 1
#define GOT_EMAIL 2
#define GOT_REAL_NAME 3
#define GOT_URL 4

/* Properties */
private string email;
private string real_name;
private string url;

// gender?
private int n_gen = -1;

// gender?
protected final int query_n_gen()
{
   return n_gen;
}

final string query_email()
{
    return email;
}

final void set_real_name(string new_name)
{
    if (this_user() != this_object()) {
      error("illegal attempt to set real name\n");
    }

    real_name = new_name;
    save_me();
}

final void set_email(string new_email)
{
    if(this_user() != this_object()) {
        error("illegal attempt to set email address\n");
    }

    email = new_email;
    save_me();
}

final void set_url(string new_url)
{
    if(this_user() != this_object()) {
        error("illegal attempt to set URL\n");
    }

    url = new_url;
    save_me();
}

final string query_url()
{
    return url;
}

protected final void userinfo_handle_logon(int state, mixed extra, string arg)
{
	arg = rtrim(arg);
   switch(state)
   {
      case GENDER_QUERY:
         modal_push(userinfo_handle_logon,({ GOT_GENDER, 0 }),
                       "Are you male or female? ");
         break;

      case GOT_GENDER:
         arg = lower_case(arg);
         if(arg == "y" || arg == "yes")
         {
            write("Ha, ha, ha. Which one are you?\n");
            return;
         }
         if(arg == "n" || arg == "no")
         {
            write("Well, which one would you have liked to be, then?\n");
            return;
         }
         if(arg == "f" || arg == "female")
            n_gen = 2;
         else if(arg != "m" && arg != "male")
         {
            write("I've never heard of that gender. Please try again.\n");
            return;
         }
         else
         {
            n_gen = 1;
         }

         write("\n"
               "The following info is only seen by you and administrators\n"
               " if you prepend a # to your response.\n"
               "\n"
               "You cannot gain developer status without valid responses to these questions:\n");

         modal_func(userinfo_handle_logon, ({ GOT_EMAIL, 0 }),
                       "Your email address: ");
         break;

      case GOT_EMAIL:
         email = arg;
         modal_func( userinfo_handle_logon, ({ GOT_REAL_NAME, 0 }),
                       "Your real name: ");
         break;

      case GOT_REAL_NAME:
         real_name = arg;

         modal_func( userinfo_handle_logon, ({GOT_URL, 0 }),
                       "Your home page address (if any): ");
         break;

      case GOT_URL:
         url = arg;
         modal_pop();

         if(file_size(NEW_PLAYER) <= 0)
         {
            sw_body_handle_new_logon();
            return;
         }

         more_file(NEW_PLAYER, 0, sw_body_handle_new_logon);
   }
}

protected final mapping save_userinfo(int|void flag) 
{
	mapping data = ([]);
	
    data["email"] = email;
    data["real_name"] = real_name;
    data["url"] = url;
    data["n_gen"] = n_gen;
    return data;    
}

protected final void restore_userinfo(mapping data, int|void flag)
{
    email = data["email"];
    real_name = data["real_name"];
    url = data["url"];
    n_gen = data["n_gen"];
}
