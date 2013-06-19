/* ========================================================================== */
/*                                                                            */
/*   Filename.c                                                               */
/*   (c) 2001 Author                                                          */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */

//#define DEBUG_PTY

inherit "char.pike";
#include <sys/types.h>
#include <stdio.h>
#include <sys/ioctl.h>


#define TN_SE                     240  /*  End of subnegotiation parameters. */
#define TN_NOP                    241  /*  No operation. */
#define TN_DM                     242  /*  The data stream portion of a Synch.
                                        This should always be accompanied
                                        by a TCP Urgent notification. */
#define TN_BRK                    243  /*  NVT character BRK. */
#define TN_IP                     244  /*  The function IP. */
#define TN_AO                     245  /*  The function AO. */
#define TN_AYT                    246  /*  The function AYT. */
#define TN_EC                     247  /*  The function EC. */
#define TN_EL                     248  /*  The function EL. */
#define TN_GA                     249  /*  The GA signal. */
#define TN_SB                     250  /*  Indicates that what follows is
                                        subnegotiation of the indicated
                                        option. */
#define TN_WILL /*(option code)*/ 251  /*  Indicates the desire to begin
                                        performing, or confirmation that
                                        you are now performing, the
                                        indicated option. */
#define TN_WONT /*(option code)*/ 252  /*  Indicates the refusal to perform,
                                        or continue performing, the
                                        indicated option. */
#define TN_DO /*(option code)*/   253  /*  Indicates the request that the
                                        other party perform, or
                                        confirmation that you are expecting
                                        the other party to perform, the
                                        indicated option. */
#define TN_DONT /*(option code)*/ 254  /*  Indicates the demand that the
                                        other party stop performing,
                                        or confirmation that you are no
                                        longer expecting the other party
                                        to perform, the indicated option. */
#define TN_IAC                    255  /*  Data Byte 255. */


private mapping(int:string) tn_lookup = ([
 240 : "<SE>",
 241 : "<NOP>",
 242 : "<DM>", 
 243 : "<BRK>",
 244 : "<IP>", 
 245 : "<AO>", 
 246 : "<AYT>",
 247 : "<EC>", 
 248 : "<EL>", 
 249 : "<GA>", 
 250 : "<SB>", 
 251 : "<WILL>",
 252 : "<WONT>",
 253 : "<DO>",
 254 : "<DONT>",
 255 : "<IAC>"

]);

/*

extern array(mixed) call_stack;
extern int bangptr;
extern int running;

extern mixed grab_cb;
extern string _read_line(int noecho);
extern string _read_char(int noecho);
extern void _write_error_message(mixed err);
extern int _open();

*/

string in_buff;

/* Required Char Device Variables */

protected array(mixed) call_stack = ({});
protected int bangptr = 0;
private int running;
protected mixed grab_cb;

/* Required Char Devices Functions */

protected string _read_line(int noecho) {
 mixed tmp;
 
 tmp = in_buff / "\n";
 while(connected && (sizeof(tmp) < 2)) {
  pty_pull();
  tmp = in_buff / "\n";
 }
 if (sizeof(tmp) > 1) {
  in_buff = tmp[1..] * "\n";
 } else {
  in_buff = "";
 }
 return tmp[0] + "\n";
}

protected string _read_char(int noecho) {
 string tmp;
 while(connected && (!sizeof(in_buff))) {
  pty_pull();
 }
 if (sizeof(in_buff)) {
  tmp = in_buff;
  in_buff = tmp[1..];
  return tmp[0..0];
 }
 return "";
}

protected void _write_error_message(mixed err) {
 write("Pty error: %O\n",err);
}

protected int _open() {
 return 1;
}

/* IOCTL */

 private mixed io_read(object ret, mixed ... args) {
  //ret->value = ({ fob->read(@args) });
#ifdef DEBUG_PTY
  write("*pty*io_write(%O,%O)\n",ret,args);
#endif    
  return 0;
 }
 
 private mixed io_write(object ret, mixed ... args) {
  string msg;
  array(string) lines;
  int idx;
  
#ifdef DEBUG_PTY
  //write("*pty*io_write(%O,%O)\n",ret,args);
#endif  
  msg = sprintf(@args);
  
  lines = msg / "\n";
  
  for (idx = 0; idx < (sizeof(lines) - 1);idx++) {
   if (lines[idx][<0..<0] != "\r") {
    lines[idx] += "\r";
   }
  }
  msg = lines * "\n";
   
  ret->value = ({ fprintf(hand,"%s",msg) });
  return 0;
 }


 public int handle_ioctl(int dev, int cmd, mixed ... args) {
  
   if (cmd == IOC_STRING) {
    string f = args[0];
    array(mixed) c_args = args[1..];
    
    switch(f) {
     case "read":
      io_read(@c_args);
     case "write":
      io_write(@c_args);
     default:
      return -1;
      break;
    }
   }  
  
  return -1;
 }


private mapping(int:int) remote_nvt = ([]);
private mapping(int:int) local_nvt = ([]);

private int hand;


private pike_pointer data;
private int connected;


array(mixed) tn_getchar() {
 string ch;
 
 array(mixed) ret;
 ret = ({});
 fread(data,1,1,hand);
 if ((sizeof(data->value)) && (sizeof(data->value[0]))) {
  ch = data->value[0];
  ret = ({ ch, ch[0] });
 } else {
  connected = 0;
 }
 return ret;
}

void parse_do() {
 array(mixed) in;
 string msg;
 
 in = tn_getchar();
 if (sizeof(in)) {
#ifdef DEBUG_PTY
 write("parse_do(%O)\n",in[1]);
#endif 
  if (zero_type(local_nvt[in[1]])) {
   switch(in[1]) {
    default:
     local_nvt[in[1]] = TN_WONT;
     msg = "   ";
     msg[0] = TN_IAC;
     msg[1] = TN_WONT;
     msg[2] = in[1]; 
     fprintf(hand,"%s",msg);
     break;
   }
  
  } else {
   // cached!
   switch(in[1]) {
    default:
     local_nvt[in[1]] = TN_WONT;
     msg = "   ";
     msg[0] = TN_IAC;
     msg[1] = TN_WONT;
     msg[2] = 
     fprintf(hand,"%s",msg);
     break;
   }     
  }
 
 } 
}

void parse_dont() {
 array(mixed) in;
 string msg;
 
 in = tn_getchar();
 if (sizeof(in)) {
#ifdef DEBUG_PTY
 write("parse_dont(%O)\n",in[1]);
#endif 
  if (zero_type(local_nvt[in[1]])) {
   switch(in[1]) {
    default:
     local_nvt[in[1]] = TN_WONT;
     msg = "   ";
     msg[0] = TN_IAC;
     msg[1] = TN_WONT;
     msg[2] = in[1]; 
     fprintf(hand,"%s",msg);
     break;
   }
  
  } else {
   // cached!
   if (local_nvt[in[1]] != TN_WONT) {   
    switch(in[1]) {
     default:
      local_nvt[in[1]] = TN_WONT;
      msg = "   ";
      msg[0] = TN_IAC;
      msg[1] = TN_WONT;
      msg[2] = 
      fprintf(hand,"%s",msg);
      break;
    }     
   }
  }
 }
}

void parse_will() {
 array(mixed) in;
 string msg;
 
 in = tn_getchar();
 if (sizeof(in)) {
#ifdef DEBUG_PTY
 write("parse_will(%O)\n",in[1]);
#endif 
  if (zero_type(remote_nvt[in[1]])) {
   switch(in[1]) {
    default:
     remote_nvt[in[1]] = TN_DONT;
     msg = "   ";
     msg[0] = TN_IAC;
     msg[1] = TN_DONT;
     msg[2] = in[1]; 
     fprintf(hand,"%s",msg);
     break;
   }
  
  } else {
   // cached!
   if (remote_nvt[in[1]] != TN_WILL)
    switch(in[1]) {
    default:
     remote_nvt[in[1]] = TN_DONT;
     msg = "   ";
     msg[0] = TN_IAC;
     msg[1] = TN_DONT;
     msg[2] = in[1];
     fprintf(hand,"%s",msg);
     break;
   }     
  }
 
 } 
}

void parse_wont() {
 array(mixed) in;
 string msg;
 
 in = tn_getchar();
 if (sizeof(in)) {
#ifdef DEBUG_PTY
 write("parse_wont(%O)\n",in[1]);
#endif 
  if (zero_type(remote_nvt[in[1]])) {
   switch(in[1]) {
    default:
     remote_nvt[in[1]] = TN_WONT;
     msg = "   ";
     msg[0] = TN_IAC;
     msg[1] = TN_DONT;
     msg[2] = in[1]; 
     fprintf(hand,"%s",msg);
     break;
   }
  
  } else {
   // cached!
   if (remote_nvt[in[1]] != TN_WONT)
    switch(in[1]) {
    default:
     remote_nvt[in[1]] = TN_WONT;
     msg = "   ";
     msg[0] = TN_IAC;
     msg[1] = TN_DONT;
     msg[2] = in[1];
     fprintf(hand,"%s",msg);
     break;
   }     
  }
 
 }
}

string parse_iac() {
 string ret;
 ret = "";
 string ch;
 int nch;
 int resolved;
 
#ifdef DEBUG_PTY 
 write("parse_iac()\n");
#endif

 fread(data,1,1,hand);
 if ((sizeof(data->value)) && (sizeof(data->value[0]))) {
  ch = data->value[0];
  nch = ch[0];
  if (nch == TN_IAC) {  
   ret = " ";
   ret[0] = TN_IAC;
  } else {
   resolved = 0;
   if (nch == TN_DO) {
    parse_do();
    resolved = 1;
   }
   if (nch == TN_DONT) {
    parse_dont();
    resolved = 1;
   }
   if (nch == TN_WILL) {
    parse_will();
    resolved = 1;
   }
   if (nch == TN_WONT) {
    parse_wont();
    resolved = 1;
   }

#ifdef DEBUG_PTY
   if (!resolved) {  
    write("telnet rcvd (%O)\n",tn_lookup[TN_IAC]);
    if (zero_type(tn_lookup[nch])) {
     write("telnet rcvd (%O)\n",sprintf("<UNKNOWN=%O>",nch));
    } else {
     write("telnet rcvd (%O)\n",tn_lookup[nch]);
    }
   }
#endif   
   
   
  }
 } else {
  connected = 0;
 }
 return ret;  
}



private int pty_pull() {
 
#ifdef DEBUG_PTY
 write("pty_pull()!\n");
#endif 
 
 string ch;
 int nch;
 
 data = pike_pointer();
 
 if(connected) {
  fread(data,1,1,hand);
  if ((sizeof(data->value)) && (sizeof(data->value[0]))) {
   ch = data->value[0];   
   nch = ch[0];
   if (nch == TN_IAC) {
    ch = parse_iac();    
   }
   if (sizeof(ch)) {
#ifdef DEBUG_PTY   
    write("telnet rcvd (%O : %O)\n",ch,nch);
#endif
    in_buff += ch;    
   }
   
  } else {
   connected = 0;
  }
 }
 #ifdef DEBUG_PTY
 if (!connected)
 write("Connection Lost!");
 #endif
 
 return 0;
}


private int pty_id;

string name() {
 return sprintf("pty/%O",pty_id);
}

private object io_master;
void grab(void|function cb) {
 if (!io_master) {
  mixed bt = backtrace();
  io_master = function_object(bt[-2][2]);
  if (functionp(cb)) {
   grab_cb = cb;
  }   
 }
}

static int ptyctr;
protected void create(int fh) {
 hand = fh;
 if (!ptyctr) ptyctr = 0;
 ptyctr++;
 pty_id = ptyctr;
 while(ioctl(-1,-1,name(),this) < 0) {
  ptyctr++;
  pty_id = ptyctr; 
 }
 in_buff = "";
 connected = 1;
 Thread.Thread thread;
 if (!running)
  thread = Thread.Thread(backend);

}
