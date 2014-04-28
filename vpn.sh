#!/bin/sh

# load json lib
. /usr/share/libubox/jshn.sh

#vpn domain
DOMAIN="weimarnetz.de"
#vpn prefix
PREFIX="vpn"
#json info url
JSONPATH="/freifunk/vpn/vpn.json"

vpnNr=1
SERVER=$PREFIX$vpnNr.$DOMAIN
vpnServerResponse="$( ping -q -c 1 -W 1 $SERVER |grep round-trip|cut -f 4 -d ' '|cut -f 0 -d '/'|sed -e 's/\.//g' )"
vpnServerName=$SERVER

for vpnNr in 2 3 4 5 6 7 8 9 10
do
	SERVER=$PREFIX$vpnNr.$DOMAIN
	responseTime="$( ping -q -c 1 -W 1 $SERVER |grep round-trip|cut -f 4 -d " "|cut -f 0 -d "/"|sed -e 's/\.//g' )"
	if [ $responseTime -lt $vpnServerResponse  ];
	then
		vpnServerResponse=$responseTime
		vpnServerName="$SERVER"
	fi
done

URL="http://$vpnServerName$JSONPATH"
echo $URL
eval $( jshn -r "$( wget -qO - "$URL" )" )

echo "Server: $JSON_VAR_server"
echo "vtun_nossl_nolzo: $JSON_VAR_port_vtun_nossl_nolzo"
echo "vtun_ssl_lzo: $JSON_VAR_port_vtun_ssl_lzo"
echo "maxmtu: $JSON_VAR_maxmtu"
