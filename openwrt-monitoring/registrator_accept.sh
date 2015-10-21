#!/bin/sh

if [ -z "$1" ]; then
	exit
else
	eval "$1"	# NODE|WIFIMAC|SSHPUBKEY|SSHPUBKEYFP
fi

log()
{
	local date="$( date )"
	local unixtime="$( date +%s )"
	local file="../log/log.txt"

	echo "$unixtime|SERVER|------------|$date|registrator: $1" >>"$file"
}

is_6bytes_hex()		# mac-address without colon's or minus
{
	local mac="$1"
	local hex="0-9a-zA-Z"

	case "$mac" in
		[$hex][$hex][$hex][$hex][$hex][$hex][$hex][$hex][$hex][$hex][$hex][$hex]) return 0 ;;
		*) return 1 ;;
	esac
}

is_6bytes_hex $WIFIMAC || {
	log "wifimac ungueltig: '$WIFIMAC'"
	exit
}

echo "$1" >>./registrator.txt		# only save last 50 lines?
echo "$1" >./recent/$WIFIMAC

if [ -e "recent/$WIFIMAC" ]; then
	log "state 1 - $( ls -l recent/$WIFIMAC )"
else
	log "state 0 - error during writing recent/$WIFIMAC"
fi

log "pwd: $( pwd ) - working on query $1"

[ -n "$SSHPUBKEYFP" ] && {

	if [ -n "$NODE" ]; then		# already registered node

		if [ -e "sshfp/$SSHPUBKEYFP" ]; then

			[ -z "$SSHPUBKEY" ] && {
				log "state A"
				echo "REGENERATE_KEY"
				exit
			}

			if [ "$( cat sshfp/$SSHPUBKEYFP )" -eq "$NODE" ]; then
				log "state B"
				echo "OK"
				touch "sshfp/$SSHPUBKEYFP"
				
			else
				log "state C"
				echo "REGENERATE_KEY"
				log "REGENERATE_KEY2: node'$NODE' want's to reg with same SSHPUBKEYFP='$SSHPUBKEYFP' like node'$( cat sshfp/$SSHPUBKEYFP )'"
			fi
		else

			[ -z "$SSHPUBKEY" ] && {
				log "state D"
				echo "REGENERATE_KEY"
				exit
			}

			if [ "$( cat sshfp/$SSHPUBKEYFP )" -eq "$NODE" ]; then
				log "state E"
				echo "REGENERATE_KEY"
				log "REGENERATE_KEY: node'$NODE' want's to reg with same SSHPUBKEYFP='$SSHPUBKEYFP' like node'$( cat sshfp/$SSHPUBKEYFP )'"
			else
				log "state F"
				echo "OK"
				echo "$NODE" >"sshfp/$SSHPUBKEYFP"
				log "registered node '$NODE', not yet in database - applying"
			fi
		fi
	else
		log "state G"

		NETWORK="$( pwd | sed -n 's#^/var/www/networks/\(.*\)/.*#\1#p' )"

		case $NETWORK in		# new nodes start at $I, with registering until old nodes are in database
			ffweimar) I=500 ;;
			 ffsundi) I=89 ;;
	                elephant) I=5 ;;
			 galerie) I=61 ;;
			       *) I=9 ;;	# die 3 steht in der liszt28...
		esac

		while [ -e "sshfp/$I" ]; do {
			I=$(( I + 1 ))	
		} done

		log "new node '$SSHPUBKEYFP' - new id is '$I' - wifimac is '$WIFIMAC'"
		
		echo "$I"
		echo "$I" >sshfp/$I
		echo "$I" >sshfp/$SSHPUBKEYFP
	fi
}
