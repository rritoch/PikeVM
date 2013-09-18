/**
 * Shell Vars Module
 *
 * @package PikeVM
 */

private mapping(string:mixed) shell_env = ([]);

mapping(string:string) shell_environment() 
{
    return copy_value(shell_env);
}

mixed get_variable(string name) 
{
	return shell_env[name];
}

int has_variable(string name) 
{
    return !zero_type(shell_env[name]);	
}

void set_variable(string name, mixed value)
{
	shell_env[name] = value;
}

void set_cwd(string value) 
{
	set_variable("pwd",value);	
}

string get_cwd() 
{
	return has_variable("pwd") ? get_variable("pwd") : ".";
}
