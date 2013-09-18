
#include <mudlib/commands.h>

inherit "/lib/mudlib/secure/verbd.pike";

int main(int argc, array(string) argv, mixed env) 
{
    array(string) files;
    string d = CMD_DIR_VERBS "/*.pike";
    files = get_dir(d);
    map_array(files, reload_verb);
    return -1;
}
