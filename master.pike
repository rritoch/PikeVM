// -*- Pike -*-
//
// Master Control Program for Pike.
//
// This file is part of Pike. For copyright information see COPYRIGHT.
// Pike is distributed under GPL, LGPL and MPL. See the file COPYING
// for more information.
//
// $Id: master.pike.in,v 1.465 2009/09/19 02:30:07 nilsson Exp $

#pike __REAL_VERSION__
//#pragma strict_types

//! @appears predef::MasterObject
//!
//! Master control program for Pike.
//!
//! @seealso
//!   @[predef::master()], @[predef::replace_master()]

// --- Some configurable parameters

#define PIKE_AUTORELOAD
#define GETCWD_CACHE
//#define FILE_STAT_CACHE

// This define is searched and replaced by bin/install.pike.
#undef PIKE_MODULE_RELOC

#ifndef PIKE_WARNINGS
#define PIKE_WARNINGS 1
#endif /* PIKE_WARNINGS */


// --- Global constants and variables

// Used by describe_backtrace() et al.
#if !defined(BT_MAX_STRING_LEN) || (BT_MAX_STRING_LEN <= 0)
#undef BT_MAX_STRING_LEN
#define BT_MAX_STRING_LEN	200
#endif /* !defined(BT_MAX_STRING_LEN) || (BT_MAX_STRING_LEN <= 0) */
constant bt_max_string_len = BT_MAX_STRING_LEN;

//! @decl constant bt_max_string_len = 200
//! This constant contains the maximum length of a function entry in a
//! backtrace. Defaults to 200 if no BT_MAX_STRING_LEN define has been
//! given.

// Enables the out of date warning in low_findprog().
#ifndef OUT_OF_DATE_WARNING
#define OUT_OF_DATE_WARNING 1
#endif /* OUT_OF_DATE_WARNING */
constant out_of_date_warning = OUT_OF_DATE_WARNING;

// FIXME: PATH_SEPARATOR and UPDIR should probably be exported,
//        or at least some functions that use them should be.
//        cf Tools.Shoot.runpike.
//	/grubba 2004-04-11
#if defined(__NT__) || defined(__amigaos__)
#define PATH_SEPARATOR ";"
#else
#define PATH_SEPARATOR ":"
#endif

#ifdef __amigaos__
#define UPDIR "/"
#else
#define UPDIR "../"
#endif

//! @decl constant out_of_date_warning = 1
//! Should Pike complain about out of date compiled files.
//! 1 means yes and 0 means no. Controlled by the OUT_OF_DATE_WARNING
//! define.

//! If not zero compilation warnings will be written out on stderr.
int want_warnings = PIKE_WARNINGS;

//!
int compat_major=-1;

//!
int compat_minor=-1;

//!
int show_if_constant_errors = 0;

// ---  Functions begin here.

// Have to access some stuff without going through the resolver.
private object(_static_modules.Builtin) Builtin = _static_modules.Builtin();
#if __REAL_VERSION__ < 7.9
private constant Files = _static_modules.files;
#else
private constant Files = _static_modules._Stdio;
#endif

#define Stat Files.Stat
#define capitalize(X) (upper_case((X)[..0])+(X)[1..])
#define trim_all_whites(X) (Builtin.string_trim_all_whites (X))

private function write = Files()->_stdout->write;
private function werror = Files()->_stderr->write;

// Tell Pike.count_memory this is global.
constant pike_cycle_depth = 0;

#ifdef RESOLV_DEBUG

#if constant (thread_local)
protected object resolv_msg_depth = thread_local();
// NOTE: May be used before __INIT has completed.
#define GET_RESOLV_MSG_DEPTH (resolv_msg_depth && resolv_msg_depth->get())
#define INC_RESOLV_MSG_DEPTH() (resolv_msg_depth && resolv_msg_depth->set (resolv_msg_depth->get() + 1))
#define DEC_RESOLV_MSG_DEPTH() (resolv_msg_depth && resolv_msg_depth->set (resolv_msg_depth->get() - 1))
#else
protected int resolv_msg_depth;
#define GET_RESOLV_MSG_DEPTH resolv_msg_depth
#define INC_RESOLV_MSG_DEPTH() (++resolv_msg_depth)
#define DEC_RESOLV_MSG_DEPTH() (--resolv_msg_depth)
#endif

void resolv_debug (sprintf_format fmt, sprintf_args... args)
{
  string pad = "  " * GET_RESOLV_MSG_DEPTH;
  if (sizeof (args)) fmt = sprintf (fmt, @args);
  if (fmt[-1] == '\n')
    fmt = pad + replace (fmt[..<1], "\n", "\n" + pad) + "\n";
  else
    fmt = pad + replace (fmt, "\n", "\n" + pad);
  if (!werror) werror = Files()->_stderr->write;
  werror (fmt);
}

#else  // !RESOLV_DEBUG
#define INC_RESOLV_MSG_DEPTH() 0
#define DEC_RESOLV_MSG_DEPTH() 0
#define resolv_debug(X...) do {} while (0)
#endif	// !RESOLV_DEBUG

constant no_value = (<>);
constant NoValue = typeof (no_value);

// Some API compatibility stuff.

//! Pike 0.5 master compatibility interface.
//!
//! Most of the interface is implemented via mixin,
//! or overloading by more recent masters.
//!
//! This interface is used for compatibility with
//! all pikes until Pike 0.5.
//!
//! @deprecated predef::MasterObject
//!
//! @seealso
//!   @[get_compat_master()], @[master()], @[predef::MasterObject]
protected class Pike_0_5_master
{
  string describe_backtrace(array(mixed) trace);
  object low_cast_to_object(string oname, string current_file);
  extern array(string) pike_include_path;
  string pike_library_path =
#if "C:/Program Files/Pike/lib"[0]!='#'
    "C:/Program Files/Pike/lib"
#else
    __DIR__
#endif
    ;
  extern array(string) pike_module_path;
  extern array(string) pike_program_path;
#ifdef GETCWD_CACHE
  extern string current_path;
  int cd(string s);
  string getcwd();
#endif
  string combine_path_with_cwd(string path);
#ifdef FILE_STAT_CACHE
  extern int invalidate_time;
  extern mapping(string:multiset(string)) dir_cache;
#endif
  local array(mixed) master_file_stat(string x)
  {
    Stat st = global::master_file_stat(x);
    return st && (array)st;
  }

  //! @decl mapping(string:array(string)) environment
  //!
  //! Mapping containing the environment variables.
  //!
  //! The mapping currently has the following structure:
  //! @mapping
  //!   @member array(string) index
  //!      Note that the index is @[lower_case()]'d on NT.
  //!      @array
  //!         @elem string varname
  //!            Variable name with case intact.
  //!         @elem string value
  //!            Variable value.
  //!      @endarray
  //! @endmapping
  //!
  //! @note
  //!   This mapping should not be accessed directly; use @[getenv()]
  //!   and @[putenv()] instead. This mapping is not publicly
  //!   accessible in pikes newer than 7.6.
  //!
  //! @note
  //!   This mapping is not compatible with @[Process.create_process()];
  //!   use the mapping returned from calling @[getenv()] without arguments
  //!   instead.
  //!
  //! @bugs
  //!   This mapping is not the real environment; it is just a copy of
  //!   the environment made at startup. Pike does attempt to keep
  //!   track of changes in the mapping and to reflect them in the
  //!   real environment, but avoid accessing this mapping if at all
  //!   possible.

  string|mapping(string:string) getenv(string|void s);
  void putenv(string|void varname, string|void value);

  // compat_environment is the mapping returned by `environment
  // (if any).
  // compat_environment_copy is used to keep track of any changes
  // performed destructively on the compat_environment mapping.
  // Both should be zero if not in use.
  protected mapping(string:array(string)) compat_environment;
  protected mapping(string:array(string)) compat_environment_copy;

#pragma no_deprecation_warnings
  local __deprecated__(mapping(string:array(string))) `environment()
  {
    if (compat_environment) return compat_environment;
    compat_environment_copy = ([]);
#ifdef __NT__
    // Can't use the cached environment returned by getenv(), since
    // variable names have been lowercased there.
    foreach((array(array(string)))Builtin._getenv(), array(string) pair) {
      compat_environment_copy[lower_case(pair[0])] = pair;
    }
#else
    foreach((array(array(string)))getenv(), array(string) pair) {
      compat_environment_copy[pair[0]] = pair;
    }
#endif
    return compat_environment = copy_value(compat_environment_copy);
  }

  local void `environment=(__deprecated__(mapping(string:array(string)))
			   new_env)
  {
    compat_environment = new_env;
    if (!new_env)
      compat_environment_copy = 0;
    else if (!compat_environment_copy)
      compat_environment_copy = ([]);
  }
#pragma deprecation_warnings

  void add_include_path(string tmp);
  void remove_include_path(string tmp);
  void add_module_path(string tmp);
  void remove_module_path(string tmp);
  void add_program_path(string tmp);
  void remove_program_path(string tmp);
  mapping(string:program|NoValue) programs;
  program cast_to_program(string pname, string current_file);
  void handle_error(array(mixed) trace);

  //! Make a new instance of a class.
  //!
  //! @note
  //!   This function should not be used. It is here for
  //!   compatibility reasons only.
  local __deprecated__ object new(mixed prog, mixed ... args)
  {
    if(stringp(prog))
      prog=cast_to_program(prog,backtrace()[-2][0]);
    return prog(@args);
  }

  void create();
  program handle_inherit(string pname, string current_file);
  extern mapping(program:object) objects;
  object low_cast_to_object(string oname, string current_file);
  object cast_to_object(string oname, string current_file);
  class dirnode {};
  object findmodule(string fullname);
  local protected object Pike_0_5_compat_handler;
  local mixed resolv(string identifier, string|void current_file)
  {
    if (!Pike_0_5_compat_handler) {
      Pike_0_5_compat_handler = global::get_compilation_handler(0, 5);
    }
    return Pike_0_5_compat_handler->resolv(identifier, current_file);
  }
  extern string _master_file_name;
  void _main(array(string) orig_argv, array(string) env);
  extern mixed inhibit_compile_errors;
  void set_inhibit_compile_errors(mixed f);
  string trim_file_name(string s);
  void compile_error(string file,int line,string err);
  string handle_include(string f, string current_file, int local_include);
  local __deprecated__ string stupid_describe(mixed m)
  {
    switch(string typ=sprintf("%t",m))
    {
    case "int":
    case "float":
      return (string)m;

    case "string":
      if(sizeof(m) < BT_MAX_STRING_LEN)
      {
	string t = sprintf("%O", m);
	if (sizeof(t) < (BT_MAX_STRING_LEN + 2)) {
	  return t;
	}
	t = 0;
      }

    case "array":
    case "mapping":
    case "multiset":
      return typ+"["+sizeof(m)+"]";

    default:
      return typ;
    }
  }

  string describe_backtrace(array(mixed) trace);

  object get_compat_master(int major, int minor)
  {
    // 0.0 - 0.5
    if (!major && (minor < 6))
      return this_program::this;
    return get_compat_master(major, minor);
  }

  /* Missing symbols:
   *
   * __INIT
   * __lambda_30	(Alias for mkmapping().)
   */
}

//! Pike 0.6 master compatibility interface.
//!
//! Most of the interface is implemented via mixin,
//! or overloading by more recent masters.
//!
//! This interface is used for compatibility with
//! Pike 0.6.
//!
//! @deprecated predef::MasterObject
//!
//! @seealso
//!   @[get_compat_master()], @[master()], @[predef::MasterObject]
protected class Pike_0_6_master
{
  inherit Pike_0_5_master;
  int is_absolute_path(string p);
  array(string) explode_path(string p);
  string dirname(string x);
  string basename(string x);
  object low_cast_to_object(string oname, string current_file);
#pragma no_deprecation_warnings
  private __deprecated__(string) pike_library_path =
    (__deprecated__(string))Pike_0_5_master::pike_library_path;
#pragma deprecation_warnings
  extern int want_warnings;
  program compile_string(string data, void|string name);
  program compile_file(string file);

#if constant(_static_modules.Builtin.mutex)
  extern object compilation_mutex;
#endif

  local constant mkmultiset = predef::mkmultiset;
  local __deprecated__(function) clone = new;
  constant master_efuns = ({});
  class joinnode {};
  extern mapping(string:mixed) fc;
  mixed handle_import(string what, string|void current_file);
  local protected object Pike_0_6_compat_handler;
  local mixed resolv(string identifier, string|void current_file)
  {
    if (!Pike_0_6_compat_handler) {
      Pike_0_6_compat_handler = global::get_compilation_handler(0, 6);
    }
    return Pike_0_6_compat_handler->resolv(identifier, current_file);
  }
  extern string _pike_file_name;
  void compile_warning(string file,int line,string err);
  string read_include(string f);

  string describe_program(program p);
  string describe_backtrace(array(mixed) trace);
  class Codec {};

  object get_compat_master(int major, int minor)
  {
    if (!major && (minor < 6))
      return Pike_0_5_master::get_compat_master(major, minor);
    // 0.6
    if (!major && (minor < 7))
      return this_program::this;
    return get_compat_master(major, minor);
  }

  /* Missing symbols:
   *
   * __INIT
   */
}

//! Pike 7.0 master compatibility interface.
//!
//! Most of the interface is implemented via mixin,
//! or overloading by more recent masters.
//!
//! This interface is used for compatibility with
//! Pike 0.7 through 7.0.
//!
//! @deprecated predef::MasterObject
//!
//! @seealso
//!   @[get_compat_master()], @[master()], @[predef::MasterObject]
class Pike_7_0_master
{
  inherit Pike_0_6_master;
  constant bt_max_string_len = 1;
  constant out_of_date_warning = 1;
#ifdef PIKE_FAKEROOT
  extern object o;
  string fakeroot(string s);
#endif
#ifdef PIKE_AUTORELOAD
  extern int autoreload_on;
  extern int newest;
  extern mapping(string:int) load_time;
#endif
  string master_read_file();
  string normalize_path(string X);
  array(string) query_precompiled_names(string fname);
  program cast_to_program(string pname, string current_file,
			  object|void handler);
  void handle_error(array(mixed)|object trace);
  protected private constant mkmultiset = mkmultiset;
  program handle_inherit(string pname, string current_file, object|void handler);
  mixed handle_import(string what, string|void current_file, object|void handler);
  mixed resolv_base(string identifier, string|void current_file);

  // FIXME: Not in 7.7!
  extern mapping resolv_cache;
  local protected object Pike_7_0_compat_handler;
  local mixed resolv(string identifier, string|void current_file)
  {
    if (!Pike_7_0_compat_handler) {
      Pike_7_0_compat_handler = global::get_compilation_handler(7, 0);
    }
    return Pike_7_0_compat_handler->resolv(identifier, current_file);
  }
  mixed get_inhibit_compile_errors();
  string decode_charset(string data, string charset);
  local __deprecated__(int) clipped=0;
  local __deprecated__(int) canclip=0;
#pragma no_deprecation_warnings
  local __deprecated__ string stupid_describe(mixed m, int maxlen)
  {
    string typ;
    if (catch (typ=sprintf("%t",m)))
      typ = "object";		// Object with a broken _sprintf(), probably.
    switch(typ)
    {
    case "int":
    case "float":
      return (string)m;
      
    case "string":
      canclip++;
      if(sizeof(m) < maxlen)
      {
	string t = sprintf("%O", m);
	if (sizeof(t) < (maxlen + 2)) {
	  return t;
	}
	t = 0;
      }
      clipped++;
      if(maxlen>10)
      {
	return sprintf("%O+[%d]",m[..maxlen-5],sizeof(m)-(maxlen-5));
      }else{
	return "string["+sizeof(m)+"]";
      }
      
    case "array":
      if(!sizeof(m)) return "({})";
      if(maxlen<5)
      {
	clipped++;
	return "array["+sizeof(m)+"]";
      }
      canclip++;
      return "({" + stupid_describe_comma_list(m,maxlen-2) +"})";
      
    case "mapping":
      if(!sizeof(m)) return "([])";
      return "mapping["+sizeof(m)+"]";
      
    case "multiset":
      if(!sizeof(m)) return "(<>)";
      return "multiset["+sizeof(m)+"]";
      
    case "function":
      if(string tmp=describe_program(m)) return tmp;
      if(object o=function_object(m))
	return (describe_object(o)||"")+"->"+function_name(m);
      else {
	string tmp;
	if (catch (tmp = function_name(m)))
	  // The function object has probably been destructed.
	  return "function";
	return tmp || "function";
      }

    case "program":
      if(string tmp=describe_program(m)) return tmp;
      return typ;

    default:
      if (objectp(m))
	if(string tmp=describe_object(m)) return tmp;
      return typ;
    }
  }
  local __deprecated__ string stupid_describe_comma_list(array x, int maxlen)
  {
    string ret="";

    if(!sizeof(x)) return "";
    if(maxlen<0) return ",,,"+sizeof(x);

    int clip=min(maxlen/2,sizeof(x));
    int len=maxlen;
    int done=0;

//  int loopcount=0;

    while(1)
    {
//    if(loopcount>10000) werror("len=%d\n",len);
      array(string) z=allocate(clip);
      array(int) isclipped=allocate(clip);
      array(int) clippable=allocate(clip);
      for(int e=0;e<clip;e++)
      {
	clipped=0;
	canclip=0;
	z[e]=stupid_describe(x[e],len);
	isclipped[e]=clipped;
	clippable[e]=canclip;
      }

      while(1)
      {
//      if(loopcount>10000)  werror("clip=%d maxlen=%d\n",clip,maxlen);
	string ret = z[..clip-1]*",";
//      if(loopcount>10000)  werror("sizeof(ret)=%d z=%O isclipped=%O done=%d\n",sizeof(ret),z[..clip-1],isclipped[..clip-1],done);
	if(done || sizeof(ret)<=maxlen+1)
	{
	  int tmp=sizeof(x)-clip-1;
//        if(loopcount>10000) werror("CLIPPED::::: %O\n",isclipped);
	  clipped=`+(0,@isclipped);
	  if(tmp>=0)
	  {
	    clipped++;
	    ret+=",,,"+tmp;
	  }
	  canclip++;
	  return ret;
	}

	int last_newlen=len;
	int newlen;
	int clipsuggest;
	while(1)
	{
//        if(loopcount++ > 20000) return "";
//        if(!(loopcount & 0xfff)) werror("GNORK\n");
	  int smallsize=0;
	  int num_large=0;
	  clipsuggest=0;

	  for(int e=0;e<clip;e++)
	  {
//          if(loopcount>10000) werror("sizeof(z[%d])=%d  len=%d\n",e,sizeof(z[e]),len);

	    if((sizeof(z[e])>=last_newlen || isclipped[e]) && clippable[e])
	      num_large++;
	    else
	      smallsize+=sizeof(z[e]);

	    if(num_large * 15 + smallsize < maxlen) clipsuggest=e+1;
	  }
        
//        if(loopcount>10000) werror("num_large=%d  maxlen=%d  smallsize=%d clippsuggest=%d\n",num_large,maxlen,smallsize,clipsuggest);
	  newlen=num_large ? (maxlen-smallsize)/num_large : 0;
       
//        if(loopcount>10000) werror("newlen=%d\n",newlen);

	  if(newlen<8 || newlen >= last_newlen) break;
	  last_newlen=newlen;
//        if(loopcount>10000) werror("len decreased, retrying.\n");
	}

	if(newlen < 8 && clip)
	{
	  clip-= (clip/4) || 1;
	  if(clip > clipsuggest) clip=clipsuggest;
//        if(loopcount>10000) werror("clip decreased, retrying.\n");
	}else{
	  len=newlen;
	  done++;
	  break;
	}
      }
    }

    return ret;
  }
#pragma deprecation_warnings

  string describe_object(object o);
  string describe_backtrace(array(mixed) trace, void|int linewidth);
  string describe_error(mixed trace);

  object get_compat_master(int major, int minor)
  {
    if (!major && (minor < 7))
      return Pike_0_6_master::get_compat_master(major, minor);
    // 0.7 - 7.0
    if ((major < 7) || ((major == 7) && !minor))
      return this_program::this;
    return get_compat_master(major, minor);
  }

  /* No missing symbols. */
}

//! Pike 7.2 master compatibility interface.
//!
//! Most of the interface is implemented via mixin,
//! or overloading by more recent masters.
//!
//! This interface is used for compatibility with
//! Pike 7.1 and 7.2.
//!
//! @deprecated predef::MasterObject
//!
//! @seealso
//!   @[get_compat_master()], @[master()], @[predef::MasterObject]
protected class Pike_7_2_master
{
  inherit Pike_7_0_master;
#ifdef PIKE_MODULE_RELOC
  string relocate_module(string s);
  string unrelocate_module(string s);
#endif
  extern int compat_major;
  extern int compat_minor;
  Stat master_file_stat(string x);
  object low_cast_to_object(string oname, string current_file,
			    object|void current_handler);
  object findmodule(string fullname, object|void handler);
  extern multiset no_resolv;
  extern string ver;
  mapping get_default_module();
  local protected object Pike_7_2_compat_handler;
  local mixed resolv(string identifier, string|void current_file)
  {
    if (!Pike_7_2_compat_handler) {
      Pike_7_2_compat_handler = global::get_compilation_handler(7, 2);
    }
    return Pike_7_2_compat_handler->resolv(identifier, current_file);
  }
  void runtime_warning(string where, string what, mixed ... args);
  protected int clipped;
  protected int canclip;
  protected string stupid_describe(mixed m, int maxlen);
  protected string stupid_describe_comma_list(array x, int maxlen);
  class Describer {};
  string describe_function(function f);
  class CompatResolver {};
  int(0..1) asyncp();
  class Version {};
  extern object currentversion;
  extern mapping(object:object) compat_handler_cache;
  object get_compilation_handler(int major, int minor);
  string _sprintf(int|void t);
  object get_compat_master(int major, int minor)
  {
    if ((major < 7) || ((major == 7) && (minor < 1)))
      return Pike_7_0_master::get_compat_master(major, minor);
    // 7.1 & 7.2
    if ((major == 7) && (minor < 3))
      return this_program::this;
    return get_compat_master(major, minor);
  }

  /* No missing symbols. */
}

//! Pike 7.4 master compatibility interface.
//!
//! Most of the interface is implemented via mixin,
//! or overloading by more recent masters.
//!
//! This interface is used for compatibility with
//! Pike 7.3 and 7.4.
//!
//! @deprecated predef::MasterObject
//!
//! @seealso
//!   @[get_compat_master()], @[master()], @[predef::MasterObject]
protected class Pike_7_4_master
{
  inherit Pike_7_2_master;
#ifdef RESOLV_DEBUG
  void resolv_debug (sprintf_format fmt, sprintf_args... args);
#endif
  void error(sprintf_format f, sprintf_args ... args);
#ifdef GETCWD_CACHE
  protected extern string current_path;
#endif
  constant no_value = (<>);
  constant NoValue = typeof (no_value);
  string programs_reverse_lookup (program prog);
  program objects_reverse_lookup (object obj);
  string fc_reverse_lookup (object obj);
  // Hide clone() and new().
  private local __deprecated__ object new(mixed prog, mixed ... args){}
  private local __deprecated__(function) clone = new;
  void unregister(program p);
  program low_cast_to_program(string pname,
			      string current_file,
			      object|void handler,
			      void|int mkobj);
  extern string include_prefix;
  extern mapping(string:string) predefines;
  extern CompatResolver parent_resolver;
  void add_predefine (string name, string value);
  void remove_predefine (string name);
  mapping get_predefines();
#if constant(thread_create)
  object backend_thread();
#endif
  function(string:string) set_trim_file_name_callback(function(string:string) s);
  int compile_exception (array|object trace);
  string program_path_to_name ( string path,
				void|string module_prefix,
				void|string module_suffix,
				void|string object_suffix );
  string describe_module(object|program mod, array(object)|void ret_obj);
  string describe_program(program|function p);
  class Encoder {};
  class Decoder {};
  extern mapping(string:Codec) codecs;
  Codec get_codec(string|void fname, int|void mkobj);

  // The following come from the inherit of Codec. */
  // Codec::Encoder:
  extern mixed encoded;
  string|array nameof (mixed what, void|array(object) module_object);
  mixed encode_object(object x);
  // Codec::Decoder:
  extern string fname;
  extern int mkobj;
  object __register_new_program(program p);
  object objectof (string|array what);
  function functionof (string|array what);
  program programof (string|array what);
  void decode_object(object o, mixed data);

  string _sprintf(int t);
  local protected object Pike_7_4_compat_handler;
  local mixed resolv(string identifier, string|void current_file)
  {
    if (!Pike_7_4_compat_handler) {
      Pike_7_4_compat_handler = global::get_compilation_handler(7, 4);
    }
    return Pike_7_4_compat_handler->resolv(identifier, current_file);
  }
  object get_compat_master(int major, int minor)
  {
    if ((major < 7) || ((major == 7) && (minor < 3)))
      return Pike_7_2_master::get_compat_master(major, minor);
    // 7.3 & 7.4
    if ((major == 7) && (minor < 5))
      return this_program::this;
    return get_compat_master(major, minor);
  }

  /* No missing symbols. */
}

//! Pike 7.6 master compatibility interface.
//!
//! Most of the interface is implemented via mixin,
//! or overloading by more recent masters.
//!
//! This interface is used for compatibility with
//! Pike 7.5 and 7.6.
//!
//! @deprecated predef::MasterObject
//!
//! @seealso
//!   @[get_compat_master()], @[master()], @[predef::MasterObject]
protected class Pike_7_6_master
{
  inherit Pike_7_4_master;
  local protected object Pike_7_6_compat_handler;
  local mixed resolv(string identifier, string|void current_file)
  {
    if (!Pike_7_6_compat_handler) {
      Pike_7_6_compat_handler = global::get_compilation_handler(7, 6);
    }
    return Pike_7_6_compat_handler->resolv(identifier, current_file);
  }
  array get_backtrace (object|array err);
  object get_compat_master(int major, int minor)
  {
    if ((major < 7) || ((major == 7) && (minor < 5)))
      return Pike_7_4_master::get_compat_master(major, minor);
    // 7.5 & 7.6
    if ((major == 7) && (minor < 7))
      return this_program::this;
    return get_compat_master(major, minor);
  }
}

//! Namespaces for compat masters.
//!
//! This inherit is used to provide compatibility namespaces
//! for @[get_compat_master()].
//!
//! @seealso
//!   @[get_compat_master()]
protected inherit Pike_7_6_master;

//! @appears error
//! Throws an error. A more readable version of the code
//! @expr{throw( ({ sprintf(f, @@args), backtrace() }) )@}.
void error(sprintf_format f, sprintf_args ... args) {
  if (sizeof(args)) f = sprintf(f, @args);
  throw( ({ f, backtrace()[..<1] }) );
}

// FIXME: Should the pikeroot-things be private?
#ifdef PIKE_FAKEROOT
object o;
string fakeroot(string s)
{
  string tmp1=combine_path_with_cwd(s);
#ifdef PIKE_FAKEROOT_OMIT
  foreach(PIKE_FAKEROOT_OMIT/PATH_SEPARATOR, string x)
    if(glob(x,tmp1))
      return s;
#endif
  return PIKE_FAKEROOT+tmp1;
}
#else
#define fakeroot(X) X
#endif // PIKE_FAKEROOT

#ifdef PIKE_MODULE_RELOC
string relocate_module(string s)
{
  if(s == "/${PIKE_MODULE_PATH}" || has_prefix (s, "/${PIKE_MODULE_PATH}/")) {
    string tmp = s[21..];
    foreach(pike_module_path, string path) {
      string s2 = fakeroot(sizeof(tmp)? combine_path(path, tmp) : path);
      if(master_file_stat(s2))
	return s2;
    }
  }
  return fakeroot(s);
}

string unrelocate_module(string s)
{
  if(s == "/${PIKE_MODULE_PATH}" || has_prefix (s, "/${PIKE_MODULE_PATH}/"))
    return s;

  foreach(pike_module_path, string path)
    if(s == path)
      return "/${PIKE_MODULE_PATH}";
    else {
      path = combine_path(path, "");
      if(has_prefix (s, path))
	return "/${PIKE_MODULE_PATH}/"+s[sizeof(path)..];
    }

  /* This is necessary to find compat modules... */
  foreach(pike_module_path, string path) {
    path = combine_path(path, UPDIR, "");
    if(has_prefix (s, path))
      return "/${PIKE_MODULE_PATH}/"+UPDIR+s[sizeof(path)..];
  }

  return s;
}

#ifdef fakeroot
#undef fakeroot
#endif
#define fakeroot relocate_module
#endif // PIKE_MODULE_RELOC


//! @appears is_absolute_path
//! Check if a path @[p] is fully qualified (ie not relative).
//!
//! @returns
//! Returns 1 if the path is absolute, 0 otherwise.
int is_absolute_path(string p)
{
#ifdef __amigaos__
#define IS_ABSOLUTE_PATH(X) (search((X),":")>0)
  return IS_ABSOLUTE_PATH(p);
#else
#ifdef __NT__
  p=replace(p,"\\","/");
  if(sscanf(p,"%[a-zA-Z]:%*c",string s)==2 && sizeof(s)==1)
    return 1;
#define IS_ABSOLUTE_PATH is_absolute_path
#else
#define IS_ABSOLUTE_PATH(X) has_prefix((X),"/")
#endif
  return has_prefix(p,"/");
#endif
}

#ifdef __NT__
#define EXPLODE_PATH(X) (replace((X),"\\","/")/"/")
#else
#define EXPLODE_PATH(X) ((X)/"/")
#endif

//! @appears explode_path
//! Split a path @[p] into its components.
//!
//! This function divides a path into its components. This might seem like
//! it could be done by dividing the string on <tt>"/"</tt>, but that will
//! not work on some operating systems.  To turn the components back into
//! a path again, use @[combine_path()].
//!
array(string) explode_path(string p)
{
#ifdef __amigaos__
  int colon = search(reverse(p), ":");
  if(colon >= 0)
    return ({ p[..<colon] }) + explode_path(p[<colon+1..]);
  array(string) r = p/"/";
  return replace(r[..<1], "", "/")+r[<0..];
#else
  array(string) r = EXPLODE_PATH(p);
  if(r[0] == "" && sizeof(p))
    r[0] = "/";
  return r;
#endif
}

//! @appears dirname
//! Returns all but the last segment of a path. Some example inputs and
//! outputs:
//!
//! @xml{<matrix>
//! <r><c><b>Expression</b></c><c><b>Value</b></c></r>
//! <r><c>dirname("/a/b")</c><c>"/a"</c></r>
//! <r><c>dirname("/a/")</c><c>"/a"</c></r>
//! <r><c>dirname("/a")</c><c>"/"</c></r>
//! <r><c>dirname("/")</c><c>"/"</c></r>
//! <r><c>dirname("")</c><c>""</c></r>
//! </matrix>@}
//!
//! @seealso
//! @[basename()], @[explode_path()]
string dirname(string x)
{
  if(x=="") return "";
#ifdef __amigaos__
  array(string) tmp=x/":";
  array(string) tmp2=tmp[-1]/"/";
  tmp[-1]=tmp2[..<1]*"/";
  if(sizeof(tmp2) >= 2 && tmp2[-2]=="") tmp[-1]+="/";
  return tmp*":";
#else
  array(string) tmp=EXPLODE_PATH(x);
  if(x[0]=='/' && sizeof(tmp)<3) return "/";
  return tmp[..<1]*"/";
#endif
}

//! @appears basename
//! Returns the last segment of a path.
//!
//! @seealso
//! @[dirname()], @[explode_path()]
string basename(string x)
{
#ifdef __amigaos__
  return ((x/":")[-1]/"/")[-1];
#define BASENAME(X) ((((X)/":")[-1]/"/")[-1])
#else
  array(string) tmp=EXPLODE_PATH(x);
  return tmp[-1];
#define BASENAME(X) (EXPLODE_PATH(X)[-1])
#endif
}

#ifdef PIKE_AUTORELOAD

int autoreload_on;
int newest;

#define AUTORELOAD_BEGIN() \
    int ___newest=newest;  \
    newest=0

#define AUTORELOAD_CHECK_FILE(X) do {					\
    if(autoreload_on)							\
      if(Stat s=master_file_stat(X))					\
	if(s->mtime>newest) newest=[int]s->mtime;			\
  } while(0)

#define AUTORELOAD_FINISH(VAR, CACHE, FILE)				\
  if(autoreload_on) {							\
    mixed val = CACHE[FILE];						\
    if(!zero_type (val) && val != no_value &&				\
       newest <= load_time[FILE]) {					\
      VAR = val;							\
    }									\
  }									\
  load_time[FILE] = newest;						\
  if(___newest > newest) newest=___newest;


mapping(string:int) load_time=([]);
#else

#define AUTORELOAD_CHECK_FILE(X)
#define AUTORELOAD_BEGIN()
#define AUTORELOAD_FINISH(VAR,CACHE,FILE)

#endif // PIKE_AUTORELOAD

//! @appears compile_string
//! Compile the Pike code in the string @[source] into a program.
//! If @[filename] is not specified, it will default to @expr{"-"@}.
//!
//! Functionally equal to @expr{@[compile](@[cpp](@[source], @[filename]))@}.
//!
//! @seealso
//! @[compile()], @[cpp()], @[compile_file()]
//!
program compile_string(string source, void|string filename,
		       object|void handler,
		       void|program p,
		       void|object o,
		       void|int _show_if_constant_errors)
{
  program ret = compile(cpp(source, filename||"-", 1, handler,
		     compat_major, compat_minor,
		     (zero_type(_show_if_constant_errors)?
		      show_if_constant_errors:
		      _show_if_constant_errors)),
		 handler,
		 compat_major,
		 compat_minor,
		 p,
		 o);
  if (source_cache)
    source_cache[ret] = source;
  return ret;
}

//!
string master_read_file(string file)
{
  object o=Files()->Fd();
  if( ([function(string, string : int)]o->open)(fakeroot(file),"r") )
    return ([function(void : string)]o->read)();
  return 0;
}

#ifdef GETCWD_CACHE
protected string current_path;
int cd(string s)
{
  current_path=0;
  return predef::cd(s);
}

string getcwd()
{
  return current_path || (current_path=predef::getcwd());
}
#endif // GETCWD_CACHE

string combine_path_with_cwd(string ... paths)
{
  return combine_path(IS_ABSOLUTE_PATH(paths[0])?"":getcwd(),@paths);
}

#ifdef FILE_STAT_CACHE

#define FILE_STAT_CACHE_TIME 20

int invalidate_time;
mapping(string:multiset(string)) dir_cache = ([]);


array(string) master_get_dir(string|void x)
{
  return get_dir(x);
}

Stat master_file_stat(string x)
{
  string dir = combine_path_with_cwd(x);
  string file = BASENAME(dir);
  dir = dirname(dir);

  if(time() > invalidate_time)
  {
    dir_cache = ([]);
    invalidate_time = time()+FILE_STAT_CACHE_TIME;
  }

  multiset(string) d = dir_cache[dir];
  if( zero_type(d) )
  {
    array(string) tmp = master_get_dir(dir);
    if(tmp)
    {
#ifdef __NT__
      tmp = map(tmp, lower_case);
#endif
      d = dir_cache[dir] = (multiset)tmp;
    }
    else
      dir_cache[dir]=0;
  }

#ifdef __NT__
  file = lower_case(file);
#endif
  if(d && !d[file]) return 0;

  return predef::file_stat(x);
}
#else
constant master_file_stat = predef::file_stat;
constant master_get_dir = predef::get_dir;
#endif // FILE_STAT_CACHE


protected mapping(string:string) environment;

#ifdef __NT__
protected void set_lc_env (mapping(string:string) env)
{
  environment = ([]);
  foreach (env; string var; string val)
    environment[lower_case (var)] = val;
}
#endif

//! @decl string getenv (string varname, void|int force_update)
//! @decl mapping(string:string) getenv (void|int force_update)
//!
//! Queries the environment variables. The first variant returns the
//! value of a specific variable or zero if it doesn't exist in the
//! environment. The second variant returns the whole environment as a
//! mapping. Destructive operations on the mapping will not affect the
//! internal environment representation.
//!
//! A cached copy of the real environment is kept to make this
//! function quicker. If the optional flag @[force_update] is nonzero
//! then the real environment is queried and the cache is updated from
//! it. That can be necessary if the environment changes through other
//! means than @[putenv], typically from a C-level library.
//!
//! Variable names and values cannot be wide strings nor contain
//! @expr{'\0'@} characters. Variable names also cannot contain
//! @expr{'='@} characters.
//!
//! @note
//!   On NT the environment variable name is case insensitive.
//!
//! @seealso
//!   @[putenv()]
string|mapping(string:string) getenv (void|int|string varname,
				      void|int force_update)
{
  // Variants doesn't seem to work well yet.
  if (stringp (varname)) {
    if (!environment || force_update) {
#ifdef __NT__
      set_lc_env (Builtin._getenv());
#else
      environment = Builtin._getenv();
#endif
      // Kill the compat environment if forced.
      compat_environment = compat_environment_copy = 0;
    }

#ifdef __NT__
    varname = lower_case(varname);
#endif

    if (compat_environment) {
      array(string) res;
      if (!equal(res = compat_environment[varname],
		 compat_environment_copy[varname])) {
	// Something has messed with the compat environment mapping.
	putenv(varname, res && res[1]);
      }
    }

    return environment[varname];
  }

  else {
    force_update = varname;

    mapping(string:string) res;

    if (force_update) {
      res = Builtin._getenv();
#ifdef __NT__
      set_lc_env (res);
#else
      environment = res + ([]);
#endif
      // Kill the compat environment if forced.
      compat_environment = compat_environment_copy = 0;
    }

    else {
      if (compat_environment &&
	  !equal(compat_environment, compat_environment_copy)) {
	foreach(compat_environment; varname; array(string) pair) {
	  if (!equal(pair, compat_environment_copy[varname])) {
	    putenv(pair[0], pair[1]);
	  }
	}
	foreach(compat_environment_copy; varname; array(string) pair) {
	  if (!compat_environment[varname]) {
	    putenv(pair[0]);
	  }
	}
      }
#ifdef __NT__
      // Can't use the cached environment since variable names have been
      // lowercased there.
      res = Builtin._getenv();
      if (!environment) set_lc_env (res);
#else
      if (!environment) environment = Builtin._getenv();
      res = environment + ([]);
#endif
    }

    return res;
  }
}

void putenv (string varname, void|string value)
//! Sets the environment variable @[varname] to @[value].
//!
//! If @[value] is omitted or zero, the environment variable
//! @[varname] is removed.
//!
//! @[varname] and @[value] cannot be wide strings nor contain
//! @expr{'\0'@} characters. @[varname] also cannot contain
//! @expr{'='@} characters.
//!
//! @note
//!   On NT the environment variable name is case insensitive.
//!
//! @seealso
//! @[getenv()]
//!
{
  Builtin._putenv (varname, value);
  if (compat_environment) {
    string lvarname = varname;
#ifdef __NT__
    lvarname = lower_case(varname);
#endif
    if (value) {
      compat_environment[lvarname] =
	(compat_environment_copy[lvarname] = ({ varname, value })) + ({});
    } else {
      m_delete(compat_environment, lvarname);
      m_delete(compat_environment_copy, lvarname);
    }
  }
  if (environment) {
#ifdef __NT__
    varname = lower_case (varname);
#endif
    if (value) environment[varname] = value;
    else m_delete (environment, varname);
  }
}


//! @appears compile_file
//! Compile the Pike code contained in the file @[filename] into a program.
//!
//! This function will compile the file @[filename] to a Pike program that can
//! later be instantiated. It is the same as doing
//! @expr{@[compile_string](@[Stdio.read_file](@[filename]), @[filename])@}.
//!
//! @seealso
//! @[compile()], @[compile_string()], @[cpp()]
//!
program compile_file(string filename,
		     object|void handler,
		     void|program p,
		     void|object o)
{
  AUTORELOAD_CHECK_FILE(filename);
  return compile(cpp(master_read_file(filename),
		     filename,
		     1,
		     handler,
		     compat_major,
		     compat_minor),
		 handler,
		 compat_major,
		 compat_minor,
		 p,
		 o);
}


//! @appears normalize_path
//! Replaces "\" with "/" if runing on MS Windows. It is
//! adviced to use @[System.normalize_path] instead.
string normalize_path( string path )
{
#ifndef __NT__
  return path;
#else
  return replace(path,"\\","/");
#endif
}

//! Mapping containing the cache of currently compiled files.
//!
//! This mapping currently has the following structure:
//! @mapping
//!    @member program filename
//! @endmapping
//! The filename path separator is / on both NT and UNIX.
//!
//! @note
//!   Special cases: The current master program is available under the
//!   name @expr{"/master"@}, and the program containing the @[main]
//!   function under @expr{"/main"@}.
mapping(string:program|NoValue) programs=(["/master":this_program]);
mapping(program:object) documentation = ([]);
mapping(program:string) source_cache;

mapping (program:object|NoValue) objects=([
  this_program : this,
  object_program(_static_modules): _static_modules,
]);

mapping(string:object|NoValue) fc=([]);

// Note: It's assumed that the mappings above never decrease in size
// unless the reverse mappings above also are updated. no_value should
// otherwise be used for entries that should be considered removed.

// The reverse mapping for objects isn't only for speed; search()
// doesn't work reliably there since it calls `==.
protected mapping(program:string) rev_programs = ([]);
protected mapping(object:program) rev_objects = ([]);
protected mapping(mixed:string) rev_fc = ([]);

string programs_reverse_lookup (program prog)
//! Returns the path for @[prog] in @[programs], if it got any.
{
  // When running with trace, this function can get called
  // before __INIT has completed.
  if (!rev_programs) return UNDEFINED;
  if (sizeof (rev_programs) < sizeof (programs)) {
    foreach (programs; string path; program|NoValue prog)
      if (prog == no_value)
	m_delete (programs, path);
      else
	rev_programs[prog] = path;
  }
  return rev_programs[prog];
}

program objects_reverse_lookup (object obj)
//! Returns the program for @[obj], if known to the master.
{
  if (sizeof (rev_objects) < sizeof (objects)) {
    foreach (objects; program prog; object|NoValue obj)
      if (obj == no_value)
	m_delete (rev_objects, obj);
      else
	rev_objects[obj] = prog;
  }
  return rev_objects[obj];
}

string fc_reverse_lookup (object obj)
//! Returns the path for @[obj] in @[fc], if it got any.
{
  if (sizeof (rev_fc) < sizeof (fc)) {
    foreach (fc; string path; mixed obj)
      if (obj == no_value)
	m_delete (fc, obj);
      else
	rev_fc[obj] = path;
  }
  return rev_fc[obj];
}

array(string) query_precompiled_names(string fname)
{
  // Filenames of potential precompiled files in priority order.
#ifdef PRECOMPILED_SEARCH_MORE
  // Search for precompiled files in all module directories, not just
  // in the one where the source file is. This is useful when running
  // pike directly from the build directory.
  fname = fakeroot (fname);
  // FIXME: Not sure if this works correctly with the fakeroot and
  // module relocation stuff.
  foreach (pike_module_path, string path)
    if (has_prefix (fname, path))
      return map (pike_module_path, `+, "/", fname[sizeof (path)..], ".o");
#endif
  return ({ fname + ".o" });
}

protected class CompileCallbackError
{
  inherit _static_modules.Builtin.GenericError;
  constant is_generic_error = 1;
  constant is_compile_callback_error = 1;
  constant is_cpp_or_compilation_error = 1;
}

protected void compile_cb_error (string msg, mixed ... args)
// Use this to throw errors that should be converted to plain compile
// error messages, without backtraces being reported by
// compile_exception.
{
  if (sizeof (args)) msg = sprintf (msg, @args);
  throw (CompileCallbackError (msg, backtrace()[..<1]));
}

protected void compile_cb_rethrow (object|array err)
// Use this to rethrow errors that should be converted to plain
// compile error messages, without backtraces being reported by
// compile_exception.
{
  array bt;
  if (array|object e = catch (bt = get_backtrace (err)))
    handle_error (e);
  throw (CompileCallbackError (describe_error (err), bt));
}

protected void call_compile_warning (object handler, string file,
				     string msg, mixed ... args)
{
  if (sizeof (args)) msg = sprintf (msg, @args);
  msg = trim_all_whites (msg);
  if (handler && handler->compile_warning)
    handler->compile_warning (file, 0, msg);
  else
    compile_warning (file, 0, msg);
}

#if constant(_static_modules.Builtin.mutex)
#define THREADED
_static_modules.Builtin.mutex compilation_mutex = Builtin.mutex();
#endif

#ifdef __NT__
#define FIX_CASE(X)	lower_case(X)
#else
#define FIX_CASE(X)	(X)
#endif /* __NT__ */

protected string base_from_filename(string fname)
{
  string low_name = FIX_CASE(fname);
  if (has_prefix(low_name, ".#")) return 0;
  if (has_suffix(low_name, ".pike") ||
      has_suffix(low_name, ".pmod")) {
    return fname[..<5];
  }
  if (has_suffix(low_name, ".so")) {
    return fname[..<3];
  }
  return 0;
}

protected int prio_from_filename(string fname)
{
  fname = FIX_CASE(fname);
  if (has_suffix(fname, ".pmod")) return 3;
  if (has_suffix(fname, ".so")) return 2;
  if (has_suffix(fname, ".pike")) return 1;

  // FIXME: Warn here?
  return 0;
}

//! Find the files in which @[mod] is defined, as they may be hidden away in 
//! joinnodes and dirnodes
//!
//! @param mod
//!   The module we are looking for.
//!
//! @returns
//!   An array of strings with filenames.
//!   (one for each file in a joinnode, or just one otherwise)
array(string) module_defined(object|program mod)
{
  array files = ({});
  if (programp(mod))
    return ({ Builtin.program_defined([program]mod) });

  array mods;
  if (mod->is_resolv_joinnode)
    mods = mod->joined_modules; 
  else
    mods = ({ mod });

  foreach (mods;; object mod)
  {
    if (mod->is_resolv_dirnode)
      files += ({ Builtin.program_defined(object_program(mod->module)) });
    else
      files += ({ Builtin.program_defined(object_program(mod)) });
  }
  return files;
}

//! Enable caching of sources from compile_string()
void enable_source_cache()
{
  if (!source_cache)
    source_cache = ([]);
}

//! Show documentation for the item @[obj]
//!
//! @param obj
//!   The object for which the documentation should be shown
//!
//! @returns
//!   an AutoDoc object
object show_doc(program|object|function obj)
{ 
  object doc_extractor = main_resolv("Tools.AutoDoc.PikeExtractor.extractClass"); 
  string child;
  program prog;

  if (programp(obj))
    prog = obj;
  if (functionp(obj))
  {
    prog = function_program(obj);
    child = ((describe_function(obj)||"")/"->")[-1];
  }
  if (objectp(obj))
  {
    if (obj->is_resolv_joinnode)
      obj = obj->joined_modules[0]; // FIXME: check for multiples
    if (obj->is_resolv_dirnode)
      prog = object_program(obj->module);
    else
      prog = object_program(obj);
  }


  if (prog && !documentation[prog] && doc_extractor)
  {
    string source;
    if (source_cache && source_cache[prog])
      source = source_cache[prog];
    else
    {
      array sourceref = array_sscanf(Builtin.program_defined(prog), 
                                     "%s%[:]%[0-9]");
      source = master_read_file(sourceref[0]);
      if (sizeof(sourceref[1]) && sizeof(sourceref[2]))
      {
        if (programp(prog))
          child = ((describe_program(prog)||"")/".")[-1];
      }
    }

    if (source)
    {
      catch
      {
        documentation[prog] = doc_extractor(source, sprintf("%O", prog));
      };
      //FIXME: handle this error somehow
    }
  }

  if (documentation[prog])
  { 
    if (child)
      return documentation[prog]->findObject(child)||documentation[prog]->findChild(child);
    else
      return documentation[prog];
  }
}


protected program low_findprog(string pname,
			       string ext,
			       object|void handler,
			       void|int mkobj)
{
  program ret;
  Stat s;
  string fname=pname+ext;

  resolv_debug("low_findprog(%O, %O, %O, %O)\n",
	       pname, ext, handler, mkobj);

#ifdef THREADED
  object key;
  // FIXME: The catch is needed, since we might be called in
  // a context when threads are disabled.
  // (compile() disables threads).
  mixed err = catch {
    key=compilation_mutex->lock(2);
  };
  if (err) {
    werror( "low_findprog: Caught spurious error:\n"
	    "%s\n", describe_backtrace(err) );
  }
#endif

#ifdef PIKE_MODULE_RELOC
  fname = unrelocate_module(fname);
#endif

#ifdef __NT__
  // Ugly kluge to work better with cygwin32 "/X:/" paths.
  if(getenv("OSTYPE")=="cygwin32")
  {
    string tmp=fname[..1];
    if((tmp=="//" || tmp=="\\\\") && (fname[3]=='/' || fname[3]=='\\'))
    {
      if(!master_file_stat(fname))
      {
	fname=fname[2..2]+":"+fname[3..];
      }
    }
  }
#endif

  if( (s=master_file_stat(fakeroot(fname))) && s->isreg )
  {
#ifdef PIKE_AUTORELOAD
    if(!autoreload_on || load_time[fname] >= s->mtime)
#endif
    {
      if(!zero_type (ret=programs[fname]) && ret != no_value) {
	resolv_debug ("low_findprog %s: returning cached (no autoreload)\n", fname);
	return ret;
      }
    }

    AUTORELOAD_BEGIN();

#ifdef PIKE_AUTORELOAD
    if (load_time[fname] >= s->mtime)
      if (!zero_type (ret=programs[fname]) && ret != no_value) {
	resolv_debug ("low_findprog %s: returning cached (autoreload)\n", fname);
	return ret;
      }
#endif

    switch(ext)
    {
    case "":
    case ".pike":
      foreach(query_precompiled_names(fname), string oname) {
	if(Stat s2=master_file_stat(fakeroot(oname)))
	{
	  if(s2->isreg && s2->mtime >= s->mtime)
	  {
	    mixed err=catch {
	      object|program decoded;
	      AUTORELOAD_CHECK_FILE(oname);
	      resolv_debug ("low_findprog %s: decoding dumped\n", fname);
	      INC_RESOLV_MSG_DEPTH();
	      decoded = decode_value(master_read_file(oname),
				     (handler && handler->get_codec ||
				      get_codec)(fname, mkobj, handler));
	      DEC_RESOLV_MSG_DEPTH();
	      resolv_debug ("low_findprog %s: dump decode ok\n", fname);
	      if (decoded && decoded->this_program_does_not_exist) {
		resolv_debug ("low_findprog %s: program claims not to exist\n",
			      fname);
		return programs[fname] = 0;
	      }
	      else {
		if (objectp(decoded)) {
		  resolv_debug("low_findprog %s: decoded object %O\n",
			       fname, decoded);
		  objects[ret = object_program(decoded)] = decoded;
		} else {
		  ret = decoded;
		}
		resolv_debug("low_findprog %s: returning %O\n", fname, ret);
		return programs[fname]=ret;
	      }
	    };
	    DEC_RESOLV_MSG_DEPTH();
	    resolv_debug ("low_findprog %s: dump decode failed\n", fname);
	    programs[fname] = no_value;
	    call_compile_warning (handler, oname,
				  "Decode failed: " + describe_error(err));
	    // handle_error(err);
	  } else if (out_of_date_warning) {
	    call_compile_warning (handler, oname,
				  "Compiled file is out of date");
	  }
	}
      }

      resolv_debug ("low_findprog %s: compiling, mkobj: %O\n", fname, mkobj);
      INC_RESOLV_MSG_DEPTH();
      programs[fname]=ret=__empty_program(0, fname);
      AUTORELOAD_CHECK_FILE (fname);
      string src;
      if (array|object err = catch (src = master_read_file (fname))) {
	DEC_RESOLV_MSG_DEPTH();
	resolv_debug ("low_findprog %s: failed to read file\n", fname);
	objects[ret] = no_value;
	ret=programs[fname]=0;	// Negative cache.
	compile_cb_rethrow (err);
      }
      if ( mixed e=catch {
	  ret=compile_string(src, fname, handler,
			     ret,
			     mkobj? (objects[ret]=__null_program()) : 0);
	} )
      {
	DEC_RESOLV_MSG_DEPTH();
	resolv_debug ("low_findprog %s: compilation failed\n", fname);
	objects[ret] = no_value;
	ret=programs[fname]=0;	// Negative cache.
        throw(e);
      }
      DEC_RESOLV_MSG_DEPTH();
      resolv_debug ("low_findprog %s: compilation ok\n", fname);
      break;

#if constant(load_module)
    case ".so":
      if (fname == "") {
	werror( "low_findprog(%O, %O) => load_module(\"\")\n"
		"%s\n", pname, ext, describe_backtrace(backtrace()) );
      }

      if (array|object err = catch (ret = load_module(fakeroot(fname)))) {
	DEC_RESOLV_MSG_DEPTH();
	resolv_debug ("low_findprog %s: failed to load binary\n", fname);
	objects[ret] = no_value;
	ret=programs[fname]=0;	// Negative cache.
	if (objectp (err) && err->is_module_load_error)
	  // Do not treat errors from dlopen(3) as exceptions since in
	  // a dist we can have .so files that are dynamically linked
	  // against libraries that don't exist on the system, and in
	  // that case we should just treat the module as nonexisting.
	  //
	  // What we really want is to do this only for errors that
	  // are due to nonexisting files, but the error reporting
	  // from dlerror(3) doesn't allow us to tell those from other
	  // errors.
	  call_compile_warning (handler, fname,
				"Failed to load library: %s\n", err->reason);
	else
	  compile_cb_rethrow (err);
      }
      else
	resolv_debug ("low_findprog %s: loaded binary\n", fname);
#endif /* load_module */
    }

    AUTORELOAD_FINISH(ret,programs,fname);

    if (ret && ret->this_program_does_not_exist) {
      resolv_debug ("low_findprog %s: program says it doesn't exist\n", fname);
      return programs[fname] = 0;
    }
    else {
      resolv_debug("low_findprog %s: returning %O\n", fname, ret);
      return programs[fname]=ret;
    }
  }

  resolv_debug ("low_findprog %s: file not found\n", fname);
  return 0;
}

//
// This function is called by the compiler when a delayed compilation
// error occurs in the given program. It should remove all references
// to the program so that it can be freed.
//
void unregister(program p)
{
  // werror("Unregistering %O...\n", p);
  if(string fname=rev_programs[p] || search(programs,p)) {
    resolv_debug("unregister %s\n", fname);
    if (m_delete (rev_programs, p))
      m_delete (programs, fname);
    else
      programs[fname] = no_value;

    fname = dirname (fname);
    object n;
    if ( fname!="" && objectp (n = fc[fname]) )
      if (n->is_resolv_dirnode || n->is_resolv_joinnode)
	n->delete_value (p);
  }

  object o = m_delete(objects, p);
  if (objectp (o)) {
    m_delete(rev_objects, o);
  }

  foreach (fc; string name; mixed mod)
    if (objectp(mod) && object_program(mod) == p)
      if (m_delete (rev_fc, mod))
	m_delete (fc, name);
      else
	fc[name] = no_value;

  // FIXME: Delete from caches in dirnodes and joinnodes.
}

protected program findprog(string pname,
			   string ext,
			   object|void handler,
			   void|int mkobj)
{
  switch(ext)
  {
  case ".pike":
  case ".so":
    return low_findprog(pname,ext,handler, mkobj);

  default:
    pname+=ext;
    return
      low_findprog(pname,"", handler, mkobj) ||
      low_findprog(pname,".pike", handler, mkobj) ||
      low_findprog(pname,".so", handler, mkobj);
  }
}

program low_cast_to_program(string pname,
			    string current_file,
			    object|void handler,
			    void|int mkobj)
{
  string ext;
  string nname;

  //werror("low_cast_to_program(%O, %O, %O, %O)\n",
  //	 pname, current_file, handler, mkobj);

  if(sscanf(reverse(BASENAME(pname)),"%s.%s",ext, nname))
  {
    ext="."+reverse(ext);
    pname=pname[..<sizeof(ext)];
  }
  else {
    ext="";
  }

  if(IS_ABSOLUTE_PATH(pname))
  {
    program|NoValue prog = programs[pname];
    if ((!zero_type(prog)) && (prog != no_value))
    { 
      return prog;
    }
    pname=combine_path("",pname);
    return findprog(pname,ext,handler,mkobj);
  }
  else {
    string cwd;
    if(current_file)
    {
      cwd=dirname(current_file);
    }
    else {
      cwd=getcwd();
    }

    if(program ret=findprog(combine_path(cwd,pname),ext,handler,mkobj))
      return ret;

    foreach(pike_program_path, string path)
      if(program ret=findprog(combine_path(path,pname),ext,handler,mkobj))
	return ret;

    return 0;
  }
}


//! This function is called when the driver wants to cast a string
//! to a program, this might be because of an explicit cast, an inherit
//! or a implict cast. In the future it might receive more arguments,
//! to aid the master finding the right program.
program cast_to_program(string pname,
			string current_file, 
			object|void handler)
{
  resolv_debug ("cast_to_program(%O, %O)\n", pname, current_file);
  INC_RESOLV_MSG_DEPTH();
  program ret = low_cast_to_program(pname, current_file, handler);
  DEC_RESOLV_MSG_DEPTH();
  resolv_debug ("cast_to_program(%O, %O) => %O\n", pname, current_file, ret);
  if (programp (ret)) return ret;
  error("Cast %O to program failed%s.\n",
	pname,
	(current_file && current_file!="-") ? sprintf(" in %O",current_file) : "");
}


//! This function is called when an error occurs that is not caught
//! with catch().
void handle_error(array|object trace)
{
  // NB: Use predef::trace() to modify trace level here.
  // predef::trace(2);
  if(mixed x=catch {
    werror(describe_backtrace(trace));
  }) {
    // One reason for this might be too little stack space, which
    // easily can occur for "out of stack" errors. It should help to
    // tune up the STACK_MARGIN values in interpret.c then.
    werror("Error in handle_error in master object:\n");
    if(catch {
      // NB: Splited werror calls to retain some information
      //     even if/when werror throws.
      catch {
	if (catch {
	  string msg = [string]x[0];
	  array bt = [array]x[1];
	  werror("%s", msg);
	  werror("%O\n", bt);
	}) {
	  werror("%O\n", x);
	}
      };
      werror("Original error:\n"
	     "%O\n", trace);
    }) {
      werror("sprintf() failed to write error.\n");
    }
  }
  // predef::trace(0);
}

/* This array contains the names of the functions
 * that a replacing master-object may want to override.
 */
constant master_efuns = ({
  "error",
  "basename",
  "dirname",
  "is_absolute_path",
  "explode_path",

  "compile_string",
  "compile_file",
  "add_include_path",
  "remove_include_path",
  "add_module_path",
  "remove_module_path",
  "add_program_path",
  "remove_program_path",
  "describe_backtrace",
  "describe_error",
  "get_backtrace",
  "normalize_path",
  "bool",
  "true",
  "false",
  "getenv",
  "putenv",

#ifdef GETCWD_CACHE
  "cd",
  "getcwd",
#endif
});

enum bool { false=0, true=1 };

//! Prefix for Pike-related C header files.
string include_prefix;

//! Prefix for autodoc files.
string doc_prefix;

//! Flags suitable for use when compiling Pike C modules
string cflags;

//! Flags suitable for use when linking Pike C modules
string ldflags; // Not yet used

//! @decl int strlen(string|multiset|array|mapping|object thing)
//! @appears strlen
//! Alias for @[sizeof].
//! @deprecated sizeof

//! @decl int write(string fmt, mixed ... args)
//! @appears write
//! Writes a string on stdout. Works just like @[Stdio.File.write]
//! on @[Stdio.stdout].

//! @decl int werror(string fmt, mixed ... args)
//! @appears werror
//! Writes a string on stderr. Works just like @[Stdio.File.write]
//! on @[Stdio.stderr].

/* Note that create is called before add_precompiled_program
 */
protected void create()
{
  foreach(master_efuns, string e)
    if (!zero_type(this[e]))
      add_constant(e, this[e]);
    else
      error("Function %O is missing from master.pike.\n", e);

  add_constant("__dirnode", dirnode);
  add_constant("__joinnode", joinnode);

  add_constant("strlen", sizeof);
  add_constant("write", write);
  add_constant("werror", werror);
  // To make it possible to overload get_dir and file_stat later on.
  // It's not possible to replace efuns with normal functions in .o-files

  add_constant("get_dir", master_get_dir );
  add_constant("file_stat", lambda( string f, int|void d ) { return file_stat(f,d);} );

#define CO(X)  add_constant(#X,Builtin.__backend->X)
  CO(call_out);
  CO(_do_call_outs);
  CO(find_call_out);
  CO(remove_call_out);
  CO(call_out_info);

#if "#share_prefix#"[0]!='#'
  // add path for architecture-independant files
  add_include_path("#share_prefix#/include");
  add_module_path("#share_prefix#/modules");
#endif

#if "C:/Program Files/Pike/lib"[0]!='#'
  // add path for architecture-dependant files
  add_include_path("C:/Program Files/Pike/lib/include");
  add_module_path("C:/Program Files/Pike/lib/modules");
#endif

#if "#cflags# "[0]!='#'
  cflags = "#cflags#";
#endif

#if "#ldflags# "[0]!='#'
  ldflags = "#ldflags#";
#endif

#if "C:/Program Files/Pike/include/pike"[0]!='#'
  include_prefix = "C:/Program Files/Pike/include/pike";
  cflags = (cflags || "") + " -I" + dirname(include_prefix);
#endif

#if "#doc_prefix#"[0]!='#'
  doc_prefix = "#doc_prefix#";
#endif

#if constant(__embedded_resource_directory)
  // for use with embedded interpreters
  // add path for architecture-dependant files
  add_include_path(__embedded_resource_directory + "/lib/include");
  add_module_path(__embedded_resource_directory + "/lib/modules");
  add_module_path(__embedded_resource_directory + "/" + replace(uname()->machine, " ", "_") + "/modules");

#endif

  system_module_path=pike_module_path;
}


//! This function is called whenever a inherit is called for.
//! It is supposed to return the program to inherit.
//! The first argument is the argument given to inherit, and the second
//! is the file name of the program currently compiling. Note that the
//! file name can be changed with #line, or set by compile_string, so
//! it can not be 100% trusted to be a filename.
//! previous_object(), can be virtually anything in this function, as it
//! is called from the compiler.
program handle_inherit(string pname, string current_file, object|void handler)
{
  resolv_debug ("handle_inherit(%O, %O)\n", pname, current_file);
  INC_RESOLV_MSG_DEPTH();
  program ret = cast_to_program(pname, current_file, handler);
  DEC_RESOLV_MSG_DEPTH();
  resolv_debug ("handle_inherit(%O, %O) => %O\n", pname, current_file, ret);
  return ret;
}

object low_cast_to_object(string oname, string current_file,
			  object|void current_handler)
{
  program p;
  object o;

  p = low_cast_to_program(oname, current_file, current_handler, 1);
  if(!p) return 0;
  // NB: p might be a function in a fake_object...
  if(!objectp (o=objects[p])) o=objects[p]=p();
  return o;
}

//! This function is called when the drivers wants to cast a string
//! to an object because of an implict or explicit cast. This function
//! may also receive more arguments in the future.
object cast_to_object(string oname, string current_file,
		      object|void current_handler)
{
  resolv_debug ("cast_to_object(%O, %O)\n", oname, current_file);
  INC_RESOLV_MSG_DEPTH();
  object o = low_cast_to_object(oname, current_file, current_handler);
  DEC_RESOLV_MSG_DEPTH();
  resolv_debug ("cast_to_object(%O, %O) => %O\n", oname, current_file, o);
  if (objectp (o)) return o;
  error("Cast %O to object failed%s.\n",
	oname,
	(current_file && current_file!="-") ? sprintf(" in %O",current_file) : "");
}

// Marker used for negative caching in module caches.
// FIXME: Won't this cause problems when inheriting "/master"?
protected class ZERO_TYPE {};

protected object Unicode;

//! Module node representing a single directory.
//!
//! @seealso
//!   @[joinnode]
class dirnode
{
  string dirname;
  object|void compilation_handler;
  constant is_resolv_dirnode = 1;
  // objectp() is intentionally not used on the module object, to
  // allow a module to deny its own existence with `!.
  mixed module;
  mapping(string:mixed) cache=([]);
  mapping(string:array(string)) file_paths = ([]);

#ifdef __NT__
#define FIX_CASE(X)	lower_case(X)
#else
#define FIX_CASE(X)	(X)
#endif /* __NT__ */

  protected string base_from_filename(string fname)
  {
    string low_name = FIX_CASE(fname);
    catch {
      // FIXME: Warn on failure?
      low_name = utf8_to_string(low_name);
      if (Builtin.string_width(low_name) > 8) {
	// We might need to normalize the string (cf MacOS X).

	// Load the Unicode module if it hasn't already been loaded.
	if (!Unicode) {
	  Unicode = resolv("Unicode");
	}
	low_name = Unicode.normalize(low_name, "NFC");
      }
    };
    if (has_prefix(low_name, ".#")) return 0;
    if (has_suffix(low_name, ".pike") ||
	has_suffix(low_name, ".pmod")) {
      return fname[..<5];
    }
    if (has_suffix(low_name, ".so")) {
      return fname[..<3];
    }
    return 0;
  }

  protected int prio_from_filename(string fname)
  {
    fname = FIX_CASE(fname);
    if (has_suffix(fname, ".pmod")) return 3;
    if (has_suffix(fname, ".so")) return 2;
    if (has_suffix(fname, ".pike")) return 1;

    // FIXME: Warn here?
    return 0;
  }

  protected void create(string d, object|void h)
  {
    resolv_debug ("dirnode(%O,%O) created\n",d,h);
    dirname=d;
    compilation_handler=h;
    fc[dirname]=this;
    array(string) files = sort(master_get_dir(d)||({}));
    if (!sizeof(d)) return;
    array(string) bases = map(files, base_from_filename);
    files = filter(files, bases);
    bases = filter(bases, bases);
    resolv_debug("dirnode(%O,%O) got %d files.\n",
		 d, h, sizeof(bases));
    if (!sizeof(files)) return;

    foreach(files; int no; string fname) {
      fname = combine_path(dirname, fname);
      string base = bases[no];
      if (base == "module") {
	// We need a module_checker.
	module = module_checker();
      }
      array(string) paths = file_paths[base];
      if (!paths) {
	// New entry.
	file_paths[base] = ({ fname });
	continue;
      }

      // Multiple files. Order according to prio_from_filename().
      // Insert sort. Worst case is 3 filenames.
      int prio = prio_from_filename(fname);
      int index;
      foreach(paths; index; string other_fname) {
	if (prio_from_filename(other_fname) <= prio) break;
      }
      file_paths[base] = paths[..index-1] + ({ fname }) + paths[index..];
    }
  }

  class module_checker
  {
    int `!()
    {
      resolv_debug ("dirnode(%O)->module_checker()->`!()\n",dirname);
      INC_RESOLV_MSG_DEPTH();

      if (mixed err = catch { 
	// Look up module.
	if (module = cache["module"] || low_ind("module", 1)) {
	  /* This allows for `[] to have side effects first time
	   * it is called. (Specifically, the Calendar module uses
	   * this).
	   */
	  cache=([]);
	  _cache_full=0;
	}
	DEC_RESOLV_MSG_DEPTH();
	resolv_debug("dirnode(%O)->module_checker()->`!() => %s\n",
		     dirname, !module ? "doesn't exist" : "exists");
	return !module;
      }) {
	//werror ("findmodule error: " + describe_backtrace (err));

	// findmodule() failed. This can occur due to circularities
	// between encode_value()'ed programs.
	// The error will then typically be:
	// "Cannot call functions in unfinished objects."

	// Pretend not to exist for now...
	DEC_RESOLV_MSG_DEPTH();
	resolv_debug("dirnode(%O)->module_checker()->`!() => failure, doesn't exist\n",
		     dirname);
	return 1;
      }
    }

    mixed `[](string index)
      {
	resolv_debug ("dirnode(%O)->module_checker()[%O] => %O\n",
		      dirname, index, module && module[index]);
	return module && module[index];
      }
    array(string) _indices() { if(module) return indices(module); }
    array _values() { if(module) return values(module); }
  }

  protected mixed low_ind(string index, int(0..1)|void set_module)
  {
    array(string) paths;

    if (!(paths = file_paths[index])) {
      DEC_RESOLV_MSG_DEPTH();
      resolv_debug("dirnode(%O)->ind(%O) => no file match\n",
		   dirname, index);
      return UNDEFINED;
    }

    foreach(paths, string fname) {
      resolv_debug("dirnode(%O)->ind(%O) Trying file %O...\n",
		   dirname, index, fname);
      Stat stat = master_file_stat(fakeroot(fname));
      if (!stat) {
	resolv_debug("dirnode(%O)->ind(%O) file %O disappeared!\n",
		     dirname, index, fname);
	continue;
      }
      if (has_suffix(fname, ".pmod")) {
	if (stat->isdir) {
	  if (dirnode n = fc[fname]) {
	    // Avoid duplicate dirnodes for the same dirs. This can
	    // happen if the master is replaced, e.g. with master_76
	    // in 7.6/modules/__default.pmod.
	    resolv_debug("dirnode(%O)->ind(%O) => found subdirectory %O, "
			 "returning old dirnode\n", dirname, index, fname);
	    return n;
	  }
	  resolv_debug("dirnode(%O)->ind(%O) => found subdirectory %O, "
		       "creating new dirnode\n", dirname, index, fname);
	  return fc[fname] = dirnode(fname, compilation_handler);
	}
	resolv_debug("dirnode(%O)->ind(%O) casting (object)%O\n",
		     dirname, index, fname);
	// FIXME: cast_to_program() and cast_to_object()
	//        have lots of overhead to guess the proper
	//        filename. This overhead isn't needed in
	//        our cases, so we could make do with
	//        low_findprog() and the caches.
	mixed ret;
	if (ret = catch {
	    if (objectp(ret = low_cast_to_object(fname, 0, compilation_handler))) {
	      // This assignment is needed for eg the Calendar module.
	      if (set_module) module = ret;
	      if(mixed tmp=ret->_module_value) ret=tmp;
	      DEC_RESOLV_MSG_DEPTH();
	      resolv_debug("dirnode(%O)->ind(%O) => found submodule %O:%O\n",
			   dirname, index, fname, ret);
	      return ret;
	    }
	  }) {
	  resolv_debug("dirnode(%O)->ind(%O) ==> Cast to object failed: %s\n",
		       dirname, index, describe_backtrace(ret));
	}
      } else {
	resolv_debug("dirnode(%O)->ind(%O) casting (program)%O\n",
		     dirname, index, fname);
	program|object ret;
	if (ret = low_cast_to_program(fname, 0, compilation_handler)) {
	  DEC_RESOLV_MSG_DEPTH();
	  resolv_debug("dirnode(%O)->ind(%O) => found subprogram %O:%O\n",
		       dirname, index, fname, ret);
#if constant(load_module)
	  if (has_suffix(fname, ".so")) {
	    // This is compatible with 7.4 behaviour.
	    if (!ret->_module_value) {
	      object o;
	      // NB: p might be a function in a fake_object...
	      if(!objectp (o=objects[ret])) o=objects[ret]=ret();
	      ret = o;
	    }
	    if(mixed tmp=ret->_module_value) ret=tmp;
	  }
#endif
	  return ret;
	}
      }
      resolv_debug("dirnode(%O)->ind(%O) => failure for file %O\n",
		   dirname, index, fname);
    }

    resolv_debug("dirnode(%O)->ind(%O) => UNDEFINED\n",
		 dirname, index);
    return UNDEFINED;
  }

  protected mixed ind(string index)
  {
    resolv_debug ("dirnode(%O)->ind(%O)\n", dirname, index);
    INC_RESOLV_MSG_DEPTH();

    if (_cache_full) {
      DEC_RESOLV_MSG_DEPTH();
      resolv_debug("dirnode(%O)->ind(%O) => cache_full %O\n",
		   dirname, index, cache[index]);
      return cache[index];
    }

    if(module)
    {
      mixed o;
//      _describe(module);
      if(!zero_type(o=module[index]))
      {
	DEC_RESOLV_MSG_DEPTH();
	resolv_debug ("dirnode(%O)->ind(%O) => found %O\n",
		      dirname, index, o);
	return o;
      }
      resolv_debug ("dirnode(%O)->ind(%O) => not found in module\n",
		    dirname, index);
    }
    else
      resolv_debug ("dirnode(%O)->ind(%O) => no module\n", dirname, index);

    return low_ind(index);
  }

  mixed `[](string index)
  {
    mixed ret;
#ifdef MODULE_TRACE
    werror("%*nDirnode(%O) cache[%O] ?????\n",
	   sizeof(backtrace()),dirname,index);
#endif
    if(!zero_type(ret=cache[index]))
    {
#ifdef MODULE_TRACE
      werror("%*nDirnode(%O) cache[%O] => %O%s\n",
	     sizeof(backtrace()),dirname,index, ret,
	     (ret != ZERO_TYPE)?"":" (zero_type)");
#endif
      if (ret != ZERO_TYPE) return ret;
#ifdef MODULE_TRACE
      werror("%*nDirnode(%O) ZERO_TYPE!\n",
	     sizeof(backtrace()),dirname);
#endif
      return UNDEFINED;
    }
    ret=ind(index);

    // We might have gotten placeholder objects in the first pass
    // which must not be cached to the second.
    if(ret == predef::__placeholder_object) {
#ifdef MODULE_TRACE
      werror("%*nDirnode(%O) PLACE_HOLDER.\n",
	     sizeof(backtrace()),dirname);
#endif
      return ret;
    }

    cache[index] = zero_type(ret) ? ZERO_TYPE : ret;
    return ret;
  }

  mixed safe_index(string index)
  {
    mixed err;
    resolv_debug ("dirnode(%O):     %O...\n", dirname, index);
    if (err = catch { return `[](index); }) {
      call_compile_warning (compilation_handler,
			    dirname+"."+fname,
			    "Compilation failed: " + describe_error(err));
    }
    return UNDEFINED;
  }

  protected int(0..1) _cache_full;
  void fill_cache()
  {
#if 0
    werror(describe_backtrace(({ sprintf("Filling cache in dirnode %O\n",
					 dirname),
				 backtrace() })));
#endif
    if (_cache_full) {
      return;
    }

    resolv_debug ("dirnode(%O) => Filling cache...\n", dirname);

    // NOTE: We rely on side effects in `[]() and safe_index()
    //       to fill the cache.

    // Why shouldn't thrown errors be propagated here? /mast
    if (module) {
      resolv_debug("dirnode(%O): module: %O, indices:%{%O, %}\n",
		   dirname, module, indices(module));
      map(indices(module), safe_index);
    }

    map(indices(file_paths), safe_index);
    _cache_full = (object_program(module) != __null_program);
    resolv_debug ("dirnode(%O) => Cache %s.\n", dirname,
		  _cache_full?"full":"partially filled");
  }

  protected array(string) _indices()
  {
    fill_cache();
    // Note: Cannot index cache at all here to filter out the
    // ZERO_TYPE values since that can change the order in the
    // mapping, and _indices() has to return the elements in the same
    // order as a nearby _values() call.
    return filter (indices (cache), map (values (cache), `!=, ZERO_TYPE));
  }

  protected array(mixed) _values()
  {
    fill_cache();
    return values(cache) - ({ZERO_TYPE});
  }

  void delete_value (mixed val)
  {
    if (string name = search (cache, val)) {
      m_delete (cache, name);
      _cache_full = 0;
    }
  }

  protected int(0..) _sizeof() {
    return sizeof(_values());
  }

  protected string _sprintf(int as)
  {
    return as=='O' && sprintf("master()->dirnode(%O:%O)",
			      dirname, module && module);
  }
}

//! Module node holding possibly multiple directories,
//! and optionally falling back to another level.
//!
//! @seealso
//!   @[dirnode]
class joinnode
{
  constant is_resolv_joinnode = 1;
  array(object|mapping) joined_modules;
  mapping(string:mixed) cache=([]);

  object compilation_handler;

  // NOTE: Uses the empty mapping as the default fallback
  // for simplified code.
  joinnode|mapping(mixed:int(0..0)) fallback_module = ([]);

  string _sprintf(int as)
  {
    return as=='O' && sprintf("master()->joinnode(%O)",joined_modules);
  }

  protected void create(array(object|mapping) _joined_modules,
			object|void _compilation_handler,
			joinnode|void _fallback_module)
  {
    joined_modules = _joined_modules;
    compilation_handler = _compilation_handler;
    fallback_module = _fallback_module || ([]);
    resolv_debug ("joinnode(%O) created\n", joined_modules);
  }

  void add_path(string path)
  {
    path = combine_path(getcwd(), path);
    dirnode node = fc[path] ||
      (fc[path] = dirnode(path, compilation_handler));
    if (sizeof(joined_modules) &&
	joined_modules[0] == node) return;
    joined_modules = ({ node }) + (joined_modules - ({ node }));
    cache = ([]);
  }

  void rem_path(string path)
  {
    path = combine_path(getcwd(), path);
    joined_modules = filter(joined_modules,
			    lambda(dirnode node) {
			      return !objectp(node) ||
				!node->is_resolv_dirnode ||
				(node->dirname != path);
			    });
    cache = ([]);
  }

  protected mixed ind(string index)
  {
    resolv_debug ("joinnode(%O)->ind(%O)\n", joined_modules, index);
    INC_RESOLV_MSG_DEPTH();

    array(mixed) res = ({});
    foreach(joined_modules, object|mapping o) 
    {
      mixed ret;
      if (!zero_type(ret = o[index])) 
      {
	if (objectp(ret) &&
	    (ret->is_resolv_dirnode || ret->is_resolv_joinnode))
        {
	  // Only join directorynodes (or joinnodes).
	  res += ({ ret });
	} else {
	  DEC_RESOLV_MSG_DEPTH();
	  resolv_debug ("joinnode(%O)->ind(%O) => found %O\n",
			joined_modules, index, ret);
	  return (ret);
	}
      }
    }

    if (sizeof(res)) {
      DEC_RESOLV_MSG_DEPTH();
      resolv_debug("joinnode(%O)->ind(%O) => new joinnode, fallback: %O\n",
		   joined_modules, index, fallback_module[index]);
      return joinnode(res, compilation_handler, fallback_module[index]);
    }

    DEC_RESOLV_MSG_DEPTH();
    resolv_debug ("joinnode(%O)->ind(%O) => not found. Trying fallback %O\n",
		  joined_modules, index, fallback_module);
    return fallback_module[index];
  }

  mixed `[](string index)
  {
    mixed ret;
    if (!zero_type(ret = cache[index])) {
      if (ret != ZERO_TYPE) {
	return ret;
      }
      return UNDEFINED;
    }
    ret = ind(index);

    // We might have gotten placeholder objects in the first pass
    // which must not be cached to the second.
    if(ret == predef::__placeholder_object) return ret;

    if (zero_type(ret)) {
      cache[index] = ZERO_TYPE;
    } else {
      cache[index] = ret;
    }
    return ret;
  }

  protected int _cache_full;

  void fill_cache()
  {
#if 0
    werror(describe_backtrace(({ "Filling cache in joinnode\n",
				 backtrace() })));
#endif
    if (_cache_full) {
      return;
    }
    foreach(joined_modules, object|mapping|program o) {
      foreach(indices(o), string index) {
	if (zero_type(cache[index])) {
	  `[](index);
	}
      }
    }
    foreach(indices(fallback_module), string index) {
      `[](index);
    }
    _cache_full = 1;
  }

  array(string) _indices()
  {
    fill_cache();
    // Note: Cannot index cache at all here to filter out the
    // ZERO_TYPE values since that can change the order in the
    // mapping, and _indices() has to return the elements in the same
    // order as a nearby _values() call.
    return filter (indices (cache), map (values (cache), `!=, ZERO_TYPE));
  }

  array(mixed) _values()
  {
    fill_cache();
    return values(cache) - ({ZERO_TYPE});
  }

  void delete_value (mixed val)
  {
    if (string name = search (cache, val))
      m_delete (cache, name);
    for (int i = 0; i < sizeof (joined_modules); i++) {
      object|mapping|program o = joined_modules[i];
      if (o == val) {
	joined_modules = joined_modules[..i - 1] + joined_modules[i + 1..];
	i--;
      }
      else if (objectp (o) && (o->is_resolv_dirnode || o->is_resolv_joinnode))
	o->delete_value (val);
      else if (string name = mappingp (o) && search (o, val))
	m_delete (o, name);
    }
  }

  int `== (mixed other)
  {
    return objectp (other) && other->is_resolv_joinnode &&
      equal (mkmultiset (joined_modules), mkmultiset (other->joined_modules));
  }

  array(object) _encode()
  {
    return joined_modules;
  }

  void _decode (array(object) joined_modules)
  {
    this_program::joined_modules = joined_modules;
  }
}

joinnode handle_import(string path, string|void current_file,
		       object|void current_handler)
{
#ifdef __amigaos__
  if(path == ".")
    path = "";
#endif
  if(current_file)
  {
    path = combine_path_with_cwd(dirname(current_file), path);
  } else {
    path = combine_path_with_cwd(path);
  }

  // FIXME: Need caching!!!
#if 0
  // FIXME: This caching strategy could be improved,
  //        since it ignores module_nodes from the
  //        ordinary module tree.

  if (module_node_cache[current_handler]) {
    if (module_node_cache[current_handler][path]) {
      return module_node_cache[current_handler][path];
    }
  } else {
    module_node_cache[current_handler] = ([]);
  }
  module_node node = module_node_cache[current_handler][path] =
    module_node("import::"+path, 0, current_handler);
#endif /* 0 */
  joinnode node = joinnode(({}), current_handler);
#ifdef PIKE_MODULE_RELOC
  // If we have PIKE_MODULE_RELOC enabled, 
  // we might need to map to multiple directories.
  if(path == "/${PIKE_MODULE_PATH}" ||
     has_prefix(path, "/${PIKE_MODULE_PATH}/")) {
    string tmp = path[21..];
    foreach(pike_module_path, string prefix) {
      node->add_path(sizeof(tmp)? combine_path(prefix, tmp) : prefix);
    }
  } else
#endif /* PIKE_MODULE_RELOC */
    node->add_path(path);
  return node;
}

program|object findmodule(string fullname, object|void handler)
{
  program|object o;

  resolv_debug ("findmodule(%O)\n", fullname);
  if(!zero_type(o=fc[fullname]) && o != no_value)
  {
    if (objectp(o) || programp(o) || o != 0) {
      resolv_debug ("findmodule(%O) => found %O (cached)\n", fullname, o);
      return o;
    }
    resolv_debug ("findmodule(%O) => not found (cached)\n", fullname);
    return UNDEFINED;
  }

  if(Stat stat=master_file_stat(fakeroot(fullname)))
  {
    if(stat->isdir)
    {
      resolv_debug ("findmodule(%O) => new dirnode\n", fullname);
      return fc[fullname] = dirnode(fullname, handler);
    }
#if constant (load_module)
    else if (has_suffix (fullname, ".so")) {
      o = fc[fullname] = low_cast_to_object(fullname, "/.", handler);
      DEC_RESOLV_MSG_DEPTH();
      resolv_debug ("findmodule(%O) => got .so object %O\n", fullname, o);
      return o;
    }
#endif
  }

  INC_RESOLV_MSG_DEPTH();

  if(objectp (o = low_cast_to_object(fullname, "/.", handler))) {
    DEC_RESOLV_MSG_DEPTH();
    resolv_debug ("findmodule(%O) => got object %O\n", fullname, o);
    return fc[fullname]=o;
  }

  if (programp (o = low_cast_to_program(fullname, "/.", handler))) {
    DEC_RESOLV_MSG_DEPTH();
    resolv_debug ("findmodule(%O) => got .pike program %O\n", fullname, o);
    return fc[fullname] = o;
  }

  DEC_RESOLV_MSG_DEPTH();
  resolv_debug ("findmodule(%O) => not found\n", fullname);
  return fc[fullname] = 0;
}

#if 0
mixed handle_import(string what, string|void current_file, object|void handler)
{
  string path;
  if(current_file)
  {
    path = combine_path_with_cwd(dirname(current_file), what);
  } else {
    path = combine_path_with_cwd(what);
  }

#if 0
  // If we can't cache the dirnode when we got a handler, then
  // findmodule has to be broken too. Good caching is necessary for
  // module dumping. /mast
  if (handler) {
    resolv_debug ("handle_import(%O, %O, %O) => new dirnode with handler\n",
		  what, current_file, handler);
    return dirnode(path, handler);
  }
#endif

  if(objectp (fc[path])) {
    resolv_debug ("handle_import(%O, %O) => found %O (cached)\n",
		  what, current_file, fc[path]);
    return fc[path];
  }
  resolv_debug ("handle_import(%O, %O) => new dirnode\n", what, current_file);
#ifdef PIKE_MODULE_RELOC
  // If we have PIKE_MODULE_RELOC enabled, 
  // we might need to map to a join node.
  // FIXME: Ought to use the non-relocate_module() fakeroot().
  if(path == "/${PIKE_MODULE_PATH}" ||
     has_prefix(path, "/${PIKE_MODULE_PATH}/")) {
    string tmp = path[21..];
    array(dirnode) dirnodes = ({});
    foreach(pike_module_path, string prefix) {
      string s2 = fakeroot(sizeof(tmp)? combine_path(prefix, tmp) : prefix);
      if(master_file_stat(s2))
	dirnodes += ({ dirnode(s2, handler) });
    }
    resolv_debug("handle_import(%O, %O) => Found %d dirnodes\n",
		 what, current_file, sizeof(dirnodes));
    if (sizeof(dirnodes) > 1) return fc[path] = joinnode(dirnodes);
    if (sizeof(dirnodes)) return fc[path] = dirnodes[0];
    return UNDEFINED;
  }
#endif /* PIKE_MODULE_RELOC */
  return fc[path] = dirnode(fakeroot(path), handler);
}
#endif /* 0 */


multiset no_resolv = (<>);

//! Resolver of symbols not located in the program being compiled.
class CompatResolver
{
  //! Join node of the root modules for this resolver.
  joinnode root_module = joinnode(({instantiate_static_modules(predef::_static_modules)}));

  //! Lookup from handler module to corresponding root_module.
  mapping(object:joinnode) handler_root_modules = ([]);

  //! The pike system module path, not including any set by the user.
  array(string) system_module_path=({});

  //! The complete module search path
  array(string) pike_module_path=({});

  //! The complete include search path
  array(string) pike_include_path=({});

  //! The complete program search path
  array(string) pike_program_path=({});

  mapping(string:string) predefines = master()->initial_predefines;
  string ver;

  //! If we fail to resolv, try the fallback.
  //!
  //! Typical configuration:
  //! @pre{0.6->7.0->7.2-> ... ->master@}
  CompatResolver fallback_resolver;

  //! The CompatResolver is initialized with a value that can be
  //! casted into a "%d.%d" string, e.g. a version object.
  //!
  //! It can also optionally be initialized with a fallback resolver.
  protected void create(mixed version, CompatResolver|void fallback_resolver)
  {
    resolv_debug("CompatResolver(%O, %O)\n", version, fallback_resolver);
    ver=(string)version;
#if 0
    if (version) {
      root_module->symbol = ver + "::";
    }
#endif
    if (CompatResolver::fallback_resolver = fallback_resolver) {
      root_module->fallback_module = fallback_resolver->root_module;
    }
    predefines = initial_predefines;
  }

  //! Add a directory to search for include files.
  //!
  //! This is the same as the command line option @tt{-I@}.
  //!
  //! @note
  //! Note that the added directory will only be searched when using
  //! < > to quote the included file.
  //!
  //! @seealso
  //! @[remove_include_path()]
  //!
  void add_include_path(string tmp)
    {
      tmp=normalize_path(combine_path_with_cwd(tmp));
      pike_include_path-=({tmp});
      pike_include_path=({tmp})+pike_include_path;
    }

  //! Remove a directory to search for include files.
  //!
  //! This function performs the reverse operation of @[add_include_path()].
  //!
  //! @seealso
  //! @[add_include_path()]
  //!
  void remove_include_path(string tmp)
    {
      tmp=normalize_path(combine_path_with_cwd(tmp));
      pike_include_path-=({tmp});
    }

  //! Add a directory to search for modules.
  //!
  //! This is the same as the command line option @tt{-M@}.
  //!
  //! @seealso
  //! @[remove_module_path()]
  //!
  void add_module_path(string tmp)
    {
      tmp=normalize_path(combine_path_with_cwd(tmp));
      root_module->add_path(tmp);
      pike_module_path = ({ tmp }) + (pike_module_path - ({ tmp }));
    }

  //! Remove a directory to search for modules.
  //!
  //! This function performs the reverse operation of @[add_module_path()].
  //!
  //! @seealso
  //! @[add_module_path()]
  //!
  void remove_module_path(string tmp)
    {
      tmp=normalize_path(combine_path_with_cwd(tmp));
      root_module->rem_path(tmp);
      pike_module_path -= ({ tmp });
    }

  //! Add a directory to search for programs.
  //!
  //! This is the same as the command line option @tt{-P@}.
  //!
  //! @seealso
  //! @[remove_program_path()]
  //!
  void add_program_path(string tmp)
    {
      tmp=normalize_path(combine_path_with_cwd(tmp));
      pike_program_path-=({tmp});
      pike_program_path=({tmp})+pike_program_path;
    }

  //! Remove a directory to search for programs.
  //!
  //! This function performs the reverse operation of @[add_program_path()].
  //!
  //! @seealso
  //! @[add_program_path()]
  //!
  void remove_program_path(string tmp)
    {
      tmp=normalize_path(combine_path_with_cwd(tmp));
      pike_program_path-=({tmp});
    }

  //! Add a define (without arguments) which will be implicitly
  //! defined in @[cpp] calls.
  void add_predefine (string name, string value)
  {
    predefines[name] = value;
  }

  //! Remove a define from the set that are implicitly defined in
  //! @[cpp] calls.
  void remove_predefine (string name)
  {
    m_delete (predefines, name);
  }

  //! Returns a mapping with the current predefines.
  mapping get_predefines()
  {
    return predefines;
  }

  //! Instantiate static modules in the same way that dynamic modules
  //! are instantiated.
  protected mapping(string:mixed) instantiate_static_modules(object|mapping static_modules)
  {
    mapping(string:mixed) res = ([]), joins = ([]);
    foreach(indices(static_modules), string name) {
      mixed val = static_modules[name];
      if (!val->_module_value)
	val = val();
      if(mixed tmp=val->_module_value) val=tmp;
      if(!has_value(name, '.'))
	res[name] = val;
      else {
	mapping(string:mixed) level = joins;
	string pfx;
	while(2 == sscanf(name, "%s.%s", pfx, name))
	  level = (level[pfx] || (level[pfx] = ([])));
	level[name] = val;
      }
    }
    joinnode joinify(mapping m)
    {
      foreach(m; string n; mixed v)
	if(mappingp(v))
	  m[n]=joinify(v);
      return joinnode(({m}));
    };
    foreach(joins; string n; mixed v) {
      if(mappingp(v))
	v = joinify(v);
      if(res[n])
	res[n] = joinnode(({res[n], v}));
      else
	res[n] = v;
    }
    return res;
  }

  //!
  mapping get_default_module()
    {
      resolv_debug ("%O->get_default_module()\n", this);

      /* This is an ugly kluge to avoid an infinite recursion.
       * The infinite recursion occurs because this function is
       * called for every file when the compat_major/minor is set.
       * This kluge could cause problems with threads if the
       * compiler was threaded. -Hubbe
       */
      int saved_compat_minor=compat_minor;
      int saved_compat_major=compat_major;
      compat_minor=-1;
      compat_major=-1;

      mixed x;
      mixed err =catch {
	if(resolv("__default") && (x=resolv("__default.all_constants")))
	  x=x();
      };

      compat_major=saved_compat_major;
      compat_minor=saved_compat_minor;
      if(err) throw(err);
      return x;
    }

  // _static_modules -- default for global::
  // current_handler->get_default_module()->_static_modules

  joinnode get_root_module(object|void current_handler)
  {
    if (!root_module) {
      error("get_root_module(%O): No default root module!\n",
	    current_handler);
    }
    if (!current_handler) return root_module;
    joinnode node = handler_root_modules[current_handler];
    if (node) return node;

    // Check for _static_modules.
    mixed static_modules = _static_modules;
    if (current_handler->get_default_module) {
      mapping(string:mixed) default_module =
	current_handler->get_default_module();
      if (default_module) {
	static_modules = default_module["_static_modules"] || ([]);
      }
    }

    node = joinnode(({ instantiate_static_modules(static_modules),
		       // Copy relevant stuff from the root module.
		       @filter(root_module->joined_modules,
			       lambda(mixed x) {
				 return objectp(x) && x->is_resolv_dirnode;
			       }) }),
		    current_handler,
		    root_module->fallback_module);

    // FIXME: Is this needed?
    // Kluge to get _static_modules to work at top level.
    node->cache->_static_modules = static_modules;

    return node;
  }

  //!
  mixed resolv_base(string identifier, string|void current_file,
		    object|void current_handler)
  {
    //      werror("Resolv_base(%O)\n",identifier);
    return get_root_module(current_handler)[identifier];
  }

  //! Same as @[resolv], but throws an error instead of returning
  //! @[UNDEFINED] if the resolv failed.
  mixed resolv_or_error(string identifier, string|void current_file,
			void|object current_handler)
  {
    mixed res = resolv(identifier, current_file, current_handler);
    if(zero_type(res)) error("Could not resolve %s.\n", identifier);
    return res;
  }

  //!
  mixed resolv(string identifier, string|void current_file,
	       object|void current_handler)
  {
    resolv_debug("resolv(%O, %O)\n",identifier, current_file);
    INC_RESOLV_MSG_DEPTH();

    // FIXME: Support having the cache in the handler?
    if( no_resolv[ identifier ] ) {
      DEC_RESOLV_MSG_DEPTH();
      resolv_debug("resolv(%O, %O) => excluded\n",identifier, current_file);
      return UNDEFINED;
    }

    if (current_file && !stringp(current_file)) {
      error("resolv(%O, %O, %O): current_file is not a string!\n",
	    identifier, current_file, current_handler);
    }

    array(string) tmp = identifier/"::";
    mixed ret;
    if (sizeof(tmp) > 1) {
      string scope = tmp[0];
      tmp = tmp[1]/".";
      switch(scope) {
      case "predef":
	ret = all_constants();
	break;
      default:
	if (sscanf(scope, "%d.%d%*s", int major, int minor) == 3) {
	  // Versioned identifier.
	  ret = get_compilation_handler(major, minor);
	  if (ret) {
	    mixed mod = ret->get_default_module();
	    if (!zero_type(mod = mod[tmp[0]])) {
	      ret = mod;
	    } else {
	      ret = ret->resolv(tmp[0]);
	    }
	    tmp = tmp[1..];
	    break;
	  }
	}
	error("resolv(%O, %O, %O): Unsupported scope: %O!\n",
	      identifier, current_file, current_handler, scope);
      }
    } else {
      tmp = identifier/".";
      ret = resolv_base(tmp[0], current_file, current_handler);
      tmp = tmp[1..];
    }
    foreach(tmp,string index) {
      resolv_debug("indexing %O with %O...\n",
		   ret, index);
      resolv_debug("indices(%O): %O\n", ret, indices(ret));
      if (zero_type(ret)) break;
      ret = ret[index];
    }
    DEC_RESOLV_MSG_DEPTH();
#ifdef RESOLV_DEBUG
    if (zero_type (ret))
      resolv_debug("resolv(%O, %O) => not found\n",identifier, current_file);
    else
      resolv_debug("resolv(%O, %O) => found %O\n",identifier, current_file, ret);
#endif /* RESOLV_DEBUG */
    return ret;
  }


  //! This function is called whenever an #include directive is
  //! encountered. It receives the argument for #include and should
  //! return the file name of the file to include
  string handle_include(string f,
			string current_file,
			int local_include)
  {
    if(local_include)
    {
      if(IS_ABSOLUTE_PATH(f)) return combine_path(f);
      return combine_path_with_cwd(dirname(current_file), f);
    }
    else
    {
      foreach(pike_include_path, string path)
      {
	path=combine_path(path,f);
	if(master_file_stat(fakeroot(path)))
	  return path;
      }
      if (fallback_resolver) {
	return fallback_resolver->handle_include(f, current_file,
						 local_include);
      }
    }
    // Failed.
    return 0;
  }

  //!
  string read_include(string f)
  {
    AUTORELOAD_CHECK_FILE(f);
    if (array|object err = catch {
	return master_read_file (f);
      })
      compile_cb_rethrow (err);
  }

  string _sprintf(int t)
  {
    return t=='O' && sprintf("CompatResolver(%O)",ver);
  }
}

inherit CompatResolver;

//!
class Pike06Resolver
{
  inherit CompatResolver;

  //! In Pike 0.6 the current directory was implicitly searched.
  mixed resolv_base(string identifier, string|void current_file,
		    object|void current_handler)
  {
    if (current_file) {
      joinnode node = handle_import(".", current_file, current_handler);
      return node[identifier] ||
	::resolv_base(identifier, current_file, current_handler);
    }
    return ::resolv_base(identifier, current_file, current_handler);
  }
}

//! These are useful if you want to start other Pike processes
//! with the same options as this one was started with.
string _pike_file_name;
string _master_file_name;

// Gets set to 1 if we're in async-mode (script->main() returned <0)
private int(0..1) _async=0;

//! Returns 1 if we�re in async-mode, e.g. if the main method has
//! returned a negative number.
int(0..1) asyncp() {
  return _async;
}

#if constant(thread_create)
// this must be done in __init if someone inherits the master
protected object _backend_thread=this_thread();

//! The backend_thread() function is useful to determine if you are
//! the backend thread - important when doing async/sync protocols.
//! This method is only available if thread_create is present.
object backend_thread()
{
   return _backend_thread;
}
#endif


mapping(string:string) initial_predefines = ([]);

protected mixed main_resolv(string sym, CompatResolver|void resolver) {
  mixed v = (resolver||this)->resolv(sym);
  if(!v)
    error("Could not resolve %s. "
	  "(Perhaps the installed pike tree has been moved.)\n", sym);
  return v;
};

//! This function is called when all the driver is done with all setup
//! of modules, efuns, tables etc. etc. and is ready to start executing
//! _real_ programs. It receives the arguments not meant for the driver.
void _main(array(string) orig_argv)
{
  array(string) argv=copy_value(orig_argv);
  int debug,trace,run_tool;
  object tmp;
  string postparseaction=0;

  predefines = initial_predefines =
    Builtin._take_over_initial_predefines();
  _pike_file_name = orig_argv[0];
#if constant(thread_create)
  _backend_thread = this_thread();
#endif

#ifndef NOT_INSTALLED
  {
    array parts = (getenv("PIKE_INCLUDE_PATH")||"")/PATH_SEPARATOR-({""});
    int i = sizeof(parts);
    while(i) add_include_path(parts[--i]);

    parts = (getenv("PIKE_PROGRAM_PATH")||"")/PATH_SEPARATOR-({""});
    i = sizeof(parts);
    while(i) add_program_path(parts[--i]);

    parts = (getenv("PIKE_MODULE_PATH")||"")/PATH_SEPARATOR-({""});
    i = sizeof(parts);
    while(i) add_module_path(parts[--i]);
  }
#endif

  // Some configure scripts depends on this format.
  string format_paths() {
    return  ("master.pike...: " + (_master_file_name || __FILE__) + "\n"
	     "Module path...: " + pike_module_path*"\n"
	     "                " + "\n"
	     "Include path..: " + pike_include_path*"\n"
	     "                " + "\n"
	     "Program path..: " + pike_program_path*"\n"
	     "                " + "\n");
  };

  Version cur_compat_ver;

  if(sizeof(argv)>1 && sizeof(argv[1]) && argv[1][0]=='-')
  {
    array q;
    tmp = main_resolv( "Getopt" );

    int NO_ARG = tmp->NO_ARG;
    int MAY_HAVE_ARG = tmp->MAY_HAVE_ARG;
    int HAS_ARG = tmp->HAS_ARG;

    q=tmp->find_all_options(argv,({
      ({"compat_version", HAS_ARG, ({"-V", "--compat"}), 0, 0}),
      ({"version",        NO_ARG,  ({"-v", "--version"}), 0, 0}),
      ({"dumpversion",    NO_ARG,  ({"--dumpversion"}), 0, 0}),
      ({"help",           MAY_HAVE_ARG, ({"-h", "--help"}), 0, 0}),
      ({"features",       NO_ARG,  ({"--features"}), 0, 0}),
      ({"info",           NO_ARG,  ({"--info"}), 0, 0}),
      ({"execute",        HAS_ARG, ({"-e", "--execute"}), 0, 0}),
      ({"debug_without",  HAS_ARG, ({"--debug-without"}), 0, 0}),
      ({"preprocess",     HAS_ARG, ({"-E", "--preprocess"}), 0, 0}),
      ({"modpath",        HAS_ARG, ({"-M", "--module-path"}), 0, 0}),
      ({"ipath",          HAS_ARG, ({"-I", "--include-path"}), 0, 0}),
      ({"ppath",          HAS_ARG, ({"-P", "--program-path"}), 0, 0}),
      ({"showpaths",      MAY_HAVE_ARG, ({"--show-paths"}), 0, 0}),
      ({"warnings",       NO_ARG,  ({"-w", "--warnings"}), 0, 0}),
      ({"nowarnings",     NO_ARG,  ({"-W", "--woff", "--no-warnings"}), 0, 0}),
      ({"autoreload",     NO_ARG,  ({"--autoreload"}), 0, 0}),
      ({"master",         HAS_ARG, ({"-m"}), 0, 0}),
      ({"compiler_trace", NO_ARG,  ({"--compiler-trace"}), 0, 0}),
      ({"assembler_debug",MAY_HAVE_ARG, ({"--assembler-debug"}), 0, 0}),
      ({"optimizer_debug",MAY_HAVE_ARG, ({"--optimizer-debug"}), 0, 0}),
      ({"debug",          MAY_HAVE_ARG, ({"--debug"}), 0, 1}),
      ({"trace",          MAY_HAVE_ARG, ({"--trace"}), 0, 1}),
      ({"ignore",         MAY_HAVE_ARG, ({"-Dqdatplr"}), 0, 1}),
      ({"ignore",         HAS_ARG, ({"-s"}), 0, 0}),
      ({"run_tool",       NO_ARG,  ({"-x"}), 0, 0}),
      ({"show_cpp_warn",  NO_ARG,  ({"--show-all-cpp-warnings","--picky-cpp"}), 0, 0}),
    }), 1);

    /* Parse -M and -I backwards */
    for(int i=sizeof(q)-1; i>=0; i--)
    {
      switch(q[i][0])
      {
	case "compat_version":
	  sscanf(q[i][1],"%d.%d",compat_major,compat_minor);
	  break;

#ifdef PIKE_AUTORELOAD
      case "autoreload":
	autoreload_on++;
	break;
#endif

      case "debug_without":
	// FIXME: Disable loading of dumped modules?
        foreach( q[i][1]/",", string feature )
        {
          switch( feature )
          {
           case "ttf":
             no_resolv[ "_Image_TTF" ] = 1;
             break;
           case "zlib":
             no_resolv[ "Gz" ] = 1;
             break;
           case "unisys":
             no_resolv[ "_Image_GIF" ] = 1;
             no_resolv[ "_Image_TIFF" ] = 1;
             break;
           case "threads":
             // not really 100% correct, but good enough for most things.
             no_resolv[ "Thread" ] = 1;
             add_constant( "thread_create" );
             break;
           default:
             no_resolv[ feature ] = 1;
             break;
          }
        }
        break;

      case "debug":
	debug+=(int)q[i][1];
	break;

#if constant(_compiler_trace)
      case "compiler_trace":
	_compiler_trace(1);
	break;
#endif /* constant(_compiler_trace) */

#if constant(_assembler_debug)
      case "assembler_debug":
	_assembler_debug((int)q[i][1]);
	break;
#endif /* constant(_assembler_debug) */

#if constant(_optimizer_debug)
      case "optimizer_debug":
	_optimizer_debug((int)q[i][1]);
	break;
#endif /* constant(_optimizer_debug) */

      case "trace":
	trace+=(int)q[i][1];
	break;

      case "modpath":
	add_module_path(q[i][1]);
	break;

      case "ipath":
	add_include_path(q[i][1]);
	break;

      case "ppath":
	add_program_path(q[i][1]);
	break;

      case "warnings":
	want_warnings++;
	break;

      case "nowarnings":
	want_warnings--;
	break;

      case "master":
	_master_file_name = q[i][1];
	break;

      case "run_tool":
	run_tool = 1;
	break;

      case "show_cpp_warn":
	show_if_constant_errors = 1;
	break;
      }
    }

    cur_compat_ver = Version (compat_major, compat_minor);
    if (compat_major != -1) {
      object compat_master = get_compat_master (compat_major, compat_minor);

      if (cur_compat_ver <= Version (7, 6)) {
	mapping(string:array(string)) compat_env = ([]);
	foreach (Builtin._getenv(); string var; string val) {
#ifdef __NT__
	  compat_env[lower_case (var)] = ({var, val});
#else
	  compat_env[var] = ({var, val});
#endif
	}
	compat_master->environment = compat_env;
      }
    }

    foreach(q, array opts)
    {
      switch(opts[0])
      {
      case "dumpversion":
	write("%d.%d.%d\n", __REAL_MAJOR__, __REAL_MINOR__, __REAL_BUILD__);
        exit(0);

      case "version":
	exit(0, version() + " Copyright � 1994-2009 Link�ping University\n"
             "Pike comes with ABSOLUTELY NO WARRANTY; This is free software and you are\n"
             "welcome to redistribute it under certain conditions; read the files\n"
             "COPYING and COPYRIGHT in the Pike distribution for more details.\n");

      case "help":
	exit( 0, main_resolv("Tools.MasterHelp")->do_help(opts[1]) );

      case "features":
	postparseaction="features";
	break;

      case "info":
	postparseaction="info";
	break;

      case "showpaths":
        if( stringp(opts[1]) )
        {
          switch(opts[1])
          {
          case "master":
            write( (_master_file_name || __FILE__)+"\n" );
            break;

          case "module":
            write( (pike_module_path * ":")+"\n" );
            break;

          case "include":
            write( (pike_include_path * ":")+"\n" );
            break;

          case "program":
            write( (pike_program_path * ":")+"\n" );
            break;

          default:
            exit(1, "Unknown path type %s\n", opts[1]);
          }
          exit(0);
        }

	exit(0, format_paths());

      case "execute":
#ifdef __AUTO_BIGNUM__
	main_resolv( "Gmp.bignum" );
#endif /* __AUTO_BIGNUM__ */

	random_seed((time() ^ (getpid()<<8)));
	argv = tmp->get_args(argv,1);

	program prog;
	mixed compile_err = catch {;
	  if(cur_compat_ver <= Version(7,4))
	    prog = compile_string(
	      "mixed create(int argc, array(string) argv,array(string) env){"+
	      opts[1]+";}");
	  else if (intp (opts[1]))
	    prog = compile_string ("mixed run() {}");
	  else {
	    string code = opts[1];
	    while(sscanf(code, "%sCHAR(%1s)%s", code, string c, string rest)==3)
	      code += c[0] + rest;
	    if (cur_compat_ver <= Version (7, 6))
	      prog = compile_string(
		"#define NOT(X) !(X)\n"
		"mixed run(int argc, array(string) argv,"
		"mapping(string:string) env){"+
		code+";}");
	    else
	      prog = compile_string(
		"#define NOT(X) !(X)\n"
		"mixed run(int argc, array(string) argv){" + code + ";}");
	  }
	  };

	if (compile_err) {
	  if (compile_err->is_cpp_or_compilation_error) {
	    // Don't clutter the output with the backtrace for
	    // compilation errors.
	    exit (20, describe_error (compile_err));
	  }
	  else throw (compile_err);
	}

#if constant(_debug)
	if(debug) _debug(debug);
#endif
	if(trace) trace = predef::trace(trace);
	mixed ret;
	mixed err = catch {
	    // One reason for this catch is to get a new call to
	    // eval_instruction in interpret.c so that the debug and
	    // trace levels set above take effect in the bytecode
	    // evaluator.
	    if(cur_compat_ver <= Version(7,4))
	      prog (sizeof(argv),argv,getenv());
	    else if (cur_compat_ver <= Version (7, 6))
	      ret = prog()->run(sizeof(argv),argv,getenv());
	    else
	      ret = prog()->run(sizeof(argv),argv);
	  };
	predef::trace(trace);
	if (err) {
	  handle_error (err);
	  ret = 10;
	}
	if(stringp(ret)) {
	  write(ret);
	  if(ret[-1]!='\n') write("\n");
	}
	if(!intp(ret) || ret<0) ret=0;
	exit(ret);

      case "preprocess":
#ifdef __AUTO_BIGNUM__
	main_resolv( "Gmp.bignum" );
#endif /* __AUTO_BIGNUM__ */
	write(cpp(master_read_file(opts[1]),opts[1]));
	exit(0);
      }
    }

    argv = tmp->get_args(argv,1);
  }
  else
    cur_compat_ver = Version (compat_major, compat_minor);

  switch (postparseaction)
  {
     case "features":
       write( main_resolv( "Tools.Install.features" )()*"\n"+"\n" );
       exit(0);

     case "info":
       write("Software......Pike\n"
	     "Version......."+version()+"\n"
	     "WWW...........http://pike.ida.liu.se/\n"
	     "\n"
	     "pike binary..."+_pike_file_name+"\n"+
	      format_paths() + "\n"
	     "Features......"+
	     main_resolv( "Tools.Install.features" )()*"\n              "+
	     "\n");
	exit(0);
  }

#ifdef __AUTO_BIGNUM__
  main_resolv( "Gmp.bignum" );
#endif /* __AUTO_BIGNUM__ */

  random_seed(time() ^ (getpid()<<8));

  if(sizeof(argv)==1)
  {
    if(run_tool) {
      werror("Pike -x specificed without tool name.\n"
	     "Available tools:\n");
      mapping t = ([]);
      int i;
      object ts = main_resolv("Tools.Standalone",
			      get_compilation_handler(compat_major,
						      compat_minor));
      foreach (indices(ts), string s) {
	mixed val = ts[s];
	if (programp (val)) {
	  object o = val();
	  if(!o->main || !o->description) continue;
	  t[s] = o->description;
	  i = max(i, sizeof(s));
	}
      }
      foreach(sort(indices(t)), string s)
	werror(" %-"+i+"s %s\n", s, t[s]);
      exit(1);
    }
    main_resolv("Tools.Hilfe",
		get_compilation_handler(compat_major,
					compat_minor))->StdinHilfe();
    exit(0);
  }
  else
    argv=argv[1..];

  program prog;

  if(run_tool) {
    mixed err = catch {
      prog = main_resolv("Tools.Standalone." + argv[0],
			 get_compilation_handler(compat_major, compat_minor));
    };

    if (err)
      exit(1, "Pike: Failed to load tool %s:\n"
           "%s\n", argv[0],
           stringp(err[0])?err[0]:describe_backtrace(err));

    argv[0] = search(programs, prog) || argv[0];
  } else {
    argv[0]=combine_path_with_cwd(argv[0]);

    mixed err = catch {
      prog=(program)argv[0];
    };

    if (err) {
      string fn = argv[0];
      if( !file_stat(fn) )
      {
        if( file_stat(fn+".pike") )
          fn += ".pike";
        else
          exit(1, "Could not find file %O.\n", fn);
      }
      if( !file_stat(fn)->isreg )
	exit(1, "File %O is not a regular file.\n", fn);
      if( !master_read_file(fn) )
	exit(1, "File %O is not readable. %s.\n",
	     fn, strerror(errno()));
      if (objectp (err) && err->is_cpp_or_compilation_error)
	exit(1, "Pike: Failed to compile script.\n");
      else
	exit(1, "Pike: Failed to compile script:\n"
	     "%s", describe_backtrace(err));
    }

    // Don't list the program with its real path in the programs
    // mapping, so that reverse lookups (typically by the codec)
    // always find the canonical "/main" instead.
    programs[argv[0]] = no_value;
  }

  programs["/main"] = prog;

  // FIXME: Can this occur at all?
  if(!prog)
    error("Pike: Couldn't find script to execute\n(%O)\n", argv[0]);

#if constant(_debug)
  if(debug) _debug(debug);
#endif
  if(trace) trace = predef::trace(trace);
  mixed ret;
  mixed err = catch {
      // The main reason for this catch is actually to get a new call
      // to eval_instruction in interpret.c so that the debug and
      // trace levels set above take effect in the bytecode evaluator.
      object script;
      if(cur_compat_ver <= Version(7,4)) {
	script=prog();
      }
      else {
	script=prog(argv);
      }
      if(!script->main)
	error("Error: %s has no main().\n", argv[0]);
      if (cur_compat_ver <= Version (7, 6))
	ret=script->main(sizeof(argv),argv,getenv());
      else
	ret=script->main(sizeof(argv),argv);
    };
  // Disable tracing.
  trace = predef::trace(trace);
  if (err) {
    handle_error (err);
    ret = 10;
  }
  if(!intp(ret))
    exit(10, "Error: Non-integer value %O returned from main.\n", ret);

  if(ret >=0) exit([int]ret);
  _async=1;

  // Reenable tracing.
  trace = predef::trace(trace);
  while(1)
  {
    mixed err=catch 
    {
      while(1)
	Builtin.__backend(3600.0);
    };
    master()->handle_error(err);
  }
}

#if constant(thread_local)
object inhibit_compile_errors = thread_local();

void set_inhibit_compile_errors(mixed f)
{
  inhibit_compile_errors->set(f);
}

mixed get_inhibit_compile_errors()
{
  return inhibit_compile_errors->get();
}
#else /* !constant(thread_local) */
mixed inhibit_compile_errors;

void set_inhibit_compile_errors(mixed f)
{
  inhibit_compile_errors=f;
}

mixed get_inhibit_compile_errors()
{
  return inhibit_compile_errors;
}
#endif /* constant(thread_local) */

protected private function(string:string) _trim_file_name_cb=0;
string trim_file_name(string s)
{
#ifdef PIKE_MODULE_RELOC
  s = relocate_module(s);
#endif
  if(getenv("LONG_PIKE_ERRORS")) return s;
  if(getenv("SHORT_PIKE_ERRORS")) return BASENAME(s);

  if (_trim_file_name_cb) return _trim_file_name_cb(s);

  /* getcwd() can fail, but since this is called from handle_error(),
   * we don't want to fail, so we don't care about that.
   */
  catch {
    string cwd=getcwd();
    if (sizeof(cwd) && (cwd[-1] != '/')) {
      cwd += "/";
    }
    if(has_prefix (s, cwd)) return s[sizeof(cwd)..];
  };
  return s;
}

function(string:string) set_trim_file_name_callback(function(string:string) s)
{
   function(string:string) f=_trim_file_name_cb;
   _trim_file_name_cb=s;
   return f;
}


//! This function is called whenever a compile error occurs. @[line]
//! is zero for errors that aren't associated with any specific line.
//! @[err] is not newline terminated.
void compile_error(string file,int line,string err)
{
  mixed val;
  if(! (val = get_inhibit_compile_errors() ))
  {
    werror( "%s:%s:%s\n",trim_file_name(file),
	    line?(string)line:"-",err );
  }
  else if(objectp(val) ||
	  programp(val) ||
	  functionp(val))
  {
    if (objectp(val) && val->compile_error) {
      val->compile_error(file, line, err);
    } else if (callablep(val)) {
      val(file, line, err);
    }
  }
}


//! This function is called whenever a compile warning occurs. @[line]
//! is zero for warnings that aren't associated with any specific
//! line. @[err] is not newline terminated.
void compile_warning(string file,int line,string err)
{
  mixed val;

  if(!(val = get_inhibit_compile_errors() ))
  {
    if(want_warnings)
      werror( "%s:%s: Warning: %s\n",trim_file_name(file),
	      line?(string)line:"-",err );
  }
  else if (objectp(val) && val->compile_warning) {
    ([function(string,int,string:void)]([object]val)
     ->compile_warning)(file, line, err);
  }
}


//! This function is called when an exception is catched during
//! compilation. Its message is also reported to @[compile_error] if
//! this function returns zero.
int compile_exception (array|object trace)
{
  if (objectp (trace) && ([object]trace)->is_cpp_or_compilation_error)
    // Errors thrown by cpp(), compile() or a compile callback should
    // be reported as a normal compile error, so let the caller do
    // just that.
    return 0;
  if (mixed val = get_inhibit_compile_errors()) {
    if (objectp(val) && ([object]val)->compile_exception)
      return ([function(object:int)]([object]val)
	      ->compile_exception)([object]trace);
  }
  else {
    handle_error (trace);
    return 1;
  }
  return 0;
}


//! Called for every runtime warning. The first argument identifies
//! where the warning comes from, the second identifies the specific
//! message, and the rest depends on that. See code below for currently
//! implemented warnings.
void runtime_warning (string where, string what, mixed... args)
{
  if (want_warnings)
    switch (where + "." + what) {
      case "gc.bad_cycle":
	// args[0] is an array containing the objects in the cycle
	// which aren't destructed and have destroy() functions.
#if 0
	// Ignore this warning for now since we do not yet have a weak
	// modifier, so it can't be avoided in a reasonable way.
	werror ("GC warning: Garbing cycle where destroy() will be called "
		"in arbitrary order:\n%{            %s\n%}",
		sprintf("%O", args[0][*]));
#endif
	break;

      default:
	werror ("%s warning: %s %O\n", capitalize (where), what, args);
    }
}


protected object Charset;

//! This function is called by cpp() when it wants to do
//! character code conversion.
string decode_charset(string data, string charset)
{
  if (!Charset) {
    object mod = [object]resolv("Locale");

    Charset = [object](mod && mod["Charset"]);
    if (!Charset)
      compile_cb_error("Cannot handle charset - no Locale.Charset module found.");
  }

  if (mixed err = catch {
      object decoder = ([function(string:object)]Charset.decoder)(charset);
      return ([function(void:string)]([function(string:object)]decoder->
				      feed)(data)->drain)();
    })
    compile_cb_rethrow (err);
}


class Describer
{
  int clipped=0;
  int canclip=0;
  mapping(mixed:int|string) ident = ([]);
  int identcount = 0;

  void identify_parts (mixed stuff)
  {
    // Use an array as stack here instead of recursing directly; we
    // might be pressed for stack space if the backtrace being
    // described is a stack overflow.
    array identify_stack = ({stuff});
    while (sizeof (identify_stack)) {
      stuff = identify_stack[-1];
      identify_stack = identify_stack[..<1];
      if (!intp(ident[stuff])) continue;	// Already identified.
      if (objectp (stuff) || functionp (stuff) || programp (stuff))
	ident[stuff]++;
      else if (arrayp (stuff)) {
	if (!ident[stuff]++)
	  identify_stack += stuff;
      }
      else if (multisetp (stuff)) {
	if (!ident[stuff]++)
	  identify_stack += indices([multiset]stuff);
      }
      else if (mappingp (stuff)) {
	if (!ident[stuff]++)
	  identify_stack += indices([mapping]stuff) + values([mapping]stuff);
      }
    }
  }

  string describe_string (string m, int maxlen)
  {
    canclip++;
    if(sizeof(m) < maxlen)
    {
      string t = sprintf("%q", m);
      if (sizeof(t) < (maxlen + 2))
	return t;
      t = 0;
    }
    clipped++;
    if(maxlen>10)
      return sprintf("%q+[%d]",m[..maxlen-5],sizeof(m)-(maxlen-5));

    return "string["+sizeof(m)+"]";
  }

  string describe_array (array m, int maxlen)
  {
    if(!sizeof(m)) return "({})";
    else {
      if(maxlen<5)
      {
	clipped++;
	return "array["+sizeof(m)+"]";
      }
      else {
	canclip++;
	return "({" + describe_comma_list(m,maxlen-2) +"})";
      }
    }
  }

  string describe_mapping (mapping m, int maxlen)
  {
    if(!sizeof(m)) return "([])";
    else return "mapping["+sizeof(m)+"]";
  }

  string describe_multiset (multiset m, int maxlen)
  {
    if(!sizeof(m)) return "(<>)";
    else return "multiset["+sizeof(m)+"]";
  }

  string describe (mixed m, int maxlen)
  {
    catch {
      if (stringp (ident[m])) return [string]ident[m];
      else if (intp (ident[m]) && ident[m] > 1)
	ident[m] = "@" + identcount++;
    };

    string res;
    if (catch (res=sprintf("%t",m)))
      res = "object";		// Object with a broken _sprintf(), probably.
    switch(res)
    {
    case "int":
      if (!m && zero_type (m) == 1)
	return "UNDEFINED";
    case "float":
      return (string)m;
    case "string":
      return describe_string ([string]m, maxlen);
    case "array":
      res = describe_array ([array]m, maxlen);
      break;
    case "mapping":
      res = describe_mapping ([mapping]m, maxlen);
      break;
    case "multiset":
      res = describe_multiset ([multiset]m, maxlen);
      break;
    case "function":
      if (string tmp=describe_function([function]m)) res = tmp;
      break;
    case "program":
      if(string tmp=describe_program([program]m)) res = tmp;
      break;
    default:
      /* object or type. */
      if (catch {
	if(string tmp=sprintf("%O", m)) res = tmp;
      }) {
	// Extra paranoia case.
	res = sprintf("Instance of %O", _typeof(m));
      }
      break;
    }
    if (stringp(ident[m]))
      return ident[m] + "=" + res;
    return res;
  }

  string describe_comma_list(array x, int maxlen)
  {
    string ret="";

    if(!sizeof(x)) return "";
    if(maxlen<0) return ",,,"+sizeof(x);

    int clip=min(maxlen/2,sizeof(x));
    int len=maxlen;
    int done=0;

    while(1)
    {
      array(string) z=allocate(clip);
      array(int) isclipped=allocate(clip);
      array(int) clippable=allocate(clip);
      for(int e=0;e<clip;e++)
      {
	clipped=0;
	canclip=0;
	z[e]=describe(x[e],len);
	isclipped[e]=clipped;
	clippable[e]=canclip;
      }

      while(1)
      {
	string ret = z[..clip-1]*",";
	if(done || sizeof(ret)<=maxlen+1)
	{
	  int tmp=sizeof(x)-clip-1;
	  clipped=`+(0,@isclipped);
	  if(tmp>=0)
	  {
	    clipped++;
	    ret+=",,,"+tmp;
	  }
	  canclip++;
	  return ret;
	}

	int last_newlen=len;
	int newlen;
	int clipsuggest;
	while(1)
	{
	  int smallsize=0;
	  int num_large=0;
	  clipsuggest=0;

	  for(int e=0;e<clip;e++)
	  {
	    if((sizeof(z[e])>=last_newlen || isclipped[e]) && clippable[e])
	      num_large++;
	    else
	      smallsize+=sizeof(z[e]);

	    if(num_large * 15 + smallsize < maxlen) clipsuggest=e+1;
	  }

	  newlen=num_large ? (maxlen-smallsize)/num_large : 0;

	  if(newlen<8 || newlen >= last_newlen) break;
	  last_newlen=newlen;
	}

	if(newlen < 8 && clip)
	{
	  clip-= (clip/4) || 1;
	  if(clip > clipsuggest) clip=clipsuggest;
	}else{
	  len=newlen;
	  done++;
	  break;
	}
      }
    }

    return ret;
  }
}


string program_path_to_name ( string path,
			      void|string module_prefix,
			      void|string module_suffix,
			      void|string object_suffix )
//! Converts a module path on the form @expr{"Foo.pmod/Bar.pmod"@} or
//! @expr{"/path/to/pike/lib/modules/Foo.pmod/Bar.pmod"@} to a module
//! identifier on the form @expr{"Foo.Bar"@}.
//!
//! If @[module_prefix] or @[module_suffix] are given, they are
//! prepended and appended, respectively, to the returned string if
//! it's a module file (i.e. ends with @expr{".pmod"@} or
//! @expr{".so"@}). If @[object_suffix] is given, it's appended to the
//! returned string if it's an object file (i.e. ends with
//! @expr{".pike"@}).
{
  if (path == "/master") return "master" + (object_suffix || "");

  array(string) sort_paths_by_length(array(string) paths)
  {
    sort(map(paths, sizeof), paths);
    return reverse(paths);
  };

  string prefix = "";

  array(Version) versions = reverse(sort(indices(compat_handler_cache)));
 find_prefix:
  foreach(versions, Version version) {
    CompatResolver r = compat_handler_cache[version];
    if (!r) continue;	// Protection against the gc...

    foreach(sort_paths_by_length(map(r->pike_module_path - ({""}),
				     lambda(string s) {
				       if (s[-1] == '/') return s;
				       return s+"/";
				     })),
	    string path_prefix) {
      if (has_prefix(path, path_prefix)) {
	path = path[sizeof(path_prefix)..];
	if (version != currentversion) {
	  prefix = ((string)version) + "::";
	}
	break find_prefix;
      }
    }
  }

#if 0
  // This seems broken. Why should the current directory or the
  // setting of SHORT_PIKE_ERRORS etc affect the module identifiers?
  // /mast
  path = trim_file_name(path);
#endif

  string modname = replace(path, ".pmod/", ".");
  if(search(modname, "/")<0) path=modname;

  path = prefix + path;

  if (has_suffix(path, ".module.pmod")) {
    return (module_prefix || "") + path[..<12] + (module_suffix || "");
  }
  if (has_suffix(path, ".pmod")) {
    return (module_prefix || "") + path[..<5] + (module_suffix || "");
  }
  if (has_suffix(path, ".so")) {
    return (module_prefix || "") + path[..<3] + (module_suffix || "");
  }
  if (has_suffix(path, ".pike")) {
    return path[..<5] + (object_suffix || "");
  }
  return path + (object_suffix || "");
}


//! Describe the path to the module @[mod].
//!
//! @param mod
//!   If @[mod] is a program, attempt to describe the path
//!   to a clone of @[mod].
//!
//! @param ret_obj
//!   If an instance of @[mod] is found, it will be returned
//!   by changing element @expr{0@} of @[ret_obj].
//!
//! @returns
//!   The a description of the path.
//!
//! @note
//!   The returned description will end with a proper indexing method
//!   currently either @expr{"."@} or @expr{"->"@}.
string describe_module(object|program mod, array(object)|void ret_obj)
{
  // Note: mod might be a bignum object; objectp won't work right for
  // our purposes. object_program returns zero for non-objects, so we
  // use it instead.
  program parent_fun = object_program(mod);
  if (parent_fun) {
    if (ret_obj) ret_obj[0] = mod;
  } else if (programp (mod)) {
    parent_fun = mod;
    // When running with debug we might be called before __INIT, so
    // we have to check if objects exists before we use it.
    if (objects && objectp (mod = objects[parent_fun]) && ret_obj)
      ret_obj[0] = mod;
  }
  else
    return "";			// efun

  if (mod) {
    catch {
      string res = sprintf("%O", mod);
      if (res != "object" && res != "")
	return (objectp (objects[parent_fun]) && programs["/master"] != parent_fun?
		res+".":res+"->");
    };
    string res = search(all_constants(), mod);
    if (res) return res;
  }
  if (!object_program(parent_fun)) {
    // We might be a top-level entity.
    if (string path = programs_reverse_lookup (parent_fun))
      return program_path_to_name(path, "", ".", "()->");
  }
  // Begin by describing our parent.
  array(object) parent_obj = ({ 0 });
  string res = describe_module(function_object(parent_fun)||
			       function_program(parent_fun)||
			       object_program(parent_fun),
			       parent_obj);
  // werror("So far: %O parent_obj:%O\n", res, parent_obj);
  object|program parent =
    object_program (parent_obj[0]) ? parent_obj[0] : object_program(parent_fun);
  if (mod && (object_program (parent) || parent)) {
    // Object identified.
    catch {
      // Check if we're an object in parent.
      int i = search(values(parent), mod);
      if (i >= 0) {
	return res + [string]indices(parent)[i] + ".";
      }
    };
  }

  // We're cloned from something in parent.
  if (string fun_name = function_name(parent_fun)) {
    return res + fun_name + "()->";
  }

  // No such luck.
  // Try identifying a clone of ourselves.
  if (!mod && (object_program (parent) || parent)) {
    catch {
      // Check if there's a clone of parent_fun in parent_obj.
      int i;
      array(mixed) val = values(parent);
      array(string) ind = [array(string)]indices(parent);
      for (i=0; i < sizeof(val); i++) {
	if (object_program(val[i]) && object_program(val[i]) == parent_fun) {
	  return res + ind[i] + ".";
	}
      }
    };
  }

  // We're really out of luck here...
  return res + (describe_program(parent_fun)||"unknown_program") + "()->";
}

//!
string describe_object(object o)
{
  string s;
  if(zero_type (o)) return 0;	// Destructed.

  // Handled by the search of all_constants() below.
  // if (o == _static_modules) return "_static_modules";

  program|function(mixed...:void|object) parent_fun = object_program(o);

  /* Constant object? */
  catch {
    object|program parent_obj =
      (function_object(parent_fun) || function_program(parent_fun));

    if (objectp (parent_obj) || parent_obj) {
      /* Check if we have a constant object. */
      object tmp = objects[parent_obj];
      if (objectp (tmp)) parent_obj = tmp;

      /* Try finding ourselves in parent_obj. */
      int i = search(values(parent_obj), o);
      if (i >= 0) {
	s = [string]indices(parent_obj)[i];
	return describe_module(parent_obj) + s;
      }
    }
  };
  if ((s = search(all_constants(), o))) return s;
  // When running with RESOLV_DEBUG this function may
  // get called before objects has been initialized.
  if(objects && objectp (objects[parent_fun]))
    if ((s = programs_reverse_lookup (parent_fun)) &&
	(s=program_path_to_name(s, "", "", "()")))
      return s;
  /* Try identifying the program. */
  if(( s=describe_program(parent_fun) ))
    return s+"()";

  return 0;
}

//!
string describe_program(program|function p)
{
  string s;
  if(!p) return 0;

  if (p == object_program (_static_modules))
    return "object_program(_static_modules)";

  if(programp(p) &&
     (s = programs_reverse_lookup ([program] p)) &&
     (s=program_path_to_name(s, "object_program(", ")", "")))
    return s;

  if(object|program tmp=(function_object(p) || function_program(p))) {
    if(s = function_name(p))
    {
      return describe_module(tmp) + s;
    }
  }

  if(s=Builtin.program_defined(p))
    return BASENAME(s);

  return search(all_constants(), p);
}

//!
string describe_function (function f)
{
  if (!f) return 0;

  string name;

  if (name = search(all_constants(), f)) return name;

  if(string s = programs_reverse_lookup (f))
  {
    if(has_suffix(s, ".pmod"))
      name = BASENAME(s[..<5]);
    else
      name = trim_file_name(s);
  }
  else 
    if (catch (name = function_name (f))) name = "function";

  object o = function_object([function(mixed...:void|mixed)]f);
  if(object_program (o)) { // Check if it's an object in a way that
			   // (hopefully) doesn't call any functions
			   // in it (neither `== nor `!).
    string s;
    if (!catch (s = sprintf("%O",o)) && s != "object")
      return s+"->"+name;
  }
  return name;
}

/* It is possible that this should be a real efun,
 * it is currently used by handle_error to convert a backtrace to a
 * readable message.
 */

//! @appears describe_backtrace
//! Return a readable message that describes where the backtrace
//! @[trace] was made (by @[backtrace]).
//!
//! It may also be an error object or array (typically caught by a
//! @[catch]), in which case the error message also is included in the
//! description.
//!
//! @seealso
//! @[backtrace()], @[describe_error()], @[catch()], @[throw()]
//!
string describe_backtrace(mixed trace, void|int linewidth)
{
  int e;
  string ret;
  int backtrace_len=((int)getenv("PIKE_BACKTRACE_LEN")) || bt_max_string_len;

  if(!linewidth)
  {
    linewidth=99999;
    catch 
    {
      linewidth=[int]Files()->_stdin->tcgetattr()->columns;
    };
    if(linewidth<10) linewidth=99999;
  }

  // Note: Partial code duplication in describe_error and get_backtrace.

  if (objectp(trace) && ([object]trace)->is_generic_error) {
    object err_obj = [object] trace;
    if (mixed err = catch {

	if (functionp (err_obj->message))
	  ret = err_obj->message();
	else if (zero_type (ret = err_obj->error_message))
	  // For compatibility with error objects trying to behave
	  // like arrays.
	  ret = err_obj[0];
	if (!ret)
	  ret = "";
	else if (!stringp (ret))
	  ret = sprintf ("<Message in %O is %t, expected string>\n",
			 err_obj, ret);

	if (functionp (err_obj->backtrace))
	  trace = err_obj->backtrace();
	else if (zero_type (trace = err_obj->error_backtrace))
	  // For compatibility with error objects trying to behave
	  // like arrays.
	  trace = err_obj[1];
	if (!trace)
	  return ret + "<No backtrace>\n";
	else if (!arrayp (trace))
	  return sprintf ("%s<Backtrace in %O is %t, expected array>\n",
			  ret, err_obj, trace);

      })
      return sprintf ("<Failed to index backtrace object %O: %s>\n",
		      err_obj, trim_all_whites (describe_error (err)));
  }

  else if (arrayp(trace)) {
    if (sizeof([array]trace)==2 && stringp(ret = ([array]trace)[0])) {
      trace = ([array] trace)[1];
      if(!trace)
	return ret + "<No backtrace>\n";
      else if (!arrayp (trace))
	return sprintf ("%s<Backtrace in error array is %t, expected array>\n",
			ret, trace);
    }
    else
      ret = "";
  }

  else {
#if constant(_gdb_breakpoint)
    _gdb_breakpoint();
#endif
    return sprintf ("<Invalid backtrace/error container: %O>\n"
		    "%s\n", trace, describe_backtrace(backtrace()));
  }

  {
    Describer desc = Describer();
    array trace = [array]trace;

    int end = 0;
    if( (sizeof(trace)>1) &&
	arrayp(trace[0]) &&
	(sizeof([array]trace[0]) > 2) &&
	(([array]trace[0])[2] == _main))
      end = 1;

    if( end==1 && (sizeof(trace)>2) &&
	arrayp(trace[1]) && (sizeof([array]trace[1])>2) &&
	(([array]trace[1])[2] == main_resolv) &&
	arrayp(trace[-1]) && (sizeof([array]trace[-1])>2) &&
	(([array]trace[-1]))[2] == compile_string )
      end = sizeof(trace);

    mapping(string:int) prev_pos = ([]);
    array(string) frames = ({});
    int loop_start = 0, loop_next, loops;

    for(e = sizeof(trace)-1; e>=end; e--)
    {
      mixed tmp;
      string row;
      if (array err=[array]catch {
	tmp = trace[e];
	if(stringp(tmp))
	{
	  row=[string]tmp;
	}
	else if(arrayp(tmp))
	{
	  if(sprintf("%t",tmp)=="object") {
	    // tmp is backtrace_frame
	    desc->identify_parts( tmp->args );
	  }
	  else
	    desc->identify_parts( tmp );
	  array tmp = [array]tmp;
	  string pos;
	  if(sizeof(tmp)>=2 && stringp(tmp[0])) {
	    if (intp(tmp[1])) {
	      pos=trim_file_name([string]tmp[0])+":"+(string)tmp[1];
	    } else {
	      pos = sprintf("%s:Bad line %t",
			    trim_file_name([string]tmp[0]), tmp[1]);
	    }
	  }else{
	    string desc="Unknown program";
	    if(sizeof(tmp)>=3 && functionp(tmp[2]))
	    {
	      catch 
              {
		if(mixed tmp=function_object([function(mixed...:
						       void|mixed)]tmp[2]))
		  if(tmp=object_program(tmp))
		    if(tmp=describe_program([program]tmp))
		      desc=[string]tmp;
	      };
	    }
	    pos=desc;
	  }

	  string data;

	  if(sizeof(tmp)>=3)
	  {
	    if(functionp(tmp[2])) {
	      data = describe_function ([function]tmp[2]);
	    }
	    else if (stringp(tmp[2])) {
	      data = [string]tmp[2];
	    } else
	      data ="unknown function";

	    data+="("+
	      desc->describe_comma_list(tmp[3..], backtrace_len)+
	    ")";

	    if(sizeof(pos)+sizeof(data) < linewidth-4)
	    {
	      row=sprintf("%s: %s",pos,data);
	    }else{
	      row=sprintf("%s:\n%s",pos,sprintf("    %*-/s",linewidth-6,data));
	    }
	  } else {
	    row = pos;
	  }
	}
	else
	{
	  if (tmp) {
	    if (catch (row = sprintf("%O", tmp)))
	      row = describe_program(object_program(tmp)) + " with broken _sprintf()";
	  } else {
	    row = "Destructed object";
	  }
	}
      }) {
  	row = sprintf("Error indexing backtrace line %d: %s (%O)!", e, err[0], err[1]);
      }

      int dup_frame;
      if (!zero_type(dup_frame = prev_pos[row])) {
	dup_frame -= sizeof(frames);
	if (!loop_start) {
	  loop_start = dup_frame;
	  loop_next = dup_frame + 1;
	  loops = 0;
	  continue;
	} else {
	  int new_loop = 0;
	  if (!loop_next) loop_next = loop_start, new_loop = 1;
	  if (dup_frame == loop_next++) {
	    loops += new_loop;
	    continue;
	  }
	}
      }
      prev_pos[row] = sizeof(frames);

      if (loop_start) {
	array(string) tail;
	if (!loop_next) tail = ({}), loops++;
	else tail = frames[loop_start + sizeof(frames) ..
			  loop_next - 1 + sizeof(frames)];
	if (loops)
	  frames += ({sprintf ("... last %d frames above repeated %d times ...\n",
			       -loop_start, loops)});
	frames += tail;
	prev_pos = ([]);
	loop_start = 0;
      }

      frames += ({row + "\n"});
    }

    if (loop_start) {
      // Want tail to contain a full loop rather than being empty; it
      // looks odd when the repeat message ends the backtrace.
      array(string) tail = frames[loop_start + sizeof(frames) ..
				  loop_next - 1 + sizeof(frames)];
      if (loops)
	frames += ({sprintf("... last %d frames above repeated %d times ...\n",
			     -loop_start, loops)});
      frames += tail;
    }

    ret += frames * "";
  }

  return ret;
}

//! @appears describe_error
//!
//! Return the error message from an error object or array (typically
//! caught by a @[catch]). The type of the error is checked, hence
//! @[err] is declared as @expr{mixed@} and not @expr{object|array@}.
//!
//! If an error message couldn't be obtained, a fallback message
//! describing the failure is returned. No errors due to incorrectness
//! in @[err] are thrown.
//!
//! @seealso
//! @[describe_backtrace()], @[get_backtrace]
//!
string describe_error (mixed /* object|array */ err)
{
  mixed msg;

  // Note: Partial code duplication in describe_backtrace and get_backtrace.

  if (objectp(err) && ([object]err)->is_generic_error) {
    object err_obj = [object] err;
    if (mixed err = catch {

	if (functionp (err_obj->message))
	  msg = err_obj->message();
	else if (zero_type (msg = err_obj->error_message))
	  // For compatibility with error objects trying to behave
	  // like arrays.
	  msg = err_obj[0];

	if (stringp (msg))
	  return msg;
	else if (!msg)
	  return "<No error message>\n";
	else
	  return sprintf ("<Message in %O is %t, expected string>\n",
			  err_obj, msg);

      })
      return sprintf ("<Failed to index error object %O: %s>\n",
		      err_obj, trim_all_whites (describe_error (err)));
  }

  else if (arrayp(err) && sizeof([array]err)==2 &&
	   (!(msg = ([array]err)[0]) || stringp (msg)))
    return [string] msg || "<No error message>\n";

  else
    return sprintf ("<Invalid error container: %O>\n", err);
}

//! @appears get_backtrace
//!
//! Return the backtrace array from an error object or array
//! (typically caught by a @[catch]), or zero if there is none. Errors
//! are thrown on if there are problems retrieving the backtrace.
//!
//! @seealso
//! @[describe_backtrace()], @[describe_error()]
//!
array get_backtrace (object|array err)
{
  array bt;

  // Note: Partial code duplication in describe_backtrace and describe_error.

  if (objectp(err) && ([object]err)->is_generic_error) {
    object err_obj = [object] err;

    if (functionp (err_obj->backtrace))
      bt = err_obj->backtrace();
    else if (zero_type (bt = err_obj->error_backtrace))
      // For compatibility with error objects trying to behave like
      // arrays.
      bt = err_obj[1];

    if (bt && !arrayp (bt))
      error ("Backtrace in %O is %t, expected array.\n", err_obj, bt);
  }

  else if (arrayp(err) && sizeof([array]err)==2 &&
	   (!(bt = ([array]err)[1]) || arrayp (bt)))
    {}

  else if (err)
    error ("Invalid error container: %O\n", err);

  return bt;
}


#ifdef ENCODE_DEBUG
#  define ENC_MSG(X...) do werror (X); while (0)
#  define ENC_RETURN(val) do {						\
  mixed _v__ = (val);							\
  werror ("  returned %s\n",						\
	  zero_type (_v__) ? "UNDEFINED" :				\
	  sprintf ("%O", _v__));					\
  return _v__;								\
} while (0)
#else
#  define ENC_MSG(X...) do {} while (0)
#  define ENC_RETURN(val) do return (val); while (0)
#endif

#ifdef DECODE_DEBUG
#  define DEC_MSG(X...) do werror (X); while (0)
#  define DEC_RETURN(val) do {						\
  mixed _v__ = (val);							\
  werror ("  returned %s\n",						\
	  zero_type (_v__) ? "UNDEFINED" :				\
	  sprintf ("%O", _v__));					\
  return _v__;								\
} while (0)
#else
#  define DEC_MSG(X...) do {} while (0)
#  define DEC_RETURN(val) do return (val); while (0)
#endif

class Encoder
//! @appears Pike.Encoder
//!
//! Codec for use with @[encode_value]. It understands all the
//! standard references to builtin functions, pike modules, and the
//! main program script.
//!
//! The format of the produced identifiers are documented here to
//! allow extension of this class:
//!
//! The produced names are either strings or arrays. The string
//! variant specifies the thing to look up according to the first
//! character:
//!
//! 'c'   Look up in all_constants().
//! 's'   Look up in _static_modules.
//! 'r'   Look up with resolv().
//! 'p'   Look up in programs.
//! 'o'   Look up in programs, then look up the result in objects.
//! 'f'   Look up in fc.
//!
//! In the array format, the first element is a string as above and
//! the rest specify a series of things to do with the result:
//!
//! A string   Look up this string in the result.
//! 'm'        Get module object in dirnode.
//! 'p'        Do object_program(result).
//!
//! All lowercase letters and the symbols ':', '/' and '.' are
//! reserved for internal use in both cases where characters are used
//! above.
{
  mixed encoded;

  protected mapping(mixed:string) rev_constants = ([]);
  protected mapping(mixed:string) rev_static_modules = ([]);

  protected array find_index (object|program parent, mixed child,
			      array(object) module_object,
			      int|void try)
  {
    array id;

  find_id: {
      array inds = indices (parent), vals = values (parent);
      int i = search (vals, child);
      if (i >= 0 && parent[inds[i]] == child) {
	id = ({inds[i]});
	ENC_MSG ("  found as parent value with index %O\n", id[0]);
      }

      else {
	// Try again with the programs of the objects in parent, since
	// it's common that only objects and not their programs are
	// accessible in modules.
	foreach (vals; i; mixed val)
	  if (objectp (val) && child == object_program (val) &&
	      val == parent[inds[i]]) {
	    if (module_object) {
	      module_object[0] = val;
	      id = ({inds[i]});
	    }
	    else
	      id = ({inds[i], 'p'});
	    ENC_MSG ("  found as program of parent value object %O with index %O\n",
		     val, id[0]);
	    break find_id;
	  }

	if (try) {
	  ENC_MSG("Cannot find %O in %O.\n", child, parent);
	  return UNDEFINED;
	}
	error ("Cannot find %O in %O.\n", child, parent);
      }
    }

    if (!stringp (id[0])) {
      if (try) {
	ENC_MSG("Got nonstring index %O for %O in %O.\n", id[0], child, parent);
	return UNDEFINED;
      }
      error ("Got nonstring index %O for %O in %O.\n", id[0], child, parent);
    }

    return id;
  }

  protected string|array compare_resolved (string name, mixed what,
					   mixed resolved,
					   array(object) module_object)
  {
    array append;

  compare: {
      if (resolved == what) {
	ENC_MSG ("  compare_resolved: %O is %O\n", what, resolved);
	/* No need for anything advanced. resolv() does the job. */
	return "r" + name;
      }

      if (objectp (resolved)) {
	if (object_program (resolved) == what) {
	  ENC_MSG ("  compare_resolved: %O is program of %O\n", what, resolved);
	  append = ({'p'});
	  break compare;
	}

	if (resolved->is_resolv_dirnode)
	  if (resolved->module == what) {
	    ENC_MSG ("  compare_resolved: %O is dirnode module of %O\n", what, resolved);
	    append = ({'m'});
	    resolved = resolved->module;
	    break compare;
	  }
	  else if (object_program (resolved->module) == what) {
	    ENC_MSG ("  compare_resolved: %O is program of dirnode module of %O\n",
		     what, resolved);
	    append = ({'m', 'p'});
	    break compare;
	  }
	  else
	    ENC_MSG ("  compare_resolved: %O is different from dirnode module %O\n",
		     what, resolved->module);

#if 0
	// This is only safe if the joinnode modules don't conflict,
	// and we don't know that.
	if (resolved->is_resolv_joinnode) {
	  ENC_MSG ("  compare_resolved: searching for %O in joinnode %O\n",
		   what, resolved);
	  foreach (resolved->joined_modules, mixed part)
	    if (string|array name = compare_resolved (name, what, part,
						      module_object)) {
	      if (module_object) module_object[0] = resolved;
	      return name;
	    }
	}
#endif
      }

      ENC_MSG ("  compare_resolved: %O is different from %O\n", what, resolved);
      return 0;
    }

    name = "r" + name;
    string|array res = name;

    if (append)
      if (module_object) {
	// The caller is going to do subindexing. In both the 'p' and
	// 'm' cases it's better to do that from the original
	// object/dirnode, so just drop the suffixes.
	module_object[0] = resolved;
	return res;
      }
      else
	return (arrayp (res) ? res : ({res})) + append;
    else
      return res;
  }

  string|array nameof (mixed what, void|array(object) module_object)
  //! When @[module_object] is set and the name would end with an
  //! @expr{object_program@} step (i.e. @expr{'p'@}), then drop that
  //! step so that the name corresponds to the object instead.
  //! @expr{@[module_object][0]@} will receive the found object.
  {
    ENC_MSG ("nameof (%t %O)\n", what, what);

    if (what == encoded) {
      ENC_MSG ("  got the thing to encode - encoding recursively\n");
      return UNDEFINED;
    }

    if (string id = rev_constants[what]) ENC_RETURN (id);
    if (string id = rev_static_modules[what]) ENC_RETURN (id);

    if (objectp (what)) {

      if (what->is_resolv_dirnode) {
	ENC_MSG ("  is a dirnode\n");
	string name = program_path_to_name (what->dirname);
	if (string|array ref = compare_resolved (name, what, resolv (name),
						 module_object))
	  ENC_RETURN (ref);
      }

      else if (what->is_resolv_joinnode) {
	ENC_MSG ("  is a joinnode\n");
	object modules = Builtin.array_iterator (what->joined_modules);
	object|mapping value;
      check_dirnode:
	if (modules && objectp (value = modules->value()) &&
	    value->is_resolv_dirnode) {
	  string name = program_path_to_name (value->dirname);
	  modules += 1;
	  foreach (modules;; value)
	    if (!objectp (value) || !value->is_resolv_dirnode ||
		program_path_to_name (value->dirname) != name)
	      break check_dirnode;
	  ENC_MSG ("  joinnode has consistent name %O\n", name);
	  if (string|array ref = compare_resolved (name, what, resolv (name),
						   module_object))
	    ENC_RETURN (ref);
	}
      }

      program prog;
      if ((prog = objects_reverse_lookup (what)))
	ENC_MSG ("  found program in objects: %O\n", prog);
#if 0
      else if ((prog = object_program (what)))
	ENC_MSG ("  got program of object: %O\n", prog);
#endif

      if (prog) {
	if (prog == encoded) ENC_RETURN ("o");
	if (string path = programs_reverse_lookup (prog)) {
	  ENC_MSG ("  found path in programs: %O\n", path);
	  string name = program_path_to_name (path);
	  ENC_MSG ("  program name: %O\n", name);
	  if (string|array ref = compare_resolved (name,
						   what->_module_value || what,
						   resolv (name), module_object))
	    ENC_RETURN (ref);
	  else {
	    ENC_MSG ("  Warning: Failed to resolve; encoding path\n");
#ifdef PIKE_MODULE_RELOC
	    ENC_RETURN ("o" + unrelocate_module (path));
#else
	    ENC_RETURN ("o" + path);
#endif
	  }
	}
      }

      if (string path = fc_reverse_lookup (what)) {
	ENC_MSG ("  found path in fc: %O\n", path);
	string name = program_path_to_name (path);
	if (string|array ref = compare_resolved (name, what, resolv (name),
						 module_object))
	  ENC_RETURN (ref);
	else {
	    ENC_MSG ("  Warning: Failed to resolve; encoding path\n");
#ifdef PIKE_MODULE_RELOC
	  ENC_RETURN ("f" + unrelocate_module (path));
#else
	  ENC_RETURN ("f" + path);
#endif
	}
      }

      if (what->_encode) {
	ENC_MSG ("  object got _encode function - encoding recursively\n");
	return UNDEFINED;
      }

      if (function|program prog = object_program (what)) {
	ENC_MSG ("  got program of object: %O\n", prog);
	object|program parent;
	if (!(parent = function_object (prog) || function_program (prog))) {
	  // Check if prog is in a module directory.
	  if (string path = programs_reverse_lookup (prog)) {
	    path = combine_path(path, "..");
	    ENC_MSG ("  found parent path in programs: %O\n", path);
	    parent = fc[path];
	  }
	}
	if (parent) {
	  ENC_MSG ("  got parent of program: %O\n", parent);
	  // We're going to subindex the parent so we ask for the
	  // module object and not the program. That since we'll
	  // always be able to do a better job if we base the indexing
	  // on objects.
	  array parent_object = ({0});
	  string|array parent_name = nameof (parent, parent_object);
	  if (!parent_name) {
	    ENC_MSG ("  inside the thing to encode - encoding recursively\n");
	    return UNDEFINED;
	  }
	  else {
	    ENC_MSG("  parent has name: %O\n", parent_name);
	    if (objectp (parent_object[0])) parent = parent_object[0];
	    array id = find_index (parent, what, module_object);
	    if ((equal(id, ({"_module_value"}))) ||
		(equal(id, ({ "__default" })) && has_suffix(parent_name, "::")))
	      ENC_RETURN (parent_name);
	    else
	      ENC_RETURN ((arrayp (parent_name) ? parent_name : ({parent_name})) + id);
	  }
	}
      }

      error ("Failed to find name of unencodable object %O.\n", what);
    }

    if (programp (what) || functionp (what)) {
      if (string path = programs_reverse_lookup (what)) {
	ENC_MSG ("  found path in programs: %O\n", path);
	string name = program_path_to_name (path);
	if (string|array ref = compare_resolved (name, what, resolv (name),
						 module_object))
	  ENC_RETURN (ref);
	else {
	    ENC_MSG ("  Warning: Failed to resolve; encoding path\n");
#ifdef PIKE_MODULE_RELOC
	  ENC_RETURN ("p" + unrelocate_module (path));
#else
	  ENC_RETURN ("p" + path);
#endif
	}
      }

      if (object|program parent = function_object (what) || function_program (what)) {
	ENC_MSG ("  got parent: %O\n", parent);
	if (!objectp (parent)) {
	  object parent_obj = objects[parent];
	  if (objectp (parent_obj)) {
	    ENC_MSG ("  found object for parent program in objects: %O\n", parent_obj);
	    parent = parent_obj;
	  }
	}

	array parent_object = ({0});
	string|array parent_name = nameof (parent, parent_object);
	if (!parent_name) {
	  ENC_MSG ("  inside the thing to encode - encoding recursively\n");
	  return UNDEFINED;
	}

	else {
	  ENC_MSG("  parent has name: %O\n", parent_name);
	  if (objectp (parent_object[0])) parent = parent_object[0];
	  if (parent["_module_value"] == what &&
	      objects_reverse_lookup (parent)) {
	    ENC_MSG ("  found as _module_value of parent module\n");
	    ENC_RETURN (parent_name);
	  }
	  else {
	    string|array id = function_name ([program]what);
	    if (stringp (id) && parent[id] == what) {
	      ENC_MSG ("  found function name in parent: %O\n", id);
	      id = ({id});
	    }
	    else {
	      if (stringp(parent_name) &&
		  has_suffix(parent_name, "::__default") &&
		  parent->all_constants) {
		if (id = find_index(parent->all_constants(), what,
				    module_object, 1)) {
		  ENC_MSG("  found in all_constants() for %O: %O\n",
			  parent, id);
		  ENC_RETURN(({parent_name[..sizeof(parent_name)-
					   (1+sizeof("__default"))] + id[0]}) +
			     id[1..]);
		}
	      }
	      id = find_index (parent, what, module_object);
	    }
	    if (equal (id, ({"_module_value"})))
	      ENC_RETURN (parent_name);
	    else
	      ENC_RETURN ((arrayp (parent_name) ? parent_name : ({parent_name})) + id);
	  }
	}
      }

      error ("Failed to find name of %t %O.\n", what, what);
    }

    // FIXME: Should have a reverse mapping of constants in modules;
    // it can potentially be large mappings and stuff that we encode
    // here. They can go stale too.

    ENC_MSG ("  encoding recursively\n");
    return ([])[0];
  }

  mixed encode_object(object x)
  {
    DEC_MSG ("encode_object (%O)\n", x);
    if(!x->_encode) {
      error ("Cannot encode object %O without _encode function.\n", x);
      // return ({});
    }
    DEC_RETURN (([function]x->_encode)());
  }

  protected void create (void|mixed encoded)
  //! Creates an encoder instance. If @[encoded] is specified, it's
  //! encoded instead of being reverse resolved to a name. That's
  //! necessary to encode programs.
  {
    this_program::encoded = encoded;

    foreach (all_constants(); string var; mixed val)
      rev_constants[val] = "c" + var;

    rev_static_modules =
      mkmapping (values (_static_modules),
		 map (indices (_static_modules),
		      lambda (string name) {return "s" + name;}));

#if 0
    // This looks flawed; when the decoder looks it up, it'll get the
    // module and not its program. /mast
    foreach (rev_static_modules; mixed module; string name) {
      if (objectp(module)) {
	program p = object_program(module);
	if (!rev_static_modules[p]) {
	  // Some people inherit modules...
	  rev_static_modules[p] = "s" + name;
	}
      }
    }
#endif
  }
}

class Decoder (void|string fname, void|int mkobj, void|object handler)
//! @appears Pike.Decoder
//!
//! Codec for use with @[decode_value]. This is the decoder
//! corresponding to @[Encoder]. See that one for more details.
{
  protected int unregistered = 1;

  object __register_new_program(program p)
  {
    DEC_MSG ("__register_new_program (%O)\n", p);
    if(unregistered && fname)
    {
      unregistered = 0;
      resolv_debug("register %s\n", fname);
      programs[fname]=p;
      if (mkobj)
	DEC_RETURN (objectp (objects[p]) ? objects[p] : (objects[p]=__null_program()));
    }
    DEC_RETURN (0);
  }

  protected mixed thingof (string|array what)
  {
    mixed res;
    array sublist;
    if (arrayp (what)) sublist = [array]what, what = [array|string]sublist[0];

    switch (what[0]) {
      case 'c':
	if (zero_type (res = all_constants()[what[1..]]))
	  error ("Cannot find global constant %O.\n", what[1..]);
	break;
      case 's':
	if (zero_type (res = _static_modules[what[1..]]))
	  error ("Cannot find %O in _static_modules.\n", what[1..]);
	break;
      case 'r':
	if (zero_type (res = resolv ([string]what[1..], fname, handler)))
	  error ("Cannot resolve %O.\n", what[1..]);
	break;
      case 'p':
	if (!(res = low_cast_to_program ([string]what[1..], fname, handler)))
	  error ("Cannot find program for %O.\n", what[1..]);
	break;
      case 'o':
	if (!objectp(res = low_cast_to_object([string]what[1..], fname, handler)))
	  error ("Cannot find object for %O.\n", what[1..]);
	break;
      case 'f':
	if (!objectp (res = findmodule ([string]what[1..], handler)))
	  error ("Cannot find module for %O.\n", what[1..]);
	break;
    }

    DEC_MSG ("  got %O\n", res);

    if (sublist) {
      mixed subres = res;
      for (int i = 1; i < sizeof (sublist); i++) {
	mixed op = sublist[i];
	if (stringp (op)) {
	  if (!programp (subres) && !objectp (subres) && !mappingp (subres))
	    error ("Cannot subindex %O%{[%O]%} since it's a %t.\n",
		   res, sublist[1..i-1], subres);
	  if (zero_type (subres = ([mapping]subres)[op]))
	    error ("Cannot find %O in %O%{[%O]%}.\n",
		   op, res, sublist[1..i-1]);
	  DEC_MSG ("  indexed with %O: %O\n", op, subres);
	}
	else switch (op) {
	  case 'm':
	    if (objectp (subres) && ([object]subres)->is_resolv_joinnode) {
	      dirnode found;
	      foreach (([object(joinnode)]subres)->joined_modules,
		       object|mapping part)
		if (objectp (part) && part->is_resolv_dirnode && part->module) {
		  if (found)
		    error ("There are ambiguous module objects in %O.\n",
			   subres);
		  else
		    found = [object(dirnode)]part;
		}
	      if (found) subres = found;
	    }

	    if (objectp (subres) && ([object]subres)->is_resolv_dirnode) {
	      if (([object]subres)->module) {
		subres = ([object]subres)->module;
		DEC_MSG ("  got dirnode module %O\n", subres);
	      }
	      else
		error ("Cannot find module object in dirnode %O.\n", subres);
	    }
	    else
	      error ("Cannot get module object in thing that isn't "
		     "a dirnode or unambiguous joinnode: %O\n", subres);
	    break;

	  case 'p':
	    subres = object_program (subres);
	    DEC_MSG ("  got object_program %O\n", subres);
	    break;

	  default:
	    error ("Unknown sublist operation %O in %O\n", op, what);
	}
      }
      res = subres;
    }

    return res;
  }

  object objectof (string|array what)
  {
    DEC_MSG ("objectof (%O)\n", what);
    if (!what) {
      // This is necessary for compatibility with 7.2 encoded values:
      // If an object was fed to encode_value there and there was no
      // codec then a zero would be encoded silently since the failed
      // call to nameof was ignored. decode_value would likewise
      // silently ignore the failed call objectof(0) and a zero would
      // be decoded. Now we supply a fairly capable codec which is
      // used by default and we therefore get these objectof(0) calls
      // here. So if we throw an error we can't decode values which
      // 7.2 would encode and decode without a codec (albeit partly
      // incorrectly). So just print a sulky warning and continue.. :P
      DEC_MSG ("Warning: Decoded broken object identifier to zero.\n");
      DEC_RETURN (0);
    }
    DEC_RETURN ([object] thingof (what));
  }

  function functionof (string|array what)
  {
    DEC_MSG ("functionof (%O)\n", what);
    DEC_RETURN ([function] thingof (what));
  }

  program programof (string|array what)
  {
    DEC_MSG ("programof (%O)\n", what);
    DEC_RETURN ([program] thingof (what));
  }

  //! Restore the state of an encoded object.
  //!
  //! @param o
  //!   Object to modify.
  //!
  //! @param data
  //!   State information from @[Encoder()->encode_object()].
  //!
  //! The default implementation calls @expr{o->_decode(data)@}
  //! if the object has an @expr{_decode()@}, otherwise if
  //! @[data] is an array, returns it to indicate that @[lfun::create()]
  //! should be called.
  //!
  //! @note
  //!   This function is called @b{before@} @[lfun::create()]
  //!   in the object has been called, but after @[lfun::__INIT()]
  //!   has been called.
  //!
  //! @returns
  //!   Returns an array to indicate to the caller that
  //!   @[lfun::create()] should be called with the elements
  //!   of the array as arguments.
  //!
  //!   Returns @expr{0@} (zero) to inhibit calling of @[lfun::create()].
  //!
  //! @seealso
  //!   @[Encoder()->encode_object()]
  array(mixed) decode_object(object o, mixed data)
  {
    DEC_MSG ("decode_object (object(%O), %O)\n", object_program (o), data);
    if(!o->_decode) {
      if (!arrayp(data)) {
	error ("Cannot decode object(%O) without _decode function.\n",
	       object_program (o));
      }
      // Try calling lfun::create().
      return data;
    }
    ([function(mixed:void)]o->_decode)(data);
    return 0;
  }
}

// Note: This mapping is not for caching but for coping with recursion
// problems by returning the same codec for the same file. As a cache
// it's really pointless.
protected mapping(string:Decoder) codecs = set_weak_flag (([]), 1);

Decoder get_codec(string|void fname, int|void mkobj, void|object handler)
{
  if (handler)
    // Decoders are currently not reused in this case since it's
    // tricky to set up a weak multilevel mapping for lookup. This is
    // seldom a problem since explicit handlers are fairly rare. If it
    // is then the handler can always override this function.
    return Decoder (fname, mkobj, handler);
  string key = fname + "\0" + mkobj;
  if (codecs[key]) return codecs[key];
  return codecs[key] = Decoder(fname, mkobj);
}

class Codec
//! @appears Pike.Codec
//!
//! @[Encoder] and @[Decoder] rolled into one. This is for mainly
//! compatibility; there's typically no use combining encoding and
//! decoding into the same object.
{
  inherit Encoder;
  inherit Decoder;

  protected void create (void|mixed encoded)
  //! The optional argument is the thing to encode; it's passed on to
  //! @[Encoder].
  {
    Encoder::create (encoded);
  }
}

// The master acts as the default codec.
inherit Codec;


//! Contains version information about a Pike version.
class Version
{

  //! The major and minor parts of the version.
  int major;
  int minor;

  //! @decl void create(int major, int minor)
  //! Set the version in the object.
  protected void create(int maj, int min)
  {
    if(maj==-1) maj = __REAL_MAJOR__;
    if(min==-1) min = __REAL_MINOR__;
    major = maj;
    minor = min;
  }

#define CMP(X)  ((major - ([object]X)->major) || (minor - ([object]X)->minor))

  //! Methods define so that version objects
  //! can be compared and ordered.
  int `<(mixed v) { return objectp(v) && CMP(v) < 0; }
  int `>(mixed v) { return objectp(v) && CMP(v) > 0; }
  int `==(mixed v) { return objectp(v) && CMP(v)== 0; }
  int __hash() { return major * 4711 + minor ; }

  string _sprintf(int t) {
    switch(t) {
    case 's': return sprintf("%d.%d",major,minor);
    case 'O': return sprintf("%O(%s)", this_program, this);
    }
  }

  //! The version object can be casted into a string.
  mixed cast(string type)
    {
      switch(type)
      {
	case "string":
	  return sprintf("%d.%d",major,minor);
      }
    }
}

//! Version information about the current Pike version.
Version currentversion = Version(__REAL_MAJOR__, __REAL_MINOR__);

mapping(Version:CompatResolver) compat_handler_cache = ([
  currentversion:this_object(),
]);

CompatResolver get_compilation_handler(int major, int minor)
{
  Version v=Version(major,minor);

  if(v > currentversion)
  {
    /* Do we want to make an error if major.minor > __MAJOR__.__MINOR ?
     *
     * No; it's useful for referring to the next version when writing
     * compat modules.
     */
    return 0;
  }

  CompatResolver ret;

  if(!zero_type(ret=compat_handler_cache[v])) return ret;

  array(string) files;
  array(Version) available=({});

#if "#share_prefix#"[0]!='#'
  if (!(files = master_get_dir("#share_prefix#"))) {
    werror ("Error listing directory %O: %s\n",
	    "#share_prefix#", strerror (errno()));
    files = ({});
  }
  foreach(files, string ver)
    {
      if(sscanf(ver,"%d.%d",int maj, int min))
      {
	Version x=Version(maj, min) ;
	if(x >= v)
	  available|=({ x });
      }
    }
#endif

#if "C:/Program Files/Pike/lib"[0]!='#'
  if (!(files = master_get_dir("C:/Program Files/Pike/lib"))) {
    werror ("Error listing directory %O: %s\n",
	    "C:/Program Files/Pike/lib", strerror (errno()));
    files = ({});
  }
  foreach(files, string ver)
    {
      if(sscanf(ver,"%d.%d",int maj, int min))
      {
	Version x=Version(maj, min) ;
	if(x >= v)
	  available|=({ x });
      }
    }
#endif

  sort(available);

#ifndef RESOLVER_HACK
  /* We need to define RESOLVER_HACK when we add
   * version-specific stuff in the CompatResolver.
   * As long as all the compatibility is done in the
   * module directories, RESOLVER_HACK can be undefined
   */

  /* No compat needed */
  if(!sizeof(available))
  {
    compat_handler_cache[v]=0;
    return 0;
  }

  /* Same as available[0] */
  if(ret=compat_handler_cache[available[0]])
    return compat_handler_cache[v]=ret;
#endif

  // The root resolver is this object.
  ret = this;

  foreach(reverse(available), Version tmp)
    {
      CompatResolver compat_handler = compat_handler_cache[tmp];
      if (!compat_handler) {
	// Create a new compat handler, that
	// falls back to the successor version.
	if (tmp <= Version(0, 6)) {
	  compat_handler = Pike06Resolver(tmp, ret);
	} else {
	  compat_handler = CompatResolver(tmp, ret);
	}

	string base;
#if "C:/Program Files/Pike/lib"[0]!='#'
	base=combine_path("C:/Program Files/Pike/lib",sprintf("%s",tmp));
	compat_handler->add_module_path(combine_path(base,"modules"));
	compat_handler->add_include_path(combine_path(base,"include"));
#endif

#if "#share_prefix#"[0]!='#'
	base=combine_path("#share_prefix#",sprintf("%s",tmp));
	compat_handler->add_module_path(combine_path(base,"modules"));
	compat_handler->add_include_path(combine_path(base,"include"));
#endif

	// Kludge to avoid(?) recursive compilation problems. It was
	// observed with a pike program containing
	//
	// #if constant (__builtin.security)
	// #endif
	//
	// when using -V7.4. There was a cycle between resolving
	// lib/modules/__builtin.pmod and lib/7.4/modules/__default.pmod.
	compat_handler->get_default_module();

#ifndef RESOLVER_HACK
	ret = compat_handler_cache[tmp] = compat_handler;
#endif
      }
    }

  // Note: May duplicate the assignment above.
  compat_handler_cache[v] = ret;

  return ret;
}

string _sprintf(int t)
{
  // NOTE: The ||'O' is for Pike 7.2 compat only.
  switch(t||'O') {
  case 't': return "master";
  case 'O': return "master()";
  }
}

//! Return a master object compatible with the specified version of Pike.
//!
//! This function is used to implement the various compatibility versions
//! of @[master()].
//!
//! @seealso
//!   @[get_compilation_handler()], @[master()]
object get_compat_master(int major, int minor)
{
  if ((major < 7) || ((major == 7) && (minor < 7)))
    return Pike_7_6_master::get_compat_master(major, minor);
  // 7.7 and later.
  return this;
}
