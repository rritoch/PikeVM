/**
 * HTTPD Configuration
 *
 * @access public  
 */
  
/**
 * Is Initialized
 * 
 * @var int is_init Is initialized
 * @access private
 */
      
private int is_init = 0;
 
mapping (string:mixed) cfg_vars;
mapping (string:object) modules;
object httpd;

public void configure();

public void init(object httpd_in, mapping (string:mixed) cfg_vars_in, mapping (string:object) modules_in) 
{    
    if(!is_init) {
       is_init = 1;
       cfg_vars = cfg_vars_in;
       modules = modules_in;
       httpd = httpd_in;
       configure();    
    } 
}
   