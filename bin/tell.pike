#include <stdio.h>

int main(int argc, array(string) argv, mixed env) 
{
    string name;
    string sender;
    string message; 
    array(object) matches;
    object user; 

    if (argc < 3) {
        fprintf(stderr,"usage: %s [user] [message] \n",argv[0]);
        return 1;
    }

    sender = this_user()->get_name();

    name = argv[1];
    message = argv[2..] * " ";
   
    matches = ({});

    foreach(users(), user) { 
        if (user->get_name() == name) {         
            matches += ({ user });
        }     
    }
 
    if (sizeof(matches) > 0) {
        printf("You tell %s: %s\n",name,message);     
        foreach(matches,user) {
            user->recv_msg("%s tells you: %s\n",sender,message);
        }
    } else {
        fprintf(stderr,"%s cannot be found\n",name);
        return 1;     
    }
 
    return 0;
}
