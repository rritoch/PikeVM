
//#pragma warnings

#define CHANNEL_FORMAT(chan) (chan[0..4] == "imud_" ? "%%^CHANNEL_IMUD%%^[%s]%%^RESET%%^ %s\n" : "%%^CHANNEL%%^[%s]%%^RESET%%^ %s\n")

//#include <security.h>
//#include <channel.h>

#include "/includes/security.h"
#include "/includes/mudlib.h"
#include "/includes/mudlib/channel.h"

//inherit M_DAEMON_DATA;
inherit M_GRAMMAR;
inherit CLASS_CHANNEL_INFO; //picked up from channel/cmd
inherit "/lib/" "channel/cmd";
inherit "/lib/" "channel/moderation";


/*
** This channel information. It specifies channel_name -> channel_info.
*/
private  mapping info;

/*
** This mapping contains which channels should not be auto-purged (keys)
** and their flags (values)
*/
private mapping permanent_channels = ([ ]);

/*
** The listener information is only saved on a "nice" shutdown (remove()).
** On a hard shutdown (mud crash), we don't care cuz the listeners and
** hooks will reattach when they load. So you'll find changes to the
** permanent_channels will save, but these two variables will usually be
** zero at those times.
*/
class listener_pair
{
    string channel_name;
    string filename;
}
private array(listener_pair)	saved_listeners;
private array(listener_pair)	saved_hooks;


private final string extract_channel_name(string channel_name)
{
  int idx = strsrch(channel_name, "_", 1);
  if ( idx == -1 )
    return channel_name;

  /* If the channel is an intermud channel, prepend an 'i' to the name */
  if(channel_name[0..4]=="imud_")
    return "i"+channel_name[idx+1..];

  return channel_name[idx+1..];
}

void save_me() {
	// todo!
}

protected final channel_info query_channel_info(string channel_name)
{
    return info[channel_name];
}

protected final void create_channel(string channel_name)
{
    channel_info	ci;

    if ( info[channel_name] )
error("channel already exists\n");

    ci = channel_info();
    ci->name	= extract_channel_name(channel_name);
    ci->listeners	= ({ });
    ci->hooked	= ({ });
    ci->history	= ({ });

    info[channel_name] = ci;
}

private void register_one(int add_hook, object listener, string channel_name)
{
    channel_info	ci = info[channel_name];

    if ( !ci )
    {
/*
** Note: the registration interface allows for auto-creation.
** The user commands request that /new be used, though. This
** allows a user to create a channel and listen to it, and it
** will "remain" even across sessions.
*/
create_channel(channel_name);
ci = info[channel_name];
    }

    /* enforce the channel restrictions now */
    /* ### not super secure, but screw it :-) */
    if ( (ci->flags & CHANNEL_WIZ_ONLY) && !adminp(this_user()) )
    {
/* ### don't error... might prevent somebody from logging in */
return;
    }
    if ( (ci->flags & CHANNEL_ADMIN_ONLY) && !adminp(this_user()) && member_array(this_user()->query_userid(), SECURE_D->query_domain_members("admin-channels")) == -1)
    {
/* ### don't error... might prevent somebody from logging in */
return;
    }

    if ( add_hook )
    {
if ( member_array(listener, ci->hooked) == -1 )
ci->hooked += ({ listener });
    }
    else
    {
if ( member_array(listener, ci->listeners) == -1 )
ci->listeners += ({ listener });
    }
}

protected final void test_for_purge(string channel_name)
{
    channel_info ci = info[channel_name];

    if ( sizeof(ci->listeners) + sizeof(ci->hooked) == 0 )
map_delete(info, channel_name);
}

private void unregister_one(string channel_name, object listener)
{
    channel_info ci = info[channel_name];

    if ( ci )
    {
ci->listeners -= ({ listener });

/* purge the channel if it isn't permanent */
if ( undefinedp(permanent_channels[channel_name]) )
test_for_purge(channel_name);
    }
}

private void register_body(object body)
{
    array(string) names;

    if (functionp(body->query_channel_list)) {
        if ( !(names = body->query_channel_list()) ) return;
        map_array(names,register_one, 0, body);
    }
}

protected final void set_permanent(string channel_name, int is_perm)
{
    int no_exist = undefinedp(permanent_channels[channel_name]);

    if ( is_perm && no_exist )
    {
channel_info ci = info[channel_name];

permanent_channels[channel_name] = ci->flags;
save_me();
    }
    else if ( !is_perm && !no_exist )
    {
map_delete(permanent_channels, channel_name);
save_me();
    }
}

protected final void set_flags(string channel_name, int flags)
{
    channel_info ci = info[channel_name];

    ci->flags = flags;

    if ( !undefinedp(permanent_channels[channel_name]) )
    {
permanent_channels[channel_name] = flags;
save_me();
    }
}

/*
** user_channel_name()
**
** Return a channel name that a user might like. Internal names are
** not "human readable"
*/
final string user_channel_name(string channel_name)
{
    channel_info	ci = info[channel_name];

    if ( ci )
return ci->name;

    return extract_channel_name(channel_name);
}

/*
** register_channels()
**
** Register previous_object() with a specific set of channels.
*/
final void register_channels(array(string) names)
{
  /* First filter out the channels that don't exist, otherwise the channel
* will be created. If the channel's not created, we don't want it to be
* done so automatically here. */
  // names=names&keys(info);
  map_array(names, register_one, 0, previous_object() );
}

/*
** unregister_channels()
**
** Un-register previous_object() from a specific set of channels. If
** the list is 0, then unregister from all channels.
*/
final void unregister_channels(array(string) names)
{
    if ( !names )
names = keys(info);

    map_array(names, unregister_one , previous_object());
}

/*
** find_sender_name()
**
** Find the sender's name
*/
private final string find_sender_name(string sender_name)
{
    if ( sender_name )
return sender_name;

    if ( this_body() )
if ( sender_name = this_body()->query_name() )
return sender_name;

    if ( !(sender_name = previous_object()->query_name()) )
sender_name = "<unknown>";

    return sender_name;
}

/*
** deliver_string()
**
** Deliver a raw string over a channel.
*/
final void deliver_string(string channel_name, string str)
{
    channel_info ci = info[channel_name];
    if ( !ci ||	sizeof(ci->listeners) == 0 )
return;

    ci->history += ({ str });
    if ( sizeof(ci->history) > CHANNEL_HISTORY_SIZE ) {
      ci->history = ci->history[1..];
    }
    ci->listeners->channel_rcv_string(channel_name, str);
}

/*
** deliver_channel()
**
** Deliver a string to a channel, prepending the channel name
*/
final void deliver_channel(string channel_name, string str)
{
    deliver_string(channel_name,
sprintf(CHANNEL_FORMAT(channel_name),
user_channel_name(channel_name),
str));
}

/*
** deliver_raw_soul()
**
** Deliver raw "soul" data over a channel.
*/
final void deliver_raw_soul(string channel_name, array(mixed) data)
{
    channel_info ci = info[channel_name];

    if ( !ci ||	sizeof(ci->listeners) == 0 )
return;

    ci->history += ({ data[1][-1] });
    if ( sizeof(ci->history) > CHANNEL_HISTORY_SIZE ) {
        ci->history = ci->history[1..];
    }

    ci->listeners->channel_rcv_soul(channel_name, data);
}

/*
** deliver_data()
**
** Deliver unformatted channel data to the listeners
*/
private final void deliver_data(string channel_name,
string sender_name,
string type,
mixed data)
{
    channel_info ci = info[channel_name];

    if ( !ci ||	sizeof(ci->listeners) == 0 )
return;

    ci->listeners->channel_rcv_data(channel_name, sender_name, type, data);
}

/*
** deliver_tell()
**
** Deliver a standard-formatted "tell" over a channel
*/
final void deliver_tell(string channel_name,
string sender_name,
string message)
{
    sender_name = find_sender_name(sender_name);

    deliver_data(channel_name, sender_name, "tell", message);
    deliver_string(channel_name,
sprintf(CHANNEL_FORMAT(channel_name),
user_channel_name(channel_name),
sender_name + ": " + punctuate(message)));
}

/*
** deliver_emote()
**
** Deliver a standard-formatted "emote" over a channel
*/
final void deliver_emote(string channel_name,
string sender_name,
string message)
{
    if( !sizeof( message ))
    {
    write( "Emote what?\n" );
        return;
}
    sender_name = find_sender_name(sender_name);

    deliver_data(channel_name, sender_name, "emote", message);
    deliver_string(channel_name,
sprintf(CHANNEL_FORMAT(channel_name),
user_channel_name(channel_name),
sender_name + " " + punctuate(message)));
}


private mixed fmt_chan(mixed arg,string channel_name, string u_channel_name) {
	
	return sprintf(CHANNEL_FORMAT(channel_name), u_channel_name, arg[0..<2]);
}

/*
** deliver_soul()
**
** Deliver a standard-formatted "soul" over a channel
*/
final void deliver_soul(string channel_name, array(mixed) soul)
{
    string u_channel_name;

    deliver_data(channel_name, find_sender_name(0), "soul", soul);

    u_channel_name = user_channel_name(channel_name);
    soul = ({ soul[0] }) +
({ map_array(soul[1],fmt_chan,channel_name,u_channel_name)
       });

    deliver_raw_soul(channel_name, soul);
}

/*
** deliver_notice()
**
** Deliver a standard-formatted "system notice" over a channel
*/
final void deliver_notice(string channel_name,
string message)
{
    deliver_string(channel_name,
sprintf(CHANNEL_FORMAT(channel_name),
user_channel_name(channel_name),
"(" + message + ")"));
}

void create()
{
  listener_pair pair;
  
  info = ([ ]);
  map_array(users(), register_body);
  //::create();
  if ( saved_listeners )
    {
      foreach ( saved_listeners,pair )
{
object ob = find_object(pair->filename);

if ( ob )
register_one(0, ob, pair->channel_name);
}
      
      saved_listeners = 0;
    }
  if ( saved_hooks )
    {
      foreach ( saved_hooks,pair )
{
object ob = find_object(pair->filename);

if ( ob )
register_one(1, ob, pair->channel_name);
}
      
      saved_hooks = 0;
    }
  
  foreach (permanent_channels ;string channel_name; int flags)
    {
      channel_info ci;
      
      if ( !info[channel_name] )
create_channel(channel_name);
      
      ci = info[channel_name];
      ci->flags = flags;
    }
}

/*
** remove()
**
** Write out all listeners and hooks that are blueprints. We'll reset
** them at creation time.
*/
void remove() {
  string channel_name;
  channel_info ci;

  saved_listeners = ({ });
  saved_hooks = ({ });

  foreach ( info ;channel_name; ci) {
    object ob;

    foreach ( ci->listeners - ({ 0 }), ob) {
      string fname = file_name(ob);
      
      if ( member_array('#', fname) == -1 ) {
listener_pair pair = listener_pair();

pair->channel_name = channel_name;
pair->filename = fname;
saved_listeners += ({ pair });
      }
    }
    
    foreach (  ci->hooked - ({ 0 }),ob ) {
      string fname = file_name(ob);
      
      if ( member_array('#', fname) == -1 ) {
listener_pair pair = listener_pair();

pair->channel_name = channel_name;
pair->filename = fname;
saved_hooks += ({ pair });
      }
    }
  }
  
  save_me();
}


/*
** query_channels()
**
** Return the list of active channels
*/
final array(string) query_channels()
{
    return keys(info);
}

/*
** query_listeners()
**
** Return the listeners of a particular channel
*/
final array(object) query_listeners(string channel_name)
{

channel_info ci = info[channel_name];

if ( ci )
return ci->listeners;
    

    return 0;
}

/*
** query_flags()
**
** Return the flags for a particular channel. 0 is returned for unknown
** channels.
*/
final int query_flags(string channel_name)
{
    channel_info ci = info[channel_name];
    int flags;

    if ( !ci )
return 0;

    flags = ci->flags;
    if ( !undefinedp(permanent_channels[channel_name]) )
flags |= CHANNEL_PERMANENT;

    return flags;
}

private int check_interactive(mixed ob) 
{
	return ob && interactive(ob);
}

/*
** make_name_list()
**
** Make a list of names given an array of players.
*/
final string make_name_list(array(mixed) list)
{
    /*
** Remove null objects, objects with no links (to interactive users),
** and link obs that are no longer interactive.
*/
    list = filter_array(list, check_interactive);
    return implode(list->query_userid(), ", ");
}

/*
** is_valid_channel()**
** Is the given string a valid channel name (as in command name) ? A list
** of internal names should be provided (such as the list a player is
** registered with). The internal channel name will be returned, or 0
** if the name does not correspond to a channel.
**
** Note: permanent channels will always be valid.
*/
final string is_valid_channel(string which,array(string) list)
{
  if(list)
    if(sizeof(list)>0)
    foreach (  list,string name )
if ( info[name] && (info[name])->name == which )
return name;
    foreach ( keys(permanent_channels),string name  )
if ( info[name] && (info[name])->name == which )
return name;
    return 0;
}