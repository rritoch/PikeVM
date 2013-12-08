
#include <stdio.h>
#include <unistd.h>

int http_content_length;
private int request_sent = 0;

int do_die = 0;

	string version = "1.1";
	string proto = "HTTP";
	int code = 200;
	string message = "OK";
	string content_type = "text/html";
	
	mapping _env;
	mapping headers = ([]);
	
	string data = "";
	int content_length;
	
	
	object cgie;
	
protected int data_sent = 0;

	void die() 
	{
		if (objectp(cgie) && cgie) {
			destruct(cgie);
		}
		do_die = 1;		
        //destruct(this_link());
        //destruct();				
	}


	
	private void parse_headers() 
	{
		string line;
		
		array(string) hparts = _env["REQUEST_HEADERS_RAW"] / "\n";
		
		array(string) lparts;
		
		string lkey = "";
		
		foreach(hparts,line) {
			if (sizeof(lkey) && (line[0..0] == " " || line[0..0] == "\t")) {
				_env[lkey] += line;
			} else {
		        lparts = line / ":";		    
		        lkey = upper_case("HTTP_"+lparts[0]);		    
		        _env[lkey] = lparts[1..] * ":";
			}	
		}		
		
	}
	
	
	private void handle_body(string s) 
	{	
	    if (data_sent + sizeof(s) < content_length) {
	        input_to(handle_body,3);	
	    } 	      	
	}
	
	void render() 
	{	    
      write("HTTP/1.1 100 Continue\r\n");    
	    write("Content-length: 0\r\n");
	    write("Connection: keep-alive\r\n");	    
	    write("\r\n\r\n");		
	}
	
		
int dispatch_request(mapping env) 
{	
    object worker = previous_object();
    
	kernel()->console_write("[apachehandler.pike->dispatch_request] Started\n");	
	_env = env;
	parse_headers();
	render();
  worker->do_continue();		
	return -1;
}

