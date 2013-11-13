#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ(2.59)
AC_INIT(FULL-PACKAGE-NAME, VERSION, BUG-REPORT-ADDRESS)
AC_CONFIG_AUX_DIR(config)
AC_CONFIG_SRCDIR([src/mod_pikevm.c])
AC_CONFIG_MACRO_DIR([m4.inc])
m4_include([m4/m4-ax_with_apxs.m4])

AM_INIT_AUTOMAKE

AC_CONFIG_HEADER(config.h)

# Checks for programs.
AC_PROG_CC
AX_WITH_APXS()

dnl Note: AC_DEFUN goes here plus other stuff

# Checks for libraries.

# Checks for header files.

# Checks for typedefs, structures, and compiler characteristics.

tmp_ac_compile=$ac_compile
ac_compile='$APXS -c conftest.$ac_ext'

AC_CHECK_MEMBER([conn_rec.remote_ip], AC_DEFINE(USE_CONN_REC_REMOTE_IP,1,[Do we have conn_rec.remote_ip]) ,,[#include "httpd.h"])
AC_CHECK_MEMBER(conn_rec.client_ip, AC_DEFINE(USE_CONN_REC_CLIENT_IP,1,[Do we have conn_rec.client_ip]),,[#include "httpd.h"])
AC_CHECK_MEMBER(conn_rec.remote_addr, AC_DEFINE(USE_CONN_REC_REMOTE_ADDR,1,[Do we have conn_rec.remote_addr]),,[#include "httpd.h"])


ac_compile=$tmp_ac_compile

# Checks for library functions.
AC_OUTPUT(Makefile src/Makefile)

