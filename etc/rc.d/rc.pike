/* ========================================================================== */
/*                                                                            */
/*   rc.pike                                                                  */
/*   (c) 2010 Ralph Ritoch                                                    */
/*                                                                            */
/*   runlevel service                                                         */
/*                                                                            */
/* ========================================================================== */

#include <stdlib.h>
#include <stdio.h>
#include <kernel.h>
#include <default_paths.h>
#include <shell.h>

int main(int argc, array(string) argv) {
 
 array(string) status_files;
 array(string) status_programs; 
 array(string) startlist;
 array(string) stoplist; 
 string f;
 
 
 int priority;
 string name;
 int idx;
 
 if (argc != 2) {
  fprintf(stderr,"usage: %s [runlevel]\n",argv[0]);
  exit(1);
 }

 printf("Entering runlevel %s\n",argv[1]);
  
 status_files = get_dir(sprintf("%s/rc.d/rc.%s",etcdir,argv[1]));
 status_programs = get_dir(sprintf("%s/rc.d/init",etcdir));
 
 
 if (status_files) {
 	for(idx=0;idx<sizeof(status_files);idx++) {
 		status_files[idx] = basename(status_files[idx]);
 	}
 }
 
 if (status_programs) {
 	for(idx=0;idx<sizeof(status_programs);idx++) {
 		status_programs[idx] = basename(status_programs[idx]);
 	} 	
 }
 
 startlist = ({});
 stoplist = ({});
 
 foreach(status_files,f) { 	
  if (sscanf(f,"S%s",name)) {
   startlist += ({ name });
  }
  if (sscanf(f,"K%s",name)) {
   stoplist += ({ name });
  } 
 }
  
 startlist = sort(startlist);
 stoplist = sort(stoplist);
   
 foreach(stoplist,f) { 	
  if (sscanf(f,"%2d%s",priority,name) > 1) {
   if (search(status_programs,name + ".pike") > -1) {     
     executef("%s/service %s stop",bindir,name);
    }
  }
 }

 foreach(startlist,f) { 	
  if (sscanf(f,"%2d%s",priority,name) > 1) {
   if (search(status_programs,name + ".pike") > -1) {
     //write("Starting %s: ",name);
     executef("%s/service %s start",bindir,name);
    }
  }
 }

}