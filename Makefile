# $Id$

PROJ := getcrl
VERSION := 1.8
MANSECT:=8
CENTER=" "
POD2MANFLAGS = --section=$(MANSECT) --center=$(CENTER) 
POD2HTMLFLAGS = --title=$(PODS:.pod=)

SRCS :=  getcrl.sh.in getcrls.sh.in
PRGS := $(SRCS:.in=)
PODS := getcrl.pod
MANS := $(PODS:.pod=.$(MANSECT))
HTML := $(PODS:.pod=.html)
TRANS := $(PRGS:=.transh)

DISTS = $(MANS) $(PODS) $(HTML) $(SRCS) $(CFG) Makefile.in configure configure.in README

prefix := /tmp/getcrl-1.10
exec_prefix := ${prefix}
sbindir := ${exec_prefix}/sbin
mandir := ${prefix}/share/man
sysconfdir := ${prefix}/etc
mandir := ${prefix}/share/man
man8ext := .$(MANSECT)
srcdir := .

man: $(MANS)

html: $(HTML)

install: transform installdirs install-prgs install-cfg install-man

installdirs:
	install -d -groot -oroot $(prefix);\
	install -d -groot -oroot $(exec_prefix);\
	install -d -groot -oroot $(sbindir);\
	install -d -groot -oroot $(sysconfigdir);\
	install -d -groot -oroot $(mandir);\
	install -d -groot -oroot $(mandir)/man$(MANSECT);\

install-prgs: $(TRANS)
	for i in $(TRANS); do\
	install -groot -oroot -m0755 $$i $(sbindir)/`basename $$i .transh`;\
	rm $$i;\
	done

install-cfg: $(CFG)

#	install -groot -oroot -m0755 $(CFG) $(sysconfdir)

install-man: $(MANS)
	install -groot -oroot -m0644 $(MANS) $(mandir)/man$(MANSECT)

uninstall: uninstall-prgs uninstall-cfg uninstall-man

uninstall-prgs:
	-for i in $(PRGS); do rm $(sbindir)/$$i; done

uninstall-cfg:
	-for i in $(CFG); do rm $(sysconfdir)/$$i; done

uninstall-man:
	-for i in $(MANS); do rm $(mandir)/man$(MANSECT)/$$i; done

transform: $(TRANS)

clean:
	-rm *.transh Makefile $(PRGS)

maintainer-clean: clean
	-rm $(MANS) $(HTML)

dist: DDIR := $(PROJ)-$(VERSION)

dist: $(DISTS) 
	mkdir $(DDIR) && cp $^ $(DDIR) && \
	tar zcvf $(DDIR).tar.gz $(DDIR) && rm -rf $(DDIR)

%.$(MANSECT): %.pod
	pod2man $(POD2MANFLAGS) $< $@

%.html: %.pod
	pod2html $(POD2HTMLFLAGS) --infile=$< --outfile=$@

%.transh: %
	sed -e 's@CFGDIR="."@CFGDIR="$(sysconfdir)"@;s@SBINDIR="."@SBINDIR="$(sbindir)"@' $< > $@

# DBG
oracle:
	@echo $(sbindir); \
	echo $(manext); \
	echo logger /usr/bin/logger; \
	echo sss @REM_STARTSTOP@; \
	echo ldapsearch $(rldapsearch) \
	echo "DISTS: " $(DISTS)

#############


#MANSECT:=8
#CENTER=" "
#POD2MANFLAGS = --section=$(MANSECT) --center=$(CENTER) 
#POD2HTMLFLAGS = --title=$(PODS:.pod=)

#PRGS := getcrl.sh getcrls.sh
#PODS := getcrl.pod
#MANS = $(PODS:.pod=.$(MANSECT))
#HTML = $(PODS:.pod=.html)

#DISTS = $(MANS) $(PODS) $(HTML) $(PRGS) Makefile

#man: $(MANS)

#html: $(HTML)

#dist: DDIR := $(PROJ)-$(VERSION)

#dist: $(DISTS) 
#	mkdir $(DDIR) && cp $^ $(DDIR) && \
#	tar zcvf $(DDIR).tar.gz $(DDIR) && rm -rf $(DDIR)

#%.$(MANSECT): %.pod
#	pod2man $(POD2MANFLAGS) $< $@

#%.html: %.pod
#	pod2html $(POD2HTMLFLAGS) --infile=$< --outfile=$@