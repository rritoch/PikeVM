
#include <daemons.h>

#define USER_CHANNELS ({"newbie", "gossip" })
#define ADMIN_CHANNELS ({"admin", "errors", "announce", "news" })

void save_me();
void receive_private_msg(string msg,array(object)|void exclude,
int|void message_type,mixed|void other);

private array(string) channel_list;

protected void setup_channels() {
  int i;
  string chan;
  
  channel_list=USER_CHANNELS;
  if(adminp(this_object()))
    channel_list+=ADMIN_CHANNELS;
    for(i=0;i<sizeof(channel_list);i++) {
        chan = channel_list[i];
        printf("Tuning in the %s channel (%s /on)\n",chan,chan);
    }
}

/*
* Initialize the users channels
*/
protected void initialize_channels() {
  if(undefinedp(channel_list))
    setup_channels();
  CHANNEL_D->register_channels(channel_list);
}

/*
* Ok, we're leaving. Unregister us from the channels
*/
protected void exit_all_channels() {
  CHANNEL_D->unregister_channels(channel_list);
}

//:FUNCTION add_channel
//Add a channel that the user is listening to
void add_channel(string which_channel) {
    channel_list += ({ which_channel });
    CHANNEL_D->register_channels(({ which_channel }));
    save_me();
}

//:FUNCTION remove_channel
//Remove a channel that the user is listening to.
void remove_channel(string which_channel) {
    channel_list -= ({ which_channel });
    CHANNEL_D->unregister_channels(({ which_channel }));
    save_me();
}

array(string) query_channel_list() 
{
    return channel_list;
}

void channel_rcv_string(string channel_name, string msg)
{
  receive_private_msg(msg);
}

void channel_rcv_soul(string channel_name, array data)
{
    string msg;

    if ( data[0][0] == this_object() )
msg = data[1][0];
    else if ( sizeof(data[0]) == 2 && data[0][1] != this_object() )
msg = data[1][2];
    else
msg = data[1][1];

    receive_private_msg(msg);
}

void channel_add(string which_channel)
{
    channel_list += ({ which_channel });
    CHANNEL_D->register_channels(({ which_channel }));
}

void channel_remove(string which_channel)
{
    channel_list -= ({ which_channel });
    CHANNEL_D->unregister_channels(({ which_channel }));
}
