#!/bin/sh

### look every x seconds if failed or up again!

# folgender aufruf ist moeglich
# /var/www/scripts/ping_counter.sh list_pubips_from_network marinabh
#
# ToDo:
# - nach abbruch, ausgeben: ls -lt /dev/shm/pingcheck/*.faulty
# - testfunction for 'fetch_testfile'
# - sehr alte pub IPs aus liste nehmen und sicherstellen, das counter beschissen wird

# helper:
# pruefen wo ist welche IP: IP='1.2.3.4'
# iptables -nxvL myping | while read LINE; do set -- $LINE; case "$3" in 'myping_'*) iptables -nxvL $3 | fgrep "$IP" && echo "$3" ;; esac; done
#
# entfernen mit:
# iptables -D myping_ejbw-pbx -s "$IP" -j ACCEPT
# besser:
# NW=liszt28; I=0; while let I+=1; do iptables -nxvL myping_$NW $I | fgrep -q " $IP " && break; done; iptables -D myping_$NW $I

log()
{
	logger -s "$(date) $0: $1"
}

list_pubips_from_network()	# parses status-files from monitoring of each node for a specific network
{
	local network="$1"
	local option="$2"	# <empty> or 'get_fileage'
	local file dir pattern filetime fileage
	local unixtime="$( date +%s )"

	case "$network" in
		'chicagovps')
			echo '198.23.155.210'
		;;
		'js.ars.is')
			echo '77.87.48.42'
		;;
		*)
			case "$network" in
				'liszt28:G5klaus')
					pattern='f8d111a9d254'
				;;
				'liszt28:Mutti')
					pattern='b0487abb4f6e'
				;;
				'liszt28:Buero')
					pattern='d85d4c9c2f1a'
				;;
				'liszt28:Fries36')
					pattern='74ea3ae44a96'
				;;
				'spbansin:Haus8')
					pattern='f4ec38c9bea0'
				;;
				'satama')
					pattern='74ea3adb1580'
				;;
				'fparkssee')
					pattern='b0487ac5d9ba'
				;;
				'marinapark')
					pattern='f4ec389d8614'
				;;
				'monami:saal')
					pattern='00259cc45101'
				;;
				'monami:buero')
					pattern='0013100ad58d'
				;;
				*)
					pattern='[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]'
				;;
			esac


# fixme! show newest at first!

			network="${network%:*}"
			dir="/var/www/networks/$network/meshrdf/recent"
			for file in $( ls -1t "$dir" | grep "$pattern"$ ); do {
#				log "ARG2: $ARG2 - file: '$file' pattern: '$pattern'"

				case "${file}_${network}" in
					*'002590382eb6_ejbw'|*'002590382edc_ejbw')
						continue	# belongs to 'ejbw-pbx'
					;;
					*'002590382eb6_ejbw-pbx')
						continue	# backup-system
					;;
				esac

				filetime="$( date +%s -r "$dir/$file" )"
				fileage=$(( unixtime - filetime ))

				[ "$option" = 'get_fileage' ] && {
					echo "$fileage"
					break
				}

				[ -e "$dir/$file.changes" ] && {
					. "$dir/$file.changes"
#					logger -s "[OK] using file '$dir/$file.changes' with IP $PUBIP_REAL"
					echo "$PUBIP_REAL"
				}

				[ $fileage -lt 86400 ] && {
					sed 's/;/\n/g' "$dir/$file" | grep ^'PUBIP_REAL=' | cut -d'"' -f2
				}
			} done | sort | uniq
		;;
	esac
}

list_networks()
{
	local option="$1"	# networkname or 'maintenance' or <empty> = all
	# in wartung:
	# aschbach = 15 euro/monat -> CANS
	# olympia  = 15 euro/monat -> CANS

	# weg seit 28.april: liszt28:Buero

	if   [ -e "/var/www/networks/${1:-unset}" ]; then
		echo "$1"
		return 0
	elif [ "$1" = 'maintenance' ]; then
		cat <<EOF
chicago
giancarlo
malchow
malchowit
malchowpferde
malchowpension
abtpark
ilm1
adagio
ibfleesensee
apphalle
ejbw
ejbw-pbx
castelfalfi
leonardo
schoeneck
extrawatt
aschbach
boltenhagendh
dhfleesensee
berlinle
spbansin
limona
xoai
amalienhof
rehungen
paltstadt
palais
EOF
	else
		cat <<EOF
giancarlo
malchow
malchowit
malchowpferde
malchowpension
abtpark
ilm1
chicagovps
adagio
ibfleesensee
apphalle
liszt28
liszt28:Mutti
liszt28:Fries36
marinabh
ejbw
ejbw-pbx
castelfalfi
leonardo
schoeneck
extrawatt
aschbach
boltenhagendh
dhfleesensee
berlinle
itzehoe
marinapark
spbansin
spbansin:Haus8
tkolleg
limona
monami
xoai
amalienhof
rehungen
paltstadt
palais
EOF
	fi

	# removed K80/H09	- 2013juli24 + switched on again: 2013juli31
	# removed ibfleesensee	- 2013jul25
	# removed hotello-B01	- 2013oct30 + switched on again: 2013nov22
	# removed vivaldi	- 2014jan17
	# removed hotello-B01 + hotello-K80 + hotello-H09 = 2014jan20
	# removed dhsylt        - 2014apr11
}

fetch_testfile()	# if ping is missing, we try to fetch a testurl/testdata - if this is failing to, cry!
{
	local funcname="fetch_testfile"
	local network="$1"
	local ip
	local proto="http"
	local port="80"
	local append="--insecure"
	local timeout=40	# seconds
	local try=5
	local ignore=
	local lastnewip lastnewip_diff

	local hour="$(   date +%H )"
#	local minute="$( date +%M )"

	[ -e '/tmp/SIMULATE_FAIL' ] && {
		rm '/tmp/SIMULATE_FAIL'
		return 1
	}

	case "$hour" in
		03)
			log "deepsleep: waiting 90 minutes till 4:30 o'clock"
			sleep $(( 90 * 60 ))
		;;
		21|22|23|24|00|01|02|04|05|06)
			timeout=120
		;;
		*)
			timeout=40
		;;
	esac

	[ -e "/dev/shm/pingcheck/$network.faulty" ] || touch "/dev/shm/pingcheck/$network.faulty"

	case "$network" in
		hotello-K80|hotello-H09|hotello-B01)
			proto="https"
			port=22443
		;;
		olympia)
			proto="https"
			port=22443
			# https://217.86.239.9:450/cgi-bin/webcm?getpage=../html/de/menus/menu2.html&var:menu=home&var:pagename=home
			# check-dsl: port 450 mit https: curl = RC 60
		;;
		ejbw-pbx)
			proto="https"
			port=443
		;;
		rehungen)
			port=10080
		;;
		schoeneck)
			port=10080
		;;
		aschbach)
			port=5480
		;;
#		dhfleesensee)
#			proto="https"
#			port=50000
#		;;
		liszt28:Buero)
			proto='https'
			port='443'
		;;
		marinabh)
			port=18796
			ip="127.0.0.1"
			timeout=$(( timeout * 10 ))
		;;
	esac

	[ -e "/dev/shm/pingcheck/$NETWORK.lastnewip" ] && {
		read -r lastnewip <"/dev/shm/pingcheck/$NETWORK.lastnewip"
		lastnewip_diff=$(( $(date +%s) - lastnewip ))
		# 86400 -/+ 2400 = 84000 / 88800
		[ $lastnewip_diff -gt 84000 -a $lastnewip_diff -lt 88800 ] && ignore="last_ip_renew: $lastnewip_diff sec"
	}

	[ -n "$ignore" ] && {
		log "$network: ignoring potential error, reason: '$ignore'"
		return 0
	}

	[ "$proto" = "https" ] || append=

	while [ $try -gt 0 ]; do {
		add_new_ipaddresses_from_network "$network"

		if [ "$ip" = "127.0.0.1" ]; then
			LIST="$ip"
		else
			LIST="$( list_pubips_from_network "$network" )"
		fi

		for ip in $LIST ; do {
			log "$network: try $try/5 $funcname() exec: curl $append --connect-timeout $timeout '$proto://$ip:$port/robots.txt'"
			curl $append --silent --connect-timeout $timeout "$proto://$ip:$port/robots.txt" | grep -q ^'User-agent:' && return 0
		} done

		try=$(( try - 1 ))
		timeout=$(( timeout - 5 ))
		log "$network: $funcname() next round, try now: $try sleep: $(( timeout / 2 ))"
		sleep $(( timeout / 2 ))
	} done

	return 1
}

sms_allowed()
{
	local network="$1"
	local effective_name="$( echo "$network" | cut -d':' -f1 )"	# e.g. ffweimar:vhs

	[ -e '/tmp/NOSMS' ] && {
		log "$network: [ERR] sending sms supressed, found '/tmp/NOSMS'"
		return 1
	}

	iptables -nL INPUT 1 | grep -q ^'myping' || {
		log "$network: [ERR] sending sms supressed, iptables-whitelister inactiv"
		return 1
	}

	if list_networks 'maintenance' | grep -q ^"$effective_name"$; then
		return 0
	else
		log "$network: no sms allowed (not in 'maintenance')"
		return 1
	fi
}

send_sms()
{
	local network="$1"
	local text="$network: $2 ($(date))"
	local number="0176/24223419"		# bastian
#	local number_technik1='0177/8083369'	# joerg
	local number_technik1=
	local list_numbers="$number $number_technik1"

	sms_allowed "$network" || return 0

	case "$network" in
		'tkolleg')
			list_numbers="$list_numbers 0171/4338506"	# wagner
		;;
		'liszt28:G5klaus')
			list_numbers="$list_numbers 0151/56971001"	# klaus
		;;
		ilm1)
			list_numbers="$list_numbers 0172/5771399 0179/7750510"	# Stefan Schlieter / Andre Hirsch
		;;
		amalienhof)
			list_numbers="$list_numbers 0176/21702147"	# sven rahaus
		;;
		xoai)
			list_numbers="$list_numbers 0084907652927"	# mario
		;;
		ejbw*)
			local number_ralf='0162/2666166'
			local number_lars='0162/2666169'
			local number_dennis='0162/2666164'
			local number_willy='0172/7813781'

			list_numbers="$list_numbers $number_lars $number_dennis $number_willy $number_ralf"
		;;
		monami)
			list_numbers="$list_numbers 0176/66632227"	# wuschel
		;;
		adagio)
			list_numbers="$list_numbers 0179/2930354"	# hedrich
		;;
		js.ars.is)
			list_numbers="$list_numbers 0178/1892478"	# max
		;;
		hotello*|aschbach)
			list_numbers="$list_numbers 0172/8117657 0172/7772555 0177/5906689"
		;;
		olympia)
			list_numbers="$list_numbers 0177/5906689"	# andi
		;;
		extrawatt)
			list_numbers="$list_numbers 0174/9466472"
		;;
		schoeneck)
			list_numbers="$list_numbers 0172/9094456"
		;;
		apphalle)
			list_numbers="$list_numbers 0174/3564025"
		;;
		dhfleesensee)
			list_numbers="$list_numbers 0170/5661165 0160/4797497"
		;;
		'palais'|'paltstadt')
			list_numbers="$list_numbers 0173/3583353"	# e-steinmetz
		;;
		'malchow'*)
			list_numbers="$list_numbers 0173/6234581"	# badowski
		;;
	esac

	for number in $list_numbers; do {
		log "sending sms, call: /var/www/scripts/send_sms.sh '$network' '$number' '$text'"
		/var/www/scripts/send_sms.sh "$network" "$number" "$text"
	} done
}

count_pings()
{
	local network="$1"
	local rulenumber=1
	local pings=0
	local ip packets

	while true; do {
		set -f
		set -- $( iptables -nxvL "myping_$network" "$rulenumber" )
		set +f
		packets="$1"
		ip="$8"

		if [ -z "$packets" ]; then
			break
		else
			[ $rulenumber -eq 1 ] && {
				echo "$ip" >"/dev/shm/pingcheck/$NETWORK.recent_ip"
			}

			rulenumber=$(( rulenumber + 1 ))
			pings=$(( pings + $1 ))
		fi
	} done

	echo "$pings"
}

add_new_ipaddresses_from_network()
{
	local network="$1"
	local list_pubips="$( list_pubips_from_network "$network" )"
	local rc=1
	local ip list_network

	# e.g. liszt28:Buero -> updates liszt28 + liszt28:Buero
	case "$network" in
		*':'*)
			list_network="$network ${network%:*}"
		;;
		*)
			list_network="$network"
		;;
	esac

	is_in_another_network()
	{
		local ip="$1"
		local rc=1
		local line

		iptables -nxvL myping | while read -r line; do {
			set -- $line

			case "$3" in
				'myping_'*)
					iptables -nxvL $3 | fgrep -q " $ip " && {
						log "will not add $ip to network '$network' - found it already in $3"
						echo "YES"
						return 0
					}
				;;
			esac
		} done

#		log "is_in_another_network: $ip - no - rc: $?"
		echo 'NO'
		return $rc
	}

	for ip in $list_pubips; do {
		# we must make sure, that already applied
		# IP 84.184.176.218 is not the same like new
		# IP 84.184.176.21

		# FIXME!
		[ "$ip" = '198.23.155.210' -a "$network" = 'ilm1' ] && {
			log "deny adding $ip to to network $network"
			continue
		}

		iptables -nL myping_$network | fgrep -q " $ip " || {
			[ "$( is_in_another_network "$ip" )" = 'NO' ] && {
				for network in $list_network; do {
					# FIXME! - when in 'failure', check if good again!
					log "[OK] adding new pub-ip $ip for network $network"
					iptables -I myping_$network -s $ip -j ACCEPT
					date +%s >"/dev/shm/pingcheck/$NETWORK.lastnewip"
					rc=0
				} done
			}
		}
	} done

	return $rc
}

iptables -nL myping 1 >/dev/null || {
	log "initial setup of myping iptables-rules"
	iptables -N myping
	iptables -I INPUT -p icmp -j myping
}

ARG1="$1"
ARG2="$2"
ARG3="$3"
ARG4="$4"

[ -n "$ARG2" ] && {
	log "calling function(): $ARG1 $ARG2 $ARG3"
	$ARG1 $ARG2 $ARG3 $ARG4
	exit 0
}

for NETWORK in $( list_networks "$ARG1" ); do {
#	log "loop NETWORK: '$NETWORK'"

	iptables -nL myping_$NETWORK 1 >/dev/null || {
		log "$NETWORK: initial setup of counters"
		iptables -N myping_$NETWORK
		iptables -I myping -p icmp -j myping_$NETWORK
		continue
	}

	iptables -nL myping | grep -q ^"myping_$NETWORK" || {
		log "$NETWORK: initial setup of collector"
		iptables -I myping -p icmp -j myping_$NETWORK
		continue
	}

	add_new_ipaddresses_from_network "$NETWORK" && continue

	I=$( count_pings "$NETWORK" )
	mkdir -p /dev/shm/pingcheck
	read -r COUNTER_OLD <"/dev/shm/pingcheck/$NETWORK"
	# for testing ping, do:
	# echo 99999 >"/dev/shm/pingcheck/$NETWORK"
	# touch /tmp/SIMULATE_FAIL				// see fetch_testfile()

	if [ ${COUNTER_OLD:=0} -lt $I ]; then
		[ -e "/dev/shm/pingcheck/$NETWORK.faulty" ] && {
			UNIXTIME_START="$( stat -c "%Y" "/dev/shm/pingcheck/$NETWORK.faulty" )"
			UNIXTIME_READY="$( date +%s )"
			MINUTES_GONE=$(( (UNIXTIME_READY - UNIXTIME_START) / 60 ))

			rm "/dev/shm/pingcheck/$NETWORK.faulty"
			echo " - $(date) = $MINUTES_GONE mins [was: total service breakdown]" >>"/var/www/networks/$NETWORK/media/error_history.txt"
			send_sms "$NETWORK" "WLAN-System: OK, Problem behoben, Ausfallzeit: $MINUTES_GONE Minuten - Vielen Dank fuer Ihr Mitwirken (ping old/new: $COUNTER_OLD/$I)"

			FILE="/var/www/networks/$NETWORK/index.html"
			URL="http://127.0.0.1/networks/$NETWORK/meshrdf/?ORDER=hostname"

			grep -sq 'Totalausfall' "$FILE" || {
				wget -O "$FILE.pingtmp" "$URL"
				mv "$FILE.pingtmp" "$FILE"
			}
		}
	else
		log "$NETWORK: potential prob: old/new = $COUNTER_OLD/$I (last IP: $( cat "/dev/shm/pingcheck/$NETWORK.recent_ip" 2>/dev/null ))"

		if [ -e "/dev/shm/pingcheck/$NETWORK.faulty" ]; then
			log "$NETWORK: error already known since $( date -d @$(stat -c "%Y" "/dev/shm/pingcheck/$NETWORK.faulty") )"

			case "$NETWORK" in
				*':'*)
					J=$( list_pubips_from_network "$NETWORK" get_fileage )
					log "[DEBUG] list_pubips_from_network '$NETWORK' get_fileage -> '$J' [sec]"
				
					if [ $J -lt 900 ]; then
						log "[OK] $NETWORK: get_fileage: $J"
						rm "/dev/shm/pingcheck/$NETWORK.faulty"
					else
						log "[ERR] $NETWORK: get_fileage: $J - still dead"
					fi
				;;
				*)
					FILE="/var/www/networks/$NETWORK/index.html"
					URL="http://127.0.0.1/networks/$NETWORK/meshrdf/?ORDER=hostname"

					grep -sq 'Totalausfall' "$FILE" || {
						wget -O "$FILE" "$URL"
					}
				;;
			esac

		elif fetch_testfile "$NETWORK" ; then
			log "[OK] $NETWORK: fetching testfile"
			# fetch_testfile will touch it, da we have a correct timestamp in case of a real failure
			[ -e "/dev/shm/pingcheck/$NETWORK.faulty" ] && rm "/dev/shm/pingcheck/$NETWORK.faulty"
		else
			J=$( count_pings "$NETWORK" )
			if [ $J -eq $I ]; then
				mkdir -p "/var/www/networks/$NETWORK/media"
				echo -n "$(date)" >>"/var/www/networks/$NETWORK/media/error_history.txt"
				send_sms "$NETWORK" "WLAN-System, Stoerung festgestellt: bitte Internet/Zentralrouter pruefen (ping old/new: $COUNTER_OLD/$I)"
				echo "sms" >"/dev/shm/pingcheck/$NETWORK.faulty"
			else
				log "$NETWORK: seems good again, raised during fetch (ping old/new: $I/$J)"
				[ -e "/dev/shm/pingcheck/$NETWORK.faulty" ] && rm "/dev/shm/pingcheck/$NETWORK.faulty"
			fi
		fi
	fi

	echo "$I" >"/dev/shm/pingcheck/$NETWORK"

	if [ -e "/dev/shm/pingcheck/$NETWORK.faulty" ]; then
		log "$NETWORK: received pings: old/new = $COUNTER_OLD/$I"
	else
		if [ -e "/dev/shm/pingcheck/$NETWORK.lastnewip" ]; then
			read -r ip        2>/dev/null <"/dev/shm/pingcheck/$NETWORK.recent_ip"
			read -r lastnewip             <"/dev/shm/pingcheck/$NETWORK.lastnewip"
			UNIXTIME_NOW="$( date +%s )"
			DIFF=$(( (UNIXTIME_NOW - lastnewip) / 3600 ))
			DIFF="$DIFF hours"
		else
			DIFF="fixed IP"		# fixme! never goes into this path, file always exists?
			ip='fixed'
		fi

		log "[OK] $NETWORK: received pings: old/new = $COUNTER_OLD/$I - lastnewip: $DIFF (IP: $ip)"
	fi
} done

