#!/usr/bin/env zsh

#typeset -A opts
#zparseopts -K -D -E -A opts -- -install=flags -style: -prefix: -bin-prefix: -man-prefix:

emulate -L zsh

TRAPZERR(){ echo ' ** Build Failed **'; exit 1 }

cd $0:h/src
SELF=../$0:t

#DEBUG=0

: ${PREFIX:=$HOME}
: ${BINDIR:=$PREFIX/bin}
: ${DATADIR:=$PREFIX/share}
: ${MANDIR:=$DATADIR/man}

: ${CC:=clang}

_CFLAGS=(-Os -mtune=native -ffast-math -fstrict-aliasing -ftree-vectorize -std=gnu99 -pipe -fvisibility=hidden -fno-pic -Wfatal-errors -Wall -Wextra -Wcast-align -Wwrite-strings -Wstrict-prototypes -Wno-cast-qual -freorder-blocks)

if [[ $CC:t == clang ]]; then
	_CFLAGS+=-march=native
fi
[[ $CC:t != gcc ]] && _CFLAGS+=-flto

UTILS=(alert any2txt app appr beep bundle cifilter dict displaysleep dup fileicon goosh hotkeys imgbrowser imgconv imgshadow imgsnap imgtext imgview imgwin loginitems menu nml normalize pdfcat pdfextract pdfinfo pid ql quit readalias setapp seticon slideshow trash uti win winalpha winlevel winmove winshadow wintransform wintransition xattr)

# HELPER FUNCTIONS

DOIT(){
	print -- $*
	[[ -z $DEBUG ]] && $*
}

# _make  util-name  extra-cflags
_make(){
  DOIT $CC -DUTIL_NAME=$1 $_CFLAGS ${(P)$(print ${1}_CFLAGS)} ${(z)CFLAGS} -o $* && _post $1
}
# post-processing of built product
_post(){
	DOIT strip $1
}

# nt  util-name  dependencies
# test if built binary up-to-date
# this script is also considered a dependency
nt(){
	[[ ! -e $1 || $SELF -nt $1 ]] && return 0
	for i ($*[2,-1]) [[ $i -nt $1 ]] && return 0
	return 1
}

# used if _make_util not specified
mk(){
	if [[ -e $1.m ]]; then
		cc_objc $*
	elif [[ -e $1.c ]]; then
		cc_c $*
	else
		print -u2 Don\'t know how to make $1
	fi
}
shared_deps=(version.h climac.h alloc.h ret_codes.h)
cc_c(){ nt $1{,.c} $shared_deps && _make $1 $1.c $*[2,-1] || : }
cc_objc(){ nt $1{,.m} $shared_deps && _make $1 $1.m -framework Foundation $*[2,-1] || : }

# groups can modify flags of a util before it is built
# f_* groups just add -framework * to cflags of util
# otherwise group name is called as a fn with $1 as util name
groups=(f_AppKit f_CoreServices f_Carbon)
in_group(){ for i (${(P)1}) [[ $i == $2 ]] && return 0; return 1 }

# add_flags  util-name  flags
# adds util-specific cflags
add_flags(){
	set -A ${1}_CFLAGS ${(P)$(print ${1}_CFLAGS)} $*[2,-1]
}
# add_fmks  util-name  frameworks
# add -framework flags for util
add_fmks(){
	for fmk ($*[2,-1]) add_flags $1 -framework $fmk
}

## == SPECIFY GROUP MEMBERSHIPS HERE ==
f_AppKit=(alert app appr beep bundle cifilter dup fileicon imgconv imgshadow imgtext setapp seticon trash)
f_CoreServices=(dict)
f_Carbon=(hotkeys)

## == UTIL-SPECIFIC CONFIGURATION HERE ==
add_fmks any2txt     	Quartz QuickLook
add_fmks displaysleep	IOKit

_make_goosh(){
	if nt goosh goosh*.*; then
		_make goosh goosh.m goosh-fn.m goosh-JSON.m -framework AppKit
	fi
}

groups_process(){
	for group in $groups; do
		if in_group $group $1; then
			if [[ $group[1,2] == f_ ]]; then
				add_fmks $1 ${group[3,-1]}
			else
				$group $1
			fi
		fi
	done
}

for util in ${*:-$UTILS}; do
	print -u2 - -- Building $util

	groups_process $util

	if [[ ${$(whence -w _make_$util)%_make_$util:*} == ' function' ]]; then
		_make_$util $util
	else
		mk $util
	fi
done
