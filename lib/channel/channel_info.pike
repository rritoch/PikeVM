
class channel_info
{
    string	name;

    array(object)	listeners;
    array(object)	hooked;

    int	flags;

    object	moderator;
    object	speaker;
    array(object)	requestors;

    array(mixed)	history;
}