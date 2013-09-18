#ifndef __MOVE_H
#define __MOVE_H

#include "/includes/mudlib.h"

#define MOVE_OK 1
#define MOVE_NOT_RELEASED "It doesn't seem moveable.\n"
#define MOVE_NOT_RECEIVED "You can't seem to move it there.\n"
#define MOVE_PREVENTED "You can't seem to move it.\n"
#define MOVE_NO_ROOM "There isn't enough room.\n"
#define MOVE_NOT_ALLOWED "That doesn't seem possible.\n"
#define MOVE_NO_ERROR -1 // Rust wanted to clone another object
#define MOVE_NO_DEST "I can't figure out where you're moving that to."

#endif