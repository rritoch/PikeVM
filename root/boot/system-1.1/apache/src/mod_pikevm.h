#ifndef __MOD_PIKEVM_H
#define __MOD_PIKEVM_H

#include "../config.h"

#undef PACKAGE_VERSION
#undef PACKAGE_TARNAME
#undef PACKAGE_STRING
#undef PACKAGE_NAME
#undef PACKAGE_BUGREPORT

#define CORE_PRIVATE

#include "apr_hooks.h"
#include "apr.h"
#include "apr_lib.h"
#include "apr_strings.h"
#include "apr_buckets.h"
#include "apr_md5.h"
#include "apr_network_io.h"
#include "apr_pools.h"
#include "apr_strings.h"
#include "apr_uri.h"
#include "apr_date.h"
#include "apr_fnmatch.h"
#define APR_WANT_STRFUNC
#include "apr_want.h"

#include "httpd.h"
#include "http_config.h"
#include "ap_config.h"
#include "http_core.h"
#include "http_protocol.h"
#include "http_request.h"
#include "http_vhost.h"
#include "http_main.h"
#include "http_log.h"
#include "http_connection.h"
#include "util_filter.h"
#include "util_ebcdic.h"

typedef struct {
    int reserved; // Reserved for future use
} pikevm_svr_cfg;

typedef struct {
    const char     *name;
    apr_port_t      port;
    apr_sockaddr_t *addr;
    apr_socket_t   *sock;
    int             close;
} pikevm_http_conn_t;


typedef struct {
    char *host;
    int port;
    char *signature_method;
    char *secret;
} pikevm_dir_cfg;

typedef struct {
    conn_rec *connection;
    char *hostname;
    apr_port_t port;
    int is_ssl;
} pikevm_conn_rec;

#endif

