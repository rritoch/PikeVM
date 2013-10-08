/* mod_pikevm.c:  */
#include <stdio.h>
#include "apr_hash.h"
#include "ap_config.h"
#include "ap_provider.h"
#include "httpd.h"
#include "http_core.h"
#include "http_config.h"
#include "http_log.h"
#include "http_protocol.h"
#include "http_request.h"

/* Define prototypes of our functions in this module */
static void ap_pikevm_register_hooks(apr_pool_t *pool);
static int ap_pikevm_handler(request_rec *r);

/* Define our module as an entity and assign a function for registering hooks  */

module AP_MODULE_DECLARE_DATA   pikevm_module =
{
    STANDARD20_MODULE_STUFF,
    NULL,            // Per-directory configuration handler
    NULL,            // Merge handler for per-directory configurations
    NULL,            // Per-server configuration handler
    NULL,            // Merge handler for per-server configurations
    NULL,            // Any directives we may have for httpd
    ap_pikevm_register_hooks   // Our hook registering function
};


/* ap_pikevm_register_hooks: Adds a hook to the httpd process */
static void ap_pikevm_register_hooks(apr_pool_t *pool) 
{
    
    /* Hook the request handler */
    ap_hook_handler(ap_pikevm_handler, NULL, NULL, APR_HOOK_LAST);
}

/* ap_pikevm_handler: The handler function for our module. */

static int ap_pikevm_handler(request_rec *r)
{
    /* First off, we need to check if this is a call for the "pikevm" handler.
     * If it is, we accept it and do our things, it not, we simply return DECLINED,
     * and Apache will try somewhere else.
     */
    if (!r->handler || strcmp(r->handler, "pikevm-handler")) return (DECLINED);
    
    // set content type
    ap_set_content_type(r, "text/html");
    
    
    // The first thing we will do is write a simple "Hello, world!" back to the client.
    //ap_rputs("Hello, world!<br/>", r);
    ap_rprintf(r, "Hello, world!");
    return OK;
}
