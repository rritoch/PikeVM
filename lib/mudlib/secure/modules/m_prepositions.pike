
mapping oneword_preps = ([
  "aboard" : "on",
  "above" : "on",
  "against" : "near",
  "alongside" : "near",
  "below" : "under",
  "beneath" : "under",
  "beside" : "near",
  "besides" : "near",
  "by" : "near",
  "inside" : "in",
  "into" : "in",
  "onto" : "on",
  "outside" : "out",
  "through" : "in",
  "underneath" : "under",
  "upon" : "on",
  "within" : "in",
  "without" : "out" ]);

mapping twoword_preps = ([
  "alongside of" : "near",
  "back of" : "near",
  "down from" : "down",
  "inside of" : "in",
  "round about" : "near",
  "near to" : "near",
  "next to" : "near",
  "off of" : "off",
  "over to" : "over",
  "outside of" : "out",
  "out of" : "out",
  "out from" : "out",
  "up to" : "up" ]);

mapping threeword_preps = ([

  "in front of" : "before",
  "in back of" : "behind",
  "on top of" : "on" ]);

mapping preposition_mappings() {
   return oneword_preps + twoword_preps + threeword_preps;
}

array consolidated_preps() {
    return clean_array(values(oneword_preps) + values(twoword_preps) +
                       values(threeword_preps));
}

string translate_preposition(string prep) {
    if (oneword_preps[prep])
        return oneword_preps[prep];
    if (twoword_preps[prep])
        return twoword_preps[prep];
    if (threeword_preps[prep])
        return threeword_preps[prep];
    return prep;
}

