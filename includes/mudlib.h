#ifndef __MUDLIB_H
#define __MUDLIB_H
#include <config.h>

//#include "/includes/config.h"

#define SHELL "/lib/mudlib/secure/shell.pike"
//#define M_ALIAS "/lib/mudlib/secure/shell/alias.pike"
//#define M_HISTORY "/lib/mudlib/secure/shell/history.pike"
//#define M_SCROLLBACK "/lib/mudlib/secure/shell/scrollback.pike"
#define M_SHELLFUNCS "/lib/mudlib/secure/shell/shellfuncs.pike"

#define DEFAULT_LIGHT_LEVEL	1

#define M_GETOPT "/lib/mudlib/secure/shell/getopt.pike"
#define M_PROMPT "/lib/mudlib/secure/shell/prompt.pike"
#define M_SHELLVARS "/lib/mudlib/secure/shell/shellvars.pike"
#define M_INPUT  "/lib/mudlib/secure/modules/m_input.pike"
#define M_PREPOSITIONS "/lib/mudlib/secure/modules/m_prepositions.pike"


#define M_MESSAGES "/lib/mudlib/modules/m_messages.pike"
#define M_REGEX "/lib/mudlib/modules/m_regex.pike"
#define M_GRAMMAR "/lib/mudlib/modules/m_grammar.pike"
#define M_PARSING "/lib/mudlib/modules/m_parsing.pike"
#define M_GETTABLE "/lib/mudlib/modules/m_gettable.pike"
#define M_ITEMS "/lib/mudlib/modules/m_items.pike"
#define M_EXIT "/lib/mudlib/modules/m_exit.pike"

#define INDOOR_ROOM "/lib/mudlib/indoor_room.pike"
#define BASE_ROOM "/lib/mudlib/base_room.pike"

#define CMD (program)"/lib/mudlib/secure/cmd.pike"
#define M_GLOB "/lib/mudlib/modules/m_glob.pike"

#define LIVING "/lib/mudlib/living.pike"
#define CONTAINER "/lib/mudlib/container.pike"
#define BASE_OBJ "/lib/mudlib/base_obj.pike"
#define OBJ "/lib/mudlib/object.pike"
#define VERB_OB "/lib/mudlib/verb_ob.pike"
#define SIMPLE_OB "/lib/mudlib/simple_ob.pike"
#define CLASS_EFFECT "/lib/mudlib/classes/effect.pike"
#define CLASS_CHANNEL_INFO "/lib/channel/channel_info.pike"

#endif
