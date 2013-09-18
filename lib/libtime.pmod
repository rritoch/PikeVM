
#include <sys/types.h>

int gettimeofday(pike_pointer tv, pike_pointer tz) 
{
	object t = kernel()->now();
	
	if (objectp(tv)) {
	    tv->value = ({timeval()});	    	
	    tv->value[0]->tv_sec = t["sec"];
	    tv->value[0]->tv_usec = t["usec"];
	
	}
	
	if (objectp(tz)) {
		 tz->value = ({timezone()});
		 tz->value[0]->tz_minuteswest = t["minuteswest"];
		 tz->value[0]->tz_dsttime = t["dsttime"];	 
	}
	    
	return 0;
}