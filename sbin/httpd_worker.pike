/* ========================================================================== */
/*                                                                            */
/*   httpd_worker.c                                                           */
/*   (c) 2013 Ralph Ritoch                                                    */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */

#include "/includes/devices.h"

#define DEBUG_REQUEST

private string request;
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
    request="";                
}

string get_name() 
{
    return "httpduser";
}

void save() 
{    
}

void have_request(string rqst) 
{
    request = strip_nl(rqst);
#ifdef DEBUG_REQUEST 
    kernel()->console_write("Have request (%s)\n",request);
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

void do_login() {
    input_to(have_request,INPUT_IGNORE_BANG,"");  
}

void handle_call_out(object sh_obj, function f, mixed ... args) {
 if (sh_obj && !zero_type(sh_obj) && functionp(sh_obj->handle_call_out)) {
  sh_obj->handle_call_out(f,@args);
  return;
 }
 f(@args);
 return;
}

private void welcome() 
{
   // no action
}

void receive_link() { 
    welcome();
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
