/**
 * Simul Efuns
 *
 */

#include <config.h>
#include <more.h>
#include <mudlib/flags.h>
#include <mudlib/msgtypes.h>

private mixed orig_constants;
private array(object) init_process;

/*
mixed do_file_stat(string x,void|int(0..1) symlink) {
  return kernel()->_file_stat(x,symlink);
}
*/
string mud_name() {
    return "PikeVM Mud";
}

private mixed printf(mixed ... args)
{
   return kernel()->_write(sprintf(@args));
}

private void load_kernel_overrides() {
 string str;
 array(string) kc;
 string c;
 string fname;

 program p;
 object ob;
 mapping (string:mixed) k;

 kc = indices(kernel());

 str = "mixed foo() { \nmapping (string:mixed) ret = ([]);";

 foreach(kc,c) {
  if (has_prefix(c, "_") && (sizeof(c) > 1)) {
   str += sprintf("ret[\"%s\"] = kernel()->%s;\n",c,c);
  }
 }


 str += "return ret; \n}\n";
 p = compile_string(str);
 ob = p();
 k = ob->foo();

 foreach(indices(k),c) {
  if (functionp(k[c])) {
   fname = c[1..];
   add_constant(fname,k[c]);
  }
 }
 return;
}

int function_exists(string str, object ob)
{
    return functionp(ob[str]);
}



array filter_array( array arr, string|function fun, mixed ... extra) {

   mixed item;
   array(mixed) ret = ({});
   if (!functionp(fun)) {
       if (sizeof(extra)) {
          fun = extra[0][fun];
          extra = extra[1..];
       }

       if (!functionp(fun)) {
           return arr; // nothing to do?
       }
   }

   foreach(arr, item) {
          if (fun(item,@extra)) {
           ret += ({ item });
          }
   }

   return ret;
}


mixed call_other(object ob, string fun, mixed ... args)
{
   string src;
   object obc;
   program p;
   mixed ret;

   int i;
   array(string) arga_enc = ({});

   for(i = 0; i < sizeof(args); i++) {
      arga_enc += ({ "args["+i+"]" });
   }

   src = "mixed foo(object ob, array(mixed) args) { return ob->"
         +fun
         +"("
         + (arga_enc * ",")
         + ");}";

    p = compile_string(src);
    obc = p();
    ret = obc->foo(ob,args);
    destruct(obc);
    return ret;
}

array(mixed) map_array(array(mixed) arr, string|function fun, mixed ... args)
{
    array(mixed) ret = ({});
    mixed extra;
    object ob;
    int i;

    if (arrayp(arr)) {
    if (functionp(fun)) {
       extra = args;
       for(i=0;i<sizeof(arr);i++) {
           ret += ({fun(arr[i],extra) });
       }
    } else if (sizeof(args) > 0) {
       ob = (object)args[0];
       extra = args[1..];
       for(i=0;i<sizeof(arr);i++) {
           ret += ({ call_other(ob,fun,arr[i],extra) });
       }
    }
    }
    return ret;
}

array(string) explode(string str, string expstr)
{
   return str / expstr;
}

mixed implode(array(mixed) arr, string|function arg1, mixed ... args)
{
    mixed last;
    mixed ret = 0;
    int idx;
    int idx_start;

    if (stringp(arg1)) {
        return arr * arg1;
    }

    if (sizeof(args) < 2 && functionp(arg1)) {

        idx_start = 0;

        if (sizeof(args)) {
            last = args[0];
        } else {
            if (sizeof(arr)) {
               last = arr[0];
               idx_start = 1;
            } else {
                return ret;
            }
        }

        for(idx=idx_start;idx<sizeof(arr);idx++) {
            last = arg1(last,arr[idx]);
        }
        ret = last;

    } else {
        error("Invalid arguments to implode");
    }
    return ret;
}

int exists(string filename)
{
    return kernel()->_file_stat(filename) != 0;
}

int is_file(string filename)
{
    return kernel()->_file_stat(filename) != 0;
}

int file_size(string filename)
{
    mixed s = kernel()->_file_stat(filename);
    return s != 0 ? s->size : -1;
}

string extract(string str, int start, int end)
{
    string ret;
    if (start < 0) {
        ret = (end < 0) ? str[<(-1-start)..<(-1-end)] : str[<(start)..(end)];
    } else {
        ret = (end < 0) ? str[(start)..<(-1-end)] : str[(start)..(end)];
    }
    return ret;
}

void map_delete(mapping map, mixed key)
{
    m_delete(map,key);
}

mixed copy(mixed value)
{
    return copy_value(value);
}

array keys(mapping value)
{
   return indices(value);
}

string wrap(string str, int|void width, int|void indent)
{
  if ( !indent )
    return sprintf("%-=*s", width || DEFAULT_WRAP_WIDTH, str);

  return sprintf(
      "%s%-=*s",
      str[0..indent - 1],
      (width || DEFAULT_WRAP_WIDTH) - indent,
      str[indent..]
      );
}

string terminal_color(
                      string str,
                      mixed map,
                      array|int|void map_args,
                      int|void do_wrap,
                      int|void indent
)
{
    string ret;

    if (functionp(map) || mappingp(map)) {

        array(string) parts;
        int i;
        string seg;
        string segt;

        parts = str / "%^";

        ret = parts[0];

        " X % X % ";

        for(i=1;i<sizeof(parts);i = i + 2) {

            seg = parts[i];

            if (sizeof(seg) < 1) {
                segt = "%^";
            } else {
                if (functionp(map)) {
                   segt = map(seg,@map_args);
                } else {
                   segt = zero_type(map[seg]) ? "%^"+seg+"%^" : map[seg];
                }
            }

            str = str + segt;

            if (i+1 < sizeof(parts)) {
                str = str + parts[i+1];
            }
        }
    }

    if (do_wrap) {
        ret = wrap(ret,DEFAULT_WRAP_WIDTH,indent);
    }
    return ret;
}

object|int this_body()
{
    return kernel()->_this_body();
}

void tell(object ob, string msg, int|void flag)
{
   if (functionp(ob->catch_tell)) {
       ob->catch_tell(msg);
   }
}

mixed get_user_variable(string varname)
{
   return kernel()->_this_shell()->get_variable(varname);
}

int default_more_lines()
{
    int t = get_user_variable("MORE");
    int num = 20;

    if ( stringp(t) ) {
        t = (int)t;
    }
    if ( t )
num = t;
    return num;
}


void more(mixed arg, int|void num, function|void continuation,
     int|void output_flags)
{
    int i;

    if (stringp(arg)) {
        arg = arg / "\n";
    } else {
        if (!arrayp(arg)) {
            return;
        }
    }

    if (!sizeof(arg)) {
        return;
    }

    if (!num) {
        num = default_more_lines();
    }

    if (sizeof(arg) < num) {

        for(i=0;i<sizeof(arg);i++) {
            string line = arg[i];
            tell(kernel()->_this_user(), line + "\n", output_flags);
        }

        if ( continuation ) {
            continuation();
        }
        return;
    }

    MORE_OB(MORE_LINES,arg,num,continuation,output_flags);
}

int clonep(mixed|void arg)
{
   return arg ? objectp(arg) : objectp(kernel()->_previous_object());
}

void more_file(mixed arg, int|void num, function|void continuation,
    int|void output_flags)
{
    if (stringp(arg)) {
        arg = ({ arg });
    } else {
        if (!arrayp(arg) || !sizeof(arg)) {
            return;
        }
    }

    if (!num) {
        num = default_more_lines();
    }

    MORE_OB(MORE_FILES, arg, num, continuation, output_flags);
}

int member_array(mixed needle,mixed haystack)
{
    return search(haystack,needle);
}

string capitalize(string str)
{
   return upper_case(str[0..0])+str[1..];
}

void tell_environment(mixed ob, string what, int|void msg_type, mixed|void exclude)
{
    // TODO: Implement Me!
}

string implode_by_arr( array(string) arr1, array(string) arr2)
{
  string res = "";
  int    i;

  if(sizeof(arr2) != (sizeof(arr1) + 1))
    error("second arg needs to have 1 more arg than first.\n");

  res += arr2[0];
  for(i=0;i<sizeof(arr1);i++)
    {
      res += arr1[i];
      res += arr2[i+1];
    }
  return res;
}

string|int replace_string(string str,string what,string replace)
{
    return (((string)str) / ( (string)what)) * ((string)replace);
}


array(mixed) clean_array(array(mixed) r) {
    int i, n;

    r = r & r; // sort. sort_array() can't hack it. And no, &= doesn't work.

    n = sizeof(r) - 1;
    while (i < n) {
if (r[i] == r[i+1]) {
int j = i+1;

while (j < n && r[i] == r[j + 1])
j++;

//r[i..j-1] = ({});
r = r[0..i-1] + r[j..];
n -= j - i;
}
i++;
    }

    return r;
}

string chr( int i )
{
  return sprintf("%c",i);
}

int strsrch( string str, string|int needle, int|void flag )
{
    array(string) tmpa;
    int tmp;

    if (!stringp(needle)) {
        tmp = needle;
        str = " ";
        str[0] = tmp;
    }

    tmpa = str / needle;

    return sizeof(tmpa) < 2 ? -1 : sizeof(tmpa[0]);
}

private array(string) wiz_dir_parts = (ADMIN_DIR / "/") - ({ "", "." });

array(string) split_path( string p ) {
    int pos;
    while(p[-1] == '/' && strlen(p) > 1) p = p[0..<2];
    pos = strsrch(p, '/', -1); /* find the last '/' */
    return ({ p[0..pos], p[pos+1..] });
}

string evaluate_path(string path, string|void prepend)
{
    array(string) tree;
    int idx;

    if (!path || path[0..0] != "/") {
        if (!prepend && kernel()->_this_shell()) {
            path = kernel()->_this_shell()->get_cwd() + "/" + path;
        } else {
          if(prepend) {
            path = prepend + "/" + path;
          } else {
           string lname = kernel()->_file_name(kernel()->_previous_object());
               int tmp = strsrch(lname, "/", -1);
               path = lname[0..tmp] + path;
          }
        }
    }

    tree = explode(path, "/") - ({ "", "." });
    while (idx < sizeof(tree)) {
string tmp = tree[idx];
if (tmp == "..") {
if (idx) {
   //tree[idx-1..idx] = ({ });
   tree = tree[0..(idx-2)] + tree[idx+1..];
idx--;
} else
//tree[idx..idx] = ({ });
tree = tree[0..idx-1] + tree[idx+1..];
continue;
}
if (tmp[0] == '~' && kernel()->_this_user()) {
if (sizeof(tmp) == 1)
tmp = kernel()->_this_user()->query_userid();
else
tmp = tmp[1..];
//tree[0..idx] = wiz_dir_parts + ({ tmp });

tree = wiz_dir_parts + ({ tmp }) + tree[idx+1..];
continue;
}
idx++;
    }
    return "/" + implode(tree, "/");
}

mixed exec_code(string cmd, string dir, string|void includefile) {

    string code = includefile ?  sprintf("#include \"%s\"\n mixed foo() { return %s; }",includefile,cmd) : sprintf("mixed foo() { return %s; }",cmd);
    program p = compile_string(code);

    object ob = p();

    return ob->foo();
}

string rtrim(string str, string|void chars)
{
    if (zero_type(str)) {
        return str;
    }
    if (!chars) {
        chars ="\r\n\t ";
    }
    while(sizeof(str) && -1 != search(chars, str[-1])) {
        str = str[..<1];
    }
    return str;
}

string ltrim(string str, string|void chars)
{
    if (!chars) {
        chars ="\r\n\t ";
    }
    while(sizeof(str) && -1 != search(chars,str[0])) {
        str = str[1..];
    }
    return str;
}

string trim_spaces(string str)
{
   return ltrim(rtrim(str));
}

string trim(string str, string|void chars)
{

    return rtrim(ltrim(str,chars),chars);
}

array(string) split(string data, string re)
{

    object rx = Regexp.PCRE._pcre(re);
    int o = -1;
    mixed result;
    array(string) ret = ({});

    while(arrayp(result = rx->exec(data,o))) {
        if (result[0] - o > 0) {
            ret += ({ data[o..(result[0]-1)] });
        } else {
            ret += ({ "" });
        }
        o = result[1];
    }

    if (o > -1) {
        ret += ({ data[o..] });
    }

    return ret;
}


int|array(mixed) regexp( string|array(string) lines, string pattern, int|void flag)
{

    object rx = Regexp.PCRE._pcre(pattern);
    string line;
    array(mixed) ret = ({});
    int i;

    if (!arrayp(lines)) {
        return !(rx->exec(lines) == -1);
    }

    if (flag & 1) { // verbose

        if (flag & 2) { // reverse
            for(i=0;i<sizeof(lines);i++) {
               line = lines[i];
               if (rx->exec(lines) == -1) {
                   ret += ({ i+1, line });
               }
            }
        } else {
            foreach(lines, line) {
               if (!(rx->exec(lines) == -1)) {
                   ret += ({ i+1, line });
               }
            }
        }

    } else {
        if (flag & 2) { // reverse
            foreach(lines, line) {
               if (rx->exec(line) == -1) {
                  ret += ({ line });
               }
            }
        } else {
            foreach(lines, line) {
               if (!(rx->exec(line) == -1)) {
                  ret += ({ line });
               }
            }
        }

    }
    return ret;
}


array reg_assoc(string str, array(string)pat_arr, array tok_arr, mixed|void def)
{

    mixed cur;
    mixed min_next;
    int min_next_i;
    int i;
    int sz;

    array(mixed) rxlist = ({});
    array(mixed) last_match = ({ -1 , -1 });
    array(mixed) ret = ({ ({ }) , ({}) });
    int done = 0;

    tok_arr = arrayp(tok_arr) ? tok_arr : ({});
    pat_arr = arrayp(pat_arr) ? pat_arr : ({});

    sz =  sizeof(pat_arr) < sizeof(tok_arr) ? sizeof(pat_arr) : sizeof(tok_arr);
    //if (sz < 1) return ({  ({ str }), ({ def }) });

    for(i = 0; i<sz; i++) {
        rxlist += ({  Regexp.PCRE._pcre(pat_arr[i]/*,Regexp.PCRE.OPTION.UNGREEDY*/) });
    }

   while(!done) {
       done = 1;

       for(i = 0; i<sz; i++) {
           cur = rxlist[i]->exec(str, last_match[1]);
           if (cur != -1) {
               if (done) {
                  min_next = cur;
                  min_next_i = i;
                  done = 0;
               } else {
                   min_next_i = cur[0] < min_next[0] ? i : min_next_i;
                   min_next = cur[0] < min_next[0] ? cur : min_next;
               }
           }
       }

       if (!done) {
           // add no-match

           if (last_match[1] < min_next[0]) {
               ret[0] += ({ str[(last_match[1])..(min_next[0]-1)]   });
           } else {
               ret[0] += ({ "" });
           }
           ret[1] += ({ def });

           // add match

           ret[0] += ({ str[min_next[0]..(min_next[1]-1)] });
           ret[1] += ({ tok_arr[min_next_i] });
           last_match = min_next;
       }
   }



    // add no-match

    if (last_match[1] + 1 < sizeof(str)) {
       ret[0] += ({ str[(last_match[1])..]});
    } else {
       ret[0] += ({ "" });
    }
    ret[1] += ({ def });

    return ret;
}

string base_name(object o)
{
    return sprintf("%O", object_program(o));
}

string base_path(string p)
{
    return kernel()->_dirname(p);
}

string pluralize(string word)
{
    return word+"s";
}

mixed choice(array(mixed) options)
{
    return options[random(sizeof(options))];
}

object owner(object ob)
{
  object env;

  env = kernel()->_environment(ob);
  while (env && !env->is_living()) {
    env = kernel()->_environment(env);
  }
  return env;
}

int count( object|void o )
{
  int num;
  array(object) obs;
  int i;

  if( !o )
  {

#ifdef ORIGIN_LOCAL
    if (origin() == ORIGIN_LOCAL)
      o = this_object();
    else
#endif

      o = kernel()->_previous_object();
  }
  if(!objectp(kernel()->_environment(o)))
    return 1;

  obs = kernel()->_all_inventory(kernel()->_environment(o));
  for (i=0; i<sizeof(obs); i++) {
    if (compare_objects(obs[i],o)) {
        num++;
    }
  }

  return num;
}

int compare_objects(object o1, object o2)
{
  return (base_name(o1)==base_name(o2) &&
      o1->ob_state()==o2->ob_state() &&
      o1->get_attributes() == o2->get_attributes() &&
      (int)o2->ob_state() != -1);
}

string cannonical_form(mixed fname)
{
    if (objectp(fname)) fname = kernel()->file_name(fname);
    sscanf(fname, "%s#%*d", fname);
    sscanf(fname, "%s.c", fname);
    if (fname[0] != '/') fname = "/" + fname;
    return fname;
}

string absolute_path( string relative_path, mixed|void relative_to )
{
    if( !relative_to ) relative_to = kernel()->_previous_object();
    if( relative_path[0] != '/' ) {
        if( objectp( relative_to )) {
            relative_path = base_path( kernel()->_file_name( relative_to )) + relative_path;
        } else {
            if ( stringp( relative_to )) {
                relative_path = relative_to + "/" + relative_path;
            } else {
                error( "Invalid relative_to path passed" );
            }
        }
    }

    relative_path = cannonical_form( relative_path );
    relative_path = evaluate_path( relative_path );
    return relative_path;
}


mixed flatten_array(mixed arr)
{
    int i = 0;

    if (!arrayp(arr)) error("Bad argument 1 to flatten_array");
    arr = copy(arr);

    while (i < sizeof(arr)) {
if (arrayp(arr[i])) {
    if (i>0) {
        if (i +1 < sizeof(arr)) {
            arr = arr[0..(i-1)] + arr[i] + arr[(i+1)..];
        } else {
            arr = arr[0..(i-1)] + arr[i];
        }
    } else {
        if (sizeof(arr) > 1) {
            arr = arr[i] + arr[(i+1)..];
        } else {
            arr = arr[i];
        }
    }
} else i++;
    }
    return arr;
}

int duplicatep( object|void o )
{
  int i;
  array(object) obs;

  if (!o)
    o = kernel()->_previous_object();

  obs = kernel()->_all_inventory(kernel()->_environment(o));
  for (i=0; i<sizeof(obs); i++)
  {
    if (obs[i]==o)
      return 0;
    if (compare_objects(obs[i], o))
      return 1;
  }
}

string inv_list(array(object) obs, int|void flag, int|void depth)
{
  string res;
  int j;

  array(object) obs2;
  object ob;

  depth++;
  res = "";
  obs2 = obs - ({ 0 });

  foreach (obs2,ob)
  {
    if (!ob->is_visible())
      continue;
    if (!ob->short())
      continue;
    if (flag && !ob->test_flag(TOUCHED) && ob->untouched_long())
      continue;
    if (ob->is_attached())
    {
      if (ob->inventory_visible() && !ob->query_hide_contents())
        res += ob->inventory_recurse(depth);
      continue;
    }
    if (!duplicatep(ob))
    {
      for (j=0; j<depth; j++)
        res+=" ";
if ((j=count(ob))>1)
{
        if (j > 4)
          res += "many " + ob->plural_short();
        else
          res += j + " " + ob->plural_short();
} else {
        if (ob->is_living())
        {
          res += ob->in_room_desc();
        } else {
          res += ob->a_short() + ob->get_attributes();
        }
      }
res += "\n";
      if( ob->inventory_visible() && !ob->query_hide_contents())
        res += ob->inventory_recurse(depth);
    }
  }
    return res == "" ? 0 : res;
}

array sort_array(array arr, mixed ... args) {

    array ret = ({});
    array args_out;
    mixed itemA;
    mixed itemB;
    int flip = 1;
    int idx;
    mixed tmp;
    function f;

    if (sizeof(arr) < 2) {
        return copy_value(arr);
    }

    if (sizeof(args) < 1 || intp(args[0])) {
       ret = copy_value(arr);
       ret = sort(ret);
       if (sizeof(args) && args[0] < 0) {
          ret = reverse(ret);
       }
    } else {
        if (stringp(args[0]) && sizeof(args) > 1 && objectp(args[1])) {
            args_out = args[2..];
            ret = copy_value(arr);
            while(flip > 0) {
                flip = 0;
                for(idx=0;idx<(sizeof(ret)-1); idx++) {
                    itemA = ret[idx];
                    itemB = ret[idx+1];
                    if (call_other(args[1],args[0],itemB,itemA, @args_out) < 0) {
                        flip = 1;
                        tmp = ret[idx];
                        ret[idx] = ret[idx+1];
                        ret[idx+1] = tmp;
                    }
                }
            }
        } else {
            if (functionp(args[0])) {
                args_out = args[1..];
                ret = copy_value(arr);
                f = args[0];
                while(flip > 0) {
                    for(idx=0;idx<(sizeof(ret)-1); idx++) {
                        itemA = ret[idx];
                        itemB = ret[idx+1];
                        if(f(itemB,itemA,@args_out) < 0) {
                            flip = 1;
                            tmp = ret[idx];
                            ret[idx] = ret[idx+1];
                            ret[idx+1] = tmp;
                        }
                    }
                }
            }
        }

    }
    return ret;
}

string format_list(array(string) list, string|void separator)
{
  if (!separator)
    separator = "and";
  if (sizeof(list)==0)
    return "";
  if (sizeof(list)==1)
    return list[0];
  if (sizeof(list)==2)
    return list[0] + " " + separator + " " + list[1];
  return implode(list[0..<2], ", ") + ", " + separator + " " + list[-1];
}


void tell_from_inside(mixed ob, string what, int|void msg_type, mixed|void exclude) {
    ob->receive_inside_msg(what, exclude, msg_type | INSIDE_MSG);
}

void tell_from_outside(mixed ob, string what, int|void msg_type, mixed|void exclude) {
    ob->receive_outside_msg(what, exclude, msg_type | OUTSIDE_MSG);
}

private array(string) normal_directions = ({ "up", "down",
                                                   "north", "northeast",
                                                   "northwest", "east",
                                                   "southeast", "southwest",
                                                   "south", "west" });

int is_normal_direction(string dir) {
     if (member_array(dir, normal_directions) != -1)
         return 1;
     return 0;
}

string join_path(string ... paths)
{
    return kernel()->_combine_path(@paths);
}


array collate_array(array arr, string|function sep, mixed|void skip) {

    mixed m_item;

    array sames = ({});
    array ret = ({});
    mixed check;
    int ptr;

    if (functionp(sep)) {
        foreach(arr, m_item) {
            check = sep(m_item);
            if (zero_type(skip) || check != skip) {
                ptr = search(sames,check);
                if (ptr < 0) {
                    sames += ({ check });
                    ret += ({ ({ m_item }) });
                } else {
                    ret[ptr] += ({ m_item });
                }
            }
        }
    } else {
        foreach(arr, m_item) {
            check = m_item[sep]();
            if (zero_type(skip) || check != skip) {
                ptr = search(sames,check);
                if (ptr < 0) {
                    sames += ({ check });
                    ret += ({ ({ m_item }) });
                } else {
                    ret[ptr] += ({ m_item });
                }
            }
        }

    }
    return ret;
}

void load_simul_efuns(array(object) init_ob,mixed lconstants) {

    init_process = init_ob;

    orig_constants = copy_value(lconstants);
    load_kernel_overrides();

    // Functions

    add_constant("function_exists",function_exists);
    add_constant("call_other",call_other);
    add_constant("map_array",map_array);
    add_constant("explode",explode);
    add_constant("implode",implode);
    add_constant("exists",exists);
    add_constant("file_size",file_size);
    add_constant("extract",extract);
    add_constant("map_delete",map_delete);
    add_constant("copy",copy);
    add_constant("keys",keys);
    add_constant("wrap",wrap);
    add_constant("terminal_color",terminal_color);
    add_constant("more_file",more_file);
    add_constant("more",more);
    add_constant("printf",printf);
    add_constant("tell",tell);
    add_constant("member_array",member_array);
    add_constant("capitalize",capitalize);
    add_constant("tell_environment",tell_environment);
    add_constant("implode_by_arr",implode_by_arr);
    add_constant("replace_string",replace_string);
    add_constant("mud_name",mud_name);
    add_constant("clean_array",clean_array);
    add_constant("chr",chr);
    add_constant("evaluate_path",evaluate_path);
    add_constant("is_file",is_file);
    add_constant("exec_code",exec_code);
    add_constant("clonep",clonep);
    add_constant("trim_spaces",trim_spaces);
    //add_constant("split",split);
    add_constant("regexp",regexp);
    add_constant("split_path",split_path);
    add_constant("strsrch",strsrch);
    add_constant("filter_array",filter_array);

    add_constant("Program",Program);

    add_constant("Regexp",Regexp);
    add_constant("reg_assoc",reg_assoc);
    add_constant("base_name",base_name);
    add_constant("base_path",base_path);
    add_constant("pluralize",pluralize);
    add_constant("choice",choice);
    add_constant("owner",owner);
    add_constant("count",count);
    add_constant("compare_objects",compare_objects);
    add_constant("absolute_path",absolute_path);
    add_constant("flatten_array",flatten_array);
    add_constant("inv_list",inv_list);
    add_constant("duplicatep",duplicatep);
    add_constant("cannonical_form",cannonical_form);
    add_constant("sort_array",sort_array);
    add_constant("format_list",format_list);
    add_constant("tell_from_inside",tell_from_inside);
    add_constant("tell_from_outside",tell_from_outside);
    add_constant("rtrim",rtrim);
    add_constant("ltrim",ltrim);
    add_constant("trim",trim);
    add_constant("is_normal_direction",is_normal_direction);
    add_constant("Thread",Thread);
    add_constant("join_path",join_path);
    add_constant("collate_array",collate_array);
    add_constant("GTK",GTK);
    add_constant("GTK2",GTK2);


 //orig_constants["add_constant"]("call_out",this->do_call_out);
}
