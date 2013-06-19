/* ========================================================================== */
/*                                                                            */
/*   Filename.c                                                               */
/*   (c) 2001 Author                                                          */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */


int main(int argc, array(string) argv, mixed env) {
 object ob;
 program|int p;
 string name;
 string cwd;
 
 cwd = env["CWD"];
 
 if (argc != 2) {
  write("Usage: %s [object/program]");
  return 1;
 }
 
 if (ob = kernel()->find_object(argv[1],cwd)) {
  name = sprintf("%O",ob);
  destruct(ob);
  if (zero_type(ob)) {
   write("Object %O destroyed!\n",name);
   return 0;
  } else {
   write("Operation failed: Object %O was not destroyed.\n");
   return 1;
  }  
 }
 
 if ((p = kernel()->find_program(argv[1],cwd)) != -1) {
  name = sprintf("%O",p);
  kernel()->unload_program(p);
  write("Program %O destroyed!\n",name);
  return 0;
 }
 
 write("Object or Program not found!\n");
 return 1;
}
