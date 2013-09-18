int main()
{

  GTK2.Window mainwindow;
  mainwindow=GTK2.Window(GTK2.WindowToplevel);
  mainwindow->set_title("GTK Test");
  mainwindow->show_all();

  return -1;
}