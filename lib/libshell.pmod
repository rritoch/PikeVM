/* ========================================================================== */
/*                                                                            */
/*   libshell.pmod                                                            */
/*   (c) 2010 Ralph Ritoch                                                    */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */


int executef(string fmt, mixed ... args) {
 return this_shell()->execute(sprintf(fmt,@args));
}

