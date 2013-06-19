/* ========================================================================== */
/*                                                                            */
/*   Filename.c                                                               */
/*   (c) 2001 Author                                                          */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */


int main() {

 mapping(string:mixed) clist;
 mixed c;
  
 clist = all_constants();
 foreach(indices(clist), c) {
  if (functionp(clist[c])) {     
   write("%s()\n",c);
  }
 }
 return 0;
}
