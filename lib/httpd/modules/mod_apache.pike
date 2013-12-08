
/**
 * HTTPD Apache Module
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
protected program apachehandler;


string moduleId()
{
	return "mod_apache";
}

/**
 * Select Handler
 */
 
private void select_handler(mapping params, object caller) 
{
    if (params["REQUEST_URI"] == "*.pike") {
		    params["handler"] = apachehandler;
	  }
}

/**
 * Setup
 */
 
private void setup() 
{
	  apachehandler = (program)"/lib/httpd/modules/mod_apache/apachehandler.pike";
    httpd->add_hook("select_handler",select_handler);  
    kernel()->console_write("[mod_apache] Loaded!\n"); 
}

/**
 * Program constructor
 */
 
void create(object _httpd) 
{
	httpd = _httpd;
	setup();
}
