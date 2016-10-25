#!/bin/sh

# for F in $( ls -1 /var/www/networks/ );do test -d /var/www/networks/$F/firmware && ... ; done

[ -z "$1" ] && {
	echo "Usage: $0 <network>"
	exit 1
}

BASE='/var/www/networks'
NETWORK="$1"

log()
{
	logger -s "$0: $1"
}

for DIR in '' tarball/stable tarball/beta tarball/testing \
	   firmware log ignore meshrdf meshrdf/recent packages \
	   registrator registrator2 registrator/sshfp \
	   registrator/recent rrd speedtest vds vpn whitelist media; do {
	mkdir "${BASE}/${NETWORK}/${DIR}" 2>/dev/null && log "creating '${BASE}/${NETWORK}/${DIR}/'"
} done

for FILE in log/log.txt meshrdf/meshrdf.txt ignore/macs.txt; do {
	FILE="$BASE/$NETWORK/$FILE"
	[ -e "$FILE" ] || {
		touch "$FILE" && log "touched '$FILE'"
	}
} done

for DIR in tarball/stable tarball/beta tarball/testing ; do {
	FILE="${BASE}/${NETWORK}/${DIR}/info.txt"

	[ -e "$FILE" ] || {
		echo >"$FILE" "CRC[md5]: 0  SIZE[byte]: 0  FILE: 'tarball.tgz'" && log "wrote '$FILE'"
	}
} done

symlink()
{
	local destinaton="$1"
	local file="$BASE/$NETWORK/$2"

	if [ -h "$file" ]; then
		return 0
	else
		if ln -s "$destinaton" "$file"; then
			log "symlink to '$destinaton'"
		else
			log "[ERR] symlink '$destinaton'"
		fi
	fi
}

symlink '/var/www/scripts/netjsongraph.css'		'meshrdf/netjsongraph.css'
symlink '/var/www/scripts/netjsongraph.css'		'meshrdf/netjsongraph.css'
symlink '/var/www/scripts/netjsongraph-theme.css'	'meshrdf/netjsongraph-theme.css'
symlink '/var/www/scripts/netjsongraph.js'		'/meshrdf/netjsongraph.js'
symlink '/var/www/scripts/netjson.html'			'meshrdf/netjson.html'
symlink '/var/www/scripts/meshrdf_generate_table.sh'	'meshrdf/generate_table.sh'
symlink '/var/www/scripts/meshrdf_generate_map.sh'	'meshrdf/generate_map.sh'
symlink '/var/www/scripts/meshrdf_accept.php'		'meshrdf/index.php'
symlink '/var/www/scripts/meshrdf_accept.sh'		'meshrdf/meshrdf_accept.sh'
symlink '/var/www/scripts/registrator_accept.php'	'registrator/index.php'
symlink '/var/www/scripts/registrator_accept.sh'	'registrator/registrator_accept.sh'
symlink '/var/www/scripts/registrator2_accept.php'	'registrator2/index.php'
symlink '/var/www/scripts/registrator2_accept.sh'	'registrator2/registrator2_accept.sh'

F="${BASE}/${NETWORK}/packages"
[ -z "$( ls -1 2>/dev/null "$F/mydesign"* )"    ] && cp /var/www/scripts/mydesign_0.1.ipk		    "$F" && log "+mydesign"
# [ -z "$( ls -1 2>/dev/null "$F/fff-adblock"* )" ] && cp /var/www/scripts/fff-adblock-list_0.1.0_mipsel.ipk  "$F" && echo "+fff-adblock-list"

chmod -R 777 "${BASE}/${NETWORK}/" && log "[OK] chmod 777 all"

/var/www/scripts/gen_package_list.sh "$NETWORK" && \
	log "[OK] generated package-list from private repo '$NETWORK'"

cd "${BASE}/${NETWORK}/vds" || exit
echo "<html><body>protected</body></html>" >index.html && log "[OK] putting empty startpage into vds-dir"

cd "${BASE}/${NETWORK}/speedtest" || exit

printf '%s\n%s\n%s' '<?php' 'echo $_SERVER["REMOTE_ADDR"];' '?>' >index.html
log "[OK] put remote_addr startpagepage into speedtest"
