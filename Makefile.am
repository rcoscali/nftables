ACLOCAL_AMFLAGS = -I m4

pkginclude_HEADERS = \
	include/nftables/libnftables.h \
	$(NULL)

noinst_HEADERS = \
	\
	include/linux/netfilter.h \
	include/linux/netfilter/nf_conntrack_common.h \
	include/linux/netfilter/nf_conntrack_tuple_common.h \
	include/linux/netfilter/nf_log.h \
	include/linux/netfilter/nf_nat.h \
	include/linux/netfilter/nf_synproxy.h \
	include/linux/netfilter/nf_tables.h \
	include/linux/netfilter/nf_tables_compat.h \
	include/linux/netfilter/nfnetlink.h \
	include/linux/netfilter/nfnetlink_hook.h \
	include/linux/netfilter/nfnetlink_osf.h \
	include/linux/netfilter_arp.h \
	include/linux/netfilter_arp/arp_tables.h \
	include/linux/netfilter_bridge.h \
	include/linux/netfilter_bridge/ebtables.h \
	include/linux/netfilter_decnet.h \
	include/linux/netfilter_ipv4.h \
	include/linux/netfilter_ipv4/ip_tables.h \
	include/linux/netfilter_ipv6.h \
	include/linux/netfilter_ipv6/ip6_tables.h \
	\
	include/cache.h \
	include/cli.h \
	include/cmd.h \
	include/ct.h \
	include/datatype.h \
	include/dccpopt.h \
	include/erec.h \
	include/expression.h \
	include/exthdr.h \
	include/fib.h \
	include/gmputil.h \
	include/hash.h \
	include/headers.h \
	include/iface.h \
	include/intervals.h \
	include/ipopt.h \
	include/json.h \
	include/list.h \
	include/meta.h \
	include/mini-gmp.h \
	include/misspell.h \
	include/mnl.h \
	include/netlink.h \
	include/nft.h \
	include/nftables.h \
	include/numgen.h \
	include/osf.h \
	include/owner.h \
	include/parser.h \
	include/payload.h \
	include/proto.h \
	include/rt.h \
	include/rule.h \
	include/sctp_chunk.h \
	include/socket.h \
	include/statement.h \
	include/tcpopt.h \
	include/utils.h \
	include/xfrm.h \
	include/xt.h \
	\
	$(NULL)

SUBDIRS =	src	\
		files	\
		doc	\
		examples\
		py

EXTRA_DIST =	tests	\
		files

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = libnftables.pc
