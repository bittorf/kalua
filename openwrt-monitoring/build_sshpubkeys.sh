#!/bin/sh

[ -z "$2" ] && {
	echo "Usage: $0 <network> <version|?|+0.1>"
	exit 1
}

NETWORK="$1"
IPKG_VERSION="$2"
IPKG_NAME="sshpubkeys"
BASE="/var/www/networks/$NETWORK"

[ "$2" = '?' ] && {
	while read -r LINE; do {

		case "$LINE" in
			*": $IPKG_NAME")
				DIRTY="1"
			;;
		esac

		case "$DIRTY-$LINE" in
			"1-Version"*)
				echo $LINE | cut -d' ' -f2
				break
			;;
		esac

	} done <"$BASE/packages/Packages"

	exit 1
}

# raise version by 0.1
[ "$2" = '+0.1' ] && {
	VERSION_NOW="$( $0 "$NETWORK" '?' )"

	NUM1="$( echo $VERSION_NOW | cut -d'.' -f1 )"
	NUM2="$( echo $VERSION_NOW | cut -d'.' -f2 )"

	if [ "$NUM2" = "9" ]; then
		NUM2="0"
		NUM1="$(( NUM1 + 1 ))"
	else
		NUM2="$(( NUM2 + 1 ))"
	fi

	VERSION_NEW="$NUM1.$NUM2"
	echo "$VERSION_NEW"

	exit 1
}


echo "#!/bin/sh"		 >postinst
echo "VERSION=$IPKG_VERSION"	>>postinst
cat ${0}.code			>>postinst	# inludes pubkey of monitoring server

# dont include files older than 30 days
I=0
for FILE in $( find $BASE/registrator/recent/ -type f -mtime -30 ); do {
	grep -q ^"$( basename $FILE )" $BASE/ignore/macs.txt || {
		if grep ^'NODE=""' $FILE ; then
			continue
		else
			I=$(( I + 1 ))
			cat $FILE >>postinst
		fi
	}
} done

cat postinst				# just to see it / debug
echo
echo "number of keys: $I"
echo "# end of file"
echo "filesize: $( ls -l postinst )"
echo

chmod 777 postinst

echo "2.0" >"debian-binary"

cat >control <<EOF
Package: $IPKG_NAME
Version: $IPKG_VERSION
Architecture: all
Priority: optional
Maintainer: Bastian Bittorf <technik@bittorf-wireless.de>
Section: net
Description: installs all public ssh keys for network '$NETWORK'
Source: http://intercity-vpn.de/networks/$NETWORK/registrator/
EOF

tar --owner=root --group=root --ignore-failed-read -czf ./data.tar.gz "" 2>/dev/null
tar czf control.tar.gz ./control ./postinst
tar czf "${IPKG_NAME}_${IPKG_VERSION}.ipk" ./debian-binary ./control.tar.gz ./data.tar.gz

rm ./data.tar.gz ./debian-binary ./control.tar.gz control postinst
mv "${IPKG_NAME}_${IPKG_VERSION}.ipk" $BASE/packages/
echo "$BASE/packages/"
ls -l $BASE/packages/
