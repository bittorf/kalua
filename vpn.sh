#!/bin/sh
. /tmp/loader

# load json lib
. /usr/share/libubox/jshn.sh

#vpn domain
DOMAIN="weimarnetz.de"
#vpn prefix
PREFIX="vpn"
#json info url
JSONPATH="/freifunk/vpn/vpn.php"

#temporary number for comparisons
CLIENTS=12345
vpnNr=1
SERVER=$PREFIX$vpnNr.$DOMAIN
vpnServerResponse="$( ping -q -c 1 -W 1 $SERVER 2>/dev/null |grep round-trip|cut -f 4 -d ' '|cut -f 0 -d '/'|sed -e 's/\.//g' )"
if [ -n $responseTime  ];
then
	URL="http://$SERVER$JSONPATH"
	eval $( jshn -r "$( _wget do "$URL" 1 2>/dev/null )" 2>/dev/null )
	if [ -n "$JSON_VAR_clients" ];
	then
		CLIENTS=${JSON_VAR_clients}
		PORT=${JSON_VAR_port_vtun_nossl_nolzo}
		MTU=${JSON_VAR_maxmtu}
		vpnServerName=$SERVER
	fi
fi

for vpnNr in 2 3 4 5 6 7 8 9 10
do
	SERVER=$PREFIX$vpnNr.$DOMAIN
	responseTime="$( ping -q -c 1 -W 1 $SERVER 2>/dev/null |grep round-trip|cut -f 4 -d " "|cut -f 0 -d "/"|sed -e 's/\.//g' )"
	if [ -n $responseTime  ];
	then
		URL="http://$SERVER$JSONPATH"
		eval $( jshn -r "$( _wget do "$URL" 1 2>/dev/null )" 2>/dev/null )
		if  test 2>/dev/null "$JSON_VAR_clients" -lt "$CLIENTS" ;
		then
			CLIENTS=${JSON_VAR_clients}
			PORT=${JSON_VAR_port_vtun_nossl_nolzo}
			MTU=${JSON_VAR_maxmtu}
			vpnServerResponse=$responseTime
			vpnServerName="$SERVER"
		fi
	fi
done

if [[ $CLIENTS = 12345 ]];
then
	CLIENTS=
fi

echo "Server: $vpnServerName"
echo "vtun_nossl_nolzo: $PORT"
echo "clients: $CLIENTS"
echo "vtun_ssl_lzo: $JSON_VAR_port_vtun_ssl_lzo"
echo "maxmtu: $MTU"
