/* ========================================================================== */
/*                                                                            */
/*   Filename.c                                                               */
/*   (c) 2001 Author                                                          */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */


int main(int argc, array(string) argv, mixed env) {
 object ob;
 
 ob = next_object();
 while(ob) {
  write("%s\n",kernel()->describe_object(ob));
  ob = next_object(ob);
 }
 return 0;
}
