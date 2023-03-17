:output;type filter hook output priority 0

*ip6;test-ip6;output

ct mark set ip6 dscp << 2 | 0x10;ok
ct mark set ip6 dscp << 26 | 0x10;ok
