#!/bin/sh

NETWORK="$1"	# liszt28
MODE="$2"	# testing

[ -z "$2" ] && {
	echo "usage: $0 <network> <mode>"
	echo "e.g. : $0 liszt28 testing"
	exit 1
}

list_networks()
{
        local pattern1="/var/www/networks/"
        local pattern2="/meshrdf/recent"

        find /var/www/networks/ -name recent |
         grep "meshrdf/recent"$ |
          sed -e "s|$pattern1||" -e "s|$pattern2||"
}

for NW in ${NETWORK:-$( list_networks )}; do {
	DIR="/var/www/networks/$NW/tarball/$MODE"
	cp -v /tmp/tarball.tgz $DIR
	echo "CRC[md5]: $(md5sum /tmp/tarball.tgz | cut -d' ' -f1)  SIZE[byte]: $(stat -c%s /tmp/tarball.tgz)  FILE: 'tarball.tgz'" >"$DIR/info.txt"
} done
