
mapping messages =
([

  "living-default" :
  ([
    "leave": "$N $vleave $o.",
    "mleave": "$N $vdisappear in a puff of smoke.",
    "enter": "$N $venter.",
    "menter": "$N $vappear in a puff of smoke.",
    "invis": "$N $vfade from view.",
    "vis": "$N $vfade into view.",
    "home": "$N $vgo home.",
    "clone": "$N $vclone the $o.",
    "destruct": "$N $vdest the $o.",
    "fol_leave": "$N $vfollow $t $o.",
    "fol_enter": "$N $venter following $t.",
    "clean": "$N $vtake a broom and $vclean $p surroundings.",
    ]),

  "nonsense" : ({
      "That doesn't seem to work.",
      "A noble attempt.",
      "You can't be serious.",
      "You don't make any sense.",
      "An interesting idea.",
      "What a concept!",
      "Seriously?",
      "Not very likly.",
  }),
  "discarded" : ({
      "Someone has left %s lying on the ground.",
      "It seems that someone has left %s lying here.",
      "%s lies here, discarded.",
      "%s lies at your feet.",
      "Some luckless fool has left %s here.",
      "%s lies here, abandoned.",
  }),
  "discarded-plural" : ({
      "Someone has left %s lying on the ground.",
      "It seems that someone has left %s lying here.",
      "%s lie here, discarded.",
      "%s lie at your feet.",
      "Some luckless fool has left %s here.",
      "%s lie here, abandoned.",
  }),
  
  
  ]);

mixed get_messages(string type) {
    return messages[type];
}

