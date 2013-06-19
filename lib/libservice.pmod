/* ========================================================================== */
/*                                                                            */
/*   libservice.pmod                                                          */
/*   (c) 2010 Ralph Ritoch                                                    */
/*                                                                            */
/*   Description                                                              */
/*     Service Library                                                        */
/* ========================================================================== */

#include <stdio.h>
#include <shell.h>

int success() {
 printf("[success]\n");
 return 0;
}

int fail() {
 printf("[failed]\n");
 return 1;
}

int daemon(string cmd) {
 int ret;
 ret = executef("%s",cmd);
 if (ret < 0) return success();
 return fail();
}
