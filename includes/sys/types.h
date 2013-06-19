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


class pike_pointer {
 array(mixed) value; 
 protected void create(mixed ... args) {
  value = ({ @args });
 }
}

#include <inttypes.h>

#endif













