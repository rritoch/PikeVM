## Find apache sys config dir
APACHE2_SYSCONFDIR = `@APXS@ -q SYSCONFDIR`

## Misc automake stuff goes here

install: install-am
	cp src/pikevm.conf $(DESTDIR)${APACHE2_SYSCONFDIR}/conf.d/pikevm.conf

