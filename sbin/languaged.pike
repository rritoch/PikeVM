
#include "/includes/mudlib.h"

inherit M_PREPOSITIONS;
inherit "/lib/mudlib/secure/modules/m_messages.pike";

#define USE_PARSER
//#define DEBUG_PARSER

array(string) tokens = ({"WRD","STR","OBJ","OBS","LIV","LVS"});

mapping verb_obs = ([]);
mapping verb_syns = ([]);

class parse_context 
{    
    string verb;
    string args;
    int offset;
    string syntax;
    array(mixed) matches;
    array(mixed) matches_raw;
    object caller;    
}

protected void log(mixed ... args) 
{
    if (sizeof(args) > 1) {
        kernel()->console_write(sprintf("[LANGUAGED] %s\n",sprintf(@args)));
    } else if (sizeof(args) == 1) {
        kernel()->console_write(args[0]);    
    }
}

mixed parser_root_environment( object ob ) 
{
    object tmp;
    while ( 
        (tmp = environment(ob)) &&
        functionp(ob->parent_environment_accessible) &&
        ob->parent_environment_accessible() ) {
        ob = tmp;
    }
    return ob;
}

mixed deep_useful_inv_parser_formatted(object ob)
{
  mixed ret = ({});
  array(object) inv;
  array(object) next_inv;

  if(!(functionp(ob->inventory_accessible) && ob->inventory_accessible())) {
    return 0;
  }
  inv = all_inventory(ob);
  if(!sizeof(inv)) {
    return 0;
  }
  foreach( inv,object item)
  {
    next_inv = deep_useful_inv_parser_formatted(item);
    if(!next_inv)
      ret += ({ item });
    else
      ret += ({ item, next_inv });
  }
  return ret;
}

public string normalize_str(string str) 
{
    int len;
    string parsed_str = lower_case(str);
            
    parsed_str = replace(parsed_str,"\t"," ");
    
    len = sizeof(parsed_str);
    parsed_str = replace(parsed_str,"  "," ");
    while(strlen(parsed_str) != len) {
        len = sizeof(parsed_str);
        parsed_str = replace(parsed_str,"  "," ");
    }
    
    parsed_str = replace(parsed_str,", and ",",");
    parsed_str = replace(parsed_str," and ",",");
    parsed_str = replace(parsed_str,", or ",",");
    parsed_str = replace(parsed_str," or ",",");
    parsed_str = replace(parsed_str," ,",",");
    parsed_str = replace(parsed_str,", ",",");
    
    parsed_str = trim(parsed_str);
    
    return parsed_str;
} 

object|int locate_object(string id, object|void ref) 
{
    array(object) items;
    mixed env;
    
    if (!ref) {
        ref = previous_object();
    }
    
    items = all_inventory(ref);
    if (env = environment(ref)) {
        items += all_inventory(env);
    }
    
    items -= ({ref});
    
    
    foreach(items, object ob) {
        if (ob->id(id)) {
            return ob;
        }
    }
    
    return 0; 
    
}


object|int locate_living(string id, object|void ref) 
{
    array(object) items;
    mixed env;
    
    if (!ref) {
        ref = previous_object();
    }
    
    items = all_inventory(ref);
    if (env = environment(ref)) {
        items += all_inventory(env);
    }
    
    items -= ref;
    
    
    foreach(items, object ob) {
        if (ob->id(id) && functionp(ob->is_living) && ob->is_living()) {
            return ob;
        }
    }
    
    return 0; 
    
}

private int match_rule(string rule, mixed context) 
{
    int ret = 0;
    int ptr;
    string id;    
    int next_token,next_word;
    string e_args = context["args"][(context["offset"])..];
    mixed n_context;
    string cur_word,cur_token;
    mixed tmp;
    int multi;
    array(string) ids;
    array(object) ob_matches;
    
#ifdef DEBUG_PARSER
    log("match_rule(rule=%O,context=%O)",rule,context);
    log("context[args] = %O e_args = %O",context["args"],e_args);
#endif    
        
    if (zero_type(context["caller"])) {
        context["caller"] = previous_object();
    }
    
    rule = trim(rule);
    
    if (e_args == "") {
        if (rule == "") {
            ret = 1;
            if (!(stringp(context["syntax"]) && sizeof(context["syntax"]))) {
                context["syntax"] = ""; 
            }
        }
        ret = rule == "" ? 1 : 0;
#ifdef DEBUG_PARSER
        log("match_rule() returning %O",ret);
#endif        
        return ret;
    }    
            
    next_token = search(rule,' ');
    
    // this should be safe, trim should have removed leading spaces
    cur_token = next_token == -1 ? rule : rule[0..(next_token-1)];
    
    next_word = search(e_args,' ');
    
    n_context = parse_context();
    n_context->caller = context["caller"];
    n_context->verb = context["verb"];
    n_context->args = context["args"];
    n_context->matches = context["matches"];    
            
    if (next_word == -1) {
           cur_word = e_args;           
           multi = search(e_args,',') == -1 ? 0 : 1;
        n_context->offset = sizeof(n_context->args);                                
    } else {
        cur_word = next_word > 0 ? e_args[0..(next_word-1)] : "";                         
        multi = -1 == search(cur_word,",") ? 0 : 1;                
           n_context->offset = context["offset"] + next_word + 1;                
    }    
    
    
    switch(cur_token) {
        case "LIV":
            if (multi) {
                ret = 0;
            } else {
                tmp = locate_living(cur_word,context["caller"]);
                if (tmp) {
                    n_context->matches += ({ tmp });            
                    if (stringp(context["syntax"]) && sizeof(context["syntax"])) {
                        n_context->syntax += "_liv"; 
                    } else {
                        n_context->syntax = "liv";
                    }
                    ret = match_rule(rule[(next_token+1)..],n_context);                     
                } else {
                    ret = 0;
                }
            }
        case "LVS":
            // verify each is living
            ids = cur_word / ",";
            ob_matches = ({});
                                 
            foreach(ids, id) {
                tmp = locate_living(id,context["caller"]);
                if (tmp) {
                    ob_matches += ({tmp});
                }
            }
            
            if (sizeof(ob_matches) == sizeof(ids)) {                
                n_context->matches += ({  ob_matches });            
                if (stringp(context["syntax"]) && sizeof(context["syntax"])) {
                    n_context->syntax += "_liv"; 
                } else {
                    n_context->syntax = "liv";
                }                
                ret = match_rule(rule[(next_token+1)..],n_context);
            } else {
                ret = 0;
            }
            
        case "OBJ":
            if (multi) {
                ret = 0;
            } else {
                tmp = locate_object(cur_word,context["caller"]);
                if (tmp) {
                    n_context->matches += ({ tmp });            
                    if (stringp(context["syntax"]) && sizeof(context["syntax"])) {
                        n_context->syntax += "_obj"; 
                    } else {
                        n_context->syntax = "obj";
                    }
                    ret = match_rule(rule[(next_token+1)..],n_context);                     
                } else {
                    ret = 0;
                }
            }
        case "OBS":
            ids = cur_word / ",";
            ob_matches = ({});
                                 
            foreach(ids, id) {
                tmp = locate_object(id,context["caller"]);
                if (tmp) {
                    ob_matches += ({tmp});
                }
            }
            
            if (sizeof(ob_matches) == sizeof(ids)) {                
                n_context->matches += ({  ob_matches });            
                if (stringp(context["syntax"]) && sizeof(context["syntax"])) {
                    n_context->syntax += "_liv"; 
                } else {
                    n_context->syntax = "liv";
                }                
                ret = match_rule(rule[(next_token+1)..],n_context);
            } else {
                ret = 0;
            }            
            
        case "WRD":            
            if (multi) {
                ret = 0;
            } else {                                    
                n_context->matches += ({ cur_word });            
                if (stringp(context["syntax"]) && sizeof(context["syntax"])) {
                    n_context->syntax += "_wrd"; 
                } else {
                    n_context->syntax = "wrd";
                }                                    
                ret = match_rule(rule[(next_token+1)..],n_context);
            }            
            break;            
        case "STR":
                
            ptr = n_context->offset;
            n_context->matches += ({ cur_word });            
            if (stringp(context["syntax"]) && sizeof(context["syntax"])) {
                n_context->syntax += "_wrd"; 
            } else {
                n_context->syntax = "wrd";
            }
            
            ret = match_rule(rule[(next_token+1)..],n_context);
            while((!ret) && n_context->offset < sizeof(context["args"])) {
                
                n_context = parse_context();
                n_context->caller = context["caller"];
                n_context->verb = context["verb"];
                n_context->args = context["args"];
                n_context->matches = context["matches"];    
                e_args = context["args"][(ptr)..];
                
                if (next_word == -1) {
                       cur_word = e_args;                                  
                    n_context->offset = sizeof(n_context->args);                                
                } else {
                    cur_word = next_word > 0 ? e_args[0..(next_word-1)] : "";                                                 
                       n_context->offset = ptr + next_word + 1;                
                }                
                
                ptr = n_context->offset;
                
                n_context->matches += ({ context["args"][(context["offset"])..(ptr-1)] });            
                if (sizeof(context["syntax"])) {
                    n_context->syntax += "_wrd"; 
                } else {
                    n_context->syntax = "wrd";
                }
                                
                ret = match_rule(rule[(next_token+1)..],n_context);
            }        
        
        default:
            // at, in, with, into
            // handle explicit match
            if (cur_token != cur_word) {
                ret = 0;
            } else {                            
                if (stringp(context["syntax"]) && sizeof(context["syntax"])) {
                    n_context->syntax += "_"; 
                } else {
                    n_context->syntax = "";
                }                
                n_context->syntax += lower_case(cur_word);
                n_context->matches += ({ cur_word });                                                
                ret = match_rule(rule[(next_token+1)..],n_context);
            }
            break;
    }

    if (ret) {
        context["matches"] = n_context->matches;
        context["syntax"] = n_context->syntax;                
    } else {
        context["matches"] = ({});
        context["syntax"] = "";
    }
#ifdef DEBUG_PARSER
        log("match_rule() returning %O",ret);
#endif     
    return ret; 
}

mixed parse_sentence(string str,mixed|void debug, mixed|void objs) 
{
    
#ifdef DEBUG_PARSER
    log("parse_sentence(str=%O,debug=%O,objs=%O)",str,debug,objs);
#endif        
    object context = parse_context();
    object base_context = parse_context();
    string parsed_str = normalize_str(str);
    object caller = previous_object();
    object handler;
    
    array(string) rparts;
    mixed result;
    
    base_context->verb = (parsed_str/" ")[0];
    base_context->args = ((parsed_str/" ")[1..]) * " ";
    
#ifdef DEBUG_PARSER
    log("base_context->verb = %O",base_context->verb);
    log("base_context->args = %O",base_context->args);
#endif
    
    array rule_list = ({});
    
    if (!zero_type(verb_obs[base_context->verb])) {
        rule_list += verb_obs[base_context->verb];
    }
    
    if (!zero_type(verb_syns[base_context->verb])) {
        rule_list += verb_syns[base_context->verb];
    }
    
#ifdef DEBUG_PARSER
    log("rule_list = %O",rule_list);
#endif
            
    foreach(rule_list, mixed rule) {
        array rparts = rule[0] / " ";
        handler = rule[1];
        
        context = parse_context();
        context->verb = base_context->verb;
        context->args = base_context->args;
        context->offset = 0;
        context->caller = caller;
        context->matches = ({});
        context->matches_raw = ({});
        
        if (match_rule(rule[0],context)) {
#ifdef DEBUG_PARSER
    log("RULE MATCH! Checking %O in %O (base_context->verb= %O, context->syntax = %O)","can_"+base_context->verb+context->syntax,handler,base_context->verb,context->syntax);
#endif            
               if (functionp(handler["can_"+base_context->verb+context->syntax])) {
#ifdef DEBUG_PARSER
    log("%O has %O",handler,"can_"+base_context->verb+context->syntax);
#endif             result = handler["can_"+base_context->verb+context->syntax](@(context->matches + context->matches_raw));
                   if (1 == result) {
                       handler["do_"+base_context->verb+context->syntax](@(context->matches + context->matches_raw));
                   } else if (stringp(result)) {
                       write(result);
                   }
                   
                   
                   return 1;                   
               } else {
#ifdef DEBUG_PARSER
    log("%O missing %O",handler,"can_"+base_context->verb+context->syntax);
#endif               	
               }
        }
                            
    }

    return 0;
}

void parse_add_rule(string verb, string rule, int|void flags) 
{
#ifdef DEBUG_PARSER
    log("parse_add_rule(verb=%O,rule=%O,flags=%O) called by %O",verb,rule,flags,previous_object());
#endif
    verb_obs[verb] += ({ ({ rule, previous_object() }) });
}

void parse_add_synonym(string syn, string verb, void | string rule) 
{
    array val2;
#ifdef DEBUG_PARSER
    log("parse_add_synonym(syn=%O,verb=%O,rule=%O)",syn,verb,rule);
#endif
    if (zero_type(verb_syns[syn])) {
        verb_syns[syn] = ({});
    }
    
    if (zero_type(rule)) {
        if (!zero_type(verb_obs[verb])) {
            foreach(verb_obs[verb], array val) {
                val2 = val + ({ verb });
                verb_syns[syn] += ({ val2 });
            }
        }
    } else {
        verb_syns[syn] += ({ ({ rule, previous_object(), verb }) });
    }
}

mapping(object:mixed) registry = ([]);

void parse_init() 
{
    object caller = previous_object();
    if (zero_type(registry[caller])) {
        registry[caller] = ({});
    }
}

void parse_refresh() 
{
    // clear cache
}

void parse_remove(string verb) 
{
    
}

void parse_dump() 
{
     
}

void parse_my_rules(object ob, string rule, int|void flags) 
{
    
}
 
int main(int argc, array(string) argv, mixed env) 
{
    return 0;
}
