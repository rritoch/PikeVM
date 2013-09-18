/* Do not remove the headers from this file! see /USAGE for more info. */

#define CARET_AS_NOT

private mapping cache = ([]);


int has_magic( string s ){
    return sizeof( regexp( ({ s }), "[\\[\\*\\]\\?]"));
}

// The flag toggles whether or not ^ and $ are valid.
// 1 means valid.
string translate( string pat, int|void flag )
{
    int i, j, n;
    string	res, stuff;

    n = strlen(pat);
    res = "";

    for( i = 0; i < n; i++ )
    {
if( pat[i] == '\\' && i+1 != n ){
res += pat[i..++i];
continue;
}
switch( pat[i] ){
case '^':
case '$':
if(flag)
{
res += pat[i..i];
continue;
}
case '.':
res += "\\" + pat[i..i];
continue;
case	'*':
res += ".*";
continue;
case '?':
res += ".";
continue;
case '[':
j=i;
if( j<n && pat[j] == '!' ) j++;
#ifdef CARET_AS_NOT
if( j<n && pat[j] == '^' ) j++;
#endif
if( j<n && pat[j] == ']' ) j++;
while( j < n && pat[j] != ']' ) j++;
if( j >= n )
res += "\\[";
else{
stuff = pat[i+1..j];
#ifndef CARET_AS_NOT
if( member_array('^', stuff) != -1 )
stuff = replace_string(stuff,"^","\\^");
#endif
i = j;
if( strlen(stuff) > 2 && stuff[0] == '!' ) stuff = "[^"+stuff[1..];
else stuff = "[" + stuff;
res += stuff;
}
continue;
default:
res+= pat[i..i];
continue;
}
    }
    return res;
}

int fnmatch( string name, string pattern )
{
    string result;

    if( zero_type(cache[pattern]) ){
result = "^"+translate(pattern)+"$";
cache[pattern] = result;
    }
    return sizeof( regexp( ({ name }), cache[pattern] ) );
}

private array(string) glob1( string dirname, string pattern){
    array(mixed)	names;
    array(mixed) result;
    string	name;
    int	i,j;

    names = get_dir(dirname+"/*");
    result = ({});
    j = sizeof(names);
    for(i=0;i<j;i++){
name = names[i];
if(name != "." && name != ".."){
if (fnmatch(name, pattern)){
result += ({ name });
}
}
    }
    return result;
}

private array(mixed) mksub(array(mixed) sublist, string dirname) {  
    mixed item;
    array(mixed) sublist_n = ({});
    foreach(sublist, item) {
        sublist_n += ({ dirname + "/" + item });
    }
    return sublist_n;
}

array(string) glob( mixed pathname ){
    string	dirname;
    string basename;
    string name;
    array(mixed)	list;
    array(mixed) result;
    array(mixed) sublist;
    int	i;

    if( !stringp(pathname) ) return ({});
    if( !has_magic(pathname) ){
if( path_exists( pathname ) ){
return ({ pathname });	
}
else{
return ({});
}
    }
    pathname = split_path( pathname );
    dirname = pathname[0];
    basename = pathname[1];
    if( has_magic(dirname) ){
list = glob(dirname);
    }
    else{
list = ({ dirname });
    }
    if( !has_magic(basename) ){
result = ({});
i = sizeof(list);
while(i--){
dirname = list[i];
if( basename || is_directory(dirname) ){
name = dirname+"/"+basename;
if( path_exists(name) )
{
result += ({ name });
}
}
}
    }
    else{
result = ({});
i = sizeof(list);
while(i--){
dirname = list[i];
if(!strlen(dirname)) continue;
if( dirname[-1] == '/' )
{
if( strlen(dirname) == 1 )
dirname = "";
else
dirname = dirname[0..<2];
}
sublist = glob1( dirname, basename );

sublist = mksub(sublist, dirname);

result += sublist;
}
    }
    return result;
}