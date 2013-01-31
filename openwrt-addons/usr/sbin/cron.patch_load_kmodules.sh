#!/bin/sh

MYVERSION="v0.2"

modules_blacklist()
{
	echo -n "ipt_REDIRECT|nf_nat_ftp|nf_nat_irc|nf_conntrack_irc|nf_conntrack_ftp|nls_base|arc4|crypto_algapi|ipt_ULOG|xt_state|tg3|bgmac|hwmon"
}

modules_whitelist()
{
	echo -n "diag|switch-*"		# are needed, but can be unloaded after netifd-init
}

modules_allowed()
{
	local line

	while read line; do {
		set -- $line
		echo -n "${1}*|"
	} done </proc/modules
}

output_new_function()
{
	echo
	echo "load_modules()	# patched $MYVERSION from $0"
	echo "{"
	echo "	local line file t1 t2 duration trash list_unload_later list_reverse kmodule"
	echo
	echo "	read t1 trash </proc/uptime"
	echo
	echo '	while [ -n "$1" ]; do {'
	echo '		file="$1"'
	echo "		shift"
	echo
	echo '		line="$( cat "$file" )"'
	echo '		test ${#line} -eq 0 && return'
	echo
	echo "		while read line; do {"
	echo '			case "$line" in'
	echo "				$( modules_blacklist ))"
	echo '					echo >>/tmp/KMODULE.action "# $line"'
	echo '				;;'
	echo "				$( modules_allowed )$( modules_whitelist ))"
	echo '					case "$line" in'
	echo "						$( modules_whitelist ))"
	echo '							# without parameters'
	echo '							echo >>/tmp/KMODULE.action "# + insmod $line - (unload later!)"'
	echo '							list_unload_later="$list_unload_later ${line/ */}"'
	echo '						;;'
	echo '						*)'
	echo '							echo >>/tmp/KMODULE.action "# + insmod $line"'
	echo '							insmod $line'
	echo '						;;'
	echo '					esac'
	echo "				;;"
	echo "				*)"
	echo '					echo >>/tmp/KMODULE.action "# $line"'
	echo "				;;"
	echo "			esac"
	echo '		} done <"$file"'
	echo "	} done"
	echo
	echo '	for kmodule in $list_unload_later; do list_reverse="$kmodule $list_reverse"; done'
	echo '	for kmodule in $list_reverse "diag"; do {'
	echo '		echo >>/tmp/KMODULE.action "rmmod $kmodule"'
	echo '	} done'
	echo
	echo '	read t2 trash </proc/uptime; duration=$(( ${t2//./} - ${t1//./} ))'
	echo '	echo >>/tmp/KMODULE.action "# done in $(( $duration / 100 )).$(( $duration % 100 )) sec"'
	echo "}"
}

if [ -e "/etc/functions.sh" ]; then
	FILE="/etc/functions.sh"
else
	FILE="/lib/functions.sh"
fi

grep -q ^"load_modules()	# patched $MYVERSION from" "$FILE" || {
	output_new_function >>"$FILE"
}
