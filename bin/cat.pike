/**
 * Catenate file
 * 
 * @author Ralph Ritoch <rritoch@gmail.com> 
 * @copyright Ralph Ritoch 2011 - ALL RIGHTS RESERVED  
 */
  
#define SECURITY_KEY "xxx123"

#include <stdio.h>

int main(int argc, array(string) argv, mixed env) {

 mixed paths;
 string msg; 
 string cwd;
 string p;
 
  
 if (argc < 2) {
  fprintf(stderr,"usage: %s [path] (path2) ... \n",argv[0]);
  return 1;
 }

 cwd = env["CWD"];
 paths = argv[1..];
 
 foreach(paths, p) {
  msg = read_file(combine_path(cwd,p));
  if (0 == msg) {
      fprintf(stderr,"Error: Unable to read file \"%s\"\n",p);
  } else {
      printf("%s",msg);
  }
 }
 
 return 0;
}
