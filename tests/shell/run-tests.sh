#!/bin/bash

_msg() {
	local level="$1"
	shift
	local msg

	msg="$level: $*"
	if [ "$level" = E -o "$level" = W ] ; then
		printf '%s\n' "$msg" >&2
	else
		printf '%s\n' "$msg"
	fi
	if [ "$level" = E ] ; then
		exit 1
	fi
}

msg_error() {
	_msg E "$@"
}

msg_warn() {
	_msg W "$@"
}

msg_info() {
	_msg I "$@"
}

bool_y() {
	case "$1" in
		y|Y|yes|Yes|YES|1|true|True|TRUE)
			printf y
			;;
		*)
			printf n
			;;
	esac
}

usage() {
	echo " $0 [OPTIONS] [TESTS...]"
	echo
	echo "OPTIONS:"
	echo " -h|--help       : Print usage."
	echo " -L|--list-tests : List test names and quit."
	echo " -v              : Sets VERBOSE=y. Specifying tests without \"--\" enables verbose mode."
	echo " -g              : Sets DUMPGEN=y."
	echo " -V              : Sets VALGRIND=y."
	echo " -K              : Sets KMEMLEAK=y."
	echo " -R|--without-realroot : Sets NFT_TEST_HAS_REALROOT=n."
	echo " -U|--no-unshare : Sets NFT_TEST_UNSHARE_CMD=\"\"."
	echo " -k|--keep-logs  : Sets NFT_TEST_KEEP_LOGS=y."
	echo " --              : Separate options from tests."
	echo " [TESTS...]      : Other options are treated as test names,"
	echo "                   that is, executables that are run by the runner."
	echo
	echo "ENVIRONMENT VARIABLES:"
	echo " NFT=<CMD>     : Path to nft executable. Will be called as \`\$NFT [...]\` so"
	echo "                 it can be a command with parameters. Note that in this mode quoting"
	echo "                 does not work, so the usage is limited and the command cannot contain"
	echo "                 spaces."
	echo " VERBOSE=*|y   : Enable verbose output."
	echo " DUMPGEN=*|y   : Regenerate dump files. Dump files are only recreated if the"
	echo "                 test completes successfully and the \"dumps\" directory for the"
	echo "                 test exits."
	echo " VALGRIND=*|y  : Run \$NFT in valgrind."
	echo " KMEMLEAK=*|y  : Check for kernel memleaks."
	echo " NFT_TEST_HAS_REALROOT=*|y : To indicate whether the test has real root permissions."
	echo "                 Usually, you don't need this and it gets autodetected."
	echo "                 You might want to set it, if you know better than the"
	echo "                 \`id -u\` check, whether the user is root in the main namespace."
	echo "                 Note that without real root, certain tests may not work,"
	echo "                 e.g. due to limited /proc/sys/net/core/{wmem_max,rmem_max}."
	echo "                 Checks that cannot pass in such environment should check for"
	echo "                 [ \"\$NFT_TEST_HAS_REALROOT\" != y ] and skip gracefully."
	echo " NFT_TEST_UNSHARE_CMD=cmd : when set, this is the command line for an unshare"
	echo "                 command, which is used to sandbox each test invocation. By"
	echo "                 setting it to empty, no unsharing is done."
	echo "                 By default it is unset, in which case it's autodetected as"
	echo "                 \`unshare -f -p\` (for root) or as \`unshare -f -p --mount-proc -U --map-root-user -n\`"
	echo "                 for non-root."
	echo "                 When setting this, you may also want to set NFT_TEST_HAS_UNSHARED="
	echo "                 and NFT_TEST_HAS_REALROOT= accordingly."
	echo " NFT_TEST_HAS_UNSHARED=*|y : To indicate to the test whether the test run will be unshared."
	echo "                 Test may consider this."
	echo "                 This is only honored when \$NFT_TEST_UNSHARE_CMD= is set. Otherwise it's detected."
	echo " NFT_TEST_KEEP_LOGS=*|y: Keep the temp directory. On success, it will be deleted by default."
	echo " TMPDIR=<PATH> : select a different base directory for the result data."
}

NFT_TEST_BASEDIR="$(dirname "$0")"

# Export the base directory. It may be used by tests.
export NFT_TEST_BASEDIR

VERBOSE="$(bool_y "$VERBOSE")"
DUMPGEN="$(bool_y "$DUMPGEN")"
VALGRIND="$(bool_y "$VALGRIND")"
KMEMLEAK="$(bool_y "$KMEMLEAK")"
NFT_TEST_KEEP_LOGS="$(bool_y "$NFT_TEST_KEEP_LOGS")"
NFT_TEST_HAS_REALROOT="$NFT_TEST_HAS_REALROOT"
DO_LIST_TESTS=

TESTS=()

while [ $# -gt 0 ] ; do
	A="$1"
	shift
	case "$A" in
		-v)
			VERBOSE=y
			;;
		-g)
			DUMPGEN=y
			;;
		-V)
			VALGRIND=y
			;;
		-K)
			KMEMLEAK=y
			;;
		-h|--help)
			usage
			exit 0
			;;
		-k|--keep-logs)
			NFT_TEST_KEEP_LOGS=y
			;;
		-L|--list-tests)
			DO_LIST_TESTS=y
			;;
		-R|--without-realroot)
			NFT_TEST_HAS_REALROOT=n
			;;
		-U|--no-unshare)
			NFT_TEST_UNSHARE_CMD=
			;;
		--)
			TESTS+=( "$@" )
			shift $#
			;;
		*)
			# Any unrecognized option is treated as a test name, and also
			# enable verbose tests.
			TESTS+=( "$A" )
			VERBOSE=y
			;;
	esac
done

find_tests() {
	find "$1" -type f -executable | sort
}

if [ "${#TESTS[@]}" -eq 0 ] ; then
	TESTS=( $(find_tests "$NFT_TEST_BASEDIR/testcases/") )
	test "${#TESTS[@]}" -gt 0 || msg_error "Could not find tests"
fi

TESTSOLD=( "${TESTS[@]}" )
TESTS=()
for t in "${TESTSOLD[@]}" ; do
	if [ -f "$t" -a -x "$t" ] ; then
		TESTS+=( "$t" )
	elif [ -d "$t" ] ; then
		TESTS+=( $(find_tests "$t") )
	else
		msg_error "Unknown test \"$t\""
	fi
done

if [ "$DO_LIST_TESTS" = y ] ; then
	printf '%s\n' "${TESTS[@]}"
	exit 0
fi

_TMPDIR="${TMPDIR:-/tmp}"

if [ "$NFT_TEST_HAS_REALROOT" = "" ] ; then
	# The caller didn't set NFT_TEST_HAS_REALROOT and didn't specify
	# -R/--without-root option. Autodetect it based on `id -u`.
	export NFT_TEST_HAS_REALROOT="$(test "$(id -u)" = "0" && echo y || echo n)"
else
	NFT_TEST_HAS_REALROOT="$(bool_y "$NFT_TEST_HAS_REALROOT")"
fi
export NFT_TEST_HAS_REALROOT

detect_unshare() {
	if ! $1 true &>/dev/null ; then
		return 1
	fi
	NFT_TEST_UNSHARE_CMD="$1"
	return 0
}

if [ -n "${NFT_TEST_UNSHARE_CMD+x}" ] ; then
	# User overrides the unshare command.
	if ! detect_unshare "$NFT_TEST_UNSHARE_CMD" ; then
		msg_error "Cannot unshare via NFT_TEST_UNSHARE_CMD=$(printf '%q' "$NFT_TEST_UNSHARE_CMD")"
	fi
	if [ -z "${NFT_TEST_HAS_UNSHARED+x}" ] ; then
		# Autodetect NFT_TEST_HAS_UNSHARED based one whether
		# $NFT_TEST_UNSHARE_CMD is set.
		if [ -n "$NFT_TEST_UNSHARE_CMD" ] ; then
			NFT_TEST_HAS_UNSHARED="y"
		else
			NFT_TEST_HAS_UNSHARED="n"
		fi
	else
		NFT_TEST_HAS_UNSHARED="$(bool_y "$NFT_TEST_HAS_UNSHARED")"
	fi
else
	if [ "$NFT_TEST_HAS_REALROOT" = y ] ; then
		# We appear to have real root. So try to unshare
		# without a separate USERNS. CLONE_NEWUSER will break
		# tests that are limited by
		# /proc/sys/net/core/{wmem_max,rmem_max}. With real
		# root, we want to test that.
		detect_unshare "unshare -f -n -m" ||
			detect_unshare "unshare -f -n" ||
			detect_unshare "unshare -f -p -m --mount-proc -U --map-root-user -n" ||
			detect_unshare "unshare -f -U --map-root-user -n"
	else
		detect_unshare "unshare -f -p -m --mount-proc -U --map-root-user -n" ||
			detect_unshare "unshare -f -U --map-root-user -n"
	fi
	if [ -z "$NFT_TEST_UNSHARE_CMD" ] ; then
		msg_error "Unshare does not work. Run as root with -U/--no-unshare or set NFT_TEST_UNSHARE_CMD"
	fi
	NFT_TEST_HAS_UNSHARED=y
fi
# If tests wish, they can know whether they are unshared via this variable.
export NFT_TEST_HAS_UNSHARED

[ -z "$NFT" ] && NFT="$NFT_TEST_BASEDIR/../../src/nft"
${NFT} > /dev/null 2>&1
ret=$?
if [ ${ret} -eq 126 ] || [ ${ret} -eq 127 ]; then
	msg_error "cannot execute nft command: $NFT"
fi

MODPROBE="$(which modprobe)"
if [ ! -x "$MODPROBE" ] ; then
	msg_error "no modprobe binary found"
fi

DIFF="$(which diff)"
if [ ! -x "$DIFF" ] ; then
	DIFF=true
fi

cleanup_on_exit() {
	if [ "$NFT_TEST_KEEP_LOGS" != y -a -n "$NFT_TEST_TMPDIR" ] ; then
		rm -rf "$NFT_TEST_TMPDIR"
	fi
}
trap cleanup_on_exit EXIT

NFT_TEST_TMPDIR="$(mktemp --tmpdir="$_TMPDIR" -d "nft-test.$(date '+%Y%m%d-%H%M%S.%3N').XXXXXX")" ||
	msg_error "Failure to create temp directory in \"$_TMPDIR\""
chmod 755 "$NFT_TEST_TMPDIR"

msg_info "conf: NFT=$(printf '%q' "$NFT")"
msg_info "conf: VERBOSE=$(printf '%q' "$VERBOSE")"
msg_info "conf: DUMPGEN=$(printf '%q' "$DUMPGEN")"
msg_info "conf: VALGRIND=$(printf '%q' "$VALGRIND")"
msg_info "conf: KMEMLEAK=$(printf '%q' "$KMEMLEAK")"
msg_info "conf: NFT_TEST_HAS_REALROOT=$(printf '%q' "$NFT_TEST_HAS_REALROOT")"
msg_info "conf: NFT_TEST_UNSHARE_CMD=$(printf '%q' "$NFT_TEST_UNSHARE_CMD")"
msg_info "conf: NFT_TEST_HAS_UNSHARED=$(printf '%q' "$NFT_TEST_HAS_UNSHARED")"
msg_info "conf: NFT_TEST_KEEP_LOGS=$(printf '%q' "$NFT_TEST_KEEP_LOGS")"
msg_info "conf: TMPDIR=$(printf '%q' "$_TMPDIR")"

NFT_TEST_LATEST="$_TMPDIR/nft-test.latest.$USER"

ln -snf "$NFT_TEST_TMPDIR" "$NFT_TEST_LATEST"

# export the tmp directory for tests. They may use it, but create distinct
# files! On success, it will be deleted on EXIT. See also "--keep-logs"
export NFT_TEST_TMPDIR

echo
msg_info "info: NFT_TEST_BASEDIR=$(printf '%q' "$NFT_TEST_BASEDIR")"
msg_info "info: NFT_TEST_TMPDIR=$(printf '%q' "$NFT_TEST_TMPDIR")"

kernel_cleanup() {
	if [ "$NFT_TEST_HAS_UNSHARED" != y ] ; then
		$NFT flush ruleset
	fi
	$MODPROBE -raq \
	nft_reject_ipv4 nft_reject_bridge nft_reject_ipv6 nft_reject \
	nft_redir_ipv4 nft_redir_ipv6 nft_redir \
	nft_dup_ipv4 nft_dup_ipv6 nft_dup nft_nat \
	nft_masq_ipv4 nft_masq_ipv6 nft_masq \
	nft_exthdr nft_payload nft_cmp nft_range \
	nft_quota nft_queue nft_numgen nft_osf nft_socket nft_tproxy \
	nft_meta nft_meta_bridge nft_counter nft_log nft_limit \
	nft_fib nft_fib_ipv4 nft_fib_ipv6 nft_fib_inet \
	nft_hash nft_ct nft_compat nft_rt nft_objref \
	nft_set_hash nft_set_rbtree nft_set_bitmap \
	nft_synproxy nft_connlimit \
	nft_chain_nat \
	nft_chain_route_ipv4 nft_chain_route_ipv6 \
	nft_dup_netdev nft_fwd_netdev \
	nft_reject nft_reject_inet nft_reject_netdev \
	nf_tables_set nf_tables \
	nf_flow_table nf_flow_table_ipv4 nf_flow_tables_ipv6 \
	nf_flow_table_inet nft_flow_offload \
	nft_xfrm
}

printscript() { # (cmd, tmpd)
	cat <<EOF
#!/bin/bash

CMD="$1"

# note: valgrind man page warns about --log-file with --trace-children, the
# last child executed overwrites previous reports unless %p or %q is used.
# Since libtool wrapper calls exec but none of the iptables tools do, this is
# perfect for us as it effectively hides bash-related errors

valgrind --log-file=$2/valgrind.log --trace-children=yes \
	 --leak-check=full --show-leak-kinds=all \$CMD "\$@"
RC=\$?

# don't keep uninteresting logs
if grep -q 'no leaks are possible' $2/valgrind.log; then
	rm $2/valgrind.log
else
	mv $2/valgrind.log $2/valgrind_\$\$.log
fi

# drop logs for failing commands for now
[ \$RC -eq 0 ] || rm $2/valgrind_\$\$.log

exit \$RC
EOF
}

if [ "$VALGRIND" == "y" ]; then
	msg_info "writing valgrind logs to $NFT_TEST_TMPDIR"
	printscript "$NFT" "$NFT_TEST_TMPDIR" > "$NFT_TEST_TMPDIR/nft"
	chmod a+x "$NFT_TEST_TMPDIR/nft"
	NFT="$NFT_TEST_TMPDIR/nft"
fi

echo ""
ok=0
skipped=0
failed=0
taint=0

check_taint()
{
	read taint_now < /proc/sys/kernel/tainted
	if [ $taint -ne $taint_now ] ; then
		msg_warn "[FAILED]	kernel is tainted: $taint  -> $taint_now"
	fi
}

kmem_runs=0
kmemleak_found=0

check_kmemleak_force()
{
	test -f /sys/kernel/debug/kmemleak || return 0

	echo scan > /sys/kernel/debug/kmemleak

	lines=$(grep "unreferenced object" /sys/kernel/debug/kmemleak | wc -l)
	if [ $lines -ne $kmemleak_found ];then
		msg_warn "[FAILED]	kmemleak detected $lines memory leaks"
		kmemleak_found=$lines
	fi

	if [ $lines -ne 0 ];then
		return 1
	fi

	return 0
}

check_kmemleak()
{
	test -f /sys/kernel/debug/kmemleak || return

	if [ "$KMEMLEAK" == "y" ] ; then
		check_kmemleak_force
		return
	fi

	kmem_runs=$((kmem_runs + 1))
	if [ $((kmem_runs % 30)) -eq 0 ]; then
		# scan slows tests down quite a bit, hence
		# do this only for every 30th test file by
		# default.
		check_kmemleak_force
	fi
}

check_taint

print_test_header() {
	local msglevel="$1"
	local testfile="$2"
	local status="$3"
	local suffix="$4"
	local text

	text="[$status]"
	text="$(printf '%-12s' "$text")"
	_msg "$msglevel" "$text $testfile${suffix:+: $suffix}"
}

print_test_result() {
	local NFT_TEST_TESTTMPDIR="$1"
	local testfile="$2"
	local rc_got="$3"
	shift 3

	local result_msg_level="I"
	local result_msg_status="OK"
	local result_msg_suffix=""
	local result_msg_files=( "$NFT_TEST_TESTTMPDIR/testout.log" "$NFT_TEST_TESTTMPDIR/ruleset-diff" )

	if [ "$rc_got" -eq 0 ] ; then
		((ok++))
	elif [ "$rc_got" -eq 124 ] ; then
		((failed++))
		result_msg_level="W"
		result_msg_status="DUMP FAIL"
	elif [ "$rc_got" -eq 77 ] ; then
		((skipped++))
		result_msg_level="I"
		result_msg_status="SKIPPED"
	else
		((failed++))
		result_msg_level="W"
		result_msg_status="FAILED"
		result_msg_suffix="got $rc_got"
		result_msg_files=( "$NFT_TEST_TESTTMPDIR/testout.log" )
	fi

	print_test_header "$result_msg_level" "$testfile" "$result_msg_status" "$result_msg_suffix"

	if [ "$VERBOSE" = "y" ] ; then
		local f

		for f in "${result_msg_files[@]}"; do
			if [ -s "$f" ] ; then
				cat "$f"
			fi
		done

		if [ "$rc_got" -ne 0 ] ; then
			msg_info "check \"$NFT_TEST_TESTTMPDIR\""
		fi
	fi
}

TESTIDX=0
for testfile in "${TESTS[@]}" ; do
	read taint < /proc/sys/kernel/tainted
	kernel_cleanup

	((TESTIDX++))

	# We also create and export a test-specific temporary directory.
	NFT_TEST_TESTTMPDIR="$NFT_TEST_TMPDIR/test-${testfile//\//-}.$TESTIDX"
	mkdir "$NFT_TEST_TESTTMPDIR"
	chmod 755 "$NFT_TEST_TESTTMPDIR"
	export NFT_TEST_TESTTMPDIR

	print_test_header I "$testfile" "EXECUTING" ""
	NFT="$NFT" DIFF="$DIFF" DUMPGEN="$DUMPGEN" $NFT_TEST_UNSHARE_CMD "$NFT_TEST_BASEDIR/helpers/test-wrapper.sh" "$testfile"
	rc_got=$?
	echo -en "\033[1A\033[K" # clean the [EXECUTING] foobar line

	print_test_result "$NFT_TEST_TESTTMPDIR" "$testfile" "$rc_got"

	check_taint
	check_kmemleak
done

echo ""

# kmemleak may report suspected leaks
# that get free'd after all, so always do
# a check after all test cases
# have completed and reset the counter
# so another warning gets emitted.
kmemleak_found=0
check_kmemleak_force

msg_info "results: [OK] $ok [SKIPPED] $skipped [FAILED] $failed [TOTAL] $((ok+skipped+failed))"

kernel_cleanup

if [ "$failed" -gt 0 -o "$NFT_TEST_KEEP_LOGS" = y ] ; then
	msg_info "check the temp directory \"$NFT_TEST_TMPDIR\" (\"$NFT_TEST_LATEST\")"
	msg_info "   ls -lad \"$NFT_TEST_LATEST\"/*/*"
	msg_info "   grep -R ^ \"$NFT_TEST_LATEST\"/"
	NFT_TEST_TMPDIR=
fi

[ "$failed" -eq 0 ]
