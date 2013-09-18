

mapping dispatch = ([]);
private mapping personal_bindings = ([]);
private array(string) modules = ({});
private mapping module_objects = ([]);
private mapping module_func_names = ([]);

protected void call_user_func(string, mixed);


void setup_for_save()
{    
    shellfuncs_setup_for_save();
}


void shellfuncs_setup_for_save() 
{
    this_object()->add_save(({ "personal_bindings", "modules" }));
}

protected void shell_bind(string command, function f, array|void args)
{
  dispatch[command] = args ? ({ f }) + args : ({ f });
}

protected void
shell_bind_if_undefined(string command, function f,  array|void args)
{
    if ( zero_type(dispatch[command])) {
       shell_bind(command,f,args);
    } 
}

protected void
shell_unbind(string command)
{
  map_delete(dispatch, command);
}

protected int
bind(string command, array(string) argv)
{
  string fname;

  if(sizeof(argv) != 1)
    return -1;
  fname = argv[0];
  if(zero_type(personal_bindings[command]) && dispatch[command])
    return -2;
  
  personal_bindings[command] = fname;
  dispatch[command] = ({ call_user_func, command });
  this_object()->save();
}

protected void
unbind(array(string) argv)
{
  string command;

  if(sizeof(argv) != 1)
    return;
  command = argv[0];
  if(undefinedp(personal_bindings[command]))
    return;

  map_delete(personal_bindings, command);
  map_delete(dispatch, command);
  this_object()->save();
}


protected void
call_user_func(string fname, mixed argv)
{
  string module;

  foreach(modules, module)
    {
      if(member_array(fname, module_func_names[module]) != -1)
{
call_other(module_objects[module],fname,argv);
return;
}
    }
}

protected int load_module(mixed argv)
{
  array(string) flist;
  //mapping finfo = ([]);
  mixed item;
  object module_ob;
  array(string) funcnames = ({});

  if(!(stringp(argv) || (arrayp(argv) && sizeof(argv) == 1 &&
stringp(argv=argv[0]))))
    return 0;
  
  if(!(module_ob = load_object(argv)))
    return 0;

  module_objects[argv] = module_ob;
  
  //flist = functions(module_ob,1);
  flist = indices(module_ob);
  
  foreach(flist,item)
    {
      /*
      if(strsrch(item[2],"protected") != -1 || strsrch(item[2],"private") != -1)
continue;
      
      finfo[item[0]];
      */
      if (functionp(module_ob[item])) {
          funcnames += ({ item });
      }
    }
  module_func_names[argv] = funcnames;
  return 1;
}
     

protected void set_module_path(array(string) mpath)
{
  modules = mpath;
  map(modules, load_module);
}
