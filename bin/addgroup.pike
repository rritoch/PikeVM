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
 string pth,cwd,group_id;
 object securityd;
 int r_flag,w_flag,x_flag;
 mixed err;
 mixed tmp;
 string privs;
  
 if (argc != 4) {  
  fprintf(stderr,"usage: %s [group] [path] [(rwx)]\n",argv[0]);
  return 1;
 }

 err = catch {
  securityd = SECURITYD;
 };
  
 if (!securityd || destructedp(securityd)) {
  fprintf(stderr,"Operation failed: securityd died!\n");
  return 1;
 }


 cwd = env["CWD"];  
 group_id = argv[1]; 
 pth = combine_path(cwd,argv[2]);
 
 r_flag = (sizeof(argv[3]) != sizeof(argv[3] - "r"));
 w_flag = (sizeof(argv[3]) != sizeof(argv[3] - "w"));
 x_flag = (sizeof(argv[3]) != sizeof(argv[3] - "x"));
  
 if (!r_flag && !w_flag && !x_flag) {
  fprintf(stderr,"No valid flags selected!\n");
  return 1; 
 }

 err = catch { 
  securityd->add_group_to_path(group_id,pth,r_flag,w_flag,x_flag);
 };
 
 if (err) {
  if (arrayp(err) && (sizeof(err) == 2) && stringp(err[0])) {
   fprintf(stderr,"Operation failed. %s\n",err[0]);
  } else {
   fprintf(stderr,"Operation failed! %O\n",err);
  }
  return 1;  
 }

 tmp = ({});
 
 if (r_flag) tmp += ({ "read" });
 if (w_flag) tmp += ({ "write" });
 if (x_flag) tmp += ({ "execute" });
 
 privs = tmp[0..<1] * ", ";
 if (sizeof(tmp) > 1) privs += " and ";
 privs += tmp[-1];
  
 printf("Group %O now has %s privileges in %O.\n",group_id,privs,pth);
 
 return 0;   
}
