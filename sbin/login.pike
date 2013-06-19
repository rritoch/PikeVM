/* ========================================================================== */
/*                                                                            */
/*   Filename.c                                                               */
/*   (c) 2001 Author                                                          */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */

#include "/includes/devices.h"

//#define DEBUG_LOGIN

private string user;
private string pass;
private int fail;
private int max_attempts;
private object shell_ob;

private object link_in;
private object link_out;
private object link_error;

private int respawn;

int recv_msg(mixed ... msg) {   
    return write(@msg);
}

protected void handle_input_to_response(string data, function fun, mixed ... args) {
 // can verify coming from 
 fun(data,@args);
}

void handle_input_to(function fun, 
              void|int flag, 
              void|string|function prompt, mixed ... args) {
 
 link_in->input_to(handle_input_to_response,flag,prompt,fun,@args);

}


private void flush() {
    user="";
    pass="";            
}

private int authenticate(string username, string password) {

            
    string filename = "/var/userdata/"+username+".o";
    string encdata = read_file(filename);        
    if (0 != encdata) {
        mapping data = decode_value(encdata);                
        if (!zero_type(data["pass"])) {
            return password == data["pass"];
        }                  
    }
    return 0;    
    //return (username == "test" && password == "test"); 
}

string get_name() 
{
    return user ? user : "";
}

void save() 
{
    if (user && user !="") {        
        mapping data = ([       
           "pass":pass    
        ]);
    
        string filename = "/var/userdata/"+user+".o";        
        string encdata = encode_value(data);
        write_file(filename,encdata);        
        write("saved.\n");                        
    }    
}

void have_username(string username) {
 user = strip_nl(username);
#ifdef DEBUG_LOGIN 
 write("Have username!\n");
#endif 
}

private string strip_nl(string msg) {
 
 if (sizeof(msg) > 1) {
  if (msg[<1..] == "\r\n") {
   return msg[..<2];
  }
 }
 
 if (sizeof(msg)) {
  if (msg[<0..<0] == "\n") {
   return msg[..<1];
  }
 }
 
 return msg;
}

void stop_login() {
 destruct();
}

void monitor_shell() {
 if (zero_type(shell_ob)) {
  if (respawn) {
   welcome();
   fail = 0;
   max_attempts = 0;
   do_login(); 
  } else {
   // release link!
  } 
 } else {
  call_out(monitor_shell,2);
 }
}

void login_success() {
    program p;
    mixed err;
 
    // load data?
    
 //write("Login successful!\n");
 call_out(monitor_shell,2);
 
 p = (program)"/bin/sh.pike";
 
 if (programp(p)) {
  shell_ob = p();
  //write("login_success: %O : %O",shell_ob,indices(shell_ob));
  err = catch {
   shell_ob->main(1,({ "/bin/sh" }),([ "stdin" : "/dev/console", "stdout" : "/dev/console", "stderr" : "/dev/console" ]));
  };
  if (err) {
   write("login_success: error %O",err);
  }
 }
}

void have_password(string password) {
#ifdef DEBUG_LOGIN
 write("Have password!\n");
#endif 
 pass = strip_nl(password);
 if (!authenticate(user,pass)) {
  fail++;
  if (max_attempts && (fail > max_attempts)) {
   stop_login();
   return;
  }
  do_login();
 } else {
  login_success();
 } 
}


void do_login() {
 input_to(have_username,INPUT_IGNORE_BANG | INPUT_PROMPT,"Username: ");
 input_to(have_password, INPUT_NOECHO | INPUT_IGNORE_BANG | INPUT_PROMPT | INPUT_APPEND,"Password: "); 
}

void handle_call_out(object sh_obj, function f, mixed ... args) {
 if (sh_obj && !zero_type(sh_obj) && functionp(sh_obj->handle_call_out)) {
  sh_obj->handle_call_out(f,@args);
  return;
 }
 f(@args);
 return;
}

private void welcome() {
 //write("%O\n",backtrace());
 //write("Pike Login System. %O\n",this_user());
 write("Pike Login System.\n");
}

void receive_link() { 
 welcome();
 fail = 0;
 max_attempts = 0;
 do_login();
} 

mixed get_link() 
{
   return ({ link_in, link_out, link_error });
}

int main(int argc, array(string) argv, mapping env) { 

 return -1;
}

protected void create(mixed link, int persistent) { 
 
 link_in    = link[0];
 link_out   = link[1];
 link_error = link[2];
 
 if (functionp(link_in->grab)) link_in->grab(receive_link);
 if (functionp(link_out->grab)) link_out->grab();
 if (functionp(link_error->grab)) link_error->grab();
 
 respawn = persistent;
}
