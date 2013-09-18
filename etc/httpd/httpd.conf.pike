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
    cfg_vars["indexes"] = ({ "index.pike", "index.html", "index.htm" }); 
    httpd->loadModule("/lib/httpd/modules/mod_cgi.pike");
    
}
   