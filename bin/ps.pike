/* ========================================================================== */
/*                                                                            */
/*   ps.pike                                                               */
/*   (c) 2013 Ralph Ritoch <rritoch@gmail.com>                                                   */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */

#include <stdio.h>

string thread_status_str(object thread) 
{
    int s = thread.status();
    string ret = "?";
    switch(s) {
        case Thread.THREAD_NOT_STARTED:
            ret = ".";
            break;
        case Thread.THREAD_RUNNING:
            ret = "+";
            break;
        case Thread.THREAD_EXITED:
            ret = "-";
            break;
    }
    return ret;
}

string thread_function_str(object thread) 
{
    return sprintf("%O", thread.backtrace()[0]->fun);
}

string thread_cur_function_str(object thread) 
{
    return sprintf("%O", thread.backtrace()[-1]->fun);
}

int main(int argc, array(string) argv, mixed env) {


    array(object) thread_list = all_threads();
    foreach(thread_list, object t) {
        printf(
            "%-10d %s %s > %s\n",
            t->id_number(),
            thread_status_str(t),
            thread_function_str(t),
            thread_cur_function_str(t)
        );
    }
    return 0;
}
