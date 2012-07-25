#!/bin/sh

. /tmp/loader

_http header_mimetype_output "text/html"

cat<<EOF
<HTML>
<HEAD>
<TITLE>$(n=$(uname -n);echo ${n:-Freifunk.Net}) - $TITLE</TITLE>
<META CONTENT="text/html; charset=iso-8859-1" HTTP-EQUIV="Content-Type">
<META CONTENT="no-cache" HTTP-EQUIV="cache-control">
<LINK HREF="ff.css" REL="StyleSheet" TYPE="text/css">
<LINK HREF="sven-ola*.t*gmx*de" REV="made" TITLE="Sven-Ola">
EOF

if [ -e /www/cgi-bin/luci ]; then

cat<<EOF
<meta http-equiv="refresh" content="0; URL=/cgi-bin/luci/freifunk/olsr/neighbors" />                   
</head>
<body style="background-color: black">
<a style="color: white; text-decoration: none" href="/cgi-bin/luci/freifunk/olsr/neighbors">Weimarnetz - status interface</a>                        
</body>
</html>
EOF

exit 0
else 

cat<<EOF
</HEAD>
<BODY> 
EOF

fi

export DATE="3.12.2008";SCRIPT=${0#/rom}
export TITLE="Status: OLSR"

WLDEV=$(sed -n 's/^ *\([^:]\+\):.*/\1/p' /proc/net/wireless)
WLMASK=$(ip -f inet addr show dev $WLDEV label $WLDEV |sed -ne'2{s# \+inet \([0-9\.\/]\+\).*#\1#;p}')
ff_httpinfo=1

cat<<EOF
<H1>Status: &Uuml;bersicht</H1>
Dein Router hat entweder zu wenig Speicherplatz oder der Administrator hat verpennt, luci zu installieren. Deshalb gibt es nur diese abgespeckte Seite zu sehen.<br>
Die Administration erfolgt &uuml;ber SSH: <a href="http://$(ip -f inet addr show dev $WLDEV label $WLDEV |sed -ne'2{s/ \+inet \([0-9\.]\+\).*/\1/;p}')/cgi-bin-tool.sh?OPT=startshell">SSH starten</a><br>
Freier Speicher: $(_system flash_free) kb 
<SCRIPT LANGUAGE="JavaScript" TYPE="text/javascript"><!--
function fold(id) {
obj = document.getElementById(id);
obj.style.display = ('none'==obj.style.display?'block':'none');
return false;
}
//--></SCRIPT>
<TABLE CLASS="shadow0" CELLPADDING="0" CELLSPACING="0"><TR><TD><TABLE CLASS="shadow1" CELLPADDING="0" CELLSPACING="0"><TR><TD><TABLE CLASS="shadow2" CELLPADDING="0" CELLSPACING="0"><TR><TD><TABLE BORDER="1" CELLPADDING="0" CELLSPACING="0" CLASS="formfixwidth">

<TR>
<TD COLSPAN="2">&nbsp;</TD>
</TR>
<TR>
<TD>IP
Adresse:</TD>
<TD>IP:&nbsp;$(ip -f inet addr show dev $WLDEV label $WLDEV |sed -ne'2{s/ \+inet \([0-9\.]\+\).*/\1/;p}'),
Maske:&nbsp;$(test -n "$WLMASK" && ipcalc -m $WLMASK|cut -d'=' -f2),
MAC:&nbsp;$(ip link show dev $WLDEV|sed -ne'2{s/.*ether \+\([^ ]\+\).*/\1/;p}')</TD>
</TR>
<TR>
<TD>WLAN-Status:</TD>
<TD>
EOF

if /rom/usr/sbin/wl -i $WLDEV status 2>&-;then
echo "<br>"
/rom/usr/sbin/wl -i $WLDEV rate
/rom/usr/sbin/wl -i $WLDEV mrate
else
iwconfig $WLDEV 2>&-
fi

cat<<EOF
</TD>
</TR>
<TR>
<TD>Ger&auml;telaufzeit:</TD>
<TD>$(uptime)</TD>
</TR>
<TR>
<TD>Versionen:</TD>
<TD>Firmware: $(cat /etc/openwrt_version)<BR>Olsrd: $(cat /etc/olsrd-release)</TD>
</TR>
<TR>
<TD>Default-Route:</TD>
<TD>$(ip route list exact 0/0|sed '1q'|sed 's#\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)#<A HREF="http://\1/cgi-bin-status.html">\1</A>#')
EOF

if [ "$ff_httpinfo" != "0" ];then

cat<<EOF
</TD>
</TR>
<TR>
<TD>Nachbarn:</TD>
<TD>
EOF

wget -q -O - http://127.0.0.1:2006/neighbours|sed -ne'
/^Table: Links/{
s/.*/<\TABLE FRAME="VOID" BORDER="1" CELLSPACING="0" CELLPADDING="1" WIDTH="400">/
:n
p
n
s/^[^	]*	//
s/^remote //
s#\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)\([^/]\)#<A HREF="http://\1/cgi-bin-status.html">\1</A>\2#g
s/	$//
s#	#</TD><TD>#g
s#.\+#<TR><TD WIDTH="100%">&</TD></TR>#
s/./&/
tn
c\
<\/TABLE>
p
}
'
fi

cat<<EOF
</TD>
</TR>
<TR>
<TD>Kernel-Log: </TD>
<TD><A HREF="#" ONCLICK="return fold('dmesg')">Ein- / Ausblenden</A></TD>
</TR>
<TR>
<TD COLSPAN="2">
EOF

echo -n '<PRE STYLE="display:none" ID="dmesg">'
dmesg 2>&1
echo '</PRE>'
if pidof syslogd>/dev/null;then

cat<<EOF
</TD>
</TR>
<TR>
<TD>System-Log: </TD>
<TD><A HREF="#" ONCLICK="return fold('logread')">Ein- / Ausblenden</A></TD>
</TR>
<TR>
<TD COLSPAN="2">
EOF

echo -n '<PRE STYLE="display:none" ID="logread">'
logread 2>&1
echo '</PRE>'
fi

cat<<EOF
</TD>
</TR>
<TR>
<TD>IP-NAT:
</TD>
<TD><A HREF="#" ONCLICK="return fold('nat')">Ein- / Ausblenden</A></TD>
</TR>
<TR>
<TD COLSPAN="2">
EOF

echo -n '<PRE STYLE="display:none" ID="nat">'
iptables -t nat -L -n -v 2>&1
echo '</PRE>'

cat<<EOF
</TD>
</TR>
<TR>
<TD>Schnittstellen-Konfiguration: </TD>
<TD><A HREF="#" ONCLICK="return fold('ifconfig')">Ein- / Ausblenden</A></TD>
</TR>
<TR>
<TD COLSPAN="2">
EOF

echo -n '<PRE STYLE="display:none" ID="ifconfig">'
echo
brctl show 2>&1
echo
ip addr show 2>&1
echo '</PRE>'

cat<<EOF
</TD>
</TR>
EOF

cat<<EOF
</TD>
</TR>
</TABLE></TD></TR></TABLE></TD></TR></TABLE></TD></TR></TABLE>


</BODY>
</HTML>
EOF
