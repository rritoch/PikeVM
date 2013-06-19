/* ========================================================================== */
/*                                                                            */
/*   Filename.c                                                               */
/*   (c) 2001 Author                                                          */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */

private mixed orig_constants;
private array(object) init_process;

/*
mixed do_file_stat(string x,void|int(0..1) symlink) {
  return kernel()->_file_stat(x,symlink);
}
*/

private void load_kernel_overrides() {
 string str;
 array(string) kc;
 string c;
 string fname;
 
 program p;
 object ob;
 mapping (string:mixed) k;
 
 kc = indices(kernel());
  
 str = "mixed foo() { \nmapping (string:mixed) ret = ([]);";
 
 foreach(kc,c) {
  if (has_prefix(c, "_") && (sizeof(c) > 1)) {
   str += sprintf("ret[\"%s\"] = kernel()->%s;\n",c,c);  
  }
 }

 
 str += "return ret; \n}\n";
 p = compile_string(str);
 ob = p();
 k = ob->foo();
 
 foreach(indices(k),c) {
  if (functionp(k[c])) {
   fname = c[1..];
   add_constant(fname,k[c]); 
  }
 }
 return; 
}

void load_simul_efuns(array(object) init_ob,mixed lconstants) {
 
 init_process = init_ob;
 
 orig_constants = copy_value(lconstants);
 load_kernel_overrides();
     
 //orig_constants["add_constant"]("call_out",this->do_call_out);
}
