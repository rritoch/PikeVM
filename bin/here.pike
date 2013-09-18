/**
 * here.pike
 *
 * Report where body is located
 * 
 * @author Ralph Ritoch <rritoch@gmail.com> 
 * @copyright Ralph Ritoch 2011 - ALL RIGHTS RESERVED  
 */
  
#define SECURITY_KEY "xxx123"

#include <stdio.h>

int main(int argc, array(string) argv, mixed env) 
{

    if (!this_body()) {
        printf("Your body is missing!\n");
        return 1;
    }
   
    printf("%O\n",environment(this_body()));
        
   
    return 0;
}
