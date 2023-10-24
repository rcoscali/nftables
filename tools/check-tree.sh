#!/bin/bash -e

# Preform various consistency checks of the source tree.

unset LANGUAGE
export LANG=C
export LC_ALL=C

die() {
	printf '%s\n' "$*"
	exit 1
}

array_contains() {
	local needle="$1"
	local a
	shift
	for a; do
		[ "$a" = "$needle" ] && return 0
	done
	return 1
}

cd "$(dirname "$0")/.."

EXIT_CODE=0

##############################################################################

check_shell_dumps() {
	local TEST="$1"
	local base="$(basename "$TEST")"
	local dir="$(dirname "$TEST")"
	local has_nft=0
	local has_nodump=0
	local nft_name
	local nodump_name

	if [ ! -d "$dir/dumps/" ] ; then
		echo "\"$TEST\" has no \"$dir/dumps/\" directory"
		EXIT_CODE=1
		return 0
	fi

	nft_name="$dir/dumps/$base.nft"
	nodump_name="$dir/dumps/$base.nodump"

	[ -f "$nft_name" ] && has_nft=1
	[ -f "$nodump_name" ] && has_nodump=1

	if [ "$has_nft" != 1 -a "$has_nodump" != 1 ] ; then
		echo "\"$TEST\" has no \"$dir/dumps/$base.{nft,nodump}\" file"
		EXIT_CODE=1
	elif [ "$has_nft" == 1 -a "$has_nodump" == 1 ] ; then
		echo "\"$TEST\" has both \"$dir/dumps/$base.{nft,nodump}\" files"
		EXIT_CODE=1
	elif [ "$has_nodump" == 1 -a -s "$nodump_name" ] ; then
		echo "\"$TEST\" has a non-empty \"$dir/dumps/$base.nodump\" file"
		EXIT_CODE=1
	fi
}

SHELL_TESTS=( $(find "tests/shell/testcases/" -type f -executable | sort) )

if [ "${#SHELL_TESTS[@]}" -eq 0 ] ; then
	echo "No executable tests under \"tests/shell/testcases/\" found"
	EXIT_CODE=1
fi
for t in "${SHELL_TESTS[@]}" ; do
	check_shell_dumps "$t"
	head -n 1 "$t" |grep -q  '^#!/bin/sh' && echo "$t uses sh instead of bash" && EXIT_CODE=1
done

##############################################################################

SHELL_TESTS2=( $(./tests/shell/run-tests.sh --list-tests) )
if [ "${SHELL_TESTS[*]}" != "${SHELL_TESTS2[*]}" ] ; then
	echo "\`./tests/shell/run-tests.sh --list-tests\` does not list the expected tests"
	EXIT_CODE=1
fi

##############################################################################
#
F=( $(find tests/shell/testcases/ -type f | grep '^tests/shell/testcases/[^/]\+/dumps/[^/]\+\.\(nft\|nodump\)$' -v | sort) )
IGNORED_FILES=( tests/shell/testcases/bogons/nft-f/* )
for f in "${F[@]}" ; do
	if ! array_contains "$f" "${SHELL_TESTS[@]}" "${IGNORED_FILES[@]}" ; then
		echo "Unexpected file \"$f\""
		EXIT_CODE=1
	fi
done

##############################################################################

FILES=( $(find "tests/shell/testcases/" -type f | sed -n 's#\(tests/shell/testcases\(/.*\)\?/\)dumps/\(.*\)\.\(nft\|nodump\)$#\0#p' | sort) )

for f in "${FILES[@]}" ; do
	f2="$(echo "$f" | sed -n 's#\(tests/shell/testcases\(/.*\)\?/\)dumps/\(.*\)\.\(nft\|nodump\)$#\1\3#p')"
	if ! array_contains "$f2" "${SHELL_TESTS[@]}" ; then
		echo "\"$f\" has no test \"$f2\""
		EXIT_CODE=1
	fi
done

##############################################################################

exit "$EXIT_CODE"
