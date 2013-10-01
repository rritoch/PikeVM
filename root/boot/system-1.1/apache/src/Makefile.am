## Find apache sys config dir
APACHE2_SYSCONFDIR = `@APXS@ -q SYSCONFDIR`

## Misc automake stuff goes here

install: install-am
	cp pikevm.conf $(DESTDIR)${APACHE2_SYSCONFDIR}/conf.d/pikevm.conf

all-am: Makefile mod_pikevm.la

mod_pikevm.la: mod_pikevm.c
	@APXS@ -c ${LIBS}-Wc,"${CFLAGS} ${CPPFLAGS}" -Wl,"${LDFLAGS}" $(srcdir)/mod_pikevm.c

clean-generic:
	rm -rf $(srcdir)/mod_pikevm.slo $(srcdir)/mod_pikevm.la $(srcdir)/mod_pikevm.o $(srcdir)/mod_pikevm.lo $(srcdir)/mod_pikevm.loT $(srcdir)/.libs

