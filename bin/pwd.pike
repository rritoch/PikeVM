/**
 * Print working directory
 *
 */
 
int main(int argc, array(string) argv, mixed env) 
{
    write("%s\n",this_shell()->get_cwd());
    return 0;
}

