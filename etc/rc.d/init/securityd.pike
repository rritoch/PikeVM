/* ========================================================================== */
/*                                                                            */
/*   securityd.pike                                                             */
/*   (c) 2010 Ralph Ritoch                                                    */
/*                                                                            */
/*   Description                                                              */
/*    securityd service controller                                              */
/* ========================================================================== */

#include <default_paths.h>
#include <service.h>
#include <stdio.h>

int start() {
 program p;
 object secd;
 mixed err;
 
 printf("Starting service securityd: ");
 
 p = (program)sprintf("%s/securityd.pike",sbindir);
 if (!programp(p)) {  
  return fail();
 }
 err = catch {
  secd = p();
 };
 if (err) {  
  return fail();
 }
 kernel()->describe_object(secd);
 return success(); 
}

int stop() {
 object ob;
 program p;
 printf("Stopping service securityd: ");
 ob = kernel()->find_object(sprintf("%s/securityd.pike(1)",sbindir));
 if (objectp(ob) && !destructedp(ob)) {
  destruct(ob);
  p = kernel()->find_program(sprintf("%s/securityd.pike",sbindir));
  if (p) {
   kernel()->unload_program(p);
  }
  return success();
 }
 return fail();
}

int status() {
 printf("Status of securityd: ");
 if (kernel()->find_object("/sbin/securityd.pike(1)")) {
  printf("[running]\n");
 } else {
  printf("[stopped]\n");
 }
 
 return 0;
}


int usage(array(string) argv) { 
 fprintf(2,"usage: %s [start/stop/status]\n",argv[0]);
 return 1;
} 

int main(int argc, array(string) argv, mixed env) {

 if (argc != 2) {  
  return usage(argv);
 }

 switch(argv[1]) {
  case "start":
   return start();
   break;
  case "stop":
   return stop();
   break;
  case "status":
   return status();
  default:
   return usage(argv);
   break;   
 }
 return 1; 
}
