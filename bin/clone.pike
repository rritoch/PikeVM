/* ========================================================================== */
/*                                                                            */
/*   clone.pike                                                                */
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
 object ob;
 
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
 
 if (!p) {
  printf("error: Program failed to load!\n");
  return 1;
 }
 
 err = catch {
  ob = p();
 };

 if (err) {
  printf("error: %O\n",err);
  return 1;
 }
 
 if (zero_type(ob)) {
  printf("object self destructed!\n");
  return 1;
 } 
 
 printf("created object: %s\n",kernel()->describe_object(ob));
 return 0;
}
