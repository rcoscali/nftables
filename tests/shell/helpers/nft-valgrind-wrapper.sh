#!/bin/bash -e

SUFFIX="$(date '+%Y%m%d-%H%M%S.%6N')"

rc=0
libtool \
	--mode=execute \
	valgrind \
		--log-file="$NFT_TEST_TESTTMPDIR/valgrind.$SUFFIX.%p.log" \
		--trace-children=yes \
		--leak-check=full \
		--show-leak-kinds=all \
		"$NFT_REAL" \
		"$@" \
	|| rc=$?

exit $rc
