#ifndef __DAEMONS_H
#define __DAEMONS_H

#define SECURITYD kernel()->security()
#define SECURE_D kernel()->security()
#define ANSI_D load_object("/sbin/ansid.pike")
#define USER_D load_object("/sbin/userd.pike")
#define CHANNEL_D load_object("/sbin/channeld.pike")
#define CMD_D load_object("/sbin/cmdd.pike")
#define PREPOSITION_D load_object("/sbin/languaged.pike")

#define MESSAGES_D load_object("/sbin/languaged.pike")
#define LANGUAGE_D load_object("/sbin/languaged.pike")

#endif
