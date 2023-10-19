ACLOCAL_AMFLAGS = -I m4

EXTRA_DIST =

###############################################################################

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

###############################################################################

SUBDIRS =	src	\
		doc	\
		examples

###############################################################################

dist_pkgdata_DATA = \
	files/nftables/all-in-one.nft \
	files/nftables/arp-filter.nft \
	files/nftables/bridge-filter.nft \
	files/nftables/inet-filter.nft \
	files/nftables/inet-nat.nft \
	files/nftables/ipv4-filter.nft \
	files/nftables/ipv4-mangle.nft \
	files/nftables/ipv4-nat.nft \
	files/nftables/ipv4-raw.nft \
	files/nftables/ipv6-filter.nft \
	files/nftables/ipv6-mangle.nft \
	files/nftables/ipv6-nat.nft \
	files/nftables/ipv6-raw.nft \
	files/nftables/netdev-ingress.nft \
	$(NULL)

pkgdocdir = ${docdir}/examples

dist_pkgdoc_SCRIPTS = \
	files/examples/ct_helpers.nft \
	files/examples/load_balancing.nft \
	files/examples/secmark.nft \
	files/examples/sets_and_maps.nft \
	$(NULL)

pkgsysconfdir = ${sysconfdir}/nftables/osf

dist_pkgsysconf_DATA = \
	files/osf/pf.os \
	$(NULL)

###############################################################################

EXTRA_DIST += \
	py/pyproject.toml \
	py/setup.cfg \
	py/setup.py \
	py/src/__init__.py \
	py/src/nftables.py \
	py/src/schema.json \
	$(NULL)

###############################################################################

EXTRA_DIST += \
	files \
	tests \
	$(NULL)

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = libnftables.pc
