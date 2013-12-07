/* mod_pikevm.c:  */

#include "mod_pikevm.h"

#define MAX_MEM_SPOOL 16384

/* Define prototypes of our functions in this module */
static void ap_pikevm_register_hooks(apr_pool_t *pool);
static int ap_pikevm_handler(request_rec *r);
static void* ap_create_pikevm_svr_config(apr_pool_t* pool, server_rec* svr);
static void* ap_create_pikevm_dir_config(apr_pool_t* pool, char* x);
static void* ap_merge_pikevm_svr_config(apr_pool_t* pool, void* BASE, void* ADD);
static void* ap_merge_pikevm_dir_config(apr_pool_t* pool, void* BASE, void* ADD);

void pikevm_init(apr_pool_t *pool);

/* Define Commands */

static const command_rec ap_pikevm_cmds[] = {
    AP_INIT_TAKE1("PikeVMHost", ap_set_string_slot,(void*)APR_OFFSETOF(pikevm_dir_cfg, host), OR_ALL,
        "Set PikeVM Server Host"),
    AP_INIT_TAKE1("PikeVMPort", ap_set_int_slot,(void*)APR_OFFSETOF(pikevm_dir_cfg, port), OR_ALL,
        "Set PikeVM Server Port"),
    AP_INIT_TAKE1("PikeVMSecret", ap_set_string_slot,(void*)APR_OFFSETOF(pikevm_dir_cfg, secret), OR_ALL,
        "Set Signature Secret"),
    AP_INIT_TAKE1("PikeVMSignatureMethod", ap_set_string_slot,(void*)APR_OFFSETOF(pikevm_dir_cfg, signature_method), OR_ALL,
        "Set Signature Hash Algorithm"),
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


// Configuration functions

/* ap_create_pikevm_svr_config: Create Server Configuration */
static void* ap_create_pikevm_svr_config(apr_pool_t *pool, server_rec *sr)
{
    pikevm_svr_cfg *svr = apr_pcalloc(pool, sizeof(pikevm_svr_cfg));
    /* Set up the default values for fields of svr */
    return svr ;
}

/* ap_create_pikevm_dir_config: Create Directory Configuration */
static void* ap_create_pikevm_dir_config(apr_pool_t* pool, char* x)
{
    pikevm_dir_cfg *dir = apr_pcalloc(pool, sizeof(pikevm_dir_cfg));
    /* Set up the default values for fields of dir */
    dir->host = NULL;
    dir->port = -1;
    dir->signature_method = NULL;
    dir->secret = NULL;
    return dir ;
}

/* ap_merge_pikevm_svr_config: Merge Server Configuration */
static void* ap_merge_pikevm_svr_config(apr_pool_t* pool, void* BASE, void* ADD)
{
    pikevm_svr_cfg* base = BASE ;
    pikevm_svr_cfg* add = ADD ;
    pikevm_svr_cfg* conf = apr_palloc(pool, sizeof(pikevm_svr_cfg)) ;
    return conf ;
}

/* ap_merge_pikevm_dir_config: Merge Directory Configuration */
static void* ap_merge_pikevm_dir_config(apr_pool_t* pool, void* BASE, void* ADD)
{
    pikevm_dir_cfg* base = BASE ;
    pikevm_dir_cfg* add = ADD ;
    pikevm_dir_cfg* conf = apr_palloc(pool, sizeof(pikevm_dir_cfg)) ;
    conf->host = ( add->host == NULL ) ? base->host : add->host ; // Should this be done via copy???
    conf->port = ( add->port == -1 ) ? base->port : add->port ;
    conf->signature_method = ( add->signature_method == NULL ) ? base->signature_method : add->signature_method ;
    conf->secret = ( add->secret == NULL ) ? base->secret : add->secret ;

    return conf ;
}
/* pikevm_init: PikeVM Apache Module Initialization */
void pikevm_init(apr_pool_t *pool)
{
    // Reserved for future use
}

static apr_status_t ap_pikevm_error(request_rec *r, int statuscode, const char *message)
{
    apr_table_setn(
        r->notes, 
        "error-notes",
	      apr_pstrcat(
            r->pool,
		            "The PikeVM server could not handle the request "
		                "<em><a href=\"", ap_escape_uri(r->pool, r->uri),
		        "\">", ap_escape_html(r->pool, r->method),
		        "&nbsp;",
		        ap_escape_html(r->pool, r->uri), 
            "</a></em>.<p>\n"
		            "Reason: <strong>",
		        ap_escape_html(r->pool, message),
		        "</strong></p>", 
            NULL
        )
    );
                         
    /* Allow "error-notes" string to be printed by ap_send_error_response() */
    apr_table_setn(
        r->notes, 
        "verbose-error-to", 
        apr_pstrdup(r->pool, "*")
    );

    r->status_line = apr_psprintf(r->pool, "%3.3u PikeVM Error", statuscode);
                         
    ap_log_rerror(
        APLOG_MARK, 
        APLOG_ERR, 
        0, 
        r,
			 "pikevm: %s returned by %s", 
       message, 
       r->uri
    );
    return statuscode;
}

// Data Functions

/* ap_pikevm_pass_brigade: Send brigade */

static apr_status_t ap_pikevm_pass_brigade(
    apr_bucket_alloc_t *bucket_alloc,
    request_rec *r,
    pikevm_http_conn_t *p_conn,
    conn_rec *dest,
    apr_bucket_brigade *bb,
    int flush
) {
    apr_status_t status;
    apr_bucket *e;

    if (flush) {
        ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "pikevm: %s: Flush!",
                         "ap_pikevm_pass_brigade");
        e = apr_bucket_flush_create(bucket_alloc);
        APR_BRIGADE_INSERT_TAIL(bb, e);
    }
    ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "pikevm: %s: Passing output_filters!",
                         "ap_pikevm_pass_brigade");
                         
    status = ap_pass_brigade(dest->output_filters, bb);

    if (status != APR_SUCCESS) {
        ap_log_error(APLOG_MARK, APLOG_ERR, status, r->server,
                     "pikevm: ap_pass_brigade failed to %pI (%s)",
                     p_conn->addr, p_conn->name);
        return status;
    }

    ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "pikevm: %s: Cleanup!",
                         "ap_pikevm_pass_brigade");
    apr_brigade_cleanup(bb);

    return APR_SUCCESS;
}

static request_rec * ap_pikevm_make_fake_req(
	pikevm_conn_rec *backend,
	request_rec *r
) {
    conn_rec *c = backend->connection;

    request_rec *rp = apr_pcalloc(c->pool, sizeof(*r));

    rp->pool            = c->pool;
    rp->status          = HTTP_OK;

    rp->headers_in      = apr_table_make(c->pool, 50);
    rp->subprocess_env  = apr_table_make(c->pool, 50);
    rp->headers_out     = apr_table_make(c->pool, 12);
    rp->err_headers_out = apr_table_make(c->pool, 5);
    rp->notes           = apr_table_make(c->pool, 5);

    rp->server = r->server;
    rp->proxyreq = r->proxyreq;
    rp->request_time = r->request_time;
    rp->connection      = c;
    rp->output_filters  = c->output_filters;
    rp->input_filters   = c->input_filters;
    rp->proto_output_filters  = c->output_filters;
    rp->proto_input_filters   = c->input_filters;

    rp->request_config  = ap_create_request_config(c->pool);
    //proxy_run_create_req(r, rp); ???
    //core_create_req(rp);
    ap_run_create_request(rp);
    return rp;
}

static apr_status_t ap_pikevm_stream_reqbody_chunked(
    request_rec *r,
    request_rec *rd,
    request_rec *rp,
    pikevm_conn_rec * backend,
    apr_bucket_brigade *bb
) {
    apr_status_t status = OK;
    if (1) {
        return ap_pikevm_error(r,HTTP_BAD_GATEWAY,"pikevm: ap_pikevm_stream_reqbody_chunked not defined");
    }
    
    return status;
}

static apr_status_t ap_pikevm_stream_reqbody_cl(
    request_rec *r,
    request_rec *rd,
    request_rec *rp,
    pikevm_conn_rec * backend,
    apr_bucket_brigade *bb,
    const char *cl_val
) {
    apr_status_t status = OK;
    if (1) {
        return ap_pikevm_error(r,HTTP_BAD_GATEWAY,"pikevm: ap_pikevm_stream_reqbody_cl not defined");
    }
    
    return status;
}

static apr_status_t ap_pikevm_spool_reqbody_cl(
    request_rec *r,
    request_rec *rd, // destination
    request_rec *rp, // source
    pikevm_conn_rec * backend,
    apr_bucket_brigade *bb,
    pikevm_http_conn_t *p_conn, // destination used for logging purposes
    int force_cl
) {
    apr_status_t status = OK;

    int seen_eos = 0;
    apr_bucket_alloc_t *bucket_alloc = r->connection->bucket_alloc;
    apr_bucket_brigade *body_brigade;
    apr_bucket *e;
    apr_off_t bytes, bytes_spooled = 0, fsize = 0;
    apr_file_t *tmpfile = NULL;

    body_brigade = apr_brigade_create(r->pool, bucket_alloc);

    while (!APR_BUCKET_IS_EOS(APR_BRIGADE_FIRST(bb)))
    {
        /* If this brigade contains EOS, either stop or remove it. */
        if (APR_BUCKET_IS_EOS(APR_BRIGADE_LAST(bb))) {
            seen_eos = 1;

            /* We can't pass this EOS to the output_filters. */
            e = APR_BRIGADE_LAST(bb);
            apr_bucket_delete(e);
        }

        apr_brigade_length(bb, 1, &bytes);

        if (bytes_spooled + bytes > MAX_MEM_SPOOL) {
            /* can't spool any more in memory; write latest brigade to disk */
            if (tmpfile == NULL) {
                const char *temp_dir;
                char *template;

                status = apr_temp_dir_get(&temp_dir, r->pool);
                if (status != APR_SUCCESS) {
                    ap_log_error(APLOG_MARK, APLOG_ERR, status, r->server,
                                 "pikevm: search for temporary directory failed");
                    return status;
                }
                apr_filepath_merge(&template, temp_dir,
                                   "modpikevm.tmp.XXXXXX",
                                   APR_FILEPATH_NATIVE, r->pool);
                status = apr_file_mktemp(&tmpfile, template, 0, r->pool);
                if (status != APR_SUCCESS) {
                    ap_log_error(APLOG_MARK, APLOG_ERR, status, r->server,
                                 "pikevm: creation of temporary file in directory %s failed",
                                 temp_dir);
                    return status;
                }
            }
            for (e = APR_BRIGADE_FIRST(bb);
                 e != APR_BRIGADE_SENTINEL(bb);
                 e = APR_BUCKET_NEXT(e)) {
                const char *data;
                apr_size_t bytes_read, bytes_written;

                apr_bucket_read(e, &data, &bytes_read, APR_BLOCK_READ);
                status = apr_file_write_full(tmpfile, data, bytes_read, &bytes_written);
                if (status != APR_SUCCESS) {
                    const char *tmpfile_name;

                    if (apr_file_name_get(&tmpfile_name, tmpfile) != APR_SUCCESS) {
                        tmpfile_name = "(unknown)";
                    }
                    ap_log_error(APLOG_MARK, APLOG_ERR, status, r->server,
                                 "proxy: write to temporary file %s failed",
                                 tmpfile_name);
                    return status;
                }
                AP_DEBUG_ASSERT(bytes_read == bytes_written);
                fsize += bytes_written;
            }
            apr_brigade_cleanup(bb);
        }
        else {

            /*
             * Save input_brigade in body_brigade. (At least) in the SSL case
             * input_brigade contains transient buckets whose data would get
             * overwritten during the next call of ap_get_brigade in the loop.
             * ap_save_brigade ensures these buckets to be set aside.
             * Calling ap_save_brigade with NULL as filter is OK, because
             * body_brigade already has been created and does not need to get
             * created by ap_save_brigade.
             */
            status = ap_save_brigade(NULL, &body_brigade, &bb, r->pool);
            if (status != APR_SUCCESS) {
                return status;
            }

        }
        
        bytes_spooled += bytes;

        if (seen_eos) {
            break;
        }

        status = ap_get_brigade(r->input_filters, bb,
                                AP_MODE_READBYTES, APR_BLOCK_READ,
                                HUGE_STRING_LEN);

        if (status != APR_SUCCESS) {
            return status;
        }
    }

    /* Don't need this, already passed headers, right? */
    //if (bytes_spooled || force_cl) {
    //    add_cl(r->pool, bucket_alloc, header_brigade, apr_off_t_toa(p, bytes_spooled));
    //}
    //terminate_headers(bucket_alloc, header_brigade);
    
    APR_BRIGADE_CONCAT(bb, body_brigade);
    if (tmpfile) {
        /* For platforms where the size of the file may be larger than
         * that which can be stored in a single bucket (where the
         * length field is an apr_size_t), split it into several
         * buckets: */
        if (sizeof(apr_off_t) > sizeof(apr_size_t)
            && fsize > AP_MAX_SENDFILE) {
            e = apr_bucket_file_create(tmpfile, 0, AP_MAX_SENDFILE, r->pool,
                                       bucket_alloc);
            while (fsize > AP_MAX_SENDFILE) {
                apr_bucket *ce;
                apr_bucket_copy(e, &ce);
                APR_BRIGADE_INSERT_TAIL(bb, ce);
                e->start += AP_MAX_SENDFILE;
                fsize -= AP_MAX_SENDFILE;
            }
            e->length = (apr_size_t)fsize; /* Resize just the last bucket */
        }
        else {
            e = apr_bucket_file_create(tmpfile, 0, (apr_size_t)fsize, r->pool,
                                       bucket_alloc);
        }
        APR_BRIGADE_INSERT_TAIL(bb, e);
    }
    /* This is all a single brigade, pass with flush flagged */
    
    if (rd != NULL) {
        status = ap_pikevm_pass_brigade(bucket_alloc, r, p_conn, rd->connection, bb, 1);
    }
    
    return status;
}

static apr_status_t ap_pikevm_pass_body(
    request_rec *r,
    request_rec *rd,
    request_rec *rp,
    pikevm_conn_rec * backend,
    pikevm_http_conn_t *p_conn,
    apr_bucket_brigade *bb
) {
    int is_proxy = 1;
    apr_status_t status = OK;
    const apr_array_header_t *headers_in_array;
    const apr_table_entry_t *headers_in;
    enum rb_methods {RB_UNKNOWN, RB_STREAM_CL, RB_STREAM_CHUNKED, RB_SPOOL_CL};
    enum rb_methods rb_method = RB_UNKNOWN;
    const char *cl_val = NULL;
    const char *te_val = NULL;
    int counter;
                         
    if (rd == NULL) {
        is_proxy = 0;
    }
    ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "pikevm: %s: is_proxy=%i",
                         "ap_pikevm_pass_body",is_proxy);
                         
    headers_in_array = apr_table_elts(rp->headers_in);
    headers_in = (const apr_table_entry_t *) headers_in_array->elts;
    for (counter = 0; counter < headers_in_array->nelts; counter++) {
        if (
            headers_in[counter].key == NULL || 
            headers_in[counter].val == NULL
        ) {
            continue;
        }
        
        if (!strcasecmp(headers_in[counter].key, "Transfer-Encoding")) {
            te_val = headers_in[counter].val;
            continue;
        }
        
        if (!strcasecmp(headers_in[counter].key, "Content-Length")) {
            cl_val = headers_in[counter].val;
            continue;
        }
    }
    
    ap_log_error(
        APLOG_MARK, 
        APLOG_DEBUG, 
        0, 
        r->server,
        "pikevm: %s: Headers parsed",
        "ap_pikevm_pass_body"
    );
                         
    if (te_val && strcmp(te_val, "chunked") != 0) {
        ap_log_error(APLOG_MARK, APLOG_ERR, 0, r->server,
                     "pikevm: %s Transfer-Encoding is not supported",
                     te_val);
        return APR_EINVAL;
    }
    
    if (te_val) {
        if (cl_val) {
            ap_log_error(
                APLOG_MARK, 
                APLOG_DEBUG, 
                APR_ENOTIMPL, 
                r->server,
                "pikevm: client %s:%i requested Transfer-Encoding body"
                    " with Content-Length (C-L ignored)",
#ifdef USE_CONN_REC_CLIENT_IP
                rp->connection->client_ip,
#else
#ifdef USE_CONN_REC_REMOTE_IP                     
                rp->connection->remote_ip,
#else
                rp->useragent_ip,
#endif
#endif

#ifdef USE_CONN_REC_REMOTE_ADDR
                rp->connection->remote_addr->port
#else
                rp->connection->client_addr->port
#endif                   
            );
        }
        rb_method = RB_STREAM_CHUNKED;
    } else {
        if (cl_val) {
            rb_method = RB_STREAM_CL;
        } else {
            rb_method = RB_SPOOL_CL;
        }
    }
    
    /* send the request body, if any. */
    switch(rb_method) {
        case RB_STREAM_CHUNKED:
        status = ap_pikevm_stream_reqbody_chunked(
            r, 
            rd, 
            rp, 
            backend, 
            bb
        );
        break;
    case RB_STREAM_CL:
        status = ap_pikevm_stream_reqbody_cl(
            r, 
            rd, 
            rp, 
            backend, 
            bb, 
            cl_val
        );
        break;
    case RB_SPOOL_CL:
        status = ap_pikevm_spool_reqbody_cl(
            r, 
            rd, 
            rp, 
            backend, 
            bb,
            p_conn, 
            (cl_val != NULL) || 
                (te_val != NULL)
        );
        break;
    default:
        ap_assert(1 != 1);
        break;
    }
    
    if (status != APR_SUCCESS) {
        if (is_proxy) {
            ap_log_error(
                APLOG_MARK, 
                APLOG_ERR, 
                status, 
                r->server,
                "pikevm: pass request body failed to %pI (%s)"
                     " from %s:%i",
                     p_conn->addr, 
                     p_conn->name ? p_conn->name: "",
#ifdef USE_CONN_REC_CLIENT_IP
                rp->connection->client_ip,
#else
#ifdef USE_CONN_REC_REMOTE_IP                     
                rp->connection->remote_ip,
#else
                rp->useragent_ip,
#endif
#endif

#ifdef USE_CONN_REC_REMOTE_ADDR
                rp->connection->remote_addr->port
#else
                rp->connection->client_addr->port
#endif
            );
        } else {
            ap_log_error(
                APLOG_MARK, 
                APLOG_ERR, 
                status, 
                r->server,
                "pikevm: pass request body failed to /dev/null"
                    " from %s:%i ",
#ifdef USE_CONN_REC_CLIENT_IP
                rp->connection->client_ip,
#else
#ifdef USE_CONN_REC_REMOTE_IP                     
                rp->connection->remote_ip,
#else
                rp->useragent_ip,
#endif
#endif

#ifdef USE_CONN_REC_REMOTE_ADDR
                rp->connection->remote_addr->port
#else
                rp->connection->client_addr->port
#endif   
            );
        }
        return status;
    }
    return status;
}

// Protocol functions

void pikevm_add_signature(request_rec *r, apr_bucket_brigade *bb)
{
    char *buf;
    apr_bucket *e;

    ap_log_rerror(
    	APLOG_MARK,
    	APLOG_ERR,
    	0,
    	r,
        "pikevm: Warning:  pikevm_add_signature is not defined"
    );

    //TODO: X-PikeVM-Auth-Token: [RandomValue]
    //TODO: X-PikeVM-Auth-Signature: [Signature of Token]
    //TODO: X-PikeVM-Auth-Signature-Method: [Signature Algorithm]
}

static apr_table_t * ap_pikevm_read_headers(
    request_rec *r,
    request_rec *rp,
    char *buffer,
    int size,
    pikevm_conn_rec *backend
) {
    apr_table_t *headers_out;
    int len;
    char *value, *end;
    char field[MAX_STRING_LEN];
    int saw_headers = 0;

    headers_out = apr_table_make(r->pool, 20);

    /*
     * Read header lines until we get the empty separator line, a read error,
     * the connection closes (EOF), or we timeout.
     */
    while ((len = ap_getline(buffer, size, rp, 1)) > 0) {

	if (!(value = strchr(buffer, ':'))) {     /* Find the colon separator */

	    /* We may encounter invalid headers, usually from buggy
	     * MS IIS servers, so we need to determine just how to handle
	     * them. We can either ignore them, assume that they mark the
	     * start-of-body (eg: a missing CRLF) or (the default) mark
	     * the headers as totally bogus and return a 500. The sole
	     * exception is an extra "HTTP/1.0 200, OK" line sprinkled
	     * in between the usual MIME headers, which is a favorite
	     * IIS bug.
	     */
	     /* XXX: The mask check is buggy if we ever see an HTTP/1.10 */

	    if (!apr_date_checkmask(buffer, "HTTP/#.# ###*")) {
		    /* if we've already started loading headers_out, then
		     * return what we've accumulated so far, in the hopes
		     * that they are useful. Otherwise, we completely bail.
		     */
		    /* FIXME: We've already scarfed the supposed 1st line of
		     * the body, so the actual content may end up being bogus
		     * as well. If the content is HTML, we may be lucky.
		     */
		    if (saw_headers) {
			ap_log_error(APLOG_MARK, APLOG_WARNING, 0, r->server,
			 "proxy: Starting body due to bogus non-header in headers "
			 "returned by %s (%s)", r->uri, r->method);
			return headers_out;
		    } else {
			 ap_log_error(APLOG_MARK, APLOG_WARNING, 0, r->server,
			 "proxy: No HTTP headers "
			 "returned by %s (%s)", r->uri, r->method);
			return NULL;
		    }

	    }
	    /* this is the psc->badopt == bad_ignore case */
	    ap_log_error(APLOG_MARK, APLOG_WARNING, 0, r->server,
			 "proxy: Ignoring bogus HTTP header "
			 "returned by %s (%s)", r->uri, r->method);
	    continue;
	}

        *value = '\0';
        ++value;
	/* XXX: RFC2068 defines only SP and HT as whitespace, this test is
	 * wrong... and so are many others probably.
	 */
        while (apr_isspace(*value))
            ++value;            /* Skip to start of value   */

	/* should strip trailing whitespace as well */
	for (end = &value[strlen(value)-1]; end > value && apr_isspace(*end); --end)
	    *end = '\0';

        /* make sure we add so as not to destroy duplicated headers */
        apr_table_add(headers_out, buffer, value);
        saw_headers = 1;

	/* the header was too long; at the least we should skip extra data */
	if (len >= size - 1) {
	    while ((len = ap_getline(field, MAX_STRING_LEN, rp, 1))
		    >= MAX_STRING_LEN - 1) {
		/* soak up the extra data */
	    }
	    if (len == 0) /* time to exit the larger loop as well */
		break;
	}
    }
    return headers_out;
}

static apr_status_t ap_pikevm_set_connection_alias(
    request_rec *r,
    pikevm_http_conn_t *p_conn,
    pikevm_conn_rec *backend,
    pikevm_dir_cfg *dir_config,
    apr_bucket_brigade *bb
) {
    char *ts;
    int status = OK;
    int rc;
    char *buf;
    char *ptr,*eptr;
    char sport[7];
    int len;
    int ctr;
    char buffer[HUGE_STRING_LEN];

    request_rec *rp;
    request_rec *dev_null = NULL;
    apr_bucket *e;
    apr_pool_t *p = r->connection->pool;

    //TODO: Generate timestamp!

    //const apr_array_header_t *headers_in_array;
    //const apr_table_entry_t *headers_in;
    //const apr_table_t * headers;
    //headers = apr_table_make (r->pool, int nelts);
    //headers_in_array = apr_table_elts(r->headers_in);
    //headers_in = (const apr_table_entry_t *) headers_in_array->elts;

    // lets build our headers...

    ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "pikevm: %s: Setting headers.",
                         "ap_pikevm_set_connection_alias");
    //PUT * HTTP/1.1
    buf = apr_pstrcat(p, "PUT *.pike HTTP/1.1",
                      CRLF,
                      (void *)NULL);
    ap_xlate_proto_to_ascii(buf, strlen(buf));
    e = apr_bucket_pool_create(buf, strlen(buf), p, r->connection->bucket_alloc);
    APR_BRIGADE_INSERT_TAIL(bb, e);

    ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "pikevm: %s: Status line set.",
                         "ap_pikevm_set_connection_alias");
                         
    //Content-Length: 0
    buf = apr_pstrcat(p, "Content-Length: ",
                      "0",
                      CRLF,
                      (void *)NULL);
    ap_xlate_proto_to_ascii(buf, strlen(buf));
    e = apr_bucket_pool_create(buf, strlen(buf), p, r->connection->bucket_alloc);
    APR_BRIGADE_INSERT_TAIL(bb, e);

    //Expect: 100-continue
    buf = apr_pstrcat(p, "Expect: ",
                      "100-continue",
                      CRLF,
                      (void *)NULL);
    ap_xlate_proto_to_ascii(buf, strlen(buf));
    e = apr_bucket_pool_create(buf, strlen(buf), p, r->connection->bucket_alloc);
    APR_BRIGADE_INSERT_TAIL(bb, e);

    //Content-Type: application/pike
    buf = apr_pstrcat(p, "Content-Type: ",
                      "application/pike",
                      CRLF,
                      (void *)NULL);
    ap_xlate_proto_to_ascii(buf, strlen(buf));
    e = apr_bucket_pool_create(buf, strlen(buf), p, r->connection->bucket_alloc);
    APR_BRIGADE_INSERT_TAIL(bb, e);

    //Connection: keep-alive
    buf = apr_pstrcat(p, "Connection: ",
                      "keep-alive",
                      CRLF,
                      (void *)NULL);
    ap_xlate_proto_to_ascii(buf, strlen(buf));
    e = apr_bucket_pool_create(buf, strlen(buf), p, r->connection->bucket_alloc);
    APR_BRIGADE_INSERT_TAIL(bb, e);

    
    //X-PikeVM-Action: set-connection-alias
    buf = apr_pstrcat(p, "X-PikeVM-Action: ",
                      "set-connection-alias",
                      CRLF,
                      (void *)NULL);
    ap_xlate_proto_to_ascii(buf, strlen(buf));
    e = apr_bucket_pool_create(buf, strlen(buf), p, r->connection->bucket_alloc);
    APR_BRIGADE_INSERT_TAIL(bb, e);
                         
    //X-PikeVM-Set-Client-IP: x.x.x.x
    buf = apr_pstrcat(
        p, "X-PikeVM-Set-Client-IP: ",
#ifdef USE_CONN_REC_REMOTE_IP
        r->connection->remote_ip,
#else
#ifdef USE_CONN_REC_CLIENT_IP
        r->connection->client_ip,
#else
        r->useragent_ip,
#endif
#endif
        CRLF,
        NULL
    );
                         
    ap_xlate_proto_to_ascii(buf, strlen(buf));
    e = apr_bucket_pool_create(buf, strlen(buf), p, r->connection->bucket_alloc);
    APR_BRIGADE_INSERT_TAIL(bb, e);

    //X-PikeVm-Set-Client-Port: x
    apr_snprintf(
        sport,
        sizeof(sport),
        "%d",
#ifdef USE_CONN_REC_REMOTE_ADDR
        r->connection->remote_addr->port
#else
        r->connection->client_addr->port
#endif

    );
    buf = apr_pstrcat(p, "X-PikeVM-Set-Client-Port: ",
                      sport,
                      CRLF,
                      NULL);
    ap_xlate_proto_to_ascii(buf, strlen(buf));
    e = apr_bucket_pool_create(buf, strlen(buf), p, r->connection->bucket_alloc);
    APR_BRIGADE_INSERT_TAIL(bb, e);

    pikevm_add_signature(r,bb);

    //TODO: X-PikeVM-Timestamp: *ts

    // End Headers
    buf = apr_pstrcat(p,
                      CRLF,
                      CRLF,
                      NULL);
    ap_xlate_proto_to_ascii(buf, strlen(buf));
    e = apr_bucket_pool_create(buf, strlen(buf), p, r->connection->bucket_alloc);
    APR_BRIGADE_INSERT_TAIL(bb, e);

    ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "pikevm: %s: Headers completed.",
                         "ap_pikevm_set_connection_alias");

    status = ap_pikevm_pass_brigade(
        r->connection->bucket_alloc,
        r,
        p_conn,
        backend->connection,
        bb,
        1
    );

    if (status != OK) {
        ap_log_error(APLOG_MARK, APLOG_ERR, 0, r->server,
                         "pikevm: %s: Pass brigade failed.",
                         "ap_pikevm_set_connection_alias");
        return status;
    }
    
    ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "pikevm: %s: Brigade sent.",
                         "ap_pikevm_set_connection_alias");

    // Headers sent! Now lets get our response!

        ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "pikevm: %s: Preparing fake request.",
                         "ap_pikevm_set_connection_alias");
    rp = ap_pikevm_make_fake_req(backend, r);

    ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "pikevm: %s: Fake request prepared.",
                         "ap_pikevm_set_connection_alias");
                         
    len = ap_getline(buffer, sizeof(buffer), rp, 0);
    if (len == 0) {
        /* handle one potential stray CRLF */
        len = ap_getline(buffer, sizeof(buffer), rp, 0);
    }

    if (len <= 0) {
        apr_socket_close(p_conn->sock);
        backend->connection = NULL;
        ap_log_rerror(APLOG_MARK, APLOG_ERR, 0, r,
                      "pikevm: error reading status line from remote "
                      "server %s", p_conn->name);
        return ap_pikevm_error(r, HTTP_BAD_GATEWAY,
                             "Error reading from remote server");
    }
    
    ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "pikevm: %s: Have status line.",
                         "ap_pikevm_set_connection_alias");
                         
    //Process status line for code
    ptr = &buffer[0];
    ctr = 0;
    
    // skip version
    while(*ptr != 0 && *ptr != 32 && ctr < (HUGE_STRING_LEN - 3)) {
        ptr++;
        ctr++;
    }

    // grab status
    status = HTTP_BAD_GATEWAY;
    if (ctr + 3 < HUGE_STRING_LEN && *ptr != 0) {
        *ptr++ = 0;
        eptr = ptr;
        ctr = 0;
        while(ctr < 3 && *eptr != 0) {
            ctr++;
            eptr++;
        }

        if (ctr == 3) {
            *eptr = 0;
            status = atoi(ptr);
        }
    }

    ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "pikevm: %s: Status = %i.",
                         "ap_pikevm_set_connection_alias",
                         status);

    // Read headers
    rp->headers_in = ap_pikevm_read_headers(r, rp, buffer,sizeof(buffer), backend);

    ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "pikevm: %s: Have PikeVM Response Headers.",
                         "ap_pikevm_set_connection_alias");
                         
    // Send body to dev/null
    rc = ap_pikevm_pass_body(r,dev_null,rp,backend,p_conn,bb);
    if (OK != rc) {        
        return status;
    }

    if (status != HTTP_CONTINUE) {
        return ap_pikevm_error(
            r,
            HTTP_BAD_GATEWAY,
            apr_psprintf(r->pool, "pikevm: ap_pikevm_set_connection_alias Gateway returned invalid response. Status = %i",status)
        );
    }

    ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "pikevm: %s: Horray!!!",
                         "ap_pikevm_set_connection_alias");
                         
    /* Log this for security purposes, if request is not in this log we have someone bypassing this module */
    ap_log_error(
        APLOG_MARK,
        APLOG_DEBUG,
        0,
        r->server,
        "pikevm: set-connection-alias SUCCESS at %s",
        ts
    );
    return HTTP_CONTINUE;
}

// Connection functions

static apr_status_t ap_pikevm_create_connection(
    request_rec *r,
    apr_uri_t *uri,
    pikevm_http_conn_t *p_conn,
    pikevm_conn_rec *backend,
    pikevm_dir_cfg *dir_config,
    apr_bucket_brigade *bb
) {
    int rc;
    conn_rec *origin;
    
    apr_socket_t *client_socket = NULL;

    apr_status_t err;
    apr_sockaddr_t *uri_addr;
    apr_sockaddr_t *backend_addr;
    int recv_buffer_size = 4096;

    int create_socket = 1;
    char * url;

    /*
     * Break up the URL to determine the host to connect to
     */

    url = r->filename;

    /* we break the URL into host, port, uri */
    if (APR_SUCCESS != apr_uri_parse(r->connection->pool, url, uri)) {
        return ap_pikevm_error(
            r,
            HTTP_BAD_REQUEST,
            apr_pstrcat(r->pool,"URI cannot be parsed: ", url,NULL)
        );
    }
    ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "pikevm: %s: URI Parsed.",
                         "ap_pikevm_create_connection");
                         
    uri->scheme = apr_pstrdup(r->connection->pool, "http");
    
    ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "pikevm: %s: Scheme set %s",
                         "ap_pikevm_create_connection",
                         uri->scheme);
                         
    uri->port = dir_config->port;
    if (!uri->port) {
        uri->port = apr_uri_port_of_scheme(uri->scheme);
    }
    
    ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "pikevm: %s: Port set.",
                         "ap_pikevm_create_connection");
                         
    uri->hostname = apr_pstrdup(r->connection->pool,dir_config->host);

    ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "pikevm: %s: Hostname set %s.",
                         "ap_pikevm_create_connection",uri->hostname);

    ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                 "pikevm: HTTP connecting %s to %s:%d", url, uri->hostname,
                 uri->port);

    /* do a DNS lookup for the destination host */
    /* see memory note above */
    err = apr_sockaddr_info_get(&uri_addr, apr_pstrdup(r->connection->pool, uri->hostname),
                                APR_UNSPEC, uri->port, 0, r->connection->pool);

    p_conn->name = apr_pstrdup(r->connection->pool, uri->hostname);
    p_conn->port = uri->port;
    p_conn->addr = uri_addr;
    url = apr_pstrcat(r->pool, uri->path, uri->query ? "?" : "",
                           uri->query ? uri->query : "",
                           uri->fragment ? "#" : "",
                           uri->fragment ? uri->fragment : "", NULL);


    if (err != APR_SUCCESS) {
        return ap_pikevm_error(r, HTTP_BAD_GATEWAY,
                             apr_pstrcat(r->pool, "DNS lookup failure for: ",
                                         p_conn->name, NULL));
    }

    if (backend->connection) {
        // Validate existing connection

        client_socket = ap_get_module_config(backend->connection->conn_config, &pikevm_module);
        if ((backend->connection->id == r->connection->id) &&
            (backend->port == p_conn->port) &&
            (backend->hostname) &&
            (!apr_strnatcasecmp(backend->hostname, p_conn->name))) {
            ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "proxy: keepalive address match (keep original socket)");
        } else {
            ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "proxy: keepalive address mismatch / connection has"
                         " changed (close old socket (%s/%s, %d/%d))",
                         p_conn->name, backend->hostname, p_conn->port,
                         backend->port);
            apr_socket_close(client_socket);
            backend->connection = NULL;
        }
    }

    if (!backend) {
        create_socket = 1;
    }


    if (create_socket) {

        apr_status_t rv;
        int connected = 0;
        int loglevel;
        backend_addr = p_conn->addr;

        while (backend_addr && !connected) {
            if (
                (
                    rv = apr_socket_create(
                        &p_conn->sock,
                        backend_addr->family,
                        SOCK_STREAM,
                        APR_PROTO_TCP,
                        r->connection->pool
                    )
                ) != APR_SUCCESS) {
                loglevel = backend_addr->next ? APLOG_DEBUG : APLOG_ERR;
                ap_log_error(APLOG_MARK, loglevel, rv, r->server,
                         "pikevm: %s: error creating fam %d socket for target %s",
                         "ap_pikevm_create_connection",
                         backend_addr->family,
                         p_conn->name);
                /* this could be an IPv6 address from the DNS but the
                 * local machine won't give us an IPv6 socket; hopefully the
                 * DNS returned an additional address to try
                 */
                backend_addr = backend_addr->next;
                continue;
            }

#if !defined(TPF) && !defined(BEOS)
            if (recv_buffer_size > 0 &&
                (rv = apr_socket_opt_set(p_conn->sock, APR_SO_RCVBUF,
                                     recv_buffer_size))) {
                ap_log_error(APLOG_MARK, APLOG_ERR, rv, r->server,
                         "apr_socket_opt_set(SO_RCVBUF): Failed to set "
                         "ProxyReceiveBufferSize, using default");
            }
#endif

            /* Set a timeout on the socket */
            apr_socket_timeout_set(p_conn->sock, r->server->timeout);


            ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                     "pikevm:  fam %d socket created to connect to %s",
                      backend_addr->family, p_conn->name);

            /* make the connection out of the socket */
            //rv = apr_connect(p_conn->sock, backend_addr);
            rv = apr_socket_connect(p_conn->sock, backend_addr);

            /* if an error occurred, loop round and try again */
            if (rv != APR_SUCCESS) {
                apr_socket_close(p_conn->sock);
                loglevel = backend_addr->next ? APLOG_DEBUG : APLOG_ERR;
                ap_log_error(APLOG_MARK, loglevel, rv, r->server,
                         "pikevm: %s: attempt to connect to %pI (%s) failed",
                         "ap_pikevm_create_connection",
                         backend_addr,
                         p_conn->name);
                backend_addr = backend_addr->next;
                continue;
            }
            connected = 1;
        }
        if (!connected) {
            ap_log_error(APLOG_MARK, APLOG_ERR, 0, r->server,
                         "pikevm: %s: Connection failed.",
                         "ap_pikevm_create_connection");
            return HTTP_BAD_GATEWAY;
        }
        
        // Register backend...
        
        origin = ap_run_create_connection(r->connection->pool, r->server, p_conn->sock,
                                           r->connection->id,
                                           r->connection->sbh, r->connection->bucket_alloc);
        if (!origin) {
        /* the peer reset the connection already; ap_run_create_connection() 
         * closed the socket
         */
            ap_log_error(APLOG_MARK, APLOG_DEBUG, 0,
                         r->server, "pikevm: an error occurred creating a "
                         "new connection to %pI (%s)", p_conn->addr,
                         p_conn->name);
            apr_socket_close(p_conn->sock);
            return HTTP_INTERNAL_SERVER_ERROR;
        }
        backend->connection = origin;
        backend->hostname = apr_pstrdup(r->connection->pool, p_conn->name);
        backend->port = p_conn->port;
        
        /*                                                                        
        if (backend->is_ssl) {
            if (!ap_proxy_ssl_enable(backend->connection)) {
                ap_log_error(APLOG_MARK, APLOG_ERR, 0,
                             r->server, "pikevm: failed to enable ssl support "
                             "for %pI (%s)", p_conn->addr, p_conn->name);
                return HTTP_INTERNAL_SERVER_ERROR;
            }
        }
        else {
            ap_proxy_ssl_disable(backend->connection);
        }
        */
        
        ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                     "pikevm: connection complete to %pI (%s)",
                     p_conn->addr, p_conn->name);
        
        /* set up the connection filters */
        rc = ap_run_pre_connection(origin, p_conn->sock);
        if (rc != OK && rc != DONE) {
            origin->aborted = 1;
            ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "pikevm: HTTP: pre_connection setup failed (%d)",
                         rc);
            return rc;
        }
                                              
        //TODO: Special handling if this is a relay request
        err = ap_pikevm_set_connection_alias(
            r,
            p_conn,
            backend,
            dir_config,
            bb
        );

        
        // receive response

        if (err == OK) {
            ap_log_error(APLOG_MARK, APLOG_ERR, 0, r->server,
              "pikevm: %s: Not a pike server.",
              "ap_pikevm_create_connection");
            return HTTP_BAD_GATEWAY; // Where is pike?
        }
        
        if (err != HTTP_CONTINUE) {       
            return err;
        }
        
        ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
              "pikevm: %s: Connection alias set.",
              "ap_pikevm_create_connection");
    }

    return OK;
}

// Process functions

static apr_status_t ap_pikevm_send_request(request_rec *r,pikevm_http_conn_t *p_conn, pikevm_dir_cfg *dir_config,apr_bucket_brigade *bb)
{
    return OK;
}

static apr_status_t ap_pikevm_process_response(request_rec *r,pikevm_http_conn_t *p_conn, pikevm_dir_cfg *dir_config,apr_bucket_brigade *bb)
{
    // set content type
    ap_set_content_type(r, "text/html");


    // The first thing we will do is write a simple "Hello, world!" back to the client.
    //ap_rputs("Hello, world!<br/>", r);
    ap_rprintf(r, "Hello, world!<br />");
    ap_rprintf(r, "Port: %i<br />",dir_config->port);
    ap_rprintf(r, "Host: %s<br />", dir_config->host == NULL ? "<b class=\"null_value\">NULL</b>" :dir_config->host);

    return OK;
}

static pikevm_conn_rec * ap_pikevm_get_backend(request_rec *r)
{

    pikevm_conn_rec *backend = NULL;
    if (!r->main) {
        backend = (pikevm_conn_rec *) ap_get_module_config(
            r->connection->conn_config,
            &pikevm_module
        );
    }
    if (!backend) {
        backend = apr_pcalloc(r->connection->pool, sizeof(pikevm_conn_rec));
        backend->connection = NULL;
        backend->hostname = NULL;
        backend->port = 0;
        if (!r->main) {
            ap_set_module_config(r->connection->conn_config, &pikevm_module, backend);
        }
    }

    backend->is_ssl = 0;

    return backend;
}

/* ap_pikevm_handler: The handler function for our module. */

static int ap_pikevm_handler(request_rec *r)
{
    pikevm_dir_cfg *dir_config;
    pikevm_http_conn_t *p_conn;
    pikevm_conn_rec *backend;
    apr_bucket_brigade *bb;
    apr_uri_t *uri;
    int status;
    //apr_pool_t *p = r->connection->pool;

    /* First off, we need to check if this is a call for the "pikevm" handler.
     * If it is, we accept it and do our things, it not, we simply return DECLINED,
     * and Apache will try somewhere else.
     */
    if (!r->handler || strcmp(r->handler, "pikevm-handler")) return (DECLINED);

    // grab configuration
    dir_config = (pikevm_dir_cfg*) ap_get_module_config(r->per_dir_config, &pikevm_module);
    
    // test configuration
    if (dir_config->host == NULL || dir_config->port == -1) {
            ap_log_error(APLOG_MARK, APLOG_ERR, 0, r->server,
                         "pikevm: %s: incomplete configuration (host=%s port=%i). Add PikeVMHost and PikeVMPort to your configuration.",
                         "ap_pikevm_handler",
                         dir_config->host,
                         dir_config->port);
            return HTTP_BAD_GATEWAY;
    }
    
    ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "pikevm: %s: configuration OK (host=%s port=%i, has_main=%i).",
                         "ap_pikevm_handler",
                         dir_config->host,
                         dir_config->port,
                         r->main ? 1 : 0
                         );
   
    // Allocate Resources
    
    // Is this right? Shouldn't this brigade be created from the backend connection?
    bb = apr_brigade_create(r->connection->pool, r->connection->bucket_alloc);

    p_conn = apr_pcalloc(r->connection->pool, sizeof(*p_conn));
    uri = apr_palloc(r->connection->pool, sizeof(*uri));

    backend = ap_pikevm_get_backend(r);

    ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "pikevm: %s: Resources allocated.",
                         "ap_pikevm_handler");
                         
    // Create Connection
    status = ap_pikevm_create_connection(r, uri, p_conn, backend, dir_config,bb);
    if ( status != OK ) {
        ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "pikevm: %s: after_pikevm_create_connection: clean exit [status=%i].",
                         "ap_pikevm_handler",
                         status
        );    
        return status;
    }

    ap_log_error(APLOG_MARK, APLOG_DEBUG, 0, r->server,
                         "pikevm: %s: Sending request.",
                         "ap_pikevm_handler");
                         
    status = ap_pikevm_send_request(r, p_conn, dir_config,bb);
    if ( status != OK ) {
        return status;
    }

    status = ap_pikevm_process_response(r,p_conn, dir_config,bb);
    if (status != OK) {
        return status;
    }

    return OK;
}


/* ap_pikevm_register_hooks: Adds a hook to the httpd process */
static void ap_pikevm_register_hooks(apr_pool_t *pool)
{
    pikevm_init(pool);
    /* Hook the request handler */
    ap_hook_handler(ap_pikevm_handler, NULL, NULL, APR_HOOK_LAST);
}



