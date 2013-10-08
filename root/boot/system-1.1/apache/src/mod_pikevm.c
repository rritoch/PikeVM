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
#include "mod_pikevm.h"

/* Define prototypes of our functions in this module */
static void ap_pikevm_register_hooks(apr_pool_t *pool);
static int ap_pikevm_handler(request_rec *r);
static void* ap_create_pikevm_svr_config(apr_pool_t* pool, server_rec* svr);
static void* ap_create_pikevm_dir_config(apr_pool_t* pool, char* x);
static void* ap_merge_pikevm_svr_config(apr_pool_t* pool, void* BASE, void* ADD);
static void* ap_merge_pikevm_dir_config(apr_pool_t* pool, void* BASE, void* ADD);

void pikevm_init(apr_pool_t *pool);

/* Define Commands */

static const cmd_rec ap_pikevm_cmds[] = {
    AP_INIT_TAKE1("PikeVMHost", ap_set_string_slot,(void*)APR_OFFSETOF(pikevm_dir_cfg, host), OR_ALL,
	    "Set PikeVM Server Host"),
    AP_INIT_TAKE1("PikeVMPort", ap_set_int_slot,(void*)APR_OFFSETOF(pikevm_dir_cfg, port), OR_ALL,
	    "Set PikeVM Server Port"),
      { NULL }
};

/* Define our module as an entity and assign a function for registering hooks  */
module AP_MODULE_DECLARE_DATA   pikevm_module =
{
    STANDARD20_MODULE_STUFF,
    ap_create_pikevm_dir_config,            // Per-directory configuration handler
    ap_merge_pikevm_dir_config,            // Merge handler for per-directory configurations
    ap_create_pikevm_svr_config,            // Per-server configuration handler
    ap_merge_pikevm_svr_config,            // Merge handler for per-server configurations
    ap_pikevm_cmds,            // Any directives we may have for httpd
    ap_pikevm_register_hooks   // Our hook registering function
};


// Globals

/* Create Server Configuration */
static void* ap_create_pikevm_svr_config(apr_pool_t* pool, server_rec* svr) 
{
    pikevm_svr_cfg *svr = apr_pcalloc(pool, sizeof(pikevm_svr_cfg));
    /* Set up the default values for fields of svr */
    return svr ;
}

/* Create Directory Configuration */
static void* ap_create_pikevm_dir_config(apr_pool_t* pool, char* x) 
{
    pikevm_dir_cfg *dir = apr_pcalloc(pool, sizeof(pikevm_dir_cfg));
    /* Set up the default values for fields of dir */
    dir->host = NULL;
    dir->port = -1;
    return dir ;
}

/* Merge Server Configuration */
static void* ap_merge_pikevm_svr_config(apr_pool_t* pool, void* BASE, void* ADD) 
{
    pikevm_svr_cfg* base = BASE ;
    pikevm_svr_cfg* add = ADD ;
    pikevm_svr_cfg* conf = apr_palloc(pool, sizeof(pikevm_svr_cfg)) ;
    return conf ;
}

/* Merge Directory Configuration */
static void* ap_merge_pikevm_dir_config(apr_pool_t* pool, void* BASE, void* ADD) 
{
    pikevm_dir_cfg* base = BASE ;
    pikevm_dir_cfg* add = ADD ;
    pikevm_dir_cfg* conf = apr_palloc(pool, sizeof(pikevm_dir_cfg)) ;
    conf->host = ( add->host == NULL ) ? base->host : add->host ; // Should this be done via copy???
    conf->port = ( add->port == -1 ) ? base->port : add->port ;
    return conf ;
}

/* ap_pikevm_register_hooks: Adds a hook to the httpd process */
static void ap_pikevm_register_hooks(apr_pool_t *pool) 
{
    pikevm_init(pool);
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

// Local

/* pikevm_init: PikeVM Apache Module Initialization */
void pikevm_init(apr_pool_t *pool) 
{
    // Reserved for future use
}



