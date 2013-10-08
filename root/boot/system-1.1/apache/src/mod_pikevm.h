#ifndef __MOD_PIKEVM_H
#define __MOD_PIKEVM_H

typedef struct {
    int reserved; // Reserved for future use
} pikevm_svr_cfg ;

typedef struct {
    char *host;
    int port;
} pikevm_dir_cfg ;

#endif