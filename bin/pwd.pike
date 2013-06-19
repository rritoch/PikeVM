/* ========================================================================== */
/*                                                                            */
/*   Filename.c                                                               */
/*   (c) 2001 Author                                                          */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */


int main(int argc, array(string) argv, mixed env) {
 write("%s\n",this_shell()->environment()["CWD"]);
 return 0;
}
