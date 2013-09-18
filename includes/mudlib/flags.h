/* Do not remove the headers from this file! see /USAGE for more info. */

#ifndef __FLAGS_H__
#define __FLAGS_H__

#define ATTACHED 2
#define MOVE_NOT_ALLOWED -2
#define HOOK_IGNORE 0 



#define MakeFlag(s,i) (((s) << 5) | ((i) & 0x1F))

#define FlagSet(w) ((w) >> 5)
#define FlagIndex(w) ((w) & 0x1F)


#define STD_FLAGS 0 /* standard flags (setbit.h) */
#define MODULE_FLAGS 1 /* module-specific flags */
#define PLAYER_FLAGS 2 /* player.c flags (playerflags.h) */
#define PLAYER_NP_FLAGS 3 /* player.c non-persist (playerflags.h) */
#define MAILBASE_FLAGS 5 /* mailbase.c flags */


#define F_INVIS MakeFlag(STD_FLAGS, 2)
#define F_TOUCHED MakeFlag(STD_FLAGS, 4)
#define F_DESTROYABLE MakeFlag(STD_FLAGS, 5)
#define F_ATTACHED MakeFlag(STD_FLAGS, 14)
#define F_TRANSPARENT MakeFlag(STD_FLAGS, 16)

#define F_OPEN MakeFlag(MODULE_FLAGS, 0)
#define F_LIGHTED MakeFlag(MODULE_FLAGS, 1)
#define F_WIELDED MakeFlag(MODULE_FLAGS, 2)
#define F_WORN MakeFlag(MODULE_FLAGS, 3)

#define F_BIFF MakeFlag(MAILBASE_FLAGS, 0)

#define INVIS MakeFlag(STD_FLAGS, 2)
#define TOUCHED MakeFlag(STD_FLAGS, 4)
#define DESTROYABLE MakeFlag(STD_FLAGS, 5)
#define ATTACHED MakeFlag(STD_FLAGS, 14)
#define TRANSPARENT MakeFlag(STD_FLAGS, 16)



#define F_SNOOPABLE MakeFlag(PLAYER_FLAGS, 3)
#define F_BRIEF MakeFlag(PLAYER_FLAGS, 6)

#define F_IN_EDIT MakeFlag(PLAYER_NP_FLAGS, 0)
#define F_INACTIVE MakeFlag(PLAYER_NP_FLAGS, 1)

#endif

