PREFIX = $(HOME)

BINDIR = $(PREFIX)/bin
DATAROOTDIR = $(PREFIX)/share
MANDIR = $(DATAROOTDIR)/man

CC = gcc

CFLAGS = -gdwarf-2 -Os -march=native -mtune=native -pedantic -mdynamic-no-pic -ffast-math -fstrict-aliasing -ftree-vectorize -flto -std=gnu99 -pipe -combine -fvisibility=hidden -fno-pic -Wfatal-errors -Wall -Wextra -Wcast-align -Wwrite-strings -Wstrict-prototypes -Wno-cast-qual -freorder-blocks -feliminate-unused-debug-types

APPKIT = -framework AppKit

POST_PROCESS = /usr/bin/strip -no_uuid
INSTALL = install -d

UTILS = alert any2txt app appr beep bundle cifilter displaysleep dup fileicon goosh hotkeys impbrowser imgconv imgshadow imgsnap imgtext imgview imgwin loginitems menu nml normalize pdfcat pdfextract pdfinfo pid ql quit readalias setapp seticon slideshow trash uti win winalpha winlevel winmove winshadow wintransform wintransition xattr

.PHONY: all install clean

all:	$(UTILS)

install: all
	mkdir -p $(BINDIR)
	$(INSTALL) $(UTILS) $(BINDIR)

climac.h : alloc.h ret_codes.h version.h

$(UTILS) : climac.h

alert : alert.m
	$(CC) $(CFLAGS) -framework AppKit $< -o $@
app : app.m
	$(CC) $(CFLAGS) -framework AppKit $< -o $@
appr : appr.m
	$(CC) $(CFLAGS) -framework AppKit $< -o $@

goosh : goosh.m goosh-fn.m goosh-fn.h goosh-JSON.m goosh-JSON.h
	$(CC) $(CFLAGS) $(APPKIT) $(srcdir)/goosh.m $(srcdir)/goosh-fn.m $(srcdir)/goosh-JSON.m -o $@

% :: %.c
	$(CC) $(CFLAGS) $< -o $@

% :: %.m
	$(CC) $(CFLAGS) -framework Foundation $< -o $@

