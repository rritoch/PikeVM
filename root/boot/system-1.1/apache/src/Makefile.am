## Find apache sys config dir

APACHE2_SYSCONFDIR = `@APXS@ -q SYSCONFDIR`

APXS_LIBEXECDIR:=$(shell @APXS@ -q LIBEXECDIR)

## Misc automake stuff goes here

install: install-am
	touch findme.txt
	cp pikevm.conf $(DESTDIR)${APACHE2_SYSCONFDIR}/../conf.d/pikevm.conf

all-am: Makefile mod_pikevm.la

mod_pikevm.la: mod_pikevm.c
	@APXS@ -c ${LIBS} -Wc,"${CFLAGS} ${CPPFLAGS}" -Wl,"${LDFLAGS}" $(srcdir)/mod_pikevm.c

install-exec-am:
	if test ! -d ${DESTDIR}${APXS_LIBEXECDIR}; then mkdir -p ${DESTDIR}${APXS_LIBEXECDIR}; fi
	@APXS@ -i -S LIBEXECDIR=${DESTDIR}${APXS_LIBEXECDIR} $(srcdir)/mod_pikevm.la

clean-generic:
	rm -rf $(srcdir)/mod_pikevm.slo $(srcdir)/mod_pikevm.la $(srcdir)/mod_pikevm.o $(srcdir)/mod_pikevm.lo $(srcdir)/mod_pikevm.loT $(srcdir)/.libs

