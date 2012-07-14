#!/bin/zsh
emulate zsh
setopt extendedglob

cd ${0:h};

mkdir -p ${PREFIX:=./htmlman1}

print -l ' == Updating files'
for i in html/*.nml; do
	g=$PREFIX/${i:t:r}.html
	t=$g.tmp
	[[ -e $g ]] && mv -f $g $t
	if [[ (! -e $t) || ($i -nt $t) || ($0 -nt $t) ]]; then
		print -- $g:t:r
		{
			print '<!DOCTYPE html>'
			print -n '<meta charset="utf-8"><title>'
			[[ ${i:t:r} == "index" ]] || print -n -- ${i:t:r}' | '
			print -n 'CLIMac &ndash; OS X Command Line Utilities</title><link href="css" rel="stylesheet">
<body>'
			${FILTER:=$(whence -p nml)} < $i
		} > $t
	fi
done

print -l ' == Syncing resources'
rsync -auv --inplace --exclude='*.nml' --exclude='.*' --filter='P *.tmp' --del html/ $PREFIX/

print -l ' == Removing old files'
[[ -e `print -- $PREFIX/*.html(N[1])` ]] && rm -v -- $PREFIX/*.html || :

for i in $PREFIX/*.tmp(N); mv $i $i:r
