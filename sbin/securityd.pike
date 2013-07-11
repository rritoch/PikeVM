/**
 *                                                                            
 *   security.pike                                                           
 *   (c) 2011 Ralph Ritoch                                                    
 *                                                                            
 *   Security system                                                                            
 */

#include <stdio.h>

class tagreader {
 protected mixed read_tag(int fh) {
  mapping(string:mixed) ret;
  
  return ret;
 }
}

inherit tagreader;

#define SECURITY_KEY "xxx123"

//#define DEBUG_SECURITY
#define SECURITY_DATAFILE "/var/security/secinfo.xml"

#define SERR_NOGROUP(X) sprintf("Group %O not found!",X)
#define AUTOSAVE_DELAY 300

#define SECURITY_NAMESPACE = "urn:pikeos:security"

/* Goals 

 1> users can create groups where they are group leader
 2> group leader can assign users to groups

/*
 * create_group team_1
*/


class securityGroupList 
{
    inherit libstdio;
    inherit tagreader;
  
    mapping(string:object) groups;
  
    void add(string name) 
    {      
        if (zero_type(groups[name])) 
            groups[name] = securityGroup(name);
    }
    
    object get(string name) {
        return groups[name];
    }
    
    array(string) listGroups() {
        return indices(groups);
    }
    
    static void create(string | void group_id) 
    {
        groups = ([]);
    }
    
    int read_xml(int fh) {
        return 1;
    }
    
    string to_xml(int | void xlevel, int | void fh) {
        string ret;
        string txt;
        string node_id;
            
        string prefix = "";
        if (xlevel) {
            prefix = " " * xlevel;
        } else {
            xlevel = 0;
        }   
        
        txt = prefix + "<securityGroupList>\r\n";
        
        if (fh) fprintf(fh,"%s",txt);        
        ret += txt;
        
        foreach(indices(groups),node_id) {
            ret += groups[node_id]->to_xml(xlevel + 1,fh) + "\r\n";
            if (fh) fprintf(fh,"\r\n");
        }        
                        
        txt = prefix + "</securityGroupList>";
        if (fh) fprintf(fh,"%s",txt);        
        ret += txt;        
        return ret;  
    }
    
    // end class securityGroupList        
}

class securityGroup {

 inherit libstdio;
 inherit tagreader;
 
 string group_id;
 
 object childGroups;
 
 mapping(string:multiset) privs;
 
 multiset admin; /* admin can assign admin, supers, privileges */
 mapping(string:string) supers; /* leaders can assign members */
 mapping(string:string) members;
 
 int has_assigned_privilege(string obj_id, string priv_id) {
 
 }

 int add_privilege(string priv_path,string priv_id) {
  if (zero_type(privs[priv_path])) {
   privs[priv_path] = (<>);
  }
  privs[priv_path][priv_id] = 1;
  return 0;
 }

 int add_admin(string user) {
  string w;
  w = "";
  if (this_user() && functionp(this_user()->user_id)) {
   w = this_user()->user_id();
  }
  supers[user] = w;
  admin[user] = 1;
  return 0;
 }

 int add_super(string user) {
  string w;
  w = "";
  if (this_user() && functionp(this_user()->user_id)) {
   w = this_user()->user_id();
  }
  supers[user] = w;
  return 0;
 }
  
 int add_user(string user) {
  string w;
  w = "";
  if (this_user() && functionp(this_user()->user_id)) {
   w = this_user()->user_id();
  }
  members[user] = w;
  return 0;
 }
 
    int add_group_node(string name) 
    {
        childGroups->add(name);
    }
 
    object get_group_node(string name) 
    {
        return childGroups->get(name);
    }
 
    mixed _sprintf(mixed t) 
    {
        if (t == 'O') {
            return "securitygroup(" + group_id + ")";
        }
    }
 
 int read_xml(int fh) {
  return 1;
 }
 
 string to_xml(int | void xlevel, int | void fh) {
  string ret;
  string msg;
  
  string user_id;
  //string node_id;
  string priv_path;
  string priv_id;
  
  string prefix = "";
  if (xlevel) {
   prefix = " " * xlevel;
  } else {
   xlevel = 0;
  }
      
  ret = prefix + "<securitygroup name=\"" + group_id + "\">\r\n";

  if (fh) fprintf(fh,"%s",ret);  
  
  msg = "";
  foreach(indices(admin), user_id) {
   msg += prefix + " <admin>" + user_id + "</admin>\r\n";     
  }
  ret += msg;
  if (fh) fprintf(fh,"%s",msg);

  msg = "";
  foreach(indices(supers), user_id) {
   msg += prefix + " <super>" + user_id + "</super>\r\n";      
  }
  ret += msg;
  if (fh) fprintf(fh,"%s",msg);

  msg = "";
  foreach(indices(members), user_id) {
   msg += prefix + " <member>" + user_id + "</member>\r\n";
  }
  ret += msg;  
  if (fh) fprintf(fh,"%s",msg);
  
  msg = "";
  foreach(indices(privs), priv_path) {
   msg += prefix + "<privilegegroup path=\"" + priv_path + "\">\r\n";
    foreach(indices(privs[priv_path]), priv_id) {
     msg += prefix + " <privilege>" + priv_id + "</privilege>\r\n";
    } 
   msg += prefix + "</privilegegroup>\r\n";
  }
  ret += msg;  
  if (fh) fprintf(fh,"%s",msg);
  
  ret += childGroups->to_xml(xlevel + 1,fh) + "\r\n";
  if (fh) fprintf(fh,"\r\n");
  
  msg = prefix + "</securitygroup>";
  
  if (fh) fprintf(fh,"%s",msg);
  ret += msg;
  
  return ret;
 }

    object getSubGroups() 
    {
        return childGroups;
    }
 
    static void create(string grp) {
        childGroups = securityGroupList();
        if (grp) group_id = grp;
        admin = (<>);
        supers = ([]);
        members = ([]);
        privs = ([]);
    }
}

class path_tree {
 inherit libstdio;
 inherit tagreader;
 
 mapping(string:object) nodes;
 multiset readers;
 multiset writers;
 multiset executers;
 string node_name;
 
 object get_node(string node_id) {
  return nodes[node_id];
 }
 
 object add_node(string node_id) {
  if (zero_type(nodes[node_id])) {
   nodes[node_id] = path_tree(node_id);
  }
 }

 array(mixed) list_groups() { 
  return ({ indices(readers), indices(writers), indices(executers) });
 } 
 int add_group(string group_id, int r, int w, int e) {
  readers[group_id] = r;
  writers[group_id] = w;
  executers[group_id] = e;
 }

 int read_xml(int fh) {
  return 1;
 }
 
 string to_xml(int | void xlevel, int | void fh) {
  string ret;
  string msg;
  
  string group_id;
  string node_id;
  string prefix = "";
  if (xlevel) {
   prefix = " " * xlevel;
  } else {
   xlevel = 0;
  }
  
  if (node_name) {  
   msg = prefix + "<path name=\"" + node_name + "\">\r\n";
  } else {
   msg = prefix + "<paths>\r\n"; 
  }
  if (fh) fprintf(fh,"%s",msg);
  ret = msg;
  
  msg = "";
  foreach(indices(readers), group_id) {
   msg += prefix + " <reader>" + group_id + "</reader>\r\n";
  }  
  ret += msg;
  if (fh) fprintf(fh,"%s",msg);

  msg = "";  
  foreach(indices(writers), group_id) {
   msg += prefix + " <writer>" + group_id + "</writer>\r\n";
  }
  ret += msg;
  if (fh) fprintf(fh,"%s",msg);
  
  msg = "";
  foreach(indices(executers), group_id) {
   msg += prefix + " <executor>" + group_id + "</executor>\r\n";
  }
  ret += msg;
  if (fh) fprintf(fh,"%s",msg);
  
  foreach(indices(nodes),node_id) {
   ret += nodes[node_id]->to_xml(xlevel + 1,fh) + "\r\n";
   if (fh) fprintf(fh,"\r\n");
  }
  
  if (node_name) {
   msg = prefix + "</path>";
  } else {
   msg = prefix + "</paths>";
  }
  ret += msg;
  if (fh) fprintf(fh,"%s",msg);
  
  return ret;
 }
 
 string _sprintf(int | void t) {
  if (t == 'O') {
   return sprintf("path_tree(%O)",([ 
     "readers" : readers, 
     "writers" : writers, 
     "executers" : executers,
     "nodes" : nodes
    ]));
  } 
 }
 
 static void create(string | void node_id) {
  readers = (<>);
  writers = (<>);
  executers = (<>);
  nodes = ([]);
  if (node_id) node_name = node_id;
 }
}

class privilege_set {
 inherit libstdio;
 inherit tagreader;
 
 mapping(string:mixed) privs;
 
 mixed add_privilege(string priv_path, string priv_id, string priv_name, string priv_desc) {
   if (zero_type(privs[priv_path])) {
    privs[priv_path] = ([]);
   }
   privs[priv_path][priv_id] = ([
    "name" : priv_name ,
    "description" : priv_desc
   ]);
   return 0;
 }
 
 int privilege_exists(string priv_path, string priv_id) {
  if (zero_type(privs[priv_path])) return 0;  
  if (zero_type(privs[priv_path][priv_id])) return 0;
  return 1;
 }

 int read_xml(int fh) {
  return 1;
 }
 
 string to_xml(int | void x, int | void fh) {
  array(string) obs;
  array(string) ids;
  array(string) vars;
  string ob;
  string id;
  string v;
  string ret,msg;
  string prefix;
  
  if (!x) x = 0;
  
  prefix = " " * x;
  ret = "";
  
  msg = prefix + "<privileges>\r\n";
  
  ret += msg;
  if (fh) fprintf(fh,"%s",msg);
  
  msg = "";
  obs = indices(privs);  
  foreach(obs, ob) {
   msg += prefix + " <privilege path=\"" + ob + "\">\r\n";
   ids = indices(privs[ob]);
   foreach(ids,id) {
    msg += prefix + "  <id name=\"" + id + "\">\r\n";
    vars = indices(privs[ob][id]);
    foreach(vars,v) {
     msg += prefix + "   <var name=\"" + v + "\">" + privs[ob][id][v] + "</var>\r\n"; 
    }
    msg += prefix + "  </id>\r\n";
   }
   msg += prefix + " </privilege>\r\n";
  }
  ret += msg;
  if (fh) fprintf(fh,"%s",msg);
  
  msg = prefix + "</privileges>";
  ret += msg;
  if (fh) fprintf(fh, "%s",msg);

  return ret;
 }
 
 static void create() {
  privs = ([]);
 }
}


/* Start Main Program */

privilege_set privileges;
path_tree paths;
object groups;
mixed autosave_cb;


mixed add_group_to_path(string group_id, string path, int r, int w, int e) 
{
    object grp; 
    string id;
    array(string) pth;
  
    mixed ptr;
    
    grp = getGroup(group_id);
    if (!grp) {
        throw( ({ SERR_NOGROUP(group_id),backtrace() }) );
        return 1;
    }
 
    if (!is_absolute_path(path)) {
        throw( ({ "Invalid Path!",backtrace() }) );
        return 1;
    }
 
    ptr = paths;
    pth = explode_path(path);
    foreach(pth, id) {
        if (ptr) {
            ptr->add_node(id);     
            ptr = ptr->get_node(id);    
        }  
    }
    
    if (!ptr) {
        throw (({ "Unable to link to path!" , backtrace()}));
        return 0;
    }
 
    ptr->add_group(group_id,r,w,e);
    return 0;
}


mixed getGroup(string group_id) {
   array(string) parts;
   object ptr;
   object grp;
   string g;
   
   parts = group_id / ".";
   
   ptr = groups;
   
   foreach(parts, g) {
       if (ptr) {   
           grp = ptr->get(g);
           if (grp) {
               ptr = grp->getSubGroups(); 
           }
        }
    }

    if (ptr) {
        return grp;
    }

    return 0;
}

int create_group(string group_id) 
{
    array(string) parts;
    string new_group;
 
    string pgrp;
    
    object parent;
          
    parts = group_id / ".";
    new_group = parts[-1];
    parts = parts[..<1];
    pgrp = parts * ".";
            
    if (sizeof(parts) > 0) {
        parent = getGroup(pgrp);
        if (!parent) {
            throw(({ sprintf("Unable to create group %O. Parent group %O not found!",group_id, pgrp) , backtrace()}));
            return 1;         
        }
        parent->getSubGroups()->add(new_group);
        return 0;
    }
    
    groups->add(new_group);
    return 0;
}


array(string) list_groups(void | string group_id) {
   array(string) ret,grps,tmplist;
   
   ret = ({});
   
   object base;
   string cur;
   string prefix = "";
   
   if (group_id) {
       prefix = group_id+".";
       base = getGroup(group_id)->getSubGroups();     
   } else {
       base = groups;
   }
   
   grps = base->listGroups();
   
   foreach(grps,cur) {
       ret += ({ prefix+cur });       
       tmplist = list_groups(prefix+cur);
       
       if (sizeof(tmplist) > 0) {
           ret += tmplist;
       }   
   }

   return ret;
}

int add_privilege(string priv_id, string priv_name, string priv_desc) {
 string prev_object;
 prev_object = kernel()->describe_program(function_program(backtrace()[-2][2]));
 return privileges->add_privilege(prev_object, priv_id,priv_name,priv_desc);
}

mixed add_admin_to_group(string user_id, string group_id) 
{
    
    object gob;     
    gob = getGroup(group_id);    
    if (!gob) {
        return ({ SERR_NOGROUP(group_id) , backtrace() });
    }
    gob->add_admin(user_id);
    return 0;
}

array(object) get_assigned_groups(string path,
                                  int r_flag,
                                  int w_flag,
                                  int x_flag) {
 
 array(string) pp; 
 string p;
 object ptr,last_ptr;
 
 
 array(mixed) g_set;
 array(object) ret;
 
 pp = explode_path(path);
 ptr = paths;
 last_ptr = ptr;

#ifdef DEBUG_SECURITY
 //printf("pp = %O\n",pp);
#endif 
 
 foreach(pp, p) {
  if (ptr) {  
   last_ptr = ptr;
   ptr = ptr->get_node(p);
  } 
 }
 if (ptr) {
  last_ptr = ptr;
 }

#ifdef DEBUG_SECURITY
 //printf("last_ptr = %O\n",last_ptr);
#endif 
 g_set = last_ptr->list_groups();
 
 if (r_flag) pp += g_set[0];
 if (w_flag) pp += g_set[1];
 if (x_flag) pp += g_set[2];
 ret = ({});
 
 foreach(pp,p) {  
  ptr = getGroup(p);
  if (ptr) {  
   ret += ({ ptr });
  } 
 }
  
 return ret; 
}

mixed add_super_to_group(string user_id, string group_id) {
    object grp;
  
    grp = getGroup(group_id);
 
    if (!grp) {
        return ({ SERR_NOGROUP(group_id) , backtrace() });
    }
 
    grp->add_super(user_id);
    return 0;
}

mixed add_user_to_group(string user_id, string group_id) {

 object grp;
 
 grp = getGroup(group_id); 
 if (!grp) {
  return ({ SERR_NOGROUP(group_id) , backtrace() });
 }
 
 grp->add_user(user_id);
 return 0;
}

int assign_privilege(string priv_path, string priv_id, string group_id) 
{
    object grp;
 
    if (!privileges->privilege_exists(priv_path,priv_id)) { 
       throw(({ sprintf("Privilege %O %O not found!",priv_path,priv_id), backtrace() }));
       return 1;
    }
 
    grp = getGroup(group_id);
    if (!grp) {
       throw(({ sprintf("Group %O Not Found!",group_id), backtrace()}));
       return 1;
    }
 
    return grp->add_privilege(priv_path,priv_id);
}

int valid_read(object caller, string fn, mixed ... args) {
 array(object) have_groups;
 array(object) need_groups;
 object have;
 object need;
 object admin;
 string c_path;
 string r_path;
 
 r_path = fn;
 c_path = kernel()->describe_program(object_program(caller));
#ifdef DEBUG_SECURITY
 //printf("caller_path = %O\n",c_path);
#endif 
 have_groups = get_assigned_groups(c_path,0,1,0);
 have_groups += ({ getGroup("0") }); 
 need_groups = get_assigned_groups(r_path,1,0,0); 
#ifdef DEBUG_SECURITY
 //printf("have_groups = %O\n",have_groups);
 //printf("need_groups = %O\n",need_groups);
#endif

 admin = getGroup("1");
 foreach(have_groups, have) {
  if (have == admin) return 1;
 }  
 foreach(need_groups, need) {
  foreach(have_groups, have) {
   if (have == need) return 1;
  }
 }
 return 0;
}


int valid_write(object caller, string fn, mixed ... args) {
 array(object) have_groups;
 array(object) need_groups;
 object have;
 object need;
 object admin;
 string c_path;
 string r_path;
 
 r_path = fn;
 c_path = kernel()->describe_program(object_program(caller));
#ifdef DEBUG_SECURITY
 //printf("caller_path = %O\n",c_path);
#endif 
 have_groups = get_assigned_groups(c_path,0,1,0);
 have_groups += ({ getGroup("0") }); 
 need_groups = get_assigned_groups(r_path,0,1,0); 
#ifdef DEBUG_SECURITY
 //printf("have_groups = %O\n",have_groups);
 //printf("need_groups = %O\n",need_groups);
#endif
 admin = getGroup("1");
 foreach(have_groups, have) {
  if (have == admin) return 1;
 }  
 foreach(need_groups, need) {
  foreach(have_groups, have) {
   if (have == need) return 1;
  }
 }
 return 0;
}



int valid_stat(object caller, string fn, mixed ... args) {
 string r_path; 
 r_path = dirname(fn);
 return valid_read(caller,r_path);
}

/**
 * Check privilege authorization
 */ 

int valid(string priv, mixed ... args) {
 int ret;
 switch(priv) {
  case "stat":
   ret = valid_stat(@args);   
   break;
  case "read":
  case "read_dir":
   ret = valid_read(@args);
   break;
  case "write":
   ret = valid_write(@args);
   break; 
  default:
#ifdef DEBUG_SECURITY  
  fprintf(stderr,"securityd: valid(%O,%O)\n",priv,args);
#endif  
  ret = 1;
 }

#ifdef DEBUG_SECURITY 
 if (ret) {
  printf("valid(%O,%O) ALLOW\n",priv,args);
 } else {
  printf("valid(%O,%O) DENY\n",priv,args);
 }
#endif
 
 //return ret;
 return 1;
}

int has_privilege(string priv_id,object | void w) {
 
 array(mixed) bt;
 array(object) lgroups;
 object group;
 string priv_path,prev_object;
 
 if (!w) {
  w = function_object(bt[-3][2]); 
 } 
  
 prev_object = kernel()->describe_program(object_program(w));
 priv_path = kernel()->describe_program(function_program(bt[-2][2]));

 if (!privileges->privilege_exists(priv_path,priv_id)) {
  throw(({ sprintf("Privilege %O undefined!",priv_id),backtrace() }));
  return -1;
 }
 
 lgroups = get_assigned_groups(kernel()->describe_program(object_program(w)),0,1,0);
 foreach(lgroups,group) {
  if (group->has_assigned_privilege(prev_object,priv_id)) {
   return 1;
  }
 }
 return 0;  
}

private int read_xml(int fh) {
 return 1;
 int moretoread;
 mapping(string:mixed) tagdata;
 
 moretoread = 1;
 while (moretoread) {
  tagdata = read_tag(fh);
  if (!zero_type(tagdata["eof"])) {
   moretoread = 0;
  } else {
   switch(tagdata["tag"]) {
    case "securitygroups":
     moretoread = !groups->read_xml(fh);
     break;
    case "paths":
     moretoread = !paths->read_xml(fh);
     break;
    case "privileges":
     moretoread = !privileges->read_xml(fh);
     break;
    default:
     moretoread = 0;
     printf("Securityd: Error reading xml file!\n");
   }
  }
 }
}

string to_xml(int | void x, int|void fh) {
 string prefix;
 string ret;
 if (!x) x = 0;
 prefix = " " * x;
 
 ret = prefix + "<security>\n";
 if (fh) {
  fprintf(fh,"%s",ret);
 }
 
 ret += groups->to_xml(x + 1, fh) + "\n";
 ret += paths->to_xml(x + 1, fh) + "\n"; 
 ret += privileges->to_xml(x + 1) + "\n";
 
 ret += prefix + "</security>";
 if (fh) {
  fprintf(fh, "%s", prefix + "</security>");
 }
 
 return ret;
}

int save() {
 int fh;
 fh = fopen(SECURITY_DATAFILE,"w");
#ifdef DEBUG_SECURITY
 printf("securityd.pike: Saving with handle %O\n",fh);
#endif   
 if (fh) {
  this->to_xml(0,fh);
 }
 fclose(fh); 
}


int autosave() {
 save();
 autosave_cb = call_out(autosave,AUTOSAVE_DELAY);
}

static void destroy() {
 remove_call_out(autosave_cb);
 save();
 kernel()->unregister_security();
}

static void create() {
 int fh;
 mixed err;
 
 privileges = privilege_set();
 paths = path_tree();
 groups = securityGroupList();
 
 if ((fh = fopen(SECURITY_DATAFILE,"r")) > 0) {
  err = read_xml(fh);
 } else {
  err = 1;
 }
 if (err) {
  create_group("0");
  create_group("1");
  add_group_to_path("0","/",1,0,0);
  add_group_to_path("1","/",0,1,0);
 }
 autosave_cb = call_out(autosave,AUTOSAVE_DELAY);
 kernel()->register_security(SECURITY_KEY);
 
#ifdef DEBUG_SECURITY
    printf("%s",to_xml());
#endif
}
