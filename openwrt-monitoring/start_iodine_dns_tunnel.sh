#!/bin/sh

# check if this is needed:
# iptables -t nat -p udp -I PREROUTING  --dport 53 -j DNAT --to-destination :5353
# (maybe not)

# http://freedns.afraid.org
# user: bittorf
# pass: UQfJbMuN
#
# mooo.com:
# bittorf.mooo.com	A 	84.38.67.43		
# means: bittorf.mooo.com = 84.38.67.43 = server which runs the iodine-daemon
#
# bittorf2.mooo.com	NS	bittorf.mooo.com
# means: bittorf2.mooo.com will ask nameserver bittorf.mooo.com
#
# preparing on client:
# IP_DEFGW="$( ip route list exact 0.0.0.0/0 | cut -d' ' -f3 )"
# IP_NAMESERVER="$( grep ^"nameserver " /etc/resolv.conf | head -n1 | cut -d' ' -f2 )"
#
# call on client:
# sudo iodine -fP test $IP_NAMESERVER bittorf2.mooo.com
#
# change routing on client after start:
# sudo ip route add $IP_NAMESERVER/32 via $IP_DEFGW
# sudo ip route del default via $IP_DEFGW
# sudo ip route add default via 172.30.0.1
#
# test on client:
# ping 172.30.0.1

 DEBUG="-D"
#DEBUG=
IPT="/sbin/iptables"
IODINED="/usr/local/sbin/iodined"
PASSWORD="test"
INCOMING_DEV="eth0"
NX_SERVER="bittorf2.mooo.com"

/bin/pidof iodined >/dev/null || {
	/bin/echo 1 > /proc/sys/net/ipv4/ip_forward

	$IPT -t filter -D FORWARD -i dns0 -o eth0 -j ACCEPT
	$IPT -t filter -D FORWARD -i eth0 -o dns0 -j ACCEPT
	$IPT -t filter -I FORWARD -i dns0 -o eth0 -j ACCEPT
	$IPT -t filter -I FORWARD -i eth0 -o dns0 -j ACCEPT

	$IPT -t nat -D POSTROUTING -s 172.30.0.0/16 -j MASQUERADE
	$IPT -t nat -I POSTROUTING -s 172.30.0.0/16 -j MASQUERADE
	$IPT -t nat -D PREROUTING -i "$INCOMING_DEV" -p udp --dport 53 -j DNAT --to :5353
	$IPT -t nat -I PREROUTING -i "$INCOMING_DEV" -p udp --dport 53 -j DNAT --to :5353

	$IODINED ${DEBUG} -c -f -p 5353 -P "$PASSWORD" 172.30.0.1 "$NX_SERVER"
}
