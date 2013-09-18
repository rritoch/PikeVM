/* ========================================================================== */
/*                                                                            */
/*   ls.pike                                                                  */
/*   (c) 2010 Ralph Ritoch                                                    */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */

#include <stdio.h>

int main(int argc, array(string) argv, mixed env) 
{

    string cwd;
 
  
    if (argc > 2) {
        printf("usage: %s [path]\n",argv[0]);
        return 1;
    }
 
    cwd = this_shell()->get_cwd();
 
    string pth = cwd;
    if (argc > 1) {
        pth = combine_path(cwd,argv[1]);
    }
 
    mixed files;
  
    files = get_dir(pth);
    if (!files) {
        printf("File not found!\n");
        return 1;
    }
  
    string fn;
    mixed s;
    string ft;
    string fullname;
    mixed p;
 
 //foreach (files,fn) {
  //fullname = combine_path(pth,fn);
    foreach(files,fullname) {
        fn = basename(fullname);
        s = file_stat(fullname);
        ft = " ";
        if (!s) {
        	ft = "e";
        } else if (s->isdir) {
            ft = "d";
            
        } else {
            if ((p = kernel()->find_program(fullname)) != -1) {
                if (programp(p)) {
                    ft = "*";
                } else {
                    ft = "-";
                }
            }
        }  
        printf("%s %s\n",ft,fn);
    }
    return 0;
}
