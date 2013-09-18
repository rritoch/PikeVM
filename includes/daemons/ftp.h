#ifndef __TELNET_H
#define __TELNET_H

#define FTP_CMD_PORT 4000
#define RESTRICT_PORTS
#define MIN_PORT 4100
#define MAX_PORT 4200
#define MAX_TRIES 10

#define BACKLOG 100
#define FTP_LOGON_OB "/sbin/ftpd_worker.pike"


#define MAX_IDLE_TIME 600 // This is really x+60 seconds. LWI.
#define NEEDS_ARG() if(!arg){ info->cmdPipe->send("500 command not understood.\n"); return; }
//#define FTPLOG(x) LOG_D->log(LOG_FTP, x)
#define FTP_WELCOME "/var/config/FTPWELCOME"

#ifdef ALLOW_ANON_FTP
#define ANON_PREFIX "/var/ftp/pub"
#define ANON_USER() (member_array(info->user, anon_logins) != -1)
#define ANON_CHECK(x) if(ANON_USER() && x[0..(strlen(ANON_PREFIX)-1)] != ANON_PREFIX) { info->cmdPipe->send("550 Pemission denied.\n"); if(info->dataPipe) destruct(info->dataPipe); return; }

#else
#define ANON_CHECK(x)
#endif

#define FTP_BLOCK_SIZE 1024

// #define FTP_ADMIN_ONLY

#endif