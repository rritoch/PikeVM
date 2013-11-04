#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ(2.59)
AC_INIT(FULL-PACKAGE-NAME, VERSION, BUG-REPORT-ADDRESS)
AC_CONFIG_AUX_DIR(config)
AC_CONFIG_SRCDIR([src/mod_pikevm.c])

AM_INIT_AUTOMAKE

# Checks for programs.
AC_PROG_CC

dnl Note: AC_DEFUN goes here plus other stuff

AC_MSG_CHECKING(for apache APXS)
AC_ARG_WITH(apxs,
            [AS_HELP_STRING([[--with-apxs[=FILE]]],
                            [path to the apxs, defaults to "apxs".])],
[
    if test "$withval" = "yes"; then
      APXS=apxs
    else
      APXS="$withval"
    fi
])

if test -z "$APXS"; then
  for i in /usr/sbin /usr/local/apache/bin /usr/bin ; do
    if test -f "$i/apxs2"; then
      APXS="$i/apxs2"
      break
    fi
    if test -f "$i/apxs"; then
      APXS="$i/apxs"
      break
    fi
  done
fi
AC_SUBST(APXS)

# Checks for libraries.

# Checks for header files.

# Checks for typedefs, structures, and compiler characteristics.

AC_CHECK_MEMBER(struct con_rec.remote_ip, define 'USE_CON_REC_REMOTE_IP',,[#include "httpd.h"]);
AC_CHECK_MEMBER(struct con_rec.client_ip, define 'USE_CON_REC_CLIENT_IP',,[#include "httpd.h"]);
AC_CHECK_MEMBER(struct con_rec.remote_addr, define 'USE_CON_REC_REMOTE_ADDR',,[#include "httpd.h"]);

# Checks for library functions.
AC_OUTPUT(Makefile src/Makefile)

