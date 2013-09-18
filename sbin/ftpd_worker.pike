
#include <daemons/ftp.h>
#include <daemons.h>
#include <config.h>

#define LTYPE_LIST 0
#define LTYPE_NLST 1

inherit "/lib/domain/secure/modules/m_shell.pike";
inherit "/lib/domain/secure/modules/m_shellvars.pike";

private object ftpd;
private object thisSession;
private string iphost;
private int ready;

private  mapping dispatch =
([
  "user" : FTP_CMD_user,
  "pass" : FTP_CMD_pass,
  "retr" : FTP_CMD_retr,
  "stor" : FTP_CMD_stor,
  "nlst" : FTP_CMD_nlst,
  "list" : FTP_CMD_list,
  "pwd" : FTP_CMD_pwd,
  "cdup" : FTP_CMD_cdup,
  "cwd" : FTP_CMD_cwd,
  "quit" : FTP_CMD_quit,
  "type" : FTP_CMD_type,
  "mkd" : FTP_CMD_mkd,
  "port" : FTP_CMD_port,
  "noop" : FTP_CMD_noop,
  "dele" : FTP_CMD_dele,
  "syst" : FTP_CMD_syst,
  "pasv" : FTP_CMD_pasv,
]);

//private object sock;

private mixed outfile=([]);

#ifdef ALLOW_ANON_FTP
private array(string) anon_logins = ({"anonymous", "ftp"});
#endif



private int is_flag(string m) 
{
	return sizeof(m) && m[0] == '-';
}

private int not_flag(string m) 
{
	return !(sizeof(m) && m[0] == '-');
}

private string find_flags(string incoming)
{
    array(string) parts;
    array(string) flags=({});
    if(!incoming) {
        return 0;
    }
    
    parts=explode(incoming," ");
    parts=filter(parts,is_flag);
    foreach(parts,string part) {
        flags+=explode(part,"");
    }
    clean_array(flags);
    return implode(flags-=({"-"}),"");
}

private string|int strip_flags(string incoming)
{
    array(string) parts;
    if(!incoming) {
        return 0;
    }
    parts=explode(incoming," ");
    parts=filter(parts,not_flag);
    return implode(parts," ");
}

private void FTPLOGF(string format, mixed ... args)
{
    //FTPLOG(sprintf(format, args...));
    kernel()->console_write(sprintf(format, @args));
}

#ifdef ALLOW_ANON_FTP
private string FTP_get_welcome_msg()
{
  return 
    sprintf("220- %s FTP server ready.\n%s"
        "220 Anonymous and admin logins accepted.\n",
        mud_name(),
        is_file(FTP_WELCOME) ? "220- " +
        replace_string(read_file(FTP_WELCOME), "\n", "\n220- ")
        +"\n": ""
    );
}
#endif

void anti_idle() 
{
	if (!thisSession->dataPipe) {
        if(thisSession->idleTime >= MAX_IDLE_TIME+60) {
        	
            FTPLOGF("%s idled out at %s.\n", capitalize(thisSession->user), ctime(time()));
            write(sprintf("421 Timeout. (%d seconds): closing control connection.\n",MAX_IDLE_TIME));            
            destruct(this);
        }
	}
}        

private int FTP_write()
{        
    write("226 Transfer complete.\n");    
    destruct(thisSession->dataPipe);
    thisSession->dataPipe = 0;
    return 0;        
}



private void FTP_PASV_read(string text)
{
    
    thisSession->dataPipe->write_cb = FTP_write;
    
    ftpd->removePassive(thisSession);
        
    
    if(!text) {
        return;
    }
        
    switch(thisSession->binary) {
        case 0:
            text=replace_string(text,"\r","");
            write_file(thisSession->targetFile, text);
            return;
        case 1:            
            write_bytes(thisSession->targetFile, thisSession->filepos,text);            
            thisSession->filepos += sizeof(text);
            return;
        default:
            break;
    }  
}

private void FTP_DATA_read(mixed text)
{

    switch(thisSession->binary) {
        case 0:
             text=replace_string(text,"\r","");
             write_file(thisSession->targetFile,text);
             break;
        case 1:      
            write_bytes(thisSession->targetFile,thisSession->filepos,text);
            thisSession->filepos+=sizeof(text);
            break;
        default:
            break;
    }
}

private void FTP_DATA_close(object socket)
{
    write("226 Transfer complete.\n");
}

private void FTP_CMD_user(string arg)
{    
    arg = lower_case(arg);
    if(thisSession->connected) {
        write("530 User %s access denied.\n", arg);
        return;
    }
    
    thisSession->user = arg;

#ifdef ALLOW_ANON_FTP
    if(member_array(arg, anon_logins) != -1) {
        write("331 Guest login ok, send your complete e-mail "
            "address as password.\n");
        return;
    }
#endif

    write("331 Password required for %s.\n", arg);
    return;
}

private void FTP_CMD_pass(string arg)
{
    string	password;
    array(mixed) userinfo;

        
    if(thisSession->connected || !thisSession->user) {
        write("503 Login with USER first.\n");
        return;
    }

#ifdef ALLOW_ANON_FTP
    if(ANON_USER()) {
        write("230 guest login ok, access restrictions apply.\n");
        thisSession->connected = 1;
        thisSession->priv = 0;
        thisSession->pwd = ANON_PREFIX;
        FTPLOGF("Anomymous login from %s (email = %s)\n", thisSession->address()[0], arg);
        return;
    }
#endif

    userinfo = USER_D->query_variable(thisSession->user,({"password"}));
    if(arrayp(userinfo) && sizeof(userinfo)) {
        password = userinfo[0];
    } else {
        write("530 Login incorrect.\n");
        //write("530 No such login.\n");
        return;
    }
    
    if(
        (!crypt(arg, password)) 
#ifdef FTP_ADMIN_ONLY        
        || !adminp(thisSession->user)
#endif        
    ) {
        write("530 Login incorrect.\n");
        //write("530 Authentication failed (%s,%s,%O).\n",arg,password,crypt(arg, password));
        return;
    }
    
    write("230 User %s logged in.\n", thisSession->user);
    thisSession->connected = 1;
    
    FTPLOGF("%s connected from %s.\n", capitalize(thisSession->user),thisSession->address()[0]);

    if(adminp(thisSession->user)) {
        thisSession->priv = 1;
    } else {
        thisSession->priv = thisSession->user;
    }
    set_cwd(join_path(ADMIN_DIR,thisSession->user));
  
    if (!is_directory(get_cwd())) {
        set_cwd("/");
    }
    return;
}

private void FTP_CMD_quit(string arg)
{
    write("221 Goodbye.\n");
    
    if(thisSession->dataPipe) {
        destruct(thisSession->dataPipe);
    }
       
    FTPLOGF("%s QUIT at %s.\n", capitalize(thisSession->user), ctime(time()));
    
    ftpd->goodbye();
    destruct();
}



private void FTP_CMD_pasv(string arg)
{
    
    array(int) port;
    int port_dec;

    if(arg) {
        write("500 command not understood.\n");
        return;
    }

    if(thisSession->dataPipe) {
        destruct(thisSession->dataPipe);
    }

    thisSession->dataPipe = ftpd->create_pasv_socket(thisSession->binary,FTP_PASV_read,FTP_DATA_close);
    
    if (objectp(thisSession->dataPipe)) {    	                 
        port_dec = thisSession->dataPipe->local_port;
        port=({port_dec>>8,port_dec%256});
    
        write(
            "227 Entering Passive mode. (%s,%d,%d)\n",
            replace_string(iphost,".",","),
            port[0],
            port[1]
        );
    }
}

private void FTP_CMD_port(string arg)
{
    string ip;
    array(string) parts;
    int	port;
    
    parts = explode(arg, ",");
    if(sizeof(parts)!=6) {
        write("550 Failed command.\n");
        if (objectp(thisSession->dataPipe)) {
            destruct(thisSession->dataPipe);
        }
        return;
    }
      
    ip = implode(parts[0..3],".");
    /* Make a 16 bit port # out of 2 8 bit values. */
    port = ( ((int) (parts[4])) << 8) + ((int)(parts[5]));
  
    if(thisSession->dataPipe) {
        destruct(thisSession->dataPipe);
    }

    thisSession->dataPipe = ftpd->create_port_socket(ip,port,thisSession->binary,FTP_DATA_read,FTP_DATA_close);
    if (objectp(thisSession->dataPipe)) {    
        thisSession->dataPipe->write_cb = FTP_write;
        write("200 PORT command successful.\n");
    }    
    return;
}

private int not_dotfile(mixed arg) 
{
	return member_array(arg[0], ({".",".."})) == -1;
}

string dir_format_one(mixed arg) 
{
    return sprintf(
        "%s %3d %=9s %=8s %=7s %s%5s %s",
        arg[1]==-2 ? "drwxrwxr-x" : "-rw-rw-r--",
        1,
        lower_case(replace_string(mud_name(), " ", "_"))[0..7],
        lower_case(replace_string(mud_name(), " ", "_"))[0..7],
        arg[1]==-2 ? "0" :sprintf("%d",arg[1]),
        ctime(arg[2])[4..10],
        (time()-arg[2])>31536000?ctime(arg[2])[20..]:ctime(arg[2])[11..15],
        basename(arg[0])
    );

}

private string first_arg_to_str(mixed arg) 
{
	return sprintf("%s",arg[0]);
}

private int FTP_List_callback() 
{
	thisSession->dataPipe->remove_clean();
	return 0;
}

private void do_list(string arg, int ltype)
{
    array(mixed) files;
    string flags;
    string output;
    int isfile;
  
    flags=find_flags(arg);
    arg=strip_flags(arg);
    
    if(!arg || arg == "") {
        arg = ".";
    }
  

    if(arg[<1..]=="/.") {
        if(is_file(arg[0..<2])) {
            isfile=1;
        }
    }
  
    arg = evaluate_path(arg, get_cwd());
    ANON_CHECK(arg);
    if(is_directory(arg)) {
        arg = join_path(arg, "*");
    }
    
    /*
    if(file_size(base_path(arg)) == -1) {
      write("550 %s: No such file OR directory.\n", arg);
      destruct(thisSession->dataPipe);
      return;
    }
    */
    
    if(isfile) {
        files=({});
    } else {
    	files = get_dir(arg,-1);
    	if (!files) {
            write("550 %s: No such file OR directory.\n", arg);
            destruct(thisSession->dataPipe);
            return;    		
    	}    	
    }
    if(!files&&!isfile) {
        write(sprintf("550 %s: Permission denied.\n",arg));
        destruct(thisSession->dataPipe);
        return;
    }
    if(flags) {
        if(strsrch(flags,"a")==-1) {
            files = filter(files, not_dotfile);
        }
    }
    
    if(!sizeof(files)&&!isfile) {
        write("550 No files found.\n");
        destruct(thisSession->dataPipe);
        return;
    }

    if (ltype == LTYPE_LIST) {
        if (flags) {
            if ( (strsrch(flags, "l") == -1) &&
                 (strsrch(flags, "C") == -1) &&
                (strsrch(flags, "1") == -1) ) {
                flags += "l";
             }
        } else {
            flags = "l";
        }
    } else {
        if (flags) {
            if (
                (strsrch(flags, "l") == -1) &&
                (strsrch(flags, "C") == -1) &&
                (strsrch(flags, "1") == -1) 
            ) {
                flags += "1";
            }
        } else {
            flags = "1";
        }
    }

    if (strsrch(flags,"F")>-1) {
      foreach(files, array(mixed) file) {
          if (file[1]==-2) {
              file[0]=sprintf("%s/",basename(file[0]));
          }
      }
    }
    
    /* The C flag */
    if(strsrch(flags,"C")>-1) {
        int lines;
        int size;
        int i;
        if((strsrch(flags,"l")>-1) || (strsrch(flags,"1")>-1)) {
              write("550: LIST -C flag is incompatible with -1 or -l.\n");
              destruct(thisSession->dataPipe);
              return;
        }
        lines=((size=sizeof(files))/3)+1;
        output="";
        for(i=0;i<lines;i++) {
            array(mixed) these_files;
            if ((i*3+2)<size) {
                these_files=files[(i*3)..(i*3+2)];
            } else if(i*3<size) {
                these_files=files[(i*3)..];
                while(sizeof(these_files)<3) {
                    these_files+=({ ({"",0,0}) });
                }
            } else {
              break;
            }
            output=sprintf("%s%-=25s %-=25s %-=25s\n",
                output,
                basename(these_files[0][0]),
                these_files[1][0],
                these_files[2][0]
            );
        }
    }
    
    if(strsrch(flags,"l")>-1) {
        if(strsrch(flags,"1")>-1) {
            write("550: LIST -l and -1 flags incompatible.\n");
            destruct(thisSession->dataPipe);
            return;
        }
      
        output = implode(map(files,
            dir_format_one),"\n");
    }


    if (strsrch(flags,"1")>-1) {
        output=implode(map(files,first_arg_to_str),"\n");
    }
        
    write("150 Opening ascii mode data connection for file list\n");
    thisSession->dataPipe->write_cb =  FTP_List_callback;    
    thisSession->dataPipe->send("%s",implode(explode(output,"\n"), "\r\n")+"\r\n");
    
       
    return;
}

private void FTP_CMD_list(string arg)
{

    if(!thisSession->dataPipe) {
        call_out( FTP_CMD_list,2,arg);
        return;
    }
    do_list(arg, LTYPE_LIST);
}

private void FTP_CMD_nlst(string arg)
{
    
    if(!thisSession->dataPipe) {
        call_out(FTP_CMD_nlst,2,arg);
        return;
    }  
    do_list(arg, LTYPE_NLST);
}

private void FTP_CMD_retr(string arg)
{
  string	target_file;
  int i;

  /* Make sure the dataPort is connected, otherwise this will error */
  if(!thisSession->dataPipe)
  {
    call_out( FTP_CMD_retr ,2,arg);
    return;
  }
    
  target_file = evaluate_path(arg, get_cwd());

  ANON_CHECK(target_file);

  if(is_directory(target_file)) {
    write("550 %s: Can't retrieve (it's a directory)."
       "\n", target_file);
    destruct(thisSession->dataPipe);
    return;
  }
  if(!is_file(target_file)) {
    write("550 %s: No such file OR directory.\n",
        target_file);
    destruct(thisSession->dataPipe);
    return;
  }
  if(!file_size(target_file)) {
    write("550 %s: File contains nothing.\n",
        target_file);
    destruct(thisSession->dataPipe);
    return;
  }
  
  switch(thisSession->binary)
  {
    case 0:
      i=file_size(target_file);
      FTPLOGF("%s GOT %s.\n", capitalize(thisSession->user), target_file);

      outfile[thisSession->dataPipe]=({target_file,0,0,thisSession->cmdPipe});
      thisSession->dataPipe->write_cb = FTP_CMD_retr_callback;

      write("150 Opening ascii mode data connection for "
"%s (%d bytes).\n", target_file, i);

      thisSession->dataPipe->send(FTP_CMD_retr_callback());
      break;
    case 1:
      i=file_size(target_file);

      outfile[thisSession->dataPipe]=({target_file,1,0,thisSession->cmdPipe});
      thisSession->dataPipe->write_cb = FTP_CMD_retr_callback;

      write("150 Opening binary mode data connection "
            "for %s (%d bytes).\n", target_file, i);

      thisSession->dataPipe->send(FTP_CMD_retr_callback());      
      break;
    default:
      break;
  }
}

void FTP_CMD_pwd(string arg)
{
  write("257 \"%s\" is current directory.\n", get_cwd());
}

void FTP_CMD_noop(string arg)
{
    write("221 NOOP command successful.\n");
}

private void FTP_CMD_stor(string arg)
{

    if(!objectp(thisSession->dataPipe)) {
        call_out( FTP_CMD_stor ,2,arg);
        return;
    }
    
    arg = evaluate_path(arg, get_cwd());


#ifndef ANON_CAN_PUT
#ifdef ALLOW_ANON_FTP
    if(ANON_USER()) {
        write("550 Permission denied.\n");
        destruct(thisSession->dataPipe);
        return;
    }
#endif
#else
  ANON_CHECK(arg);
#endif

    if (!is_directory(base_path(arg))) {
        write("553 No such directory to store into. %O\n",base_path(arg));
        destruct(thisSession->dataPipe);
        return;  
    }
    
    thisSession->targetFile = arg;
    if(is_file(arg)) {
        if(!rm(arg)) {
            write("550 %s: Permission denied A.\n", arg);
            destruct(thisSession->dataPipe);
            return;
        }
    } else if(!write_file(arg, "")) {
        write("550 %s: Permission denied B.\n", arg);
        destruct(thisSession->dataPipe);
        return;
    }
  
  
    FTPLOGF("%s PUT %s.\n", capitalize(thisSession->user), arg);


    thisSession->filepos=0;
    write(
        "150 Opening %s mode data connection for %s.\n",
        thisSession->binary ? "binary" : "ascii",
        arg
    );
    
    thisSession->dataPipe->do_read();
}

private void FTP_CMD_cdup(string arg)
{
    FTP_CMD_cwd("..");
}

private void FTP_CMD_cwd(string arg)
{
  string	newpath;


  newpath = evaluate_path(arg, get_cwd());

  ANON_CHECK(newpath);

  if(!is_directory(newpath)) {
    write("550 %s: No such file or directory.\n",
        newpath);
    return;
  }
  set_cwd(newpath);
  write("250 CWD command successful.\n");
}

private void FTP_CMD_mkd(string arg)
{
  
  arg = evaluate_path(arg, get_cwd());

#ifndef ANON_CAN_PUT
#ifdef ALLOW_ANON_FTP
  if(ANON_USER())
  {
    write("550 Permission denied.\n");
    destruct(thisSession->dataPipe);
    return;
  }
#endif
#else
  ANON_CHECK(arg);
#endif

  if(!is_directory(base_path(arg))) {
    write("550 %s: No such directory.\n",
        base_path(arg));
    return;
  }
  if(file_size(arg) != -1) {
    write("550 %s: File exists.\n", arg);
    return;
  }

  if(!mkdir(arg)) {
    write("550 %s: Permission denied.\n", arg);
    return;
  }
  write("257 MKD command successful.\n");
  return;
}

private void FTP_CMD_type(string arg)
{
  
  switch(arg)
  {
    case "a":
    case "A":
      thisSession->binary = 0;
      write("200 Type set to A.\n");
      return;
    case "i":
    case "I":
      thisSession->binary = 1;
      write("200 Type set to I.\n");
      return;
    default:
      write("550 Unknown file type.\n");
      return;
  }
}

private void FTP_CMD_dele(string arg)
{
  
    arg = evaluate_path(arg, thisSession->pwd);

    ANON_CHECK(arg);

    if(!is_file(arg)) {
        write("550 %s: No such file OR directory.\n", arg);
        return;
    }
    if(!rm(arg)) {
        write("550 %s: Permission denied.\n",arg);
        return;
    }
    FTPLOGF("%s DELETED %s.\n", capitalize(thisSession->user), arg);
    write("250 DELE command successful.\n");
}

int clean_up() { return 0; }



private void FTP_CMD_syst(string arg)
{
    write("215 UNIX Mud Name: "+mud_name()+"\n");
}

string FTP_CMD_retr_callback()
{
    int start,length;
    mixed ret;


    if (zero_type(outfile[thisSession->dataPipe])) {
        return 0;
    }

    start=outfile[thisSession->dataPipe][2];
    length=FTP_BLOCK_SIZE;
    outfile[thisSession->dataPipe][2]+=length;

    if (start+length>file_size(outfile[thisSession->dataPipe][0])) {
        length=file_size(outfile[thisSession->dataPipe][0])-start;
    }

    ret=read_bytes(outfile[thisSession->dataPipe][0],start,length);

    if (start+length>=file_size(outfile[thisSession->dataPipe][0])) {
        map_delete(outfile,thisSession->dataPipe);
        thisSession->dataPipe->write_cb = FTP_write;
    }

    return ret;
}



string query_iphost() 
{ 
	return iphost; 
}


private void do_command(string data)
{
    string cmd, arg;    
    function dispatchTo;
    

    mixed err;
    
    thisSession->idleTime = 0;
    
    thisSession->command = rtrim(data);
    
    if (!sscanf(thisSession->command, "%s %s", cmd, arg)) {
        cmd = thisSession->command;
    }

    cmd = lower_case(cmd);

    if (!thisSession->connected) {
        switch(cmd) {
            case "user":
                FTP_CMD_user(arg);
                break;
            case "pass":
                FTP_CMD_pass(arg);
                break;
            case "quit":
                FTP_CMD_quit(arg);
                break;
            case "noop":
                FTP_CMD_noop(arg);
                break;
            default:
                write("503 Log in with USER first.\n");
                break;
        }
        
        input_to(do_command);
        return;
    }

    
    if (zero_type(dispatch[cmd])) {        
        write("502 Unknown command %s.\n", cmd);
        input_to(do_command);
        return;
    }
    
    dispatchTo = dispatch[cmd];
    
    if(err = catch(dispatchTo(arg))) {
    	if (objectp(err)) {
        FTPLOGF("%s caused a FAILURE with command '%s'. %O %O\n",
            capitalize(thisSession->user), data,err,err->backtrace());    		
    	} else {
        FTPLOGF("%s caused a FAILURE with command '%s'. %O\n",
            capitalize(thisSession->user), data,err);
    	}
            write("550 Unknown failure. Please report what you were doing "
            "to the mud admin.\n"
        );
    } else {
    	input_to(do_command);
    }
}


void logon() 
{
    set_variable("LIB_PATHS","/lib");
    set_variable("INCLUDE_PATHS","/includes");
    set_cwd("/");		
}

void register_session(object daemon,object session, string host) 
{
	if (!ready) {
		ready = 1;
	    thisSession = session;
	    ftpd = daemon;
	    iphost = host;
	    input_to(do_command);
	    
#ifdef ALLOW_ANON_FTP
    write(FTP_get_welcome_msg());
#else
    write(sprintf("220- %s FTP server ready.\n220 Please login with your"
        " admin name.\n", mud_name()));
#endif
	    
	}
}


void destroy() 
{		
	destruct(thisSession);
    ftpd->goodbye();
    destruct();
}
