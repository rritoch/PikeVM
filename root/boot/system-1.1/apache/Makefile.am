

distclean-generic:
	-test -z "$(CONFIG_CLEAN_FILES)" || rm -f $(CONFIG_CLEAN_FILES)
	rm -rf autom4te.cache

mod_pikevm/Makefile.am:
    ACLOCAL_AMFLAGS = -I m4
    SUBDIRS = src
    EXTRA_DIST = autogen.sh
