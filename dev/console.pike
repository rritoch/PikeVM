/* ========================================================================== */
/*                                                                            */
/*   console.pike                                                             */
/*   (c) 2010 Ralph Ritoch                                                    */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */

//#define DEBUG_CONSOLE

inherit "char.pike";

static array(mixed) call_stack = ({});
static int bangptr = 0;

static int running;


private object io_master;
protected mixed grab_cb;

/* Low Level Device Functions */

static object read_ob;

protected int _open() {
 //read_ob = Stdio.stdin;
 read_ob = Stdio.Readline();
 //read_ob = _static_modules.files()->Fd();
 //read_ob->open(0,"r");
 return 1;
}

protected string _read_line(int noecho) {

#ifdef DEBUG_CONSOLE
 write("NO_ECHO = %O\n",noecho); 
 write("read_ob = %O",indices(read_ob));
#endif 
 //if (read_ob->tcgetattr) write("read_ob->tcgetattr() = %O",read_ob->tcgetattr());
 //if (read_ob->mode) write("read_ob->mode() = %O",read_ob->mode());
 
 if (noecho) {
  read_ob->set_echo(0);
  //read_ob->tcsetattr((["ECHO":0,"ICANON":0,"VMIN":0,"VTIME":0]));
#ifdef DEBUG_CONSOLE  
  write("NOECHO!!!\n");
#endif  
 } else {
  read_ob->set_echo(1);
  //read_ob->tcsetattr((["ECHO":1,"ICANON":0,"VMIN":0,"VTIME":0]));
 }
 return read_ob->read();
}

protected string _read_char(int noecho) {
 return _read_line(noecho);
}

protected void _write_error_message(mixed err) {
    if (objectp(err) && functionp(err->backtrace)) {
        write(sprintf("Console error: %O\n backtrace = %O\n",err,err->backtrace()));
    } else {
        write(sprintf("Console error: %O\n",err));
     }
}

/* Core Functions */


void grab(void|function cb) {
 if (!io_master) {
  mixed bt = backtrace();
  io_master = function_object(bt[-2][2]);
  if (functionp(cb)) {
   grab_cb = cb;
  }   
 }
}
public int handle_ioctl(int dev, int cmd, mixed ... args) {
    return kernel()->handle_ioctl(dev,cmd,@args);
}
protected void create() 
{
    write("console.pike->create()\n");
    Thread.Thread thread;
    if (!running) {
        thread = Thread.Thread(backend);
    }
}