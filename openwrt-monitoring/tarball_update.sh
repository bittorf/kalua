#!/bin/sh

NETWORK="$1"	# liszt28
MODE="$2"	# testing
TARBALL='/tmp/tarball.tgz'

[ -z "$2" ] && {
	echo "usage: $0 <network|all> <mode>"
	echo "e.g. : $0 liszt28 testing"
	exit 1
}

[ -e "$TARBALL" ] || {
	cat <<EOF
[ERROR] cannot find tarball '$TARBALL', please do:

cd /root/tarball/
cd kalua
git pull
cd ..
kalua/openwrt-build/mybuild.sh build_kalua_update_tarball
EOF
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

[ "$NETWORK" = 'all' ] && NETWORK="$( list_networks )"

for NW in $NETWORK; do {
	DIR="/var/www/networks/$NW/tarball/$MODE"
	MD5="$( md5sum "$TARBALL" | cut -d' ' -f1 )"
	SIZE="$( stat -c%s "$TARBALL" )"

	cp -v "$TARBALL" "$DIR"
	echo "CRC[md5]: $MD5  SIZE[byte]: $SIZE  FILE: 'tarball.tgz'" >"$DIR/info.txt"
} done
