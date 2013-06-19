/* ========================================================================== */
/*                                                                            */
/*   rc.runonce.pike                                                                  */
/*   (c) 2010 Ralph Ritoch                                                    */
/*                                                                            */
/*   runlevel service                                                         */
/*                                                                            */
/* ========================================================================== */

#include <stdlib.h>
#include <stdio.h>
#include <kernel.h>
#include <default_paths.h>
#include <shell.h>

void welcome() {
 write("\n\n     Pike-OoPosix system startup\n\n");
}

int done() {
 printf("System startup complete!\n");
 return -1;
}

int main(int argc, array(string) argv) {
 string default_runlevel;
 
 welcome();
 
 default_runlevel = "5";
 
 executef("%s/rc.d/rc %s",etcdir,default_runlevel);
 
 kernel()->make_user("console","console","console",1);
 
 return done();
  
}
