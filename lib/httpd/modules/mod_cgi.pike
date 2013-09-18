
/**
 * HTTPD CGI Module
 *
 * @author Ralph Ritoch <rritoch@gmail.com>
 */

/**
 * HTTPD
 *
 * @var object httpd
 * @access protected
 */
 
protected object httpd;
protected program cgihandler;


string moduleId()
{
	return "mod_cgi";
}

/**
 * Select Handler
 */
 
private void select_handler(mapping params, object caller) 
{	
	if (params["PATH_TRANSLATED"][<4..] == ".pike") {
		params["handler"] = cgihandler;
	}
}

/**
 * Setup
 */
 
private void setup() 
{
	cgihandler = (program)"/lib/httpd/modules/mod_cgi/cgihandler.pike";
    httpd->add_hook("select_handler",select_handler);  
    kernel()->console_write("[mod_cgi] Loaded!\n"); 
}

/**
 * Program constructor
 */
 
void create(object _httpd) 
{
	httpd = _httpd;
	setup();
}
