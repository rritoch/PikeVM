/* ed.c
 * The LPC ded tool  (version 2.1 - by Jubal E. Harshaw)
 *
 * This is an lpc interpreted version of the ed() driver function
 *
 * It opens and closes files at a comparable rate to the ed() function,
 * although it will take up more driver time and memory.
 * It is also limited by size because of its file I/O functions which could
 * be improved.  (see read_filearr and write_filearr)
 *
 * On the other hand, it has many added improvements, such as an undo feature
 * (which could easily be converted into an undo stack for multiple undo),
 * better help, and better settings and prompt.  It also has a transparent
 * mode setting, that sends all commands that it doesn't understand through
 * to the player object, so you don't have to do ! escapes all the time.
 * 
 * To use, just clone this object, and then use the 'ded <file>' command
 *
 * If you lose the input_to because of a netdead or another input_to, then
 * use the regrab command.  This will put you back into the editor with
 * whatever is in the text array.
 * You should realize that the security on this is purposefully not strong.
 */

/*
 * This program has been successfully ported to the following drivers:
 * 2.4.5, 3.1.2, 3.1.2 -DR, 3.1.2 -CD and 3.2 (amylaar)
 *
 * This code is copyright 1993, David Ljung
 *                              Spawning Cow! Productions
 *                              310 South Bassett St.
 *                              Madison, WI. 53703
 *                              (608) 257-2697
 *                              ljung@cae.wisc.edu
 *
 * It may be freely redistributed, but it may not be sold in any form.
 */
 
/**
 * This code was ported to PikeVM
 *    
 * Copyright Ralph Ritoch 2013 - ALL RIGHTS RESERVED 
 */  
  
#define TP this_player()

#define RANGE_STR(a,b) ((b<=a)?" "+a:"s "+a+"-"+b)

#define NUM 1
#define TRANS 2
#define PROMPT 3
#define BUILDPROMPT 4

#define MAX_ARRAY 1000

/**
 * Active File
 */
  
string file;

/**
 * Buffer
 */
  
array(string) text;

int line,totlines,dirty;
int from,to;   
string searchstr;

/**
 * Settings
 */
  
array(mixed) settings;

int getline;
array(string) tmptxt;

string action;
mixed old;
int where,towhere;

/**
 * Get Short Description
 */
  
string short() 
{ 
   return "ed"; 
}

/**
 * Check ID
 */
 
int id(string str) 
{ 
    return str==short(); 
}

/**
 * Get Long Description
 */

string long() 
{ 
    write(short()+".\n"); 
}

/**
 * Can Get
 */
 
int get() 
{ 
    return 1; 
}

/**
 * Init (depricated)
 */ 
 
void init() 
{  
  //add_action("lpc_ed","ded");
  //add_action("comm_prompt","regrab");
}

int lpc_ed(string what) 
{

  //if(!what) return !notify_fail("Usage: "+query_verb()+" <file>\n");

  file=what;
  line=0;
  dirty=0;
  settings=({"number transparent prompt",1,1,"$line> ",1});

  text=read_filearr(file);
  
  if(!text) {
    text=({"","$"});
    write("New file: ");
  }
  
  totlines=sizeof(text)-2;
  if(totlines==0) write("New file: "+file+"\n");
  else if(totlines==MAX_ARRAY-2)
    write("Read in: "+file+" (TRUNCATED AT: "+totlines+")\n");
  else write("Read in: "+file+" ("+totlines+" lines)\n");

  comm_prompt();

  return 1;
}

int comm(string str) 
{
  int ret;
  string func,args;

  from=0;   to=0;
  if(sscanf(str,"%d,%d%s",from,to,str)==3 || sscanf(str,"%d%s",from,str)==2) {
    if(!valid_range(str)) return comm_prompt();
  } else if(!valid_line(str)) return comm_prompt();
  if(sscanf(str,"/%s",args)) func="slash";
  else if(sscanf(str,"\\%s",args)) func="backslash";
  else if(!sscanf(str,"%s %s",func,args)) func=str;
  if(function_exists("_"+func,this_object()))
    ret=call_other(this_object(),"_"+func,args,from,to);
  if(ret==-1) return 0;  /* either quit or another input_to */
  /*
  if(!ret)
    if(settings[TRANS]) command(str,TP);
  */    
    else write("Unrecognized or failed command.  ('h' for help)\n");
  comm_prompt();
}

int valid_range(string str) 
{
  if(from>0 && from<=totlines && (!to || (to>=from && to<=totlines))) return 1;
  if(!to) return !write("Bad line: "+from+"\n");
  return !write("Bad  range: "+from+"-"+to+"\n");
}

/* only allow <return> 'z' and 'a' at TOF */
int valid_line(string str) {
  if((line>=0 && line<=totlines) || (line==1 && totlines==0)) return 1;
  write("Bad current line: "+line+" (setting to 1)\n");
  line=1;
  return 0;
}


/* ed commands */

int _(string arg) 
{   /*  just hit return */
  if(totlines==0) {
    line=1;
    write("Blank file\n");
    return 1;
  }
  if(from && to) {
    write_lines(from,to);
    line=to;
    return 1;
  }
  if(from) {
    write_line(from);
    line=from;
    return 1;
  }
  line=(line<totlines)?line+1:totlines;
  write_line(line);
  return 1;
}

int _slash(string arg) 
{
  int i,a,b;
  string dummy;

  if(!arg || arg=="") {
    if(!searchstr) return write("No previous search.\n");
    a=from?from:line+1;
    arg=searchstr;
  } else {
    searchstr=arg;
    a=from?from:line;
  }
  b=to?to:totlines;
  for(i=a;i<b;i++)
    if(sscanf(text[i],"%s"+arg+"%s",dummy,dummy)) {
      line=i;
      return write_line(i);
    }
  if(!to)
    for(i=0;i<a-1;i++)
      if(sscanf(text[i],"%s"+arg+"%s",dummy,dummy)) {
        line=i;
        write("(Wrapped)\n");
        return write_line(i);
      }
  write("Not found.\n");
  return 1;
}

/* doesn't work yet ..  not backwards :) */
int _backslash(string arg) 
{
  int i,a,b;
  string dummy;

  if(!arg || arg=="") {
    if(!searchstr) return write("No previous search.\n");
    a=from?from:line-1;
    arg=searchstr;
  } else {
    searchstr=arg;
    a=from?from:line;
  }
  b=to?to:totlines;
  for(i=a;i<b;i++)
    if(sscanf(text[i],"%s"+arg+"%s",dummy,dummy)) {
      line=i;
      return write_line(i);
    }
  if(!to)
    for(i=0;i<a-1;i++)
      if(sscanf(text[i],"%s"+arg+"%s",dummy,dummy)) {
        line=i;
        write("(Wrapped)\n");
        return write_line(i);
      }
  write("Not found.\n");
  return 1;
}

int _a(string arg) 
{
  if(to) return write("Cannot append in a range (line"+RANGE_STR(from,to)+"\n");
  from=from?from+1:line+1;
  if(from>totlines) from=totlines;
  return _i(arg);
}

int _c(string arg) {
  if(!from) from=line?line:1;
  if(!totlines)
    return write("Can't change lines in an empty file (use insert)\n");
  else line=from;
  if(!to) to=from;     /* don't insert if !to */
  tmptxt=({});
  getline=from;
  action="replace";
  get_text();
  return -1;  /* don't quit, but don't do a comm_prompt() */
}

int _d(string|void arg) {
  action="delete";
  if(!from) from=line?line:1;
  if(!totlines)
    return write("Can't delete lines in an empty file (use insert)\n");
  else line=from;
  where=from;
  if(!to) to=from;
  towhere=to;  /* if undo, just insert it back */
  towhere=to;
  old=text[from..to];
  text=text[0..from-1]+text[to+1..totlines];
  totlines-=towhere-where+1;
  write("Deleted line"+RANGE_STR(from,to)+"\n");
  dirty++;
  return 1;
}

#define UNDOABLE write("*This command can be undone.\n")
int _help(string arg) { 
    return _h(arg); 
}


int _h(string arg) 
{
  switch(arg) {
  case 0:
    write("   Help for 'ded' by Jubal\n"
         +"-----------------------------------------------------\n"
         +"a	append line(s)\n"
         +"c	change line(s)\n"
         +"d	delete line(s)\n"
         +"h	this command.  h <char> for  specific help\n"
         +"i	insert line(s)\n"
         +"n	toggle number setting on/off\n"
         +"q	quit\n"
         +"Q	quit without saving\n"
         +"set	set or check settings\n"
         +"u	undo\n"
         +"w	write file\n"
         +"wq	write quit\n"
         +"z	cat lines (if no range then next 20 lines)\n"
         +"/	search ('\' for search backward)\n"
         +"	just use return or a range to show lines\n"
         +"To get back to the ed prompt with the file"
         +" you were working on type 'regrab'\n"
         +"(even after a quit!)\n"
       );
    break;
  case "/":
    write("Forward text search.  Can use a range of lines to search in.\n"
         +"Examples:  /bo    search for string \"bo\" from current line.\n"
         +"           /      continue last search.\n"
         +"If you don't use a range to search and it reaches the end of the"
         +" file\nthen the search will wrap around to the beginning of the"
         +" file.\nIf any matches are then made, it will print \"(Wrapped)\"\n"
         +"  Also see:  \\\n");
    break;
  case "\\":
    write("Backwards search.  This is not implemented yet.\n"
         +"  Also see:  /\n");
    break;
  case "a":
    write("Append text after line\n"
         +"Examples:  a      append text after current line\n"
         +"           5a     append after line 5\n"
         +"You can stop entering text by typing '.' or '**' on one line\n"
         +"To cancel the text you have typed, type '~q' on one line\n"
         +"  Also see:  c (change), d (delete), i (insert)\n");
    UNDOABLE;
    break;
  case "c":
    write("Change line(s) of text\n"
         +"Examples:  c      put new text in place of current line\n"
         +"           3c     put in place of line 3\n"
         +"You can stop entering text by typing '.' or '**' on one line\n"
         +"To cancel the text you have typed, type '~q' on one line\n"
         +"The text you enter does not have to be the same"
         +" size as the text you replace\n"
         +"  Also see:  a (append), d (delete), i (insert)\n");
    UNDOABLE;
    break;
  case "d":
    write("Delete line or range of lines\n"
         +"Examples:  d      delete this line\n"
         +"           3,9d   delete lines 3-9\n"
         +"  Also see:  a (append), c (change), i (insert)\n");
    UNDOABLE;
    break;
  case "h":
    write("Show help screen or help on a certain command.\n"
         +"Example:   h d    get help on the d command\n"
         +"Other topics:  range\n");
    break;
  case "i":
    write("Insert text before line\n"
         +"Examples:  i      insert text before current line\n"
         +"           7i     insert before line 7\n"
         +"You can stop entering text by typing '.' or '**' on one line\n"
         +"To cancel the text you have typed, type '~q' on one line\n"
         +"  Also see:  a (append), c (change), d (delete)\n");
    UNDOABLE;
    break;
  case "range":
    write("You can use a range for most commands.\n"
         +"Examples:  5,9z   show lines 5-9\n"
         +"           6d     delete line 6\n");
    break;
  case "set":
    write("set               show settings and other info\n"
         +"set <what>        show setting for what\n"
         +"set <what> <val>  set what to val\n"
         +"Example:   set num on\n"
         +"You can set: "+settings[0]+"\n"
         +"Do 'h <setting>' for more information\n");
    break;
  /* the settings */
  case "number":
    write("Setting: number            Values: 'on' or 'off'\n"
         +"If 'on' then line numbers will be shown before lines of text\n");
    write("Current setting: ");
    _set("number");
    break;
  case "transparent":
    write("Setting: transparent       Values: 'on' or 'off'\n"
         +"When this is 'on', any commands not understood by ded will be\n"
         +"attempted as normal mud commands\n");
    write("Current setting: ");
    _set("transparent");
    break;
  case "prompt":
    write("Setting: prompt            Value: string\n"
         +"Possible replacements in the prompt: $line and $file\n"
         +"Examples:  set prompt $file:$line>\n"
         +"  (You will probably want to type a space at the end"
         +" of the prompt string)\n");
    write("Current setting: ");
    _set("prompt");
    break;
  /* end settings */
  case "n":
    write("toggles the setting for number\n"
         +"A quick way to change 'set number'\n"
         +"  Also see:  set, number\n");
    break;
  case "q":
    write("quit\n"
         +"if you haven't saved, this will stop and warn you.\n");
    break;
  case "Q":
    write("quit without saving\n"
         +"This will quit regardless of whether you have unsaved changes.\n");
    break;
  case "u":
    write("Undo a change to the text\n"
         +"After undoing a change, undo again will redo the change.\n");
    break;
  case "w":
    write("write file\n"
         +"This can take a range and/or a filename to save to\n"
         +"Examples:  w         write this file\n"
         +"           w cow     write this text to file 'cow'\n"
         +"           5,6w cow  write lines 5-6 to 'cow'\n");
    break;
  case "wq":
    write("write file and quit  (see help w and help q)\n");
    break;
  case "z":
    write("Show page\n"
         +"This normally shows the next 20 lines starting at the current line\n"
         +"But can take a line number ('2z') or a range ('4,10z')\n");
    break;
  default:
    write("I don't have any help for the topic: "+arg+"\n");
  }
  return 1;
}

int _i(string arg) 
{
  /* if range then do _c */
  if(to) return _c(arg);
  if(!from) from=line?line:1;
  else line=from;
  tmptxt=({});
  getline=from;
  action="replace";
  get_text();
  return -1;  /* don't quit, but don't do a comm_prompt() */
}

int _n(string arg) 
{
  settings[NUM]=!settings[NUM];
  _set("number");
  return 1;
}

int _q(string arg) 
{
  if(dirty)
    return write("File modified."
     +"  Q: quits without saving, w: writes, wq: writes and quits\n");
  write("Quitting.\n");
  return -1;
}

int _Q(string arg) 
{
  if(dirty) write("Quitting without saving changes.\n");
  else write("Quitting.\n");
  return -1;
}

int _set(string arg) 
{
  string what,to,tmp;
  
  if(arg && sscanf(arg,"%s %s",what,to)!=2) what=arg;

  switch(what) {
  case 0:
    write("  Settings:\n");
    write("-----------------------\n");
    map_array(explode(settings[0]," "),"_set",this_object());
    write("total lines  "+totlines+"\n");
    if(dirty) write("File has been modified ("+dirty+" changes)\n");
    else write("File has not been modified\n");
    break;
  case "n":
  case "num":
  case "number":
    if(to) {
      settings[NUM]=(to=="on");
      _set("number");
    } else write("number "+(settings[NUM]?"on":"off")+"\n");
    break;
  case "trans":
  case "transparent":
    if(to) {
      settings[TRANS]=(to=="on");
      _set("transparent");
    } else write("transparent "+(settings[TRANS]?"on":"off")+"\n");
    break;
  case "prompt":
    if(to) {
      settings[PROMPT]=to;
      settings[BUILDPROMPT]=(sscanf(to,"%s$line%s",tmp,tmp)
                             || sscanf(to,"%s$file%s",tmp,tmp));
      _set("prompt");
    } else {
      write("prompt \""+settings[PROMPT]+"\"\n");
      if(settings[BUILDPROMPT]) write("Prompt must be built (slower).\n");
      else write("Prompt is static (faster).\n");
    }
    break;
  default:
    write("You can't set "+what+"\n");
  }
  return 1;
}

int _u(string arg) {
  int saveline;
  switch(action) {
  case 0:
    write("Nothing to undo\n");
    break;
  case "delete":
    text=text[0..where-1]+old+text[where..totlines];
    totlines+=towhere-where+1;
    write("Undeleted line"+RANGE_STR(where,towhere)+"\n");
    dirty--;
    action="undelete";
    break;
  case "undelete":
    saveline=line;
    from=where;     to=towhere;
    _d();
    write("Re-deleted line"+RANGE_STR(from,to)+"\n");
    line=saveline;
    break;
  case "replace":
    saveline=line;
    tmptxt=old;
    if(sizeof(old))
      write("Replaced line"+RANGE_STR(where,towhere)+" with original line"
            +RANGE_STR(where,(where+sizeof(old)-1))+"\n");
    else write("Uninserted text at line"+RANGE_STR(where,towhere)+"\n");
    from=where;
    to=towhere;
    replace(1);
    action="unreplace";
    dirty-=2;  /* dirty++ in replace */
    line=saveline;
    break;
  case "unreplace":
    saveline=line;
    from=where;
    to=towhere;
    tmptxt=old;
    if(!towhere)
      write("Re-inserted line"+RANGE_STR(from,(from+sizeof(tmptxt)-1))+"\n");
    else write("Re-replaced text at line"+RANGE_STR(from,to)+"\n");
    replace(1);
    action="replace";
    line=saveline;
    break;
  default:
    write("Don't know how to undo: "+action+"\n");
    break;
  }
  return 1;
}

int _w(string arg) 
{
  if(!to) {
    if(!arg) arg=file;
    if(write_filearr(arg,text,1,totlines)) {
      dirty=0;
      write("Saved to: "+arg+"\n");
    }
    return 1;
  }
  if(!arg) return write("Use delete to save sections of a file,"
                       +" or save it to another file.\n");
  if(write_filearr(arg,text,from,to)) 
    write("Saved lines "+from+"-"+to+" to: "+arg+"\n");
  return 1;
}

int _wq(string arg) 
{
  _w(arg);
  return _q(arg);
}

int _z(string arg) 
{
  if(totlines==0) {
    line=1;
    write("Blank file\n");
    return 1;
  }
  if(!from) from=line?line:1;
  if(!to) to=from+20<totlines?from+20:totlines;
  line=to;
  return write_lines(from,to);
}

/* utility functions */
/* read and write_filearr can be moved elsewhere, for hacking tools ;) */
/* text[0] is "" and text[<last line>] is "$" */

mixed read_filearr(string name) 
{
  string tmp;
  mixed txt;
  int i;

  if(!(name=mk_path(name))) return !write("Couldn't read "+name+"\n");
/* use file_size if exists is not an efun */
  if(!exists(name)) return ({ txt }) +({"$"});

  /* this can be done faster later (by allocating chunks at a time) */
  txt= read_bytes(name,0,file_size(name));
  if(txt) {
    txt=({""})+explode(txt,"\n")+({"$"});
    if(sizeof(txt)==2) return 0;
    return txt;
  }
  write("Large file - opening via slow method.\n");

/*as far as I can tell, read_bytes is MUCH faster - but screws up bigger files*/
  txt=({});
  i=1;
  while((tmp=read_file(file,i++)) && i<MAX_ARRAY)
    txt+=extract(tmp,0,-2);
  if(i==2) return 0;
  return txt+({"$"});
}

int write_filearr(string name, mixed txt, mixed a,mixed b) {
  int i;

  if(!(name=mk_path(name))) return !write("Couldn't write to "+name+"\n");
  if(exists(name) && !rm(name))
    return !write("Failed to remove old copy: "+name+"\n");
  /* couldn't get write_bytes to work at all :( */
  for(i=a;i<=b;i++)
    if(!write_file(name,txt[i]+"\n"))
      return !write("ERROR: writing line "+i+" to "+name+"\n");
  return 1;
}

/* this can be altered in many ways -- use valid_write, mk_path, whatever */
/* make sure it returns the prepending "/" */
string mk_path(string name) 
{
    //return TP->mk_path(name);
    return this_shell()->shell_combine_path(this_shell()->get_cwd(),name);
}

int comm_prompt() 
{
  string prompt;

  if(settings[BUILDPROMPT]) {
    prompt=implode(explode(" "+settings[PROMPT]+" ","$file"),file);
    if(line==0) prompt=implode(explode(prompt,"$line"),"TOF");
    else if(line==totlines) prompt=implode(explode(prompt,"$line"),"$");
    else prompt=implode(explode(prompt,"$line"),line+"");

    write(extract(prompt,1,strlen(prompt)-2));
  } else write(settings[PROMPT]);

  input_to("comm");
  return 1;
}

int write_lines(int a,int b) 
{
  int i;

  if(settings[NUM])
    for(i=a;i<=b;i++)
      write(int_str(i,1)+": "+text[i]+"\n");
  else
    for(i=a;i<=b;i++)
      write(text[i]+"\n");
  return 1;
}

int write_line(int a) 
{
    if(settings[NUM]) write(int_str(a,1)+": ");
    write(text[a]+"\n");
    return 1;
}

int size;
/* makes a str with the number justified in it with number of spaces
 * equal to the number of spaces in totlines (supposedly the biggest #)
 * 2nd arg 1 for left justify, 0 for right justify
 * don't use pad for portability
 */
string int_str(string|int a, mixed lt) 
{
  string str;
  int i;

    a = (string)a;
    
  if(!size)   /* hope that this sets size>0 :) */
    size=strlen(""+totlines);
  i=size-strlen(""+a);
  if(i) str="          "[0..i-1];
  else str="";
  if(lt) return str+a;
  else return a+str;
}


void get_text() 
{
  if(settings[NUM]) write(int_str(getline,1)+": ");
  else write("*\b");
  input_to("input_text");
}

void input_text(string str) 
{
  if(str=="." || str=="**" || str=="~q") {
    if(str=="~q")
       tmptxt=0;
    line=getline-1;
    call_other(this_object(),action);
    return;
  }
  tmptxt+=({str });
  getline++;
  get_text();
}

/* replaces lines: from-to with tmptxt.
 * where and towhere are set to the begin and end of the text put in the file
 * (for replaceback).  If no tmptext, then towhere=0;
 * if !to then just insert at from.
 */
int|void replace(int justreturn) 
{
  if(!tmptxt)
    if(justreturn) return;
    else return comm_prompt();

  dirty++;

  if(to) {   /* we are replacing text, not just inserting */
    old=text[from..to];
    text=text[0..from-1]+tmptxt+text[to+1..totlines];
    totlines+=sizeof(tmptxt)-sizeof(old);
  } else {
    old=({});
    text=text[0..from-1]+tmptxt+text[from..totlines];
    totlines+=sizeof(tmptxt);
  }
  where=from;
  towhere=sizeof(tmptxt)?from+sizeof(tmptxt)-1:0;

  if(justreturn) return;
  comm_prompt();
}



int main(int argc, array(string) argv, mixed env)
{
    if (sizeof(argv) > 1) {
        lpc_ed(argv[1..] * " ");
    } else {
        lpc_ed("");
    }
    return -1;
}

