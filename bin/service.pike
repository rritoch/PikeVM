/* ========================================================================== */
/*                                                                            */
/*   service.pike                                                             */
/*   (c) 2010 Author                                                          */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */

#include <stdio.h>
#include <shell.h>
#include <default_paths.h>

int main(int argc, array(string) argv, mixed env) {
 int ret;
 if (argc != 3) {
  fprintf(2,"usage: %s [service] [start/stop/status]");
  return 1;
 }

 ret = executef("%s/rc.d/init/%s%s %s",etcdir,argv[1],".pike", argv[2]);
 if (ret > 0) {
  return ret;
 }
 return 0; 
}
