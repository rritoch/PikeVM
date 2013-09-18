/* ========================================================================== */
/*                                                                            */
/*   verbd.pike                                                             */
/*   (c) 2010 Ralph Ritoch                                                    */
/*                                                                            */
/*   Description                                                              */
/*    verbd service controller                                              */
/* ========================================================================== */

#include <default_paths.h>
#include <service.h>
#include <stdio.h>

int start() {
 printf("Starting service verbd: ");
 return daemon(sprintf("%s/verbd.pike",sbindir)); 
}

int stop() {
 printf("Stopping service verbd: ");
 return fail();
}

int status() {
 printf("Status of verbd: ");
 printf("[unknown]\n");
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
