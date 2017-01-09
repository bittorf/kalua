#!/bin/sh

read -r t1 _ </proc/uptime
[ -d '/tmp/crashlogs' ] || {
	mkdir -p '/tmp/crashlogs'
	chmod -R 777 '/tmp/crashlogs'
}

LIST_OMIT_REV='r33160 r32793 r33502 r33616 r33726 r35300 r37767 r33867 r34599 <46425'

# TODO:
# unaligned access? show 'process' in table

# build www with:
# /var/www/scripts/crashlog_build_html.sh >/tmp/crash_$$; mv /tmp/crash_$$ /var/www/crashlog/report.html

count_crashs()
{
	ls -1 /tmp/crashlogs/crash-* | wc -l
}

count_crashs_unreal()
{
	local file
	local i=0
	local j=0

	for file in /tmp/crashlogs/crash-*; do {
		if   grep -Fsq "SysRq : Trigger a crash" "$file"; then
			i=$(( i + 1 ))
		elif grep -Fsq "invoked oom-killer:" "$file"; then
			j=$(( j + 1 ))
		fi
	} done

	echo "$i $j"
}

list_ids()
{
	ls -1 /tmp/crashlogs/crash-* | sed -n 's/^.*crash-\(.*\).txt/\1/p' | sort -n -r
}

html_head()
{
	local crash_all=$( count_crashs )
	local crash_unreal="$( count_crashs_unreal )"
	set -- $crash_unreal
	local crash_sysrq=$1
	local crash_oom=$2

	local crash_real=$(( crash_all - crash_sysrq - crash_oom ))

	cat <<EOF
<html><head><title>crashlogs @ $( date "+%d.%b'%y-%H:%M" )</title></head><body>
<h3>OpenWrt crashlogs</h3>
<small>$crash_real real, $crash_sysrq manually invoked and $crash_oom by oom-killer = $crash_all crashs overall - omitting these revs: $LIST_OMIT_REV<br></small>
<br><tt>these crashs are part of an automatic crashdump-collection of several thousand OpenWrt-routers</tt>
<br><br>
<table cellspacing='1' cellpadding='1' border='1'>
EOF

	printf '%s' "<th>crash, time of apport</th>"

	printf '%s' "<th>size[bytes]</th>"

	printf '%s' "<th>time ago ~</th>"

	printf '%s' "<th> reason </td>"

	printf '%s' "<th> call_trace </th>"

	printf '%s' "<th> process </th>"

	printf '%s' "<th> hardware </th>"

	printf '%s' "<th>"
	printf '%s' "<a href='https://dev.openwrt.org/timeline?from=$( date +%m%%2f%d%%2f%y )&daysback=30&author=&changeset=on&update=Update'>"
	printf '%s' "revision</a>"
	printf '%s' "</th>"

	printf '%s' "<th><a href='https://dev.openwrt.org/wiki/platforms'>platform</a></th>"

	printf '%s' "<th>debug</th>"

	printf '%s' "<th>kernel</th>"
}

html_foot()
{
	local t1="$1"
	local t2 duration age_sec file unixtime_now unixtime_file

	read -r t2 _ </proc/uptime
	# dash cannot do this
	# duration=$(( ${t2//./} - ${t1//./} ))
	duration=$(( $( echo $t2 | sed 's/\.//' ) - $( echo $t1 | sed 's/\.//' ) ))
	for file in /tmp/crashlogs/crash-*; do :; done
	unixtime_file="$( date '+%s' -r "$file" )"
	unixtime_now="$(  date '+%s' )"
	age_sec=$(( unixtime_now - unixtime_file ))

	cat <<EOF
</table>
<br><b>note:</b><br>
getting a <a href='https://dev.openwrt.org/browser/trunk/target/linux/generic/patches-3.3/930-crashlog.patch'>crashlog</a> after reboot is possible since july 2012 with <a href='https://dev.openwrt.org/changeset/32787/trunk'>r32787</a><br>
all the magic is done by: <a href='https://github.com/bittorf/kalua/blob/master/openwrt-addons/etc/init.d/crashlog_apport'>crashlog_apport</a>
<br>overview generated in in $(( duration / 100 )).$(( duration % 100 )) sec, most recent crash is $age_sec seconds old.
</body></html>
EOF
}

seconds2humanreadable()
{
	local integer="$1"
	local humanreadable min sec hours days

	min=$(( integer / 60 ))
	sec=$(( integer % 60 ))

	if   [ $min -gt 1440 ]; then
		days=$(( min / 1440 ))
		min=$(( min % 1440 ))
		hours=$(( min / 60 ))
		min=$(( min % 60 ))
		humanreadable="${days}d ${hours}h ${min}min ${sec}sec"
	elif [ $min -gt 60 ]; then
		hours=$(( min / 60 ))
		min=$(( min % 60 ))
		humanreadable="${hours}h ${min}min ${sec}sec"
	else
		humanreadable="${min}min ${sec}sec"
	fi

	echo "$humanreadable"
}

call_trace()
{
	local file="$1"
	local start line

	while read -r line; do {
		case "${line}${start}" in
			*[0-9]"]1")
				break
			;;
		esac

		[ "$start" = "1" ] && {
			echo "$line" | cut -d' ' -f3 | cut -d'+' -f1
		}

		case "$line" in
			*"Call Trace:")
				start=1
			;;
		esac
	} done <"$file" | md5sum | cut -d' ' -f1 | cut -b 1-8
}

process_name()
{
	local file="$1"
	local line

	line="$( grep -F '] Process ' "$file" )" && {
		set -- $line
		while [ "$1" != "Process" ]; do shift; done
		echo $2

		return 0
	}

	line="$( grep -F ' invoked oom-killer: ' "$file" )" && {
		set -- $line
		while [ "$2" != "invoked" ]; do shift; done
		echo $1

		return 0
	}
}

hardware_type()
{
	local file="$1"

	head -n5 "$file" | tail -n1
}

html_tablecontent()
{
	local id revision platform file timediff vmlinux size reason uptime
	local unixtime_now="$( date +%s )"
	local unixtime_file
	local unixtime_midnight_today="$( date --date "$( date +%Y-%m-%d ) 00:00:00" +%s )"
	local linebreak i=1
	local tracehash bgcolor hint
	local kernel

	for id in $( list_ids ); do {
		file="/tmp/crashlogs/crash-${id}.txt"
#test "$id" = "1356093945" && logger -s "working $id"
		read -r revision <"$file"
		case "$revision" in
			r*)
				case "$LIST_OMIT_REV" in
					*"$revision"*)
						continue
					;;
				esac

				# FIXME! hardcoded
				[ "$( echo "$revision" | cut -b2- )" -lt 46425 ] && continue
			;;
			*)
				revision="?"
			;;
		esac

#		while read -r kernel kernel; do 

		unixtime_file="$( stat --printf %Y "$file" )"
		size="$( sed -n '6,999p' "$file" | strings | wc -c )"
		[ $size -lt 256 ] && {
			if [ $size -eq 0 ]; then
				continue
			else
				size="trash:$size"
			fi
		}

		if   grep -Fq "SysRq : Trigger a crash" "$file"; then
			# fixme!
			continue
			# fixme!

			reason="$( sed -n 's/^.* Process \(.*\) (pid: .*/\1/p' "$file" | head -n1 )"
			uptime="$( sed -n "s/^.*\[[ ]*\([0-9]*\)\..*\] Process $reason .*/\1/p" "$file" | head -n1 )"

			test $uptime -lt 80 && continue

			if [ $uptime -gt 129000 ]; then
				uptime="$(( uptime / 60 / 60 ))h"
			else
				uptime="$(( uptime / 60 ))min"
			fi

			reason="manual SysRq/$reason/$uptime"
		elif grep -Fq "invoked oom-killer:" "$file"; then
			reason="oom-killer"
			# fixme!
#			continue
			# fixme!
		elif grep -Fq 'Instruction bus error' "$file"; then
			reason='Instruction bus error'
		elif grep -Fq "Unable to handle kernel paging request at virtual address 00000000" "$file"; then
			reason="0ptr_deref"
		elif grep -Fq "Unhandled kernel unaligned access" "$file"; then
			reason="unaligned_access"
		elif grep -Fq "Unable to handle kernel paging request at virtual address" "$file"; then
			reason="kernel_paging_fuckup"
		elif grep -Fq "Reserved instruction in kernel code" "$file"; then
			reason="illegal Opcode"
		elif grep -Fq "do_cpu invoked from kernel context" "$file"; then
			reason="bad call to do_cpu()"
		elif grep -Fq "unaligned instruction access" "$file"; then
			reason="unaligned_instr_access"
		elif grep -Fq "SQUASHFS error:" "$file"; then
			reason="squashfs"
		elif grep -Fq "Kernel bug detected" "$file"; then
			reason="kernel_bug"
		elif grep -Fq "device closed unexpectedly" "$file"; then
			reason="watchdog"
		else
			reason="?"
			logger -s "unknown reason for id $id"
			# fixme!
#			continue
			# fixme!
		fi


		if   grep -Fq "ar71xx" "$file"; then
			platform="ar71xx"
		elif grep -Fq "TL-WR1043ND" "$file"; then
			platform="ar71xx"
		elif grep -Fq "Buffalo WHR-HP-G54" "$file"; then
			platform="brcm47xx"
		elif grep -Fq "Dell TrueMobile 2300" "$file"; then
			platform="brcm47xx"
		elif grep -Fq "Linksys WRT54G/GS/GL" "$file"; then
			platform="brcm47xx"
		else
			platform="?"
		fi

		timediff=$(( unixtime_now - unixtime_file ))
		timediff="$( seconds2humanreadable "$timediff" )"

		if [ -e "/var/www/crashlog/vmlinux.${platform}.${revision}.lzma" ]; then
			# kalua/openwrt-build/mybuild.sh apport_vmlinux
			vmlinux="<a href='vmlinux.${platform}.${revision}.lzma'>vmlinux.bin</a>"
		else
			vmlinux="-"
		fi

		[ $unixtime_file -lt $unixtime_midnight_today ] && {
			[ -z "$linebreak" ] && {
				[ $i -gt 1 ] && {
					linebreak="was already"
					echo "<tr bgcolor='lightyellow'><td colspan='11' align='center'><small>(midnight)</small></td></tr>"
				}
			}
		}

		bgcolor=
		hint=
		tracehash="$( call_trace "$file" )"
		case "$tracehash" in
			d41d8cd9)		# empty
				tracehash=
			;;
			0fe0baa7|ca992ba2)	# manual SysRq
				tracehash=
			;;
			b49ee163|e5d4949e|ada8211f|16792924|39f3e170|0626949e)	# ipt_do_table...
				bgcolor='lightblue'
				hint="ipt_do_table..."
			;;
			shit_happens)
				bgcolor='lightgreen'
				hint="give me a name"
			;;
		esac

		set -- $( head -n2 "$file" )
		kernel="$4"

		echo    "<tr><td><a href='?id=$id'>$( date -d @$id )</a></td>"
		printf '%s' "<td align='right'>$size</td><td align='right'>$timediff</td>"
		printf '%s' "<td align='center'>$reason</td><td title='$hint' bgcolor='$bgcolor'>$tracehash</td>"
		printf '%s' "<td>$( process_name "$file" )</td>"
		printf '%s' "<td>$( hardware_type "$file" )</td>"
		printf '%s' "<td>$revision</td><td>$platform</td>"
		printf '%s' "<td align='center'>$vmlinux</td>"
		printf '%s' "<td align='right'>$kernel</tr>"

		i=$(( i + 1 ))
	} done
}

logger -s "[START] $0"
html_head
html_tablecontent
html_foot "$t1"
logger -s "[READY] $0"

