#!/bin/bash -e

die() {
	printf "%s\n" "$*"
	exit 1
}

do_sed() {
	sed '1s/\({"nftables": \[{"metainfo": {"version": "\)[0-9.]\+\(", "release_name": "\)[^"]\+\(", "\)/\1VERSION\2RELEASE_NAME\3/' "$@"
}

if [ "$#" = 0 ] ; then
	do_sed
	exit $?
fi

for f ; do
	test -f "$f" || die "$0: file \"$f\" does not exist"
done

for f ; do
	do_sed -i "$f" || die "$0: \`sed -i\` failed for \"$f\""
done
