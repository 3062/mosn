#!/usr/bin/sudo /bin/bash

source ./iptables_config.sh

ip rule add fwmark $egress_mark table 100
ip rule add fwmark $ingress_mark table 100
ip route add local 0.0.0.0/0 dev lo table 100


# 双向全端口透明代理，当前存在一个问题，在注释中会标注。
# 同时需要所有 mosn 发送的包都携带 mark，即 listener 监听以及向 cluster 连接建立


# 跳过 ssh 之类的特殊端口
for port in ${passthrough_port[@]}
    do
    iptables -t mangle -A PREROUTING -p tcp --dport $port -j ACCEPT
    iptables -t mangle -A OUTPUT -p tcp --sport $port -j ACCEPT
    done

# 最先判断 egress 模式的代理
iptables -t mangle -A PREROUTING -p tcp -m mark --mark $egress_mark -j TPROXY --on-port $egress_port --tproxy-mark $egress_mark

# 用于 [mosn 主动建立连接时返回的包] 以及 [本地 app 的接收 mosn 发送的包]，从连接中获取标记 (参考 OUTPUT) 并跳过 ingress 代理
iptables -t mangle -A PREROUTING -j CONNMARK --restore-mark
iptables -t mangle -A PREROUTING -p tcp -m mark ! --mark 0 -j ACCEPT

# ingress 模式，代理其余全部
# 当前问题：除第一个包以外，后续包会受到 mosn 的响应影响，在上面两条规则直接直接 ACCEPT，但是依然正常执行了代理
# 猜测是因为 tproxy 也是对整个连接做的标记，只需要第一个包执行，后续包不必走此条规则
iptables -t mangle -A PREROUTING -p tcp -j TPROXY --on-port $ingress_port --tproxy-mark $ingress_mark 


# mosn 发出的包包含 mark，将其加入到连接，并跳过 egress 代理
# 当前问题：mosn 的响应也会将 mark 加入到整个连接中。egress 模式中，mosn 响应本地 app 需要此功能，但会影响其他
iptables -t mangle -A OUTPUT -p tcp -m mark ! --mark 0 -j CONNMARK --save-mark
iptables -t mangle -A OUTPUT -p tcp -m mark ! --mark 0 -j ACCEPT

# 用于 ingress 模式中，mosn->app 建立的连接，app 的响应不走 egress 代理
# 当前问题：无法直接使用连接中的 mark 跳过，因为会使 egress 模式下除第一次以外的包没有 egress_mark 标记(因为 mosn 响应了)，从而无法转到 PREROUTING
iptables -t mangle -A OUTPUT -p tcp -o lo -j ACCEPT

# 其余包打 egress_mark，利用路由表转到 PREROUTING，走 egress 代理
iptables -t mangle -A OUTPUT -p tcp -j MARK --set-mark $egress_mark