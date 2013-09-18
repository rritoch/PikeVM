
private  array(string) room_state = ({});
private  mapping room_state_extra_longs = ([]);

array(string) get_room_state_info()
{
  return copy(room_state);
}

int query_state(string state) 
{
    return member_array(state + "_on", room_state) != -1;
}

string|int query_state_desc(string state) {
	function f;
    if (member_array(state + "_on", room_state) != -1) {
        f = room_state_extra_longs[state + "_on"];        
        return f() || "";
    } else if (member_array(state + "_off", room_state) != -1) {
    	f = room_state_extra_longs[state + "_off"];
        return f() || "";
    }
    return 0; /* not a valid state */
}

void set_room_state(string state)
{
  room_state -= ({state+"_off",state+"_on"});
  room_state += ({state+"_on"});
}

void clear_room_state(string state)
{
  room_state -= ({state+"_on",state+"_off"});
  room_state += ({state+"_off"});
}

void set_state_description(string state, mixed desc)
{
  if((strlen(state) < 4) || ((state[<2..] != "_on")
&& (state[<3..] != "_off")))
    {
      error("State description must be state + _on or _off\n");
    }
  if(state[-3] == '_')
    {
      if((member_array(state, room_state) == -1) &&
(member_array(state[0..<3]+"_off",room_state) == -1))
clear_room_state(state[0..<3]);
    }
  else
    {
      if((member_array(state, room_state) == -1) &&
(member_array(state[0..<4]+"_on",room_state) == -1))
clear_room_state(state[0..<4]);
    }
  room_state_extra_longs[state] = desc;
}