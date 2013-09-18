#ifndef __CONFIG_H__
#define __CONFIG_H__

//#define DEBUG_LOGIN
//#define DEBUG_USER_IO

#define WELCOME_FILE "/var/config/WELCOME"
#define NEW_PLAYER		"/var/config/NEW_PLAYER"
#define MOTD_FILE		"/var/config/MOTD"
#define LOGIN_PROMPT		"What is your name? "


#define LOGIN_NAME_WAIT 300
#define LOGIN_PASSWORD_WAIT 180

#define WIZARD_START		"/var/domains/std/adminroom.pike"
#define START		"/var/domains/std/void.pike"

#define __HOST__		"localhost"

#define ADMIN_EMAIL		"rritoch@gmail.com"
#define WSHELL_PATH(x)	sprintf("/var/wshells/%c/%s",x[0],x)

#define ADMIN_DIR			"/home"

#define LINK_PATH(x) sprintf("/var/links/%c/%s",x[0],x)
#define USER_PATH(x) sprintf("/var/players/%c/%s",x[0],x)
#define PSHELL_PATH(x) sprintf("/var/pshells/%c/%s",x[0],x)


#define ADMIN_SHELL (program)"/sbin/wshell.pike"
#define USER_SHELL (program)"/sbin/wshell.pike"

#define DEFAULT_WRAP_WIDTH 80

#define __SAVE_EXTENSION__ ".o"

#define VOID_ROOM first_instance("/var/domains/std")

#define USER_OB (program)"/root/lib/user.pike"
#define BODY_OB "/lib/mudlib/body.pike"

#endif
