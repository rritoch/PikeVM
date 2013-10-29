/* ========================================================================== */
/*                                                                            */
/*   load.pike                                                                */
/*   (c) 2010 Ralph Ritoch                                                    */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */


#include <stdio.h>

int main(int argc, array(string) argv, mixed env) 
{ 
    program|int p;
    string name;
    string cwd;
    mixed err;
    object ob;
 
    cwd = this_shell()->get_cwd();
    
    if (argc != 2) {
        fprintf(stderr,"Usage: %s [program]\n",argv[0]);
        return 1;
    }
 
    name = combine_path(cwd,argv[1]);
 
    if (sizeof(name) > 5 && name[<4..<0] == ".pike") {
    	name = name[0..<5];
    }
 
    if (ob =kernel()->find_object(name,cwd)) {
    	destruct(ob);
    }
    
    if ((p = kernel()->find_program(name,cwd)) != -1) {  
        kernel()->unload_program(p);
    }
    
    if (ob =kernel()->find_object(name + ".pike",cwd)) {
    	destruct(ob);
    }
    
    if ((p = kernel()->find_program(name + ".pike",cwd)) != -1) {  
        kernel()->unload_program(p);
    }    
      
 
    err = catch {
       p = (program)name;
    };
  
    if (err) {
        fprintf(stderr,"error: %O\n",err);
        return 1;
    }
 
    if (!p) {
       fprintf(stderr,"Update failed! Program %O failed to load!\n",name);
       return 1;
    }
    printf("Program %O has been updated!\n",kernel()->describe_program(p));
    return 0;
}
