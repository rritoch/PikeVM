
#include "/includes/mudlib.h"
#include "/includes/mudlib/msgtypes.h"

inherit CLASS_CHANNEL_INFO;

channel_info query_channel_info(string channel_name);
string user_channel_name(string channel_name);
void deliver_notice(string channel_name, string message);
string make_name_list(array(mixed) list);


/*
** print_mod_info()
**
** Print moderator/speak infor for a moderated channel.
*/
protected final void print_mod_info(string channel_name)
{
    channel_info ci = query_channel_info(channel_name);

    if ( !ci->moderator )
return;

    printf("It is being moderated by %s.\n", ci->moderator->query_name());

    if ( ci->speaker )
printf("The current speaker is %s.\n", ci->speaker->query_name());
    else
printf("There is no current speaker.\n");

    if ( ci->moderator == this_body() )
    {
if ( !ci->requestors ||
!sizeof(ci->requestors) )
printf("There are no requestors.\n");
else
tell(this_user(), sprintf("Requestors are: %s.\n",
                 make_name_list(ci->requestors)), MSG_INDENT);
    }
    else if ( member_array(this_body(), ci->requestors) != -1 )
    {
printf("Your hand is raised to speak.\n");
    }
}


/* this is used when signing off from a channel... */
protected final void moderation_signoff(string channel_name)
{
    channel_info ci = query_channel_info(channel_name);

    if ( !ci )
return;

    if ( this_body() == ci->moderator )
    {
ci->moderator = ci->speaker = ci->requestors = 0;

deliver_notice(channel_name, "This channel is now unmoderated");
    }
    else if ( this_body() == ci->speaker )
    {
ci->speaker = 0;
deliver_notice(channel_name,
sprintf("%s is no longer speaking",
this_body()->query_name()));
    }
}

private int lc_match(mixed ob, string arg) 
{
	return arg == lower_case(ob->query_name());
}

protected final int cmd_moderation(string channel_name, string arg)
{
    channel_info ci = query_channel_info(channel_name);
    string user_channel_name = user_channel_name(channel_name);
    object tb = this_body();
    string sender_name = tb->query_name();

    if ( arg == "/raise" )
    {
if ( !ci->moderator )
{
printf("'%s' is not moderated.\n", user_channel_name);
}
else if ( tb == ci->speaker )
{
printf("You are already speaking on '%s'.\n", user_channel_name);
}
else if ( member_array(tb, ci->requestors) == -1 )
{
printf("Your raise your hand to speak on '%s'.\n",
user_channel_name);
ci->requestors += ({ tb });
ci->moderator->channel_rcv_string(channel_name,
sprintf("[%s] (%s raises a hand to speak)\n",
user_channel_name,
sender_name));
}
else
{
printf("You already have your hand raised to speak on '%s'.\n",
user_channel_name);
}
    }
    else if ( arg == "/lower" )
    {
if ( !ci->moderator )
{
printf("'%s' is not moderated.\n", user_channel_name);
}
else if ( member_array(tb, ci->requestors) != -1 )
{
printf("Your lower your hand to avoid speaking on '%s'.\n",
user_channel_name);
ci->requestors -= ({ tb });
ci->moderator->channel_rcv_string(channel_name,
sprintf("[%s] (%s lowers a hand)\n",
user_channel_name,
sender_name));
}
else
{
printf("Your hand is not raised to speak on '%s'.\n",
user_channel_name);
}
    }
    else if ( arg[0..4] == "/call" )
    {
arg = lower_case(trim_spaces(arg[5..]));
if ( !ci->moderator )
{
printf("'%s' is not moderated.\n", user_channel_name);
}
else if ( ci->moderator != tb )
{
printf("You are not the moderator of '%s'.\n", user_channel_name);
}
else if ( arg == "" )
{
if ( sizeof(ci->requestors) == 0 )
{
printf("Nobody has their hand raised.\n");
}
else
{
ci->speaker = ci->requestors[0];
ci->requestors = ci->requestors[1..];
deliver_notice(channel_name,
sprintf("%s will now speak",
ci->speaker->query_name()));
}
}
else
{
array(object) spkr;

spkr = filter_array(ci->requestors,
lc_match,arg);
if ( sizeof(spkr) == 0 )
{
printf("'%s' was not found (or did not have their hand raised.\n",
capitalize(arg));
}
else
{
ci->speaker = spkr[0];
ci->requestors -= ({ spkr[0] });
deliver_notice(channel_name,
sprintf("%s will now speak",
ci->speaker->query_name()));
}
}
    }
    else if ( arg == "/moderate" )
    {
if ( 

    adminp(this_user()) 

#ifdef GROUP_D
    || GROUP_D->member_group(this_user()->query_userid(), "moderators") 
#endif

) {
ci->moderator = tb;
if ( !ci->requestors )
ci->requestors = ({ });
deliver_notice(channel_name,
sprintf("%s is now moderating", sender_name));
}
else
{
printf("You are not allowed to moderate this channel.\n");
}
    }
    else
    {
/* not handled */
return 0;
    }

    /* handled */
    return 1;
}
