/* ========================================================================== */
/*                                                                            */
/*   load.pike                                                                */
/*   (c) 2010 Ralph Ritoch                                                    */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */


#include <stdio.h>

int main(int argc, array(string) argv, mixed env) { 
 program|int p;
 string name;
 string cwd;
 mixed err;
 
 cwd = env["CWD"];
 
 if (argc != 2) {
  write("Usage: %s [program]");
  return 1;
 }
 name = combine_path(cwd,argv[1]);
 
 err = catch {
  p = (program)name;
 };
  
 if (err) {
  printf("error: %O\n",err);
  return 1;
 }
 
 return 0;
}
