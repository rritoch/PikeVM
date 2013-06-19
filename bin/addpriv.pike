/* ========================================================================== */
/*                                                                            */
/*   addpriv.pike                                                            */
/*   (c) 2010 Ralph Ritoch                                                    */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */

#include <stdio.h>

#define SECURITYD (object)"/root/security.pike(1)"

int main(int argc, array(string) argv, mixed env) { 
 string priv_path, priv_id, group_id;
 object securityd; 
 mixed err;
 mixed ret;
  
 if (argc != 4) {  
  fprintf(stderr,"usage: %s [privilege path] [privilege id] [group]\n",argv[0]);
  return 1;
 }

 securityd = SECURITYD; 
 if (!securityd || destructedp(securityd)) {
  fprintf(stderr,"securityd died!\n");
  return 1;
 }
  
 priv_path = argv[1]; 
 priv_id = argv[2];
 group_id = argv[3];
  
 err = catch {
  ret = securityd->assign_privilege(priv_path,priv_id,group_id);
 };
 
 if (err) {
  if (arrayp(err) && (sizeof(err) == 2) && stringp(err[0])) {
    fprintf(stderr,"Operation Failed! %s\n",err[0]);
  } else {
   fprintf(stderr,"Operation Failed! %O\n",err);
  }
  return 1;  
 }

 printf("Privilege %O %O was added to group %O.\n",priv_path,priv_id,group_id);
 
 return 0;   
}
