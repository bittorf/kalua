#!/bin/sh

ARG1="$1"	# <start|networkname
ARG2="$2"	# <empty> or 'force'

PACKAGE="sshpubkeys"
SCRIPT="/var/www/scripts/build_$PACKAGE.sh"

I=0
J=0

log()
{
	logger -s "$0: $1"
}

filehash()
{
	sed '2d' "$1" | md5sum | cut -d' ' -f1
}

list_networks()
{
	local pattern1="/var/www/networks/"
	local pattern2="/meshrdf/recent"

	find /var/www/networks/ -name recent |
	 grep "meshrdf/recent"$ |
	  sed -e "s|$pattern1||" -e "s|$pattern2||"
}

case "$ARG1" in
	'')
		echo "Usage: $0 <start|networkname>"
		echo
		echo "loops over:"
		list_networks
		exit 1
	;;
	start)
		LIST_NETWORKS="$( list_networks )"
	;;
	*)
		LIST_NETWORKS="$ARG1"
	;;
esac

for NETWORK in $LIST_NETWORKS; do {
	PACKAGE_BASE="/var/www/networks/$NETWORK/packages"

	if [ -d "$PACKAGE_BASE" ]; then
		cd "$PACKAGE_BASE" || exit
	else
#		log "dir '$PACKAGE_BASE' not found, omiting network"
		continue
	fi

	VERSION_NOW="$( $SCRIPT "$NETWORK" "?"    )"
	VERSION_NEW="$( $SCRIPT "$NETWORK" "+0.1" )"

	[ -n "$VERSION_NOW" ] || {
#		log "not found any $PACKAGE file, omiting network"
		continue
	}

#	log "[START] making new version $VERSION_NOW -> $VERSION_NEW"
	$SCRIPT "$NETWORK" "$VERSION_NEW" >/dev/null
#	log "[READY] new version"

	F1="$PACKAGE_BASE/${PACKAGE}_${VERSION_NOW}"*
	F2="$PACKAGE_BASE/${PACKAGE}_${VERSION_NEW}"*

#	log "[START] checking hash tar1 = ${PACKAGE}_${VERSION_NOW}*"
	tar xzf "${PACKAGE}_${VERSION_NOW}"* "./control.tar.gz"
	tar xzf "control.tar.gz" "./postinst"
	HASH1="$( filehash "./postinst" )"
	rm "./control.tar.gz"
	rm "./postinst"
#	log "[READY] check hash1"

#	log "[START] checking hash tar2 = ${PACKAGE}_${VERSION_NEW}*"
	tar xzf "${PACKAGE}_${VERSION_NEW}"* "./control.tar.gz"
	tar xzf "control.tar.gz" "./postinst"
	HASH2="$( filehash "./postinst" )"
	rm "./control.tar.gz"
	rm "./postinst"
#	log "[READY] check hash2"

	if [ "$HASH1" = "$HASH2" -a "$ARG2" != 'force' ]; then
#		log "[OK] same hash for network $NETWORK - nothing to do, staying at version $VERSION_NOW"
		I=$(( I + 1 ))
		rm $F2 2>/dev/null
	else
		log "[OK] hash differs, leaving new package v$VERSION_NEW, deleting old, regen index"
		J=$(( J + 1 ))
		rm $F1 2>/dev/null
		/var/www/scripts/gen_package_list.sh start
	fi

#	log "[READY] $NETWORK"
} done

log "[OK] $(( I + J )) overall, $I unchanged, $J updated"
