/* ========================================================================== */
/*                                                                            */
/*   Filename.c                                                               */
/*   (c) 2001 Author                                                          */
/*                                                                            */
/*   Description                                                              */
/*                                                                            */
/* ========================================================================== */


constant INPUT_NOECHO = 1;
constant INPUT_CHARMODE = 2;
constant INPUT_PROMPT = 4;
constant INPUT_NO_TELNET = 8;
constant INPUT_APPEND = 16;
constant INPUT_IGNORE_BANG = 128;

#define I_FUNC        0
#define I_NO_ECHO     1
#define I_IGNORE_BANG 2
#define I_CHARMODE    3
#define I_PROMPT      4
#define I_USER        5
#define I_ARGS        6


extern array(mixed) call_stack;
extern int bangptr;
extern int running;

extern mixed grab_cb;
extern string _read_line(int noecho);
extern string _read_char(int noecho);
extern void _write_error_message(mixed err);
extern int _open();

protected int kill_fh = 0;

void input_to(function fun, 
              void|int flag, 
              void|string|function prompt, mixed ... args) {
 
 array(mixed) ent;
 
 int no_echo; 
 no_echo = flag & INPUT_NOECHO;
 
 int charmode; 
 charmode = (INPUT_CHARMODE & flag) > 0;
 if (charmode) {
  charmode += (INPUT_NO_TELNET & flag) > 0;
 } 
   
 array(mixed) input_prompt = ({ });    
 if (flag & INPUT_PROMPT) input_prompt = ({ prompt }) + args;    
  
 int ignore_bang = 0; 
 if ( (flag & INPUT_IGNORE_BANG) && 
      (master()->valid) && 
      master()->valid("input_ignore_bang")) {
  ignore_bang = 1;     
 }
 
 ent = ({ fun, no_echo, ignore_bang, charmode, input_prompt, this_user(), args });
 
 /* if INPUT_APPEND add to end of array otherwise add to begin */ 

 while (sizeof(call_stack) < (bangptr + 1)) call_stack += ({({})});
 if (flag & INPUT_APPEND) {
  call_stack[bangptr] = ({ ent }) + call_stack[bangptr]; 
 } else {
  if (sizeof(call_stack) == (bangptr + 1)) {
   if (sizeof(call_stack[bangptr]) > 0) {
    call_stack += ({({ ent })});
    bangptr++;
   } else {
    call_stack[bangptr] = ({ ent }); 
   }   
  } else {
   call_stack = call_stack[0..bangptr] + ({ ent }) + call_stack[(bangptr + 1)..];
   bangptr++;
  }
     
 }
  
}


protected int backend() {
 if (running++) return 1; 
 array(mixed) ent;
 int r;
 string str;
 string ch;
 mixed err;
 int kfh;
 function f;
 if (!_open()) return 1;
 
 while (this) { // Master Loop
 
  kfh = kill_fh;
  if (functionp(grab_cb)) {
   f = grab_cb;
   grab_cb = 0;
   f();
  }
  running = 1;
  
  // Clean Empty Refrences from stack
  
  while ((sizeof(call_stack)) && (!sizeof(call_stack[-1]))) {
   if (sizeof(call_stack) > 1) {
    call_stack = call_stack[0..<1];
   } else {
    call_stack = ({});
   } 
  }  
  bangptr = sizeof(call_stack) - (sizeof(call_stack) > 0);

#ifdef DEBUG_CONSOLE  
  write(sprintf("console.pike: call_stack = %O\n",call_stack));
#endif  
  if (sizeof(call_stack) > 0) {   
   
   ent = call_stack[bangptr][-1];
   
   
  // draw prompt
   if (sizeof(ent[I_PROMPT])) {
    if (functionp(ent[I_PROMPT][0])) {
     if (ent[I_USER] && !zero_type(ent[I_USER])) {
      ent[I_USER]->recv_msg(ent[I_PROMPT][0](@ent[I_PROMPT][1..]));
     } else {    
      write(ent[I_PROMPT][0](@ent[I_PROMPT][1..]));
     }
    }
    if (stringp(ent[I_PROMPT][0])) {
     if (ent[I_USER] && !zero_type(ent[I_USER])) {
      ent[I_USER]->recv_msg(ent[I_PROMPT][0]);
     } else {
      write(ent[I_PROMPT][0]);
     }
    }
   }
   if (ent[I_CHARMODE] == 1) {
    str = _read_char(ent[I_NO_ECHO]);
   } else {
    str = _read_line(ent[I_NO_ECHO]);
   }
   
   r = 0;   
   while(sizeof(str) > 0) {
     
    ent = call_stack[bangptr][-1];
#ifdef DEBUG_CONSOLE    
    write(sprintf("console.pike: Processing %O as %O\n",ent,str));
#endif    
    if (ent[I_IGNORE_BANG]) { // ignore bang
     if (ent[I_CHARMODE] > 0) {
      ch = str[0..0];
      if (sizeof(str) > 1) {
       str = str[1..];
      } else {
       str = "";
      }
     } else {
      ch = str;
      str = "";
     }
     // remove entry from stack
     if (sizeof(call_stack[bangptr]) > 1) {
      call_stack[bangptr] = call_stack[bangptr][0..<1];
     } else {
      call_stack[bangptr] = ({});
      str = "";
     }     
     // call function
     // catch so we don't screw up our bangptr
     err = catch {
      ent[I_FUNC](ch,@ent[I_ARGS]);
     };
     if (err) {
      _write_error_message(err);
     }       
    } else {
     if (str[0..0] == "!") {
      if (bangptr) bangptr--;
      if (sizeof(str) > 1) {
       str = str[1..];
      } else {
       str = "";
      }
     } else {
      // process no bang

      if (ent[I_CHARMODE] > 0) {
       ch = str[0..0];
       if (sizeof(str) > 1) {
        str = str[1..];
       } else {
        str = "";
       }
      } else {
       ch = str;
       str = "";
      }
      // remove entry from stack
      if (sizeof(call_stack[bangptr]) > 1) {
       call_stack[bangptr] = call_stack[bangptr][0..<1];
      } else {
       call_stack[bangptr] = ({});
       str = "";
      }     
      // call function
      // catch so we don't screw up our bangptr
      err = catch {
       ent[I_FUNC](ch,@ent[I_ARGS]);
      };
      if (err) {
       _write_error_message(err);
      }    
     }  
    }
   }
  } else {
    sleep(1);    
  }
 }
 
    if (kfh) {
        fclose(kfh);
    }
}
