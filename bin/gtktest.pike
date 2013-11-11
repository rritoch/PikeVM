

void window_event(object ob, object evt, mixed ... args) 
{
	//kernel()->console_write(sprintf("window_event: %O\n",evt));
	GTK2.main_iteration_do(0);
}

void window_destroy(mixed ... args) 
{
	//kernel()->console_write(sprintf("window_destroy: args=%O\n",args));
}

GTK2.Window mainwindow;

void show_win() {
   catch {
      GTK2.gtk_init();
  };
  mainwindow=GTK2.Window(GTK2.WindowToplevel);
  mainwindow->signal_connect("event",window_event);
  mainwindow->signal_connect("destroy",window_destroy);
  mainwindow->set_title("GTK Test");
  mainwindow->show_all();
  //kernel()->console_write(sprintf("%O\n",indices(mainwindow)));
  while(this) {
     sleep(1);
  }
}

int main()
{
  Thread.Thread t;
  
  t = Thread.Thread(show_win);
  
  return -1;
}