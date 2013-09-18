/* ========================================================================== */
/*                                                                            */
/*   Filename.c                                                               */
/*   (c) 2001 Author                                                          */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */


int main(int argc, array(string) argv, mixed env) 
{
    string cwd;
    mixed s;
 
    if (argc > 2) {
        write("usage: %s (path)\n",argv[0]);
        return 1;
    }
 
    if (argc == 1) {
        write("Not implemented\n");
        return 0;
    }
    cwd = this_shell()->get_cwd();
    cwd = combine_path(cwd,argv[1]);
 
    s = file_stat(cwd);
 
    if (s && s->isdir) {
        this_shell()->set_cwd(cwd);
        write("%s\n",cwd);
    } else {
        write("No such directory! %s\n",cwd);
    }
 
    return 0; 
}
