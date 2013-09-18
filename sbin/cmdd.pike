
#include "/includes/security.h"
#include "/includes/mudlib.h"

//#define DEBUG_CMD_SEARCH

#define PLURAL 1
#define STR 2
#define NUM 4

#define IS_PATH 8
#define IS_FILE 16
#define IS_DIR 32
#define IS_FNAME 64
#define IS_PIKEFILE 128
#define IS_OBFILE 256

#define FILE (8 | 16)
#define DIR (8 | 32)
#define PIKEFILE (8 | 16 | 128)
#define OBFILE (8 | 16 | 128 | 256)
#define FNAME (8 | 64)

#define IS_OBJECT 512
#define ONLY_USER 1024

#define OBJECT (512)
#define USER (512 | 1024)

#define FILE_FLAGS (8 | 16 | 32 | 256 | 64)

inherit M_GLOB;
inherit M_REGEX;
inherit M_GETOPT;
//inherit M_ACCESS;


//private mixed parse_arg(int,string);

class proto_info
{
  string options;
  array(int)	prototype;
  int	first_optional_arg;
  string	proto_string;
}


private mapping cmd_info = ([]);
private mapping proto_info_store = ([]);

void create()
{
  //set_privilege(1);
}

private void parse_verb_defs(string dir, string filecontents)
{
  mapping	pathmap = ([]);
  array(string) lines = explode(filecontents,"\n");
  array(string) words;
  string line, cmd, item;
  int size, flags, error_flag, i;
  string	errors = "";

  foreach(lines,line)
  {
    words = split(line, "[ \t]+") - ({""," "});
    size = sizeof(words);
    if(!size || words[0][0] == '#')
      continue;
    cmd = words[0];
    if(!zero_type(pathmap[cmd]))
      errors += sprintf("Warning: %s redefined. Previous definition being clobbered.\n", cmd);
    pathmap[cmd] = proto_info();
//### gross.
    pathmap[cmd]->proto_string =
replace_string( replace_string( replace_string( replace_string
(replace_string (replace_string( implode (words," "),
"num","number"), "str","string"), "obj", "object"), "fname", "filename"),
"*", "(s)"), "pikefile", "file");
    if(!(--size))
      continue;
    words = words[1..];
    if(words[0][0] == '-' && strlen(words[0]) > 1)
    {
      (pathmap[cmd])->options = words[0][1..];
      if(!(--size))
      {
        errors += "Bad line: " + line +"\n";
        continue;
      }
      words = words[1..];
    }
    (pathmap[cmd])->prototype = allocate(size);
    (pathmap[cmd])->first_optional_arg = -1;
    for(i=0; i<size;i++)
    {
      flags = 0;
      if(words[i][0] == '[' && words[i][-1] == ']')
      {
        words[i] = words[i][1..<2];
        if((pathmap[cmd])->first_optional_arg == -1)
         (pathmap[cmd])->first_optional_arg = i;
      }
      if(words[i][-1] == '*')
      {
        flags |= PLURAL;
        words[i] = words[i][0..<2];
      }
      if(words[i] == "")
{
        errors += "Bad line: "+line + "\n";
        error_flag = 0;
        break;
      }
      foreach(explode(words[i],"|"),item)
        switch(item)
        {
          case "str": flags |= STR; break;
          case "file": flags |= FILE; break;
          case "obfile": flags |= OBFILE; break;
          case "dir": flags |= DIR; break;
          case "obj": flags |= OBJECT; break;
          case "user": flags |= USER; break;
          case "fname": flags |= FNAME; break;
          case "num": flags |= NUM; break;
          case "pikefile": flags |= PIKEFILE; break;
          default:
            errors += "Bad line (invalid argument type): "+line + "\n";
            error_flag = 1;
            break;
        }
      if(error_flag)
        break;
      (pathmap[cmd])->prototype[i] = flags;

    }
    if(error_flag)
    {
      error_flag = 0;
      continue;
    }
  }
  proto_info_store[dir] = pathmap;
  
  /*
  if(strlen(errors))
    NEWS_D->system_post(BUG_NEWSGROUP, "Bugs found by " + base_name(this_object()), errors);
  */    
}

mixed pop2(mixed arg) 
{
    return arg[0..<5];
}

private void cache_dir(string dir)
{
  array(string) files,files_orig;
  string fn;
    
  if(dir[-1] != '/')
    dir += "/";

  
  if(is_file(dir+"Cmd_rules")) {
      parse_verb_defs(dir, read_file(dir+"Cmd_rules"));
  }
    
  files_orig = get_dir(dir);
  files = ({});
  foreach(files_orig,fn) {
      if (".pike"==fn[<4..]) {
         files += ({ basename(fn) });	
      }
  }
   
  if(!arrayp(files) || !sizeof(files))
    return;
  cmd_info[dir] = map(files, pop2);
}

void cache(array(string) paths)
{
  if(!paths)
    paths = keys(cmd_info);
  map(paths,cache_dir);
}

int is_command(object o)
{
  //mixed ret;
  
  /*
  if (!Program.inherits(object_program(o),CMD)) {
      return 0;
  } 
  */
  
  /* 
  if(function_exists("call_main", o) != CMD)
    return 0;
  */
  
  if (!functionp(o->main)) {
      return 0;	
  }
  
  if (functionp(o->not_a_cmd) && o->not_a_cmd()) {
      return 0;
  }
  
  /*
  if ((ret = o->not_a_cmd()) && (ret == 1 || ret == file_name(o)))
    return 0;
  */
  return 1;
}

// This one won't match commands not in your path. For players, mainly...
mixed find_cmd_in_path(string cmd, array(string) path)
{
	
#ifdef DEBUG_CMD_SEARCH
   kernel()->console_write("find_cmd_in_path(%O,%O)\n",cmd,path);
#endif
   	
  string dir;
  object o;

  foreach(path,dir)
  {
    if(dir[-1] != '/')
      dir += "/";
//Try adding this dir if we don't have it,
    if(!cmd_info[dir])
      cache_dir(dir);
//And if it's still not in the cache, this is a bogus path.
    if(!cmd_info[dir])
      continue;
    if(member_array(cmd, cmd_info[dir]) != -1 &&
        is_file(dir+cmd+".pike") &&
        (o = load_object(dir+cmd)))
    {
      if(!is_command(o))
        return -1;
      return ({ o, dir, cmd });
    }
  }

  return 0;
}

mixed find_cmd(string cmd, array(string) path)
{
  object	o;
  string	dir, s;
  
#ifdef DEBUG_CMD_SEARCH
   kernel()->console_write("find_cmd(%O,%O)\n",cmd,path);
#endif   
    
  if (member_array('/', cmd) != -1)
  {
    s = evaluate_path(cmd);
    if(o = load_object(s))
    {
      if (is_command(o))
      {
        mixed tmp = split_path(s);
        dir = tmp[0];
        s = tmp[1];
        sscanf(s, "%s.pike", s);
        if(!cmd_info[dir])
          cache_dir(dir);
        return ({o, dir, s });
      }
    }
  }
  return find_cmd_in_path(cmd, path);
}

string _to_str(mixed value) {
   return stringp(value) ? value : sprintf("%O",value);
}

mixed _unquote(mixed value) {
  return  (stringp(value) && value[0] == '"' && value[-1] == '"') ?
      value[1..<2] : value;
}

mixed smart_arg_parsing(mixed argv, array(string) path, array(string) implode_info)
{
    mixed	resv;
    mixed	info;
    string cmd_name;
    string	this_path;
    object	cmd_obj;
    proto_info	pstuff;
    string	USAGE;
    string	opstr;
    mapping	ops;
    int	argcounter;
    int	i;
    mixed expanded_arg;
    mixed	this_arg;
    int	plural;

#ifdef DEBUG_CMD_SEARCH
   kernel()->console_write("*smart_arg_parsing(%O,%O,%O)\n",argv,path,implode_info);
#endif

    if (sizeof(argv) == 0) {
#ifdef DEBUG_CMD_SEARCH
   kernel()->console_write("smart_arg_parsing(%O,%O,%O) nothing to do\n",argv,path,implode_info);
#endif    	
        return -1;
    }
    
    cmd_name = trim_spaces(argv[0]);
    
    
    if (member_array('/', cmd_name) != -1) {
        array matches = filter_array(glob(cmd_name + ".pike"),  is_file );
           
        switch (sizeof(matches)) {
            case 1:
                if ((cmd_obj = load_object(matches[0])) &&
            is_command(cmd_obj))
        {
          mixed tmp = split_path(matches[0]);
          this_path = tmp[0];
          cmd_name = tmp[1][0..<3];
        } else {
          return 0;
        }
        break;
      case 0:
        break;
      default:
        printf("Ambiguous expansion for %s.\n", cmd_name);
        return 1;
    }
  }
  
  
  if (!this_path)
  {
    info = find_cmd(cmd_name, path);
    if (intp(info))
      return info;
    cmd_obj = info[0];
    this_path = info[1];
    cmd_name = info[2];
  }

  if(zero_type(proto_info_store[this_path]) ||
      undefinedp(pstuff=proto_info_store[this_path][cmd_name]))
  {
// no prototypes, so don't do no globbing or nothin'.
// In fact, just send back the raw string.
    if(sizeof(argv) > 1)
    {
// make it so that all non-strings are converted to strings,
// since whatever command is going to be expecting a string.
      argv = map(argv, _to_str);
      return ({cmd_obj, ([]), implode_by_arr(argv[1..], implode_info) });
    }
    else
      return ({ cmd_obj, ([]), 0});
  }

// Remove "'s for: "word1 word2"
  argv = map(argv, _unquote);
  USAGE = pstuff->proto_string;

  if(sizeof(argv) > 1)
  {
    argv = argv[1..];
    if((opstr = pstuff->options))
    {
      info = getopt(argv, opstr);
      if(!arrayp(info))
        return -2;
      argv = info[1];
      ops = info[0];
    }
  } else {
    argv = ({});
  }
  if(!ops) ops = ([]);

  argcounter = 0;
  resv = allocate(sizeof(pstuff->prototype));
  for(i=0; i<sizeof(pstuff->prototype); i++)
  {
    if(argcounter == sizeof(argv))
    {
      if(i >= pstuff->first_optional_arg && pstuff->first_optional_arg != -1)
        break;
      printf("Too few arguments.\nUsage: %s\n", USAGE);
      return 1;
    }
    expanded_arg = parse_arg(pstuff->prototype[i],argv[argcounter++]);
    if (intp(expanded_arg))
    {
// error
      switch (expanded_arg)
      {
        case -1:
          printf("Invalid argument: %O\nUsage: %s\n",
                  argv[argcounter-1], USAGE);
          break;
        case -2:
          printf("Vague argument: %O\nUsage: %s\n",
                  argv[argcounter-1], USAGE);
          break;
        case -3:
          printf("%s: No such file or directory.\n", argv[argcounter-1]);
          break;
      }
      return 1;
    }
    plural = pstuff->prototype[i] & PLURAL;
    this_arg = expanded_arg[0];
    resv[i] = expanded_arg[1];
    if(!plural)
    {
      if(sizeof(resv[i]) > 1)
      {
        printf("Vague argument: %s\nUsage: %s\n", argv[argcounter-1], USAGE);
        return 1;
      }
      resv[i] = resv[i][0];
      continue;
    }
    while (1)
    {
      if(argcounter == sizeof(argv))
        break;	
      expanded_arg = parse_arg(this_arg, argv[argcounter]);
      if(!arrayp(expanded_arg))
        break;
      if(sizeof(expanded_arg[1]) == 1 &&
           i+1 != sizeof(pstuff->prototype) &&
           !(pstuff->prototype[i+1]&PLURAL) &&
           (pstuff->prototype[i+1] & expanded_arg[0]) &&
           (argcounter + 1 == sizeof(argv) ||
           intp(parse_arg(pstuff->prototype[i+1], argv[argcounter+1]))))
        break;
      resv[i] += expanded_arg[1];
      argcounter++;
    }
  }
  if(argcounter != sizeof(argv))
  {
    if(pstuff->prototype[i-1] & PLURAL)
      printf("%s: not found.\n", argv[argcounter]);
    else
      printf("Too many arguments.\nUsage: %s\n",USAGE);
    return 1;
  }
  return ({ cmd_obj, ops, resv });
}

int _n_is_directory(mixed arg) {
    return !is_directory(arg);
}

private mixed parse_arg(int this_arg, mixed argv)
{
  int	hits;
  mixed	untrimmed_argv;
  array	result = ({});
  array string_result;
    
  untrimmed_argv = argv;

  if(stringp(argv))
  {
    argv = trim_spaces(argv);
    if (this_arg & IS_PATH)
    {
      string path = evaluate_path(argv);
      result = glob(path);
      if((this_arg & IS_PIKEFILE) && ! (this_arg & IS_DIR))
        result = filter(result, _n_is_directory);
      if (!sizeof(result) && (this_arg & IS_OBFILE))
      {
        object ob = get_object(argv);
        if (ob)
        {
          string bname = base_name(ob);
          if(is_file(bname + ".pike"))
            result = ({ bname + ".pike" });
            /*
          else
          {
            if(is_file(bname + ".scr"))
              result = ({bname + ".scr"});
          }
          */
        }
      }
      if (!sizeof(result) && (this_arg & IS_PIKEFILE))
      {
        int ix = strsrch(path, ".", -1);
        string extension = path[ix+1..];

        if(extension != "c" && extension != "scr")
        {
          result = glob(path + ".pike") /* + glob(path + ".scr") */;
        }
      }

      if ((this_arg & IS_FILE) && !(this_arg & IS_DIR))
        result = filter(result, is_file );

      if ((this_arg & IS_DIR) && !(this_arg & IS_FILE))
        result = filter(result, is_directory );

      if (!sizeof(result) && (this_arg & IS_FNAME))
      {
        if (is_directory(base_path(path)))
          result = ({ path });
      }

      if (!sizeof(result))
        result = 0;
      else
      {
        result = ({ this_arg & FILE_FLAGS, result });
        hits++;
      }
    }

    if (this_arg & STR)
    {
      string_result = ({ STR, ({ untrimmed_argv }) });
      hits++;
    }
  }

  if (this_arg & IS_OBJECT)
  {
    object ob;

    if(stringp(argv))
      ob = get_object(argv);
    else if (objectp(argv))
      ob = argv;
    else
      ob = 0;

    if((this_arg & ONLY_USER) && ob && !ob->query_link())
      ob = 0;

    if(ob)
    {
      result = ({ this_arg & (IS_OBJECT | ONLY_USER), ({ ob }) });
      hits++;
    }
  }

  if (this_arg & NUM)
  {
    int tmp;

    if (intp(argv))
    {
      result = ({ NUM, ({ argv }) });
      hits++;
    }
    else if (sscanf(argv,"%d",tmp))
    {
      result = ({ NUM, ({ tmp }) });
      hits++;
    }
  }

  if(!hits)
  {
    if (this_arg & IS_PATH)
      return -3;
    else
      return -1;
  }

  if (this_arg & STR)
  {
    if (hits == 1)
      result = string_result; // use string hit
    else
      hits--; // discard string hit
  }

  if(hits > 1)
    return -2;

  return result;
}