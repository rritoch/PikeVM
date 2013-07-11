/**
 * Simul Efuns
 *  
 */
 
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

array(mixed) map_array(array(mixed) arr, string|function fun, mixed ... args)
{
    array(mixed) ret = ({});
    mixed extra;    
    object ob;
    int i;
    
    if (functionp(fun)) {
       extra = args[0];
       for(i=0;i<sizeof(arr);i++) {
           ret[i] = fun(arr[i],extra);
       }
    } else {
       ob = (object)args[0];
       extra = args[1];
       for(i=0;i<sizeof(arr);i++) {
           ret[i] = call_other(ob,fun,arr[i],extra);
       }       
    }
    return ret;    
}

array(string) explode(string str, string expstr) 
{
   return str / expstr;
}

string implode(array(string) strlist, string impstr) 
{
    return strlist * impstr;
}

int exists(string filename) 
{
    return file_stat(filename) != 0;
}

int file_size(string filename) 
{
    mixed s = file_stat(filename);    
    return s != 0 ? s->size : -1;
}

string extract(string str, int start, int end) 
{
    string ret;    
    if (start < 0) {    
        ret = (end < 0) ? str[<(-1-start)..<(-1-end)] : str[<(start)..(end)]; 
    } else {
        ret = (end < 0) ? str[(start)..<(-1-end)] : str[(start)..(end)];   
    }
    return ret;
}

void load_simul_efuns(array(object) init_ob,mixed lconstants) {
 
    init_process = init_ob;
 
    orig_constants = copy_value(lconstants);
    load_kernel_overrides();
 
    // Functions
 
    add_constant("function_exists",function_exists);
    add_constant("call_other",call_other);
    add_constant("map_array",map_array);
    add_constant("explode",explode);
    add_constant("implode",implode);
    add_constant("exists",exists);
    add_constant("file_size",file_size);
    add_constant("extract",extract);
              
 //orig_constants["add_constant"]("call_out",this->do_call_out);
}
