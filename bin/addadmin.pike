/* ========================================================================== */
/*                                                                            */
/*   addadmin.pike                                                            */
/*   (c) 2010 Ralph Ritoch                                                    */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */

#include <stdio.h>

#define SECURITYD (object)"/root/security.pike(1)"

int main(int argc, array(string) argv, mixed env) {
 string cwd,group_id,user_id;
 object securityd; 
 mixed err;
  
 if (argc != 3) {  
  fprintf(stderr,"usage: %s [user_id] [group]\n",argv[0]);
  return 1;
 }

 securityd = SECURITYD; 
 if (!securityd || destructedp(securityd)) {
  fprintf(stderr,"securityd died!\n");
  return 1;
 }


 cwd = env["CWD"];  
 group_id = argv[2]; 
 user_id = argv[1];
  
 err = securityd->add_admin_to_group(user_id,group_id);
 if (err) {
  fprintf(stderr,"Operation Failed! %O\n",err);
  return 1;  
 }

 printf("User %O was added to group %O as a member.\n",user_id,group_id);
 
 return 0;   
}
