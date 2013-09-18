/* ========================================================================== */
/*                                                                            */
/*   ftpd.pike                                                             */
/*   (c) 2010 Ralph Ritoch                                                    */
/*                                                                            */
/*   Description                                                              */
/*    ftpd service controller                                              */
/* ========================================================================== */

#include <default_paths.h>
#include <service.h>
#include <stdio.h>

int start() {
 printf("Starting service ftpd: ");
 return daemon(sprintf("%s/ftpd.pike",sbindir)); 
}

int stop() {
 printf("Stopping service ftpd: ");
 return fail();
}

int status() {
 printf("Status of ftp: ");
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
