#!/bin/sh
. /tmp/loader

log()
{
	logger -s -- "$1"
}

list_shellfunctions()
{
	local file="$1"
	local line

	# see https://github.com/koalaman/shellcheck/issues/529
	grep -s '^[ 	]*[a-zA-Z_][a-zA-Z0-9_]*[ ]*()' "$file" | cut -d'(' -f1 | while read line; do {
		echo "$line"
	} done
}

show_shellfunction_usage_count()
{
	local name="$1"		# e.g. '_olsr_txtinfo'
	local kalua_name
	local occurence_direct="$( git grep "$name" | wc -l )"
	local occurence_nested=0

	case "$name" in
		'_'*)
			without_first_underliner="${name#_}"		#  olsr_txtinfo

			if [ -e "openwrt-addons/etc/kalua/$without_first_underliner" ]; then
				kalua_name="$without_first_underliner"		# _random_username
			else
				kalua_name="_${without_first_underliner/_/ }"	# _olsr txtinfo
			fi

			occurence_nested="$( git grep "$kalua_name" | wc -l )"
			echo "$occurence_direct/$occurence_nested"
		;;
		*)
			echo "$occurence_direct"
		;;
	esac
}

show_shellfunction()
{
	local name="$1"
	local file="$2"
	local method i

	tabs() { for _ in $(seq $i); do printf '	'; done; }

	a() { grep ^"$name(){.*}"$ "$file"; }				# myfunc() { :;}	// very strict
	b() { sed -n "/^$name()/,/^}$/p"  "$file"; }			# myfunc()
	c() { sed -n "/^$name ()/,/^}$/p" "$file"; }			# myfunc ()
	d() { grep ^"$name()" "$file"; }				# myfunc() { :;}
	e() { grep ^"$name ()" "$file"; }				# myfunc () { :;}
	t() { sed -n "/^$( tabs )$name()/,/^$( tabs )}/p" "$file"; }	# 	myfunc()

	i=-5	# will be '1' at first 't' call
	for method in a b c d e t t t t t t t t t; do {
		i=$(( i + 1 ))
		$method | grep -q ^ && {	# any output?
			$method			# show it!
			return 0
		}
	} done

	log "[ERR] cannot find function '$name' in file '$file'"
	return 1
}

function_seems_generated()
{
	local file="$1"
	local name="$2"

	# TODO: define only the NOT functions: uci(),mv(),uci(),ip(),isnumber(),bool_true(),_()
	fgrep -q "\\$" "$file" && {
		case "$name" in
			'_weblogin_'*|'_system_'*|'_sanitizer_'*|'_olsr_'*|'_netfilter_'*|'_mail_'*)
				return 1
			;;
			'_help_'*|'_firmware_'*|'_file_'*|'_db_'*|'_wifi_'*)
				return 1
			;;
			'boot'|'func_cron_config_write'|'build_network_clients'|'build_package_mydesign')
				return 1
			;;
			'print_usage_and_exit'|'check_working_directory'|'apply_symbol'|'_config_dhcp'|'urlencode')
				return 1
			;;
			'login_ok'|'batalias_add_if_needed'|'ifname_from_dev'|'_copy_terms_of_use')
				return 1
			;;
		esac

		return 0
	}

	return 1
}

function_too_large()
{
	local name="$1"
	local file="$2"
	local file_origin="$3"
	local codelines
	local border=45		# bigger than 1 readable screen / lines
	local bloatlines=6	# dont count boilerplate code (see creating tempfile)

	codelines=$( wc -l <"$file" )
	codelines=$(( codelines - bloatlines ))

	[ $codelines -gt $border ] && {
		log "[attention] too large ($codelines lines) check: $name() from file '$file_origin'"
	}
}

function_too_wide()
{
	local name="$1"
	local file="$2"
	local file_origin="$3"
	local border=120	# http://richarddingwall.name/2008/05/31/is-the-80-character-line-limit-still-relevant/
	local max=0
	local i=0

	# automatically cuts off leading spaces/tabs:
	while read -r line; do {
		case "$line" in
			'#'*)
				# ignore comments
				continue
			;;
		esac

		test ${#line} -gt $border && {
			i=$(( i + 1 ))
			test ${#line} -gt $max && max=${#line}
		}
	} done <"$file"

	[ $i -gt 0 ] && {
		log "[attention] too wide (>$border chars in $i lines, max $max) in $name() from file '$file_origin'"
	}
}

do_sloccount()
{
	local line

	if command -v sloccount >/dev/null; then
		echo
		log "sloccount: counting lines of code:"

		sloccount . | while read -r line; do {
			case "$line" in
				[0-9]*|*'%)'|*'):'|*' = '*|'SLOC '*)
					# only show interesting lines
					echo "$line"
				;;
			esac
		} done
	else
		log '[OK] sloccount not installed'
	fi
}

test_division_by_zero_is_protected()
{
	log "test ocurence of possible unprotected division by 0"

	git grep ' / [^0-9]' | fgrep '$(( ' | grep -v 'divisor_valid' | grep ^'openwrt-addons' && return 1
	git grep ' % [^0-9]' | fgrep '$(( ' | grep -v 'divisor_valid' | grep ^'openwrt-addons' && return 1

	git grep ' / [^0-9]' | fgrep '$(( ' | grep -v 'divisor_valid' | grep  'apply_profile' && return 1
	git grep ' % [^0-9]' | fgrep '$(( ' | grep -v 'divisor_valid' | grep  'apply_profile' && return 1

	return 0
}

test_divisor_valid()
{
	log 'testing divisor_valid()'
	set -x

	divisor_valid && return 1
	divisor_valid '' && return 1
	divisor_valid '0' && return 1
	divisor_valid '-0' && return 1
	divisor_valid 'a' && return 1
	divisor_valid '0.1' && return 1

	divisor_valid '-1' || return 1
	divisor_valid '1' || return 1

	set +x
	return 0
}

test_isnumber()
{
	log 'testing isnumber()'
	set -x

	isnumber '-1' || return 1
	isnumber $((  65536 * 65536 )) || return 1
	isnumber $(( -65536 * 65536 )) || return 1

	isnumber 'A' && return 1
	isnumber && return 1
	isnumber ''  && return 1
	isnumber ' ' && return 1
	isnumber '1.34' && return 1

	set +x
	return 0
}

test_explode()
{
	log 'testing explode-alias (also with asterisk)'

	mkdir "$TMPDIR/explode_test"
	cd "$TMPDIR/explode_test" || return
	touch 'foo1'		# files which will expand during globbing
	touch 'foo2'

	alias explode		# just show it

	set -x
	explode A B ./* C	# this must not glob
	set +x

	[ "$1" = 'A' -a "$4" = 'C' -a "$3" = './*' ] || {
		log "explode failed: '$1', '$4', '$3'"
		return 1
	}

	cd - >/dev/null || return
	rm -fR "$TMPDIR/explode_test"
	return 0
}

test_loader_metafunction()
{
	log "test loader_metafunction _()"
	# via _() we have some possible calls:

	# show methods (both the same output)
	# must show all lines with beginning function name
	_http | grep -v ^'_http_' && return 1
	_ s 'system' | grep -v ^'_system_' && return 1

	# test if function with unloaded class is loaded and 2 arguments are passed
	local out
	out="$( _system load 15min full )"
	isnumber "$out" && return 1
	out="$( _system load 15min )"
	isnumber "$out" || return 1

	# test if 'include only' works
	_system include
	# busybox/dash: _system_crashreboot is a shell function
	# bash: _system_crashreboot is a function
	out="$( LC_ALL=C type '_system_crashreboot' )"
	# avoid broken pipe: http://superuser.com/questions/554855/how-can-i-fix-a-broken-pipe-error
	echo "$out" | grep -q ' function' || return 1

	# test if 'rebuild' works (changed date-string in file)
	local hash1="$( md5sum '/tmp/loader' )"
	_ rebuild
	local hash2="$( md5sum '/tmp/loader' )"
	test "$hash1" = "$hash2" && return 1

	# test if loader is loaded 8-)
	_ t || return 1

	# list classes
	test $( _ | wc -l ) -gt 10
}

run_test()
{
	local shellcheck_bin start_test build_loader ignore file tempfile filelist pattern ip
	local hash1 hash2 size1 size2 line line_stripped i list name
	local func_too_large=0
	local func_too_wide=0
	local count_files=0
	local count_functions=0
	local good='true'
	local tab='	'

	log "echo '\$HARDWARE' + '\$SHELL' + '\$USER' + diskspace"
	echo "'$HARDWARE' + '$SHELL' + '$USER'"
	df

	test_isnumber || return 1
	test_divisor_valid || return 1
	test_explode || return 1
	test_loader_metafunction || return 1
	test_division_by_zero_is_protected || return 1

	log 'testing firmware get_usecase'
	echo 'Standard,debug,VDS,OLSRd2,kalua@41eba50,FeatureXY' >"$TMPDIR/test"
	[ "$( _firmware get_usecase '' "$TMPDIR/test" )" = 'Standard,debug,VDS,OLSRd2,kalua,FeatureXY' ] || return 1
	rm "$TMPDIR/test"

	log 'building/testing initial NETPARAM'
	openwrt-addons/etc/init.d/S41build_static_netparam call
	if [ -e "$TMPDIR/NETPARAM" ]; then
		# should at least have _some_ filled vars
		if grep -qv '='$ "$TMPDIR/NETPARAM"; then
			grep -v '='$ "$TMPDIR/NETPARAM"
		else
			return 1
		fi
	else
		return 1
	fi

	log '_net get_external_ip'
	_net get_external_ip

	log '_net my_isp'
	_net my_isp

	log "list=\"\$( ls -1R . )\""
	list="$( ls -1R . )"

	log "_list count_elements \"\$list\""
	_list count_elements "$list" || return 1
	isnumber "$( _list count_elements "$list" )" || return 1

	log "_list random_element \"\$list\""
	_list random_element "$list" || return 1

	log "_system architecture"
	_system architecture || return 1

	log "_system ram_free"
	_system ram_free || return 1
	isnumber "$( _system ram_free )" || return 1

	log '_filetype detect_mimetype /tmp/loader'
	_filetype shellscript /tmp/loader || return 1
	_filetype detect_mimetype /tmp/loader || return 1
	[ "$( _filetype detect_mimetype '/tmp/loader' )" = 'text/x-shellscript' ] || return 1

	log '_system load 1min full ; _system load'
	_system load 1min full || return 1
	_system load || return 1

	tempfile='/dev/shm/testfile'
	shellcheck_bin="$( command -v shellcheck )"
	[ -e ~/.cabal/bin/shellcheck ] && shellcheck_bin=~/.cabal/bin/shellcheck

	ip="$( _net get_external_ip )"
	log "_weblogin htmlout_loginpage | ip=$ip"	# omit 2 lines header:
	_weblogin htmlout_loginpage '' '' '' '' "http://$ip" '(cache)' | tail -n+3 >"$tempfile"

	if [ -z "$shellcheck_bin" ]; then
		log "[OK] shellcheck not installed - no deeper tests"
	else
		$shellcheck_bin --version
		# SC1091: Not following: /tmp/loader was not specified as input (see shellcheck -x).
		# SC1090: Can't follow non-constant source. Use a directive to specify location.
		#
		# SC2016: echp '$a' => Expressions don't expand in single quotes, use double quotes for that.
		# SC2029: ssh "$serv" "command '$server_dir'" => Note that, unescaped, this expands on the client side.
		# SC2031: FIXME! ...in net_local_inet_offer()
		# SC2039: In POSIX sh, echo flags are not supported.
		#  SC2039: In POSIX sh, string replacement is not supported.
		#  SC2039: In POSIX sh, 'let' is not supported.
		#  SC2039: In POSIX sh, 'local' is not supported. -> we need another SCxy for that
# TODO #		# SC2046: eval $( _http query_string_sanitize ) Quote this to prevent word splitting.
		# SC2086: ${CONTENT_LENGTH:-0} Double quote to prevent globbing and word splitting.
		#  - https://github.com/koalaman/shellcheck/issues/480#issuecomment-144514791
		# SC2155: local var="$( bla )" -> loosing returncode
		#  - https://github.com/koalaman/shellcheck/issues/262
# TODO #		# SC2166: Prefer [ p ] && [ q ] as [ p -a q ] is not well defined.

		shellsheck_ignore()
		{
			printf 'SC1090,SC1091,'
			printf 'SC2016,SC2029,SC2031,SC2039,SC2046,SC2086,SC2155,SC2166'
		}

		log "testing with '$shellcheck_bin', ignoring: $( shellsheck_ignore )"

		filelist='/dev/shm/filelist'
		# collect all shellscripts:
		find  >"$filelist" 'openwrt-addons' 'openwrt-build' 'openwrt-monitoring' -type f -not -iwholename '*.git*'
		echo >>"$filelist" '/tmp/loader'

		$shellcheck_bin --help 2>"$tempfile"
		grep -q 'external-sources' "$tempfile" && shellcheck_bin="$shellcheck_bin --external-sources"
		log "[OK] shellcheck call: $shellcheck_bin ..."

		while read -r file; do {
			case "$file" in
				'openwrt-build/mybuild.sh'|'openwrt-monitoring/meshrdf_generate_table.sh')
					log "[OK] ignoring '$file' - deprecated/unused/too_buggy"
					continue
				;;
				'openwrt-monitoring/'*)
					ignore="$( shellsheck_ignore ),SC2010,SC2012,SC2034,SC2044,SC2045,SC2062"
				;;
				'openwrt-build/apply_profile.code.definitions'|'openwrt-build/build.sh')
					# SC2034: VAR appears unused. Verify it or export it
					ignore="$( shellsheck_ignore ),SC2034"
				;;
				'/tmp/loader')
					# SC2015: Note that A && B || C is not if-then-else....
					# SC2034: VAR appears unused. Verify it or export it
					ignore="$( shellsheck_ignore ),SC2015,SC2034"
				;;
				*)
					ignore="$( shellsheck_ignore )"
				;;
			esac

			case "$( _filetype detect_mimetype "$file" )" in
				'text/x-shellscript')
					tr -cd '\11\12\15\40-\176' <"$file" >"$tempfile"
					hash1="$( md5sum <"$tempfile" | cut -d' ' -f1 )"
					size1="$( wc -c <"$tempfile" )"
					cp "$file" "$tempfile"
					hash2="$( md5sum <"$tempfile" | cut -d' ' -f1 )"
					size2="$( wc -c <"$tempfile" )"
					[ "$hash1" = "$hash2" ] || {
						log "[ERR] non-ascii chars in '$file', sizes: $size1/$size2"

						i=0
						while read -r line; do {
							i=$(( i + 1 ))
							size1=${#line}
							line_stripped="$( echo "$line" | tr -cd '\11\12\15\40-\176' )"
							size2=${#line_stripped}
							[ $size1 -eq $size2 ] || {
								echo "line $i: $size1 bytes: original: $line"
								echo "line $i: $size2 bytes: stripped: $line_stripped"
								echo "$line" | hexdump -C
							}
						} done <"$tempfile"
					}

					# SC2039: https://github.com/koalaman/shellcheck/issues/354
#						sed -i 's/echo -n /printf /g' "$tempfile"
#						sed -i 's/echo -en /printf /g' "$tempfile"

					case "$file" in
						# otherwise we get https://github.com/koalaman/shellcheck/wiki/SC2034
						'openwrt-addons/etc/init.d/'*|'openwrt-build/apply_profile'*)
							# otherwise we get https://github.com/koalaman/shellcheck/wiki/SC2034
							sed -i '/^START=/d' "$tempfile"
							sed -i '/^EXTRA_COMMANDS=/d' "$tempfile"
						;;
						'openwrt-addons/etc/kalua/scheduler')
							# otherwise we get https://github.com/koalaman/shellcheck/wiki/SC2034
							sed -i '/^PID=/d' "$tempfile"
							sed -i '/^SCHEDULER/d' "$tempfile"
						;;
						'openwrt-addons/etc/kalua/mail')
							# strip non-ascii chars, otherwise the parser can fail with
							# openwrt-addons/etc/kalua/mail: hGetContents: invalid argument (invalid byte sequence)
							tr -cd '\11\12\15\40-\176' <"$file" >"$tempfile"
						;;
					esac

					if $shellcheck_bin --exclude="$ignore" "$tempfile"; then
						log "[OK] shellcheck: '$file'"
					else
						log "[ERROR] try $shellcheck_bin -e $ignore '$file'"
						good='false'
					fi

					count_files=$(( count_files + 1 ))
				;;
				*)
					log "[IGNORE] non-shellfile '$file'"
					continue
				;;
			esac


			# TODO: run each function and check if we leak env vars
			# TODO: check if each function call '_class method' is allowed/possible
			for name in $( list_shellfunctions "$file" ); do {
				{
					echo '#!/bin/sh'
					echo '. /tmp/loader'
					echo

					if show_shellfunction "$name" "$file" | head -n1 | grep -q ^"[ $tab]"; then
						echo "# nested function from file '$file'"
						ignore="$ignore,SC2154"		# VAR is referenced but not assigned
						ignore="$ignore,SC2034"		# VAR appears unused. Verify it or export it.
					else
						echo "# from file '$file'"
					fi

					show_shellfunction "$name" "$file" || return 1

					echo
					echo "$name \"\$@\""
				} >"$tempfile"

				function_too_large "$name" "$tempfile" "$file" && func_too_large=$(( func_too_large + 1 ))
				function_too_wide  "$name" "$tempfile" "$file" && func_too_wide=$(( func_too_wide + 1 ))
				# TODO: test if file to wide

				if   function_seems_generated "$tempfile" "$name"; then
					log "[OK] --> function '$name()' - will not check, seems to be generated"
				elif $shellcheck_bin --exclude="$ignore" "$tempfile"; then
					log "[OK] --> function '$name()' used: $( show_shellfunction_usage_count "$name" ) times"
				else
					log "[ERROR] try $shellcheck_bin -e $ignore '$file' -> $name()"
					good='false'

					# debug
					grep -q 'EOF' "$tempfile" && hexdump -C "$tempfile" | grep 'EOF'

					echo '### start'
					grep -n ^ "$tempfile"
					echo '### end'
				fi

				count_functions=$(( count_functions + 1 ))
			} done

			rm "$tempfile"
		} done <"$filelist"
		rm "$filelist"

		log "[OK] checked $count_files shellfiles with $count_functions functions"
		log "[OK] hint: $func_too_large/$count_functions functions ($(( (func_too_large * 100) / count_functions ))%) are too large"
		log "[OK] hint: $func_too_wide/$count_functions functions ($(( (func_too_wide * 100) / count_functions ))%) are too wide"
		[ "$good" = 'false' ] && return 1
	fi

	do_sloccount

	log 'cleanup'
	rm -fR /tmp/loader /tmp/kalua "$TMPDIR/NETPARAM"

	log '[READY]'
}

[ -n "$1" ] && run_test
