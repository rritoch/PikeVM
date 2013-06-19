/* ========================================================================== */
/*                                                                            */
/*   libstdio.pmod                                                            */
/*   (c) 2010 Ralph Ritoch                                                    */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */

#include <sys/types.h>
#include <sys/ioctl.h>

 int fprintf(int fh, string fmt, mixed ... args) {
  pike_pointer ret = pike_pointer(-1);
  
  if (ioctl(fh,IOC_STRING,"write",ret,sprintf(fmt,@args)) < 0) {
   return -1;
  }
  return ret->value[0];
 }
 
 int printf(string fmt, mixed ... args) {
  return fprintf(1, fmt, @args); 
 }
 
 void perror(string msg) {
  fprintf(2,"%s %s\n",msg,strerror(errno()));
 }

int fclose(int fh) {
 return ioctl(fh,IOC_STRING,"close");
} 
 
size_t fread(pike_pointer ptr, size_t size, size_t nmemb, int fh) {
 int i;
 array(mixed) ret;
 pike_pointer data;
 mixed err;
 
 data = pike_pointer();
 
 ret = ({});
 
 i = 0;
 while ((i < nmemb) && (!err)) { 
  err = ioctl(fh,IOC_STRING,"read",data,size);
  if (!err) {
   i++;
   ret += data->value;
  }
 } 
 ptr->value = ret;
 return i;
} 

size_t fwrite(pike_pointer ptr, size_t size, size_t nmemb, int fh) {

} 

/*

void clearerr(FILE *stream);
int feof(FILE *stream);
int ferror(FILE *stream);
int fileno(FILE *stream); 
FILE *fdopen(int fildes, const char *mode);
FILE *freopen(const char *path, const char *mode, FILE *stream); 

*/

