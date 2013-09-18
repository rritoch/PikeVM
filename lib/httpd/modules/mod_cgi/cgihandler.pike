
#include <stdio.h>
#include <unistd.h>

private int data_read;
int http_content_length;
private object cgi_link;
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
	
	protected object pty_in;
	protected object pty_out;
	protected object pty_err;
	
	protected int cgi_hin;
	protected int cgi_hout;
	protected int cgi_herr;	
	
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

	
	private void go() 
	{
        cgie = kernel()->make_user(pty_in->name(), pty_out->name(), pty_err->name(), 0,"/lib/httpd/modules/mod_cgi/cgiexec.pike");
        object _self = this_object();
        _env["cgi"] = _self;
        cgi_link = get_link(cgie);
        request_sent = 1; 
        kernel()->console_write("[cgihandler] Before main()\n");
        cgie->main(2, ({"/lib/httpd/cgiexec.pike", _env["PATH_TRANSLATED"] }), _env);
        kernel()->console_write(sprintf("[cgihandler] After main() %O\n",_self));      	
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
	    fprintf(cgi_hin,"%s",s); // this could block?  
	    data_sent += sizeof(s); 	
	}
	
	void render() 
	{
		program pty;
		
		pike_pointer p_in = pike_pointer();
		pike_pointer p_out = pike_pointer();
		pike_pointer p_err = pike_pointer();
		
		
		pipe(p_in);	
		pipe(p_out);
		pipe(p_err);
		
        pty =  (program)"/dev/pty.pike";
        
        pty_in = pty(p_in->value[1]);
        pty_out = pty(p_out->value[1]);
        pty_err = pty(p_err->value[1]);
 
        cgi_hin = p_in->value[0];
        cgi_hout = p_out->value[0];
        cgi_herr = p_err->value[0];
        
		Thread.Thread thread; 
        thread = Thread.Thread(go);
	
		if ( (!zero_type(_env["HTTP_CONTENT_LENGTH"])) && 0 < (int) _env["HTTP_CONTENT_LENGTH"]) {
			data_read = 0;
			http_content_length = (int) _env["HTTP_CONTENT_LENGTH"];
			input_to(handle_body,3);
		}
		
		pike_pointer readfds  = pike_pointer();
		pike_pointer writefds = pike_pointer();
		pike_pointer exceptfds = pike_pointer();
		pike_pointer timeout = pike_pointer();
		
		timeout->value = ({10 });
		readfds->value = ({ cgi_herr, cgi_hout });
		writefds->value = 0;		
		exceptfds->value = 0;
		
		// read headers from cgi_hout?
		// read body from cgi_hout and cgi_herr?
		pike_pointer data = pike_pointer();
		
		if (do_die) {
			timeout->value = ({1});
		}
		kernel()->console_write("[cgihandler] Before First Select\n");
		int rslt = select(2, readfds, writefds, exceptfds, timeout);
		kernel()->console_write("[cgihandler] After First Select\n");
		while(this_object() && rslt > 0) {			
			 foreach(readfds->value[0], int h) {
			 	if (fread(data , 1, 1, h) > 0) {
			 		 kernel()->console_write(sprintf("[cgihandler] write %O\n",data->value));
                     printf("%s",data->value[0]);
			 	}
			 }
             readfds->value = ({ cgi_herr, cgi_hout });
		     writefds->value = 0;		
		     exceptfds->value = 0;
		     
		     if (request_sent && !cgi_link) {
		     	break;
		     }
		     
		     if (do_die) {
			     timeout->value = ({1});
		     } else {
		     	timeout->value = ({10 });
		     }
		     kernel()->console_write("[cgihandler] Before Select\n");
             rslt = select(2, readfds, writefds, exceptfds, timeout);  
             kernel()->console_write("[cgihandler] After Select\n");
		}
		
		kernel()->console_write("[cgihandler] Destruct\n");
        destruct(this_link());
        destruct();	
		
	}
	
		
int dispatch_request(mapping env) 
{	
	kernel()->console_write("[cgihandler.pike->dispatch_request] Started\n");	
	_env = env;
	parse_headers();
	render();		
	return -1;
}

