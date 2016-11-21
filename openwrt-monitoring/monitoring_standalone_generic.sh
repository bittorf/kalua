#!/bin/sh
#
# install with:
# wget -qO /usr/sbin/monitoring.sh http://84.38.67.43/scripts/monitoring_standalone_generic.sh
# chmod +x /usr/sbin/monitoring.sh
#
# and edit HARDWARE/NODENUMBER/ETHERNET/VERSION
#
# use a cronjob like this:
# */15 * * * * /usr/local/bin/monitoring.sh
#
# TODO: sanitize hostname + url-encode
# TODO: autoupdate (but remember all custom vars)
# TODO: scp SCRIPT root@84.38.67.43:/var/www/scripts/monitoring_standalone_generic.sh
#
# AirOS: copy to /etc/persistent/
# echo  >/etc/persistent/rc.poststart '#!/bin/sh'
# echo >>/etc/persistent/rc.poststart '/usr/bin/crond -b -c /etc/persistent/crontabs'
# mkdir -p /etc/persistent/crontabs
# echo >/etc/persistent/crontabs/ubnt '*/15 * * * * /etc/persistent/monitoring.sh'
# execute 'save' or 'cfgmtd -w -p /etc/'

MONI_SERVER=84.38.67.43			# or with DNS = intercity-vpn.de
NETWORK='liszt28'			# gnm
HARDWARE='Ubiquity+NanoBridge+M5'	# must be url-encoded
NODENUMBER=867
ETHERNET=eth0
VERSION=5.5.6			# or <empty> for dpkg-check or custom e.g. 5.5.6

log()
{
	logger -s "$0: $1"

	if [ "$2" = 'die' ]; then
		exit 1
	else
		return 0
	fi
}

if grep -q ^'dns0[[:blank:]]0000000' /proc/net/route; then
	log "[OK] no action: dnstunnel-mode" die
else
	log "[START]"
fi

MYPUBIP="$( wget -qO - "http://$MONI_SERVER/scripts/getip/" | head -n1 | fgrep '.' )"
[ -z "$MYPUBIP" ] && {
	[ -e '/var/run/olsrd.pid' ] && {
		pidof olsrd || /etc/init.d/olsrd
	}

	log '[ERR] no pub ip' die
}

[ -z "$ETHERNET" ] && {
ETHERNET="$( ip --oneline link show |
		while read LINE; do {
			case "$LINE" in
				*' lo: '*|*' wwan0: '*)
				;;
				*)
					set $LINE
					echo ${2%%:*}
					break
				;;
			esac
		} done
	)"
}

log "using ethernet: '$ETHERNET'"

set -- $( route -n | grep ^'0\.0\.0\.0' )
MYGW=$2		# e.g. 100.64.0.1
[ -z "$MYGW" ] && exit 0
while [ -n "$1" ]; do MYDEV=$1; shift; done

set -- $( ifconfig "$ETHERNET" | grep 'inet addr:' | tr ':' ' ' )
MYIP=$3

URL="http://$MONI_SERVER/networks/$NETWORK/meshrdf"
#read HOSTNAME </proc/sys/kernel/hostname
HOSTNAME="$( cat /proc/sys/kernel/hostname )"
#logger -s "HOSTNAME: '$HOSTNAME'"
[ -z "$VERSION" ] && VERSION=$(( $( stat --printf %Y /var/lib/dpkg/status || echo 0 ) / 3600 ))
while read L; do case "$L" in MemTotal:*) set -- $L; RAM=$2; break;; esac; done </proc/meminfo

set -- $( ifconfig "$ETHERNET" )
MAC=$5
MAC="$( echo "$MAC" | sed 's/://g' | tr 'A-F' 'a-f' )"

UPTIME=$(( $( read A </proc/uptime; echo ${A%%.*} ) / 3600 ))
read LOAD </proc/loadavg; LOAD=${LOAD%% *}	#; LOAD=${LOAD//./}
LOAD="$( echo $LOAD | sed 's/\.//g' )"
SSID=

if   [ -e '/usr/local/bin/omap4_temp' ]; then
	SSID="$( /usr/local/bin/omap4_temp )"
	SSID="$SSID+%c2%b0C"	# space grad celcius
elif [ -e '/usr/bin/sensors' ]; then
	# apt-get install lm-sensors
	set -- $( sensors | fgrep 'temp1:' )
	SSID="$2"					# +56.0°C
	SSID="$( echo "$SSID" | sed 's/[^0-9\.]//g' )"	#  56.0
	SSID="$SSID+%c2%b0C"	# space grad celcius

	set -- $( sensors | fgrep 'fan1:' )
	SSID="$SSID+%7C+$2+RPM"				# 56.0 °C | 4900 RPM

	# TODO: show highest
	# sensors | grep '°C' | cut -d'+' -f2 | cut -d'.' -f1 | sort -n | tail -n1
fi

[ -e '/usr/bin/scrot' ] && {		# comment out, if unneeded
	HASH_OLD="$( sha1sum "/tmp/screenshot.jpg" )"
	export DISPLAY=:0
	scrot --quality 10 "/tmp/screenshot.jpg"
	HASH_NEW="$( sha1sum "/tmp/screenshot.jpg" )"

	if [ "$HASH_OLD" = "$HASH_NEW" ]; then
		logger -s "screen didnt change"
	else
		logger -s "screen changed, sending screenshot"
		scp "/tmp/screenshot.jpg" root@$MONI_SERVER:/var/www/networks/$NETWORK/settings/$MAC.screenshot.jpg
	fi
}

diskspace()
{
	set -- $( df -h | grep ^'/dev/sd' | head -n1 )	# first HDD
	echo "flash.free.kb%3a$4"			# %3a = :
}

show_switch()
{
	return 0

	ip link show dev "$ETHERNET" | fgrep -q 'NO-CARRIER' && return 1
	[ -e "/sbin/mii-tool" ] && /sbin/mii-tool "$ETHERNET" 2>/dev/null
}

SWITCH="$( show_switch )"
case "$SWITCH" in
	*'1000baseT-FD'*) SWITCH='C' ;;
	*'1000baseT-HD'*) SWITCH='c' ;;
	*) SWITCH='-' ;;
esac

URL="$URL/?local=$( date +%Y%b%d_%Huhr%M )&node=$NODENUMBER&city=168&mac=${MAC}&latlon=&hostname=${HOSTNAME}&update=0&wifidrv=&olsrver=&olsrrestartcount=0&olsrrestarttime=&portfw=&optimizenlq=&optimizeneigh=off&txpwr=0&wifimode=ap&channel=1&mrate=auto&hw=${HARDWARE}&frag=&rts=&pfilter=&gmodeprot=0&gmode=11ng&profile=${NETWORK}_ap&noise=-1&rssi=&distance=&version=${VERSION}&reboot=1&up=${UPTIME}&load=${LOAD}&forwarded=0&essid=${SSID}&bssid=&gw=1&gwnode=1&etx2gw=1&hop2gw=0&neigh=&users=&pubip=${MYPUBIP}&sens=&wifiscan=&v1=$( uname -r )&v2=&s1=${SWITCH}&h1=${RAM}&h2=&h4=2&h5=33&h6=4096&h7=337&d0=&d1=&n0=&i0=static&i1=wan&i2=${MYIP}%2f29&i3=0&i4=0&i5=${MYGW}&r0=&w0=wlan0&w1=0&services=$( diskspace )"

logger -s "$0: ${#URL} bytes: $URL"
if wget -qO /dev/null "$URL"; then
	echo "$URL" >/tmp/MONITORING.ok
else
	touch /tmp/MONITORING.err
fi

logger -s "$0: [READY]"
