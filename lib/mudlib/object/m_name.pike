
#include "/includes/mudlib/setbit.h"
#include <daemons.h>

private  array(string) ids;
private  array(string) plurals;
private  array(string) adjs;
private int quantity;
private string primary_id, primary_adj;

private  mixed internal_short;

private  int unique;

private  int plural;

private  mixed proper_name;


array(string) fake_item_id_list();
int is_visible();
string invis_name();
int test_flag(mixed);

 mixed call_hooks(string, mixed, mixed);
private void resync();
 string get_attributes(object ob);

protected final void name_create() 
{
    LANGUAGE_D->parse_init();
    ids = ({});
    plurals = ({});
    adjs = ({});
    resync();	
}

void create()
{
    name_create();
}

final void set_proper_name(string str)
{
    proper_name = str;
    resync();
}

//:FUNCTION set_unique
//Unique objects are always refered to as 'the ...' and never 'a ...'
void set_unique(int x)
{
    unique = x;
}

//:FUNCTION query_unique
//Return the value of 'unique'
int query_unique()
{
    return unique;
}

//:FUNCTION set_plural
//Plural objects are referred to as "the", not "a"
void set_plural( int x )
{
    plural = x;
}

//:FUNCTION query_plural
//Return the value of plural
int query_plural()
{
    return plural;
}


private void resync() {
    if (!proper_name) {
if (!primary_id && sizeof(ids))
primary_id = ids[0];
if (!primary_adj && arrayp(adjs) && sizeof(adjs))
primary_adj = adjs[0];

if (primary_id) {
if (primary_adj)
internal_short = primary_adj + " " + primary_id;
else
internal_short = primary_id;
}
else {
internal_short = "nondescript thing";
}
    } else
internal_short = proper_name;
    //parse_refresh();
}

mixed ob_state() {
    return internal_short;
}

//:FUNCTION short
//Return the 'short' description of a object, which is the name by which
//it should be refered to
string short()
{
    if (!is_visible()) {
        return invis_name();
    }
    return internal_short;
}

string plural_short() {
    if (!query_plural()) {
        return pluralize(short());
    }
    else return short();
}

void set_quantity( int x ){
    quantity = x;
}

int query_quantity()
{
    return quantity;
}

string add_article(string str) {
    if (quantity ) return "some " + str;
    switch (str[0]) {
    case 'a':
    case 'e':
    case 'i':
    case 'o':
    case 'u':
return "an "+str;
    }
    return "a "+str;
}

//:FUNCTION the_short
//return the short descriptions, with the word 'the' in front if appropriate
string the_short() {
    if(!is_visible())
return invis_name();

    if (!proper_name) return "the "+short();
    return proper_name;
}


string a_short() {
    if(!is_visible())
return invis_name();

    if (plural || unique) return the_short();
    if (!proper_name) return add_article(short());
    return proper_name;
}


int id(string arg)
{
    if(!arrayp( ids)) return 0;
    return member_array(arg,ids) != -1;
}

int plural_id( mixed arg ) {
    if( !arrayp( plurals)) return 0;
    return member_array(arg, plurals) != -1;
}

void add_adj(string ... adj)
{
    if(!arrayp(adjs)) {
        adjs = adj;
    } else{
        adjs += adj;
    }
    resync();
}


void add_plural( string ... plural)
{
    if(!arrayp(plurals)) {
        plurals = plural;
    } else {
        plurals += plural;
    }
    resync();
}


void add_id_no_plural( string ... id ) {
    // set new primary
    if (arrayp(id)) {        
        if(!arrayp(ids)) {
            ids = id;
        } else {
            ids += id;
        }
    }
    resync();
}


void add_id( string ... id)
{
	ids = ids ? ids + id : id; 
    plurals += map(id, pluralize );
    resync();
}


void set_id( string ... id) {
    ids = id + ids; // Ensure proper order for resync of primary id
    plurals += map_array(id, pluralize);
    primary_id = 0;
    resync();
}

void set_adj( array(string) ... adj ) 
{
	adjs = adjs ? adj + adjs : adj;
    primary_adj = 0;
    resync();
}

void remove_id( string ... id)
{
    if(!arrayp(ids))
return;
    ids -= id;
    plurals -= map_array(id, pluralize );
    primary_id = 0;
    resync();
}

void remove_adj( array(string)  ... adj) {
    if(!arrayp(ids))
return;
    adjs -= adj;
    primary_adj = 0;
    resync();
}


void clear_id() 
{
    ids = ({ });
    plurals = ({ });
    primary_id = 0;
    resync();
}


void clear_adj()
{
    adjs = ({ });
    primary_adj = 0;
    resync();
}


array(string) query_id() {
    array(string) fake = this_object()->fake_item_id_list();

    if (fake) return fake + ids;
    else return ids;
}

string query_primary_id() {
    return primary_id;
}


string query_primary_adj() {
    return primary_adj;
}


string query_primary_name() {
    return (primary_adj ? primary_adj + " " : "") + primary_id;
}


array(string) query_adj()
{
    return adjs;
}


array(string) parse_command_id_list()
{
    if (test_flag(INVIS)) return ({ });
    //### should strip non-alphanumerics here; might need an efun to do it
    //### efficiently
    return query_id();
}

final array(string) parse_command_plural_id_list() {
    if (test_flag(INVIS)) return ({ });
    return plurals;
}

final array(string) parse_command_adjectiv_id_list() {
    if (test_flag(INVIS)) return ({ });
    return adjs;
}
