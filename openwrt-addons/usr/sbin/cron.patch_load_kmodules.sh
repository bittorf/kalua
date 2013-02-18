#!/bin/sh
. /tmp/loader

MYVERSION="v0.5"

modules_blacklist()
{
	local line

	echo -n "ipt_REDIRECT|nf_nat_ftp|nf_nat_irc|nf_conntrack_irc|nf_conntrack_ftp|nls_base|crypto_algapi|ipt_ULOG|xt_state|tg3|bgmac|hwmon"

	[ -e "/www/SIMPLE_MESHNODE" ] && {
		# iptables related
		echo -n '|xt_*|nf_*|ipt_*|x_*'
	}
}

modules_masquerading()
{
	if _net local_inet_offer >/dev/null; then
		echo -n "ipt_MASQUERADE|iptable_nat|nf_nat|nf_conntrack_ipv4|nf_defrag_ipv4|nf_conntrack|ip_tables|x_tables"
	else
		echo -n "no_masquering_needed"
	fi
}

modules_whitelist()
{
	case "$( _system architecture )" in
		atheros)
			echo -n "arc4|"
		;;
	esac

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
	echo '	for kmodule in bgmac tg3 hwmon; do {'
	echo '		grep -q ^"$kmodule " /proc/modules && {'
	echo '			echo >>/tmp/KMODULE.action "# unloaded: $kmodule"'
	echo '			rmmod "$kmodule"'
	echo '		}'
	echo '	} done'
	echo
	echo '	echo >>/tmp/KMODULE.action "# loaded modules now:"'
	echo "	sed 's/^/# preinit: /' /proc/modules >>/tmp/KMODULE.action"
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
	echo "				$( modules_masquerading ))"
	echo '					echo >>/tmp/KMODULE.action "# allowed-NAT: insmod $line"'
	echo '					insmod $line'
	echo '				;;'
	echo "				$( modules_blacklist ))"
	echo '					echo >>/tmp/KMODULE.action "# blacklisted: $line"'
	echo '				;;'
	echo "				$( modules_allowed )$( modules_whitelist ))"
	echo '					case "$line" in'
	echo "						$( modules_whitelist ))"
	echo '							# without parameters'
	echo '							echo >>/tmp/KMODULE.action "# whitelisted: insmod $line - (unload later!)"'
	echo '							list_unload_later="$list_unload_later ${line/ */}"'
	echo '						;;'
	echo '						*)'
	echo '							echo >>/tmp/KMODULE.action "# allowed: insmod $line"'
	echo '							insmod $line'
	echo '						;;'
	echo '					esac'
	echo "				;;"
	echo "				*)"
	echo '					echo >>/tmp/KMODULE.action "# ignored: $line"'
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

permanent_remove_kmodule()
{
	local name="$1"
	local file="/lib/modules/$( uname -r )/${name}.ko"

	[ -e "$file" ] && rm "$file"
}

if [ -e "/etc/functions.sh" ]; then
	FILE="/etc/functions.sh"
else
	FILE="/lib/functions.sh"
fi

if grep -q ^"load_modules()	# patched $MYVERSION from" "$FILE"; then
	# already patched
	EXITCODE=1
else
	output_new_function >>"$FILE"
	EXITCODE=0
fi

permanent_remove_kmodule tg3	&& EXITCODE=0
permanent_remove_kmodule bgmac	&& EXITCODE=0
permanent_remove_kmodule hwmon	&& EXITCODE=0

exit "$EXITCODE"
