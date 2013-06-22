#include <stdio.h>

int main(int argc, array(string) argv, mixed env) {


 object user; 

 foreach(users(), user) {
 
     if (user->get_name() != "") {
         printf("%s %O\n",user->get_name(),user->get_link()[0]);     
     } else {
         printf("[login] %O\n",user->get_link()[0]);
     }
     
 }
 
 return 0;
}
