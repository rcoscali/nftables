#!/bin/bash -e

# This wrapper wraps the invocation of the test. It is called by run-tests.sh,
# and already in the unshared namespace.
#
# For some printf debugging, you can also patch this file.

TEST="$1"
TESTBASE="$(basename "$TEST")"
TESTDIR="$(dirname "$TEST")"

printf '%s\n' "$TEST" > "$NFT_TEST_TESTTMPDIR/name"

read tainted_before < /proc/sys/kernel/tainted

rc_test=0
"$TEST" &> "$NFT_TEST_TESTTMPDIR/testout.log" || rc_test=$?

$NFT list ruleset > "$NFT_TEST_TESTTMPDIR/ruleset-after"

read tainted_after < /proc/sys/kernel/tainted

DUMPPATH="$TESTDIR/dumps"
DUMPFILE="$DUMPPATH/$TESTBASE.nft"

dump_written=
rc_dump=

# The caller can request a re-geneating of the dumps, by setting
# DUMPGEN=y.
#
# This only will happen if the command completed with success.
#
# It also will only happen for tests, that have a "$DUMPPATH" directory. There
# might be tests, that don't want to have dumps created. The existence of the
# directory controls that.
if [ "$rc_test" -eq 0 -a "$DUMPGEN" = y -a -d "$DUMPPATH" ] ; then
	dump_written=y
	cat "$NFT_TEST_TESTTMPDIR/ruleset-after" > "$DUMPFILE"
fi

if [ "$rc_test" -ne 77 -a -f "$DUMPFILE" ] ; then
	rc_dump=0
	if [ "$dump_written" != y ] ; then
		$DIFF -u "$DUMPFILE" "$NFT_TEST_TESTTMPDIR/ruleset-after" &> "$NFT_TEST_TESTTMPDIR/ruleset-diff" || rc_dump=$?
		if [ "$rc_dump" -eq 0 ] ; then
			rm -f "$NFT_TEST_TESTTMPDIR/ruleset-diff"
		fi
	fi
fi

if [ "$tainted_before" != "$tainted_after" ] ; then
	echo "$tainted_after" > "$NFT_TEST_TESTTMPDIR/rc-failed-tainted"
fi

rc_exit="$rc_test"
if [ -n "$rc_dump" ] && [ "$rc_dump" -ne 0 ] ; then
	echo "$DUMPFILE" > "$NFT_TEST_TESTTMPDIR/rc-failed-dump"
	echo "$rc_test" > "$NFT_TEST_TESTTMPDIR/rc-failed"
	if [ "$rc_exit" -eq 0 ] ; then
		# Special exit code to indicate dump diff.
		rc_exit=124
	fi
elif [ "$rc_test" -eq 77 ] ; then
	echo "$rc_test" > "$NFT_TEST_TESTTMPDIR/rc-skipped"
elif [ "$rc_test" -eq 0 -a "$tainted_before" = "$tainted_after" ] ; then
	echo "$rc_test" > "$NFT_TEST_TESTTMPDIR/rc-ok"
else
	echo "$rc_test" > "$NFT_TEST_TESTTMPDIR/rc-failed"
	if [ "$rc_test" -eq 0 -a "$tainted_before" != "$tainted_after" ] ; then
		# Special exit code to indicate tainted.
		rc_exit=123
	elif [ "$rc_test" -eq 124 -o "$rc_test" -eq 123 ] ; then
		# These exit codes are reserved
		rc_exit=125
	fi
fi

exit "$rc_exit"
