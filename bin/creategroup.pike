/* ========================================================================== */
/*                                                                            */
/*   creategroup.pike                                                               */
/*   (c) 2010 Ralph Ritoch                                                    */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */

#include <stdio.h>
#include <security.h>


int main(int argc, array(string) argv, mixed env) {
 string cwd,group_id;
 object securityd; 
 mixed err;
  
 if (argc != 2) {  
  fprintf(stderr,"usage: %s [group]\n",argv[0]);
  return 1;
 }
 err = catch {
  securityd = SECURITYD;
 };
  
 if (!securityd || destructedp(securityd)) {
  fprintf(stderr,"Operation failed: securityd is not running!\n");
  return 1;
 }


 cwd = env["CWD"];  
 group_id = argv[1]; 
  
 err = catch {
  securityd->create_group(group_id);
 };
 
 if (err) {
  if (arrayp(err) && (sizeof(err) == 2) && stringp(err[0])) {
   fprintf(stderr,"Operation Failed! %s\n",err[0]);
  } else {
   fprintf(stderr,"Operation Failed! %O\n",err);
  }
  return 1;  
 }

 printf("Created group %O.\n",group_id);
 
 return 0;   
}
