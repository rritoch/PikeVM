/* ========================================================================== */
/*                                                                            */
/*   addgroup.pike                                                               */
/*   (c) 2010 Ralph Ritoch                                                    */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */

#include <stdio.h>
#include <security.h>

int main(int argc, array(string) argv, mixed env) {
 string group_id;
 object securityd; 
 mixed err;
 
 
 array(string) groups;
  
 if (argc != 1) {  
  fprintf(stderr,"usage: %s\n",argv[0]);
  return 1;
 }

 err = catch {
  securityd = SECURITYD;
 };
  
 if (!securityd || destructedp(securityd)) {
  fprintf(stderr,"Operation failed: securityd died!\n");
  return 1;
 }

 err = catch { 
   groups = securityd->list_groups();
 };
 
 if (err) {
  if (arrayp(err) && (sizeof(err) == 2) && stringp(err[0])) {
   fprintf(stderr,"Operation failed. %s\n",err[0]);
  } else {
   fprintf(stderr,"Operation failed! %O\n",err);
  }
  return 1;  
 }
 
  foreach(groups,group_id) {
       printf("%s\n",group_id);
  }
   
 return 0;   
}
