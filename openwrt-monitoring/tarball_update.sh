#!/bin/sh

NETWORK="$1"	# liszt28 or 'start'
MODE="$2"	# testing or <githash>
TARBALL='/tmp/tarball.tgz'

[ "$NETWORK" = 'start' ] && {
	HASH="$MODE"

	mkdir -p /root/tarball
	cd /root/tarball || exit
	cd kalua || {
		git clone 'https://github.com/bittorf/kalua.git'
		cd kalua || exit
	}

	git log -1
	git pull
	[ -n "$HASH" ] && {
		if git show "$HASH" >/dev/null; then
			git checkout -b 'userwish' "$HASH"
		else
			HASH=
		fi
	}
	git log -1
	cd ..

	kalua/openwrt-build/mybuild.sh build_kalua_update_tarball

	[ -n "$HASH" ] && {
		cd kalua || exit
		git checkout master
		git branch -D 'userwish'
		cd ..
	}

	exit $?
}

[ -z "$MODE" ] && {
	echo "usage: $0 <network|all> <mode>"
	echo "       $0 start"
	echo
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

[ "$NETWORK" = 'all' ] && NETWORK="$( list_networks )"

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

for NW in $NETWORK; do {
	DIR="/var/www/networks/$NW/tarball/$MODE"
	MD5="$( md5sum "$TARBALL" | cut -d' ' -f1 )"
	SHA256="$( sha256sum "$TARBALL" | cut -d' ' -f1 )"
	SIZE="$( stat -c%s "$TARBALL" )"
	mkdir -p "$DIR"

	cd /root/tarball/kalua || exit
	LAST_UNIXTIME="$( date +%s -r "$DIR/info.txt" )"
	LAST_COMMIT="$( git rev-list -n1 --format=%h --before="@$LAST_UNIXTIME" master | tail -n1 )"
	COMMIT_NOW="$( git log -1 --format=%h )"
#	[ -n "$HASH" ] && COMMIT_NOW="$HASH"
	logger -s "from...to: $LAST_COMMIT...$COMMIT_NOW"
	[ "$LAST_COMMIT" = "$COMMIT_NOW" ] || {
		echo "$( date ) - pmu: $LAST_COMMIT...$COMMIT_NOW" >>"$DIR/../../media/error_history.txt"
	}

	logger -s "https://github.com/bittorf/kalua/compare/$LAST_COMMIT...$COMMIT_NOW"
	logger -s "count commits:"
	git rev-list --format=%h $LAST_COMMIT...$COMMIT_NOW master | grep -c ^'commit '
	logger -s "shortlog/authors"
	git shortlog -s $LAST_COMMIT...$COMMIT_NOW

	cd - || exit

	logger -s "cp -v '$TARBALL' '$DIR'"
	ls -l "$DIR/info.txt"
	cat "$DIR/info.txt"

	cp -v "$TARBALL" "$DIR"

	# TODO: move to build.sh, so we can use 'usign' from staging_dir?
	cat >"$DIR/info.json" <<EOF
{
  "build_time": "$( date )",
  "update_file": "tarball.tgz",
  "update_size": "$SIZE",
  "update_md5": "$MD5",
  "update_sha256": "$SHA256",
  "update_signature": "foo"
}
EOF

	echo "CRC[md5]: $MD5  SIZE[byte]: $SIZE  FILE: 'tarball.tgz'" >"$DIR/info.txt"
} done
