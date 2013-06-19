/**
 * HTTPD Configuration
 *
 * @access public  
 */
  
inherit "/lib/httpd/configuration.pike";

void configure() 
{
    //httpd->loadModule("/etc/httpd/modules/rewrite.pike");
    cfg_vars["document_root"] = "/var/www/html"; 
}
   