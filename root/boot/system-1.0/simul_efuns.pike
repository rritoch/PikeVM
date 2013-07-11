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

int function_exists(string str, object ob)
{
    return functionp(ob[str]);
}

mixed call_other(object ob, string fun, mixed ... args) 
{
   string src;
   object obc;
   program p;
   mixed ret;
   
   int i;
   array(string) arga_enc = ({});
        
   for(i = 0; i < sizeof(args); i++) {
      arga_enc[i] = "args["+i+"]";
   }
   
   src = "mixed foo(object ob, array(mixed) args) { return ob->"
         +fun
         +"("
         + (arga_enc * ",")
         + ");}";
      
    p = compile_string(src);
    obc = p();
    ret = obc->foo(ob,args);
    destruct(obc);    
    return ret;   
}

void load_simul_efuns(array(object) init_ob,mixed lconstants) {
 
 init_process = init_ob;
 
 orig_constants = copy_value(lconstants);
 load_kernel_overrides();
 
 // Functions
 
 add_constant("function_exists",function_exists);
 add_constant("call_other",call_other);
     
 //orig_constants["add_constant"]("call_out",this->do_call_out);
}
