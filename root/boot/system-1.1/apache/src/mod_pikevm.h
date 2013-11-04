#ifndef __MOD_PIKEVM_H
#define __MOD_PIKEVM_H

#include "../config.h"

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

