#!/usr/bin/sudo /bin/bash

source ./iptables_config.sh

ip rule del from all fwmark $egress_mark lookup 100
ip rule del from all fwmark $ingress_mark lookup 100
ip route del local 0.0.0.0/0 dev lo table 100

for port in ${passthrough_port[@]}
    do
    iptables -t mangle -D PREROUTING -p tcp --dport $port -j ACCEPT
    done

iptables -t mangle -D PREROUTING -p tcp -d localhost -j ACCEPT 
iptables -t mangle -D PREROUTING -p tcp -m mark --mark $egress_mark -j TPROXY --on-port $egress_port --tproxy-mark $egress_mark
iptables -t mangle -D PREROUTING -p tcp -j TPROXY --on-port $ingress_port --tproxy-mark $ingress_mark 

iptables -t mangle -D OUTPUT -p tcp -o lo -j ACCEPT
iptables -t mangle -D OUTPUT -p tcp -m mark ! --mark 0 -j ACCEPT
iptables -t mangle -D OUTPUT -p tcp -j MARK --set-mark $egress_mark

iptables -t mangle -F
