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

for DIR in tarball/stable tarball/beta tarball/testing \
	   firmware log ignore meshrdf meshrdf/recent packages \
	   registrator registrator2 registrator/sshfp \
	   registrator/recent rrd speedtest vds vpn whitelist media; do {
	mkdir -p "${BASE}/${NETWORK}/${DIR}" && echo "creating '${BASE}/${NETWORK}/${DIR}/'"
} done

for FILE in log/log.txt meshrdf/meshrdf.txt ignore/macs.txt; do {
	touch "${BASE}/${NETWORK}/${FILE}" && echo "touching '${BASE}/${NETWORK}/${FILE}'"
} done

for DIR in tarball/stable tarball/beta tarball/testing ; do {
	FILE="${BASE}/${NETWORK}/${DIR}/info.txt"

	[ -e "$FILE" ] || {
		echo >"$FILE" "CRC[md5]: 0  SIZE[byte]: 0  FILE: 'tarball.tgz'" && log "wrote '$FILE'"
	}
} done

F='/var/www/scripts/netjsongraph.js';		ln -s "$F" "${BASE}/${NETWORK}/meshrdf/netjsongraph.js"			&& echo "symlink to '$F'"
F='/var/www/scripts/netjson.html';		ln -s "$F" "${BASE}/${NETWORK}/meshrdf/netjson.html"			&& echo "symlink to '$F'"
F="/var/www/scripts/meshrdf_generate_table.sh";	ln -s "$F" "${BASE}/${NETWORK}/meshrdf/generate_table.sh"		&& echo "symlink to '$F'"
F="/var/www/scripts/meshrdf_generate_map.sh";	ln -s "$F" "${BASE}/${NETWORK}/meshrdf/generate_map.sh"			&& echo "symlink to '$F'"
F="/var/www/scripts/meshrdf_accept.php";	ln -s "$F" "${BASE}/${NETWORK}/meshrdf/index.php"			&& echo "symlink to '$F'"
F="/var/www/scripts/meshrdf_accept.sh";		ln -s "$F" "${BASE}/${NETWORK}/meshrdf/meshrdf_accept.sh"		&& echo "symlink to '$F'"
F="/var/www/scripts/registrator_accept.php";	ln -s "$F" "${BASE}/${NETWORK}/registrator/index.php"			&& echo "symlink to '$F'"
F="/var/www/scripts/registrator_accept.sh";	ln -s "$F" "${BASE}/${NETWORK}/registrator/registrator_accept.sh"	&& echo "symlink to '$F'"
F="/var/www/scripts/registrator2_accept.php";	ln -s "$F" "${BASE}/${NETWORK}/registrator2/index.php"			&& echo "symlink to '$F'"
F="/var/www/scripts/registrator2_accept.sh";	ln -s "$F" "${BASE}/${NETWORK}/registrator2/registrator2_accept.sh"	&& echo "symlink to '$F'"

F="${BASE}/${NETWORK}/packages"
[ -z "$( ls -1 2>/dev/null "$F/mydesign"* )"    ] && cp /var/www/scripts/mydesign_0.1.ipk		    "$F" && echo "+mydesign"
# [ -z "$( ls -1 2>/dev/null "$F/fff-adblock"* )" ] && cp /var/www/scripts/fff-adblock-list_0.1.0_mipsel.ipk  "$F" && echo "+fff-adblock-list"

chmod -R 777 "${BASE}/${NETWORK}/" && echo "chmod 777 all"

cd "${BASE}/${NETWORK}/packages"
/var/www/scripts/gen_package_list.sh && echo "generated package-list from private repo"

cd "${BASE}/${NETWORK}/vds"
echo "<html><body>hi</body></html>" >index.html && echo "put empty startpagepage into vds"

cd "${BASE}/${NETWORK}/speedtest"
echo -e '<?php\necho $_SERVER["REMOTE_ADDR"];\n?>' >index.html && echo "put remote_addr startpagepage into speedtest"

