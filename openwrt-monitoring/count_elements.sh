#!/bin/sh

ARG1="$1"	# routers

list_networks()
{
	ls -1 /var/www/networks
}

for NETWORK in $( list_networks ); do {
#	find /some/dir/ -maxdepth 0 -empty
	DIR="/var/www/networks/$NETWORK/meshrdf/recent"
	[ -e "$DIR" ] && {
		ls -1 "$DIR"
	}
} done

echo "$ARG1"
