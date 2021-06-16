:output;type filter hook output priority 0

*ip;test-ip4;output
*ip6;test-ip6;output
*inet;test-inet;output
*arp;test-arp;output
*bridge;test-bridge;output

queue;ok;queue num 0
queue num 2;ok
queue num 65535;ok
queue num 65536;fail
queue num 2-3;ok
queue num 1-65535;ok
queue num 4-5 fanout bypass;ok;queue flags bypass,fanout num 4-5
queue num 4-5 fanout;ok;queue flags fanout num 4-5
queue num 4-5 bypass;ok;queue flags bypass num 4-5
