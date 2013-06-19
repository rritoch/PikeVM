/* ========================================================================== */
/*                                                                            */
/*   mkdir.pike                                                               */
/*   (c) 2010 Ralph Ritoch                                                    */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */

#include <stdio.h>

int main(int argc, array(string) argv, mixed env) {

 string pth;
 mixed ret;
  
 if (argc != 2) {
  fprintf(stderr,"usage: %s [path]\n",argv[0]);
  return 1;
 }

 pth = argv[1]; 
 if (!zero_type(env["CWD"])) {
  pth = combine_path(env["CWD"],argv[1]);
 } else {
  pth = combine_path("/",argv[1]);
 }

 ret = mkdir(pth);
 if (ret) {
  fprintf(stderr,"Unable to create directory %O.\n",pth);
  return 1;
 }
 printf("Directory %O created.\n",pth);
 return 0;
}
