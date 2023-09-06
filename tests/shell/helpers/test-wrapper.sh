#!/bin/bash -e

# This wrapper wraps the invocation of the test. It is called by run-tests.sh,
# and already in the unshared namespace.
#
# For some printf debugging, you can also patch this file.

TEST="$1"

printf '%s\n' "$TEST" > "$NFT_TEST_TESTTMPDIR/name"

rc_test=0
"$TEST" |& tee "$NFT_TEST_TESTTMPDIR/testout.log" || rc_test=$?

if [ "$rc_test" -eq 0 ] ; then
	echo "$rc_test" > "$NFT_TEST_TESTTMPDIR/rc_test-ok"
elif [ "$rc_test" -eq 77 ] ; then
	echo "$rc_test" > "$NFT_TEST_TESTTMPDIR/rc_test-skipped"
else
	echo "$rc_test" > "$NFT_TEST_TESTTMPDIR/rc_test-failed"
fi

$NFT list ruleset > "$NFT_TEST_TESTTMPDIR/ruleset-after"

exit "$rc_test"
