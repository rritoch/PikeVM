/* ========================================================================== */

/*                                                                            */

/*   sys/types.h                                                              */

/*   (c) 2010 Ralph Ritoch                                                    */

/*                                                                            */

/*   Description                                                              */

/*                                                                            */

/* ========================================================================== */



#ifndef __SYS_TYPES

#define __SYS_TYPES



#define NULL UNDEFINED



#define size_t int

#define time_t int

#define suseconds_t int




class pike_pointer {

 array(mixed) value; 

 protected void create(mixed ... args) {

  value = ({ @args });

 }

}

class timeval 
{
    time_t tv_sec;
    suseconds_t tv_usec;
}

class timezone 
{
    int tz_minuteswest;     /* minutes west of Greenwich */
    int tz_dsttime;         /* type of DST correction */
};

#include "../inttypes.h"

#endif



























