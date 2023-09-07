#!/bin/bash -e

# This wrapper wraps the invocation of the test. It is called by run-tests.sh,
# and already in the unshared namespace.
#
# For some printf debugging, you can also patch this file.

TEST="$1"
TESTBASE="$(basename "$TEST")"
TESTDIR="$(dirname "$TEST")"

START_TIME="$(cut -d ' ' -f1 /proc/uptime)"

export TMPDIR="$NFT_TEST_TESTTMPDIR"

CLEANUP_UMOUNT_RUN_NETNS=n

cleanup() {
	if [ "$CLEANUP_UMOUNT_RUN_NETNS" = y ] ; then
		umount "/var/run/netns" || :
	fi
}

trap cleanup EXIT

printf '%s\n' "$TEST" > "$NFT_TEST_TESTTMPDIR/name"

read tainted_before < /proc/sys/kernel/tainted

if [ "$NFT_TEST_HAS_UNSHARED_MOUNT" = y ] ; then
	# We have a private mount namespace. We will mount /run/netns as a tmpfs,
	# this is useful because `ip netns add` wants to add files there.
	#
	# When running as rootless, this is necessary to get such tests to
	# pass.  When running rootful, it's still useful to not touch the
	# "real" /var/run/netns of the system.
	mkdir -p /var/run/netns
	if mount -t tmpfs --make-private "/var/run/netns" ; then
		CLEANUP_UMOUNT_RUN_NETNS=y
	fi
fi

rc_test=0
"$TEST" &> "$NFT_TEST_TESTTMPDIR/testout.log" || rc_test=$?

$NFT list ruleset > "$NFT_TEST_TESTTMPDIR/ruleset-after"

read tainted_after < /proc/sys/kernel/tainted

DUMPPATH="$TESTDIR/dumps"
DUMPFILE="$DUMPPATH/$TESTBASE.nft"

dump_written=

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

rc_dump=0
if [ "$rc_test" -ne 77 -a -f "$DUMPFILE" ] ; then
	if [ "$dump_written" != y ] ; then
		if ! $DIFF -u "$DUMPFILE" "$NFT_TEST_TESTTMPDIR/ruleset-after" &> "$NFT_TEST_TESTTMPDIR/ruleset-diff" ; then
			rc_dump=124
			rm -f "$NFT_TEST_TESTTMPDIR/ruleset-diff"
		fi
	fi
fi
if [ "$rc_dump" -ne 0 ] ; then
	echo "$DUMPFILE" > "$NFT_TEST_TESTTMPDIR/rc-failed-dump"
fi

rc_tainted=0
if [ "$tainted_before" != "$tainted_after" ] ; then
	echo "$tainted_after" > "$NFT_TEST_TESTTMPDIR/rc-failed-tainted"
	rc_tainted=123
fi

if [ "$rc_tainted" -ne 0 ] ; then
	rc_exit="$rc_tainted"
elif [ "$rc_test" -ge 118 -a "$rc_test" -le 124 ] ; then
	# Special exit codes are reserved. Coerce them.
	rc_exit="125"
elif [ "$rc_test" -ne 0 ] ; then
	rc_exit="$rc_test"
elif [ "$rc_dump" -ne 0 ] ; then
	rc_exit="$rc_dump"
else
	rc_exit="0"
fi


# We always write the real exit code of the test ($rc_test) to one of the files
# rc-{ok,skipped,failed}, depending on which it is.
#
# Note that there might be other rc-failed-{dump,tainted} files with additional
# errors. Note that if such files exist, the overall state will always be
# failed too (and an "rc-failed" file exists).
#
# On failure, we also write the combined "$rc_exit" code from "test-wrapper.sh"
# to "rc-failed-exit" file.
#
# This means, failed tests will have a "rc-failed" file, and additional
# "rc-failed-*" files exist for further information.
if [ "$rc_exit" -eq 0 ] ; then
	RC_FILENAME="rc-ok"
elif [ "$rc_exit" -eq 77 ] ; then
	RC_FILENAME="rc-skipped"
else
	RC_FILENAME="rc-failed"
	echo "$rc_exit" > "$NFT_TEST_TESTTMPDIR/rc-failed-exit"
fi
echo "$rc_test" > "$NFT_TEST_TESTTMPDIR/$RC_FILENAME"

END_TIME="$(cut -d ' ' -f1 /proc/uptime)"
WALL_TIME="$(awk -v start="$START_TIME" -v end="$END_TIME" "BEGIN { print(end - start) }")"
printf "%s\n" "$WALL_TIME" "$START_TIME" "$END_TIME" > "$NFT_TEST_TESTTMPDIR/times"

exit "$rc_exit"
