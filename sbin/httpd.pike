/**
 * HTTP Daemon
 *  
 * @author Ralph Ritoch <rritoch@gmail.com>
 * @package httpd 
 * @access public
 */    

#include <netinet/in.h>
#include <netdb.h>
#include <stdio.h>
#include <unistd.h>

#include "/includes/devices.h"
#include "/includes/master.h"

#define PORT 8082
#define BACKLOG 100

inherit "/lib/core/hookprovider.pike";

mapping(string:string) shell_env = ([]);
mapping(string:object) modules = ([]);
mapping(string:mixed) cfg_vars = ([]);

class default_handler 
{
	
	string version = "1.0";
	string proto = "HTTP";
	int code = 200;
	string message = "OK";
	string content_type = "text/html";
	
	mapping _env;
	mapping headers = ([]);
	
	string data = "";
	int content_length;
	
	private void send_header() 
	{	    	    
	    write("%s/%s %s %s\r\n",proto,version,replace(sprintf("%3d",code)," ","0"), message);	    
	    write("Content-type: %s\r\n",content_type);
	    write("Connection: close\r\n");	    
	    write("\r\n");	
	}
	
	void send_file(string src) 
	{	       
            kernel()->shell_exec("/bin/sh.pike",({"/bin/sh.pike", "/bin/cat.pike",src}),this_shell()->environment());
    }	
	
	private void die() 
	{
		kernel()->console_write("HTTPD->DIE");
		
        destruct(this_link());
        destruct();				
	}

	void poll() 
	{				
        input_to(have_poll,3);	
	}
	
	void render() 
	{		
	    send_header();
		send_file(this_shell()->get_variable("PATH_TRANSLATED"));				
	}
	
	void have_poll(string c) {        		
		data += c;						
		if(sizeof(data) < content_length) {
			poll();
		} else {			
            render();
            die();
		}
	}

		
	int dispatch_request(mapping env) {
		string line;		
		_env = env;
		content_length = 0;		
		array(string) hparts = env["REQUEST_HEADERS_RAW"] / "\n";
		
		array(string) lparts;
		
		string lkey = "";
		
		foreach(hparts,line) {
			if (sizeof(lkey) && (line[0..0] == " " || line[0..0] == "\t")) {
				headers[lkey] += line;
			} else {
		        lparts = line / ":";		    
		        lkey = upper_case(lparts[0]);		    
		        headers[lkey] = lparts[1..] * ":";
			}	
		}
		
		if (!zero_type(headers["CONTENT-LENGTH"])) {			
			content_length = (int)headers["CONTENT-LENGTH"];					
			if (content_length > 0) {
                poll();
			    return -1;
			}
		}
		render();		
		return 0;
	}
}


class default_404_handler 
{
	
	string version = "1.0";
	string proto = "HTTP";
	int code = 400;
	string message = "Page not found";
	string content_type = "text/html";
	
	mapping _env;
	mapping headers = ([]);
	
	string data = "";
	int content_length;
	
	private void send_header() 
	{	    	    
	    write("%s/%s %s %s\r\n",proto,version,replace(sprintf("%3d",code)," ","0"), message);	    
	    write("Content-type: %s\r\n",content_type);
	    write("Connection: close\r\n");	    
	    write("\r\n");	
	}
	
	private void send_file() 
	{	       
        write("%s",
            "<HTML><HEAD>\n" +
            "    <TITLE>404 Page Not Found</TITLE>\n"+
            "</HEAD><BODY>\n" +
            "    <H1>Page not found (404)</H1>\n" +
            "    <P>The page you requested could not be located</P>\n"+
             "</BODY></HTML>\n"
        );
    }	
	
	private void die() 
	{
        destruct(this_link());
        destruct();				
	}

	void poll() 
	{		
        input_to(have_poll,3);	
	}
	
	void render() 
	{		
	    send_header();
		send_file();				
	}
	
	void have_poll(string c) 
	{
		data += c;
		if(sizeof(data) < content_length) {
			poll();
		} else {			
            render();
            die();
		}		
		
	}

		
	int dispatch_request(mapping env) {
		string line;		
		_env = env;
		content_length = 0;		
		array(string) hparts = env["REQUEST_HEADERS_RAW"] / "\n";
		
		array(string) lparts;
		
		string lkey = "";
		
		foreach(hparts,line) {
			if (sizeof(lkey) && (line[0..0] == " " || line[0..0] == "\t")) {
				headers[lkey] += line;
			} else {
		        lparts = line / ":";		    
		        lkey = upper_case(lparts[0]);		    
		        headers[lkey] = lparts[1..] * ":";
			}	
		}
		
		if (!zero_type(headers["CONTENT-LENGTH"])) {			
			content_length = (int)headers["CONTENT-LENGTH"];					
			if (content_length > 0) {
                poll();
			    return -1;
			}
		}
		render();		
		return 0;
	}
}

protected void selectHandler(mapping info) 
{
	//kernel()->console_write(sprintf("[selectHandler] %O\n",info));
	
	info["handler"] = default_handler;
	call_hooks("select_handler",info);
	
}

void loadModule(string path) 
{
	
	mixed err = catch {
		program p = (program)path;
		object ob = p(this_object());	
		
		modules[ob->moduleId()] = ob;	
	};
	
	if (err) {
		debug(sprintf("[loadModule] error %O",err));
	}
	
}

mapping resolve_request_uri(string uri) 
{
	array indexes;
	
	string document_root = cfg_vars["document_root"];
	
	string filename = document_root+uri;
	mapping ret = ([]);
			
	if (is_directory(filename)) {
		indexes = cfg_vars["indexes"];		
		foreach(indexes,string index) {
			if (file_exists(filename+"/"+index)) {				
				ret["PATH_TRANSLATED"] = filename+"/"+index;
				selectHandler(ret);			
				return ret; 
			}
		}
	} else if (file_exists(filename)) {
		ret["PATH_TRANSLATED"] = filename;		
		ret["handler"] = default_handler;	
		selectHandler(ret);	
	} else {
		ret["PATH_TRANSLATED"] = filename;
		ret["handler"] = default_404_handler;
	}
	
	return ret;		
}

void debug(mixed msg) 
{
    printf("[debug] %O %O\n",msg, backtrace()[-2]);
}

int is_shell() 
{
    return 1;
}

void handle_call_out(function f, mixed ... args) 
{
    f(@args);
}

string get_cwd() 
{
    if (!zero_type(shell_env["CWD"])) {
        return shell_env["CWD"];
    }
    return ".";
}

mapping(string:string) environment() 
{
    return copy_value(shell_env);
}

string set_env(string vname, string val) 
{
    shell_env[vname] = val;
    return val;
}

string get_env(string vname) 
{
    if (zero_type(shell_env[vname])) {
        return "";
    }
    return shell_env[vname];
}

joinnode_t get_root_module(object|void current_handler) 
{
    string lib_path;
    string p;
    array(string) paths;
    string cwd;
    string clean_path;
    joinnode_t root_module;
 
#ifdef DEBUG_GET_ROOT_MODULE
    write("sh.pike: get_root_module(%O)",current_handler);
#endif  
  
    if (zero_type(shell_env["LIB_PATHS"])) {
        lib_path = "";
    } else {
        lib_path = shell_env["LIB_PATHS"];
    }
  
    // Cache!
    //if (last_root_module_path && last_root_module_path == lib_path) return root_module;
  
    // New Tree
    root_module = master()->joinnode(({}));
  
    // Init Vars
    paths = lib_path / ";";  
    cwd = get_cwd();
  
    // Build Tree
    foreach(paths,p) {
        clean_path = combine_path(cwd,p);
        // Can Read/Exec Check here????
        root_module->add_path(clean_path);
    }
    
    // Init Cache!
    //last_root_module_path = lib_path;
    // Done!
    return root_module; 
 } 

void handle_connect(int fd) 
{ 
    program pty;
    object mypty;
 
    pty = (program)"/dev/pty.pike";
    mypty = pty(fd);
 
    object u = kernel()->make_user(mypty->name(), mypty->name(), mypty->name(), 0,"/sbin/httpd_worker.pike");
    
    u->main(1, ({"/sbin/httpd_worker.pike"}), shell_env);   
}


private void httpd() 
{
    sockaddr_storage their_addr; // connector's address information
    socklen_t sin_size;
    int new_fd;
    string s;
    
    printf("server: waiting for connections...\n");
    
    while(1) {  // main accept() loop
        sin_size = _SS_SIZE; // this means nothing... oh well... orig: sizeof their_addr;
        their_addr = sockaddr_storage();        
        new_fd = accept(sockfd, their_addr, sin_size);
        if (new_fd == -1) {
            perror("accept");
            continue;
        }
        
        s = "somewhere!";
        /*
        inet_ntop(their_addr->ss_family,
            get_in_addr((struct sockaddr *)&their_addr),
            s, sizeof s);
        */
        printf("server: got connection from %s on %O\n", s, new_fd);                
        handle_connect(new_fd);

        //close(new_fd);  // parent doesn't need this
    }

    return 0;
}

private int sockfd;

private void init() 
{
    debug("Init Started");
    
    // if (file exists) {
    program cfgp = (program)cfg_vars["config_filename"];    
    object cfg = cfgp();
    cfg->init(this_object(),cfg_vars,modules);
    // } // endif
            
    debug("Init Complete");
}

private void pre_init(int argc, array(string) argv) 
{
    debug("Pre-Init Started");
    cfg_vars["document_root"] = "/var/www/html";
    cfg_vars["config_filename"] = "/etc/httpd/httpd.conf.pike";
    cfg_vars["indexes"] = ({ "index.html","index.htm" });    
    debug("Pre-Init Complete");
}

int main(int argc, array(string) argv, mixed env) 
{
    addrinfo hints, servinfo, p;
    //struct sigaction sa;
    shell_env = copy_value(env);
    int yes = 1;
    
    //char s[INET6_ADDRSTRLEN];
    
    int rv;

    //memset(&hints, 0, sizeof hints);
    pre_init(argc,argv);
    init();
    
    hints = addrinfo();
    
    hints->ai_family = AF_UNSPEC;
    hints->ai_socktype = SOCK_STREAM;
    hints->ai_flags = AI_PASSIVE; // use my IP
    
    debug("have hints");
    servinfo = addrinfo();
    debug("have serverinfo object");
    
    if ((rv = getaddrinfo(NULL, PORT, hints, servinfo)) != 0) {
        debug("getaddrinfo exit");
        fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(rv));
        return 1;
    }
    
    debug("Have getaddrinfo");
    
    // loop through all the results and bind to the first we can
    for(p = servinfo; p != NULL; p = p->ai_next) {
        if ((sockfd = socket(p->ai_family, p->ai_socktype,
                p->ai_protocol)) == -1) {
            perror("server: socket");
            continue;
        }

        if (setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, ({ yes }),
                sizeof(({ yes }))) == -1) {
            perror("setsockopt");
            return 1;//exit(1);
        }

        if (bind(sockfd, p->ai_addr, p->ai_addrlen) == -1) {
            close(sockfd);
            perror("server: bind");
            continue;
        }

        break;
    }

    if (p == NULL)  {
        fprintf(stderr, "server: failed to bind\n");
        return 2;
    }
    
    debug("Socket is bound!");
    
    freeaddrinfo(servinfo); // all done with this structure

    if (listen(sockfd, BACKLOG) == -1) {
        perror("listen");
        return 1; //exit(1);
    }

/*
    sa.sa_handler = sigchld_handler; // reap all dead processes
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_RESTART;
    if (sigaction(SIGCHLD, &sa, NULL) == -1) {
        perror("sigaction");
        return 1; //exit(1);
    }
*/

    Thread.Thread thread; 
    thread = Thread.Thread(httpd);
    return 0;
}

/* EOF */
