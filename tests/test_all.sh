#!/bin/sh
. /tmp/loader

# find too wide functions/files with:
# i=0; while read -r L; do i=$(( i + 1 )); test ${#L} -gt 120 && echo "$i: $L"; done <$FILE

log()
{
	logger -s -- "$1"
}

list_shellfunctions()
{
	local file="$1"
	local line

	# see https://github.com/koalaman/shellcheck/issues/529
	grep -s '^[ 	]*[a-zA-Z_][a-zA-Z0-9_]*[ ]*()' "$file" | cut -d'(' -f1 | while read -r line; do {
		echo "$line"
	} done
}

show_shellfunction_usage_count()
{
	local name="$1"		# e.g. '_olsr_txtinfo'
	local kalua_name
	local occurrence_direct="$( git grep "$name" | wc -l )"
	local occurrence_nested=0

	case "$name" in
		'_'*)
			without_first_underliner="${name#_}"		#  olsr_txtinfo

			if [ -e "openwrt-addons/etc/kalua/$without_first_underliner" ]; then
				kalua_name="$without_first_underliner"		# _random_username
			else
				kalua_name="_${without_first_underliner/_/ }"	# _olsr txtinfo
			fi

			occurrence_nested="$( git grep "$kalua_name" | wc -l )"
			echo "$occurrence_direct/$occurrence_nested"
		;;
		*)
			echo "$occurrence_direct"
		;;
	esac
}

show_shellfunction()
{
	local name="$1"
	local file="$2"
	local method i
	local tab='	'

#	spaces() { for _ in $( seq ${1:-$i} ); do printf '%s ' ' '; done; }
#	tabs() { for _ in $( seq ${1:-$i} ); do printf '%s ' "$tab"; done; }
	tabs() { for _ in $( seq $i ); do printf '%s ' "$tab"; done; }

	# led_on()  { echo '255' >"$file"; }
	_a() { grep ^"$name(){.*}"$ "$file"; }				# myfunc(){ :;}		// very strict
	_b() { grep ^"$name() {.*}"$ "$file"; }				# myfunc() { :;}	// very strict
	_c() { grep ^"$name()  {.*}"$ "$file"; }			# myfunc()  { :;}	// very strict
	_d() { sed -n "/^$name()/,/^}$/p"  "$file"; }			# myfunc()
	_e() { sed -n "/^$name ()/,/^}$/p" "$file"; }			# myfunc ()
	_f() { grep ^"$name()" "$file"; }				# myfunc() { :;}
	_g() { grep ^"$name ()" "$file"; }				# myfunc () { :;}
	_t() { sed -n "/^$( tabs )$name()/,/^$( tabs )}/p" "$file"; }	# myfunc()

	for method in a b c d e f g XXX t t t t t t t t t; do {
		if [ "$method" = 'XXX' ]; then
			i=0	# for tabs()
		else
			i=$(( i + 1 ))

			_$method | grep -q ^ && {	# any output?
				_$method		# show it!
				return 0
			}
		fi
	} done

	log "[ERR] cannot find function '$name' in file '$file'"
	return 1
}

function_seems_generated()
{
	local file="$1"
	local name="$2"

	show_shellfunction "$name" "$file" >/dev/null && {
		case "$name" in
			'copy_terms_of_use'|'generate_script'|'apply_settings'|'hostname'|'essid')
			;;
			'mytc'|'ipt'|'uci'|'mv'|'ip'|'isnumber'|'bool_true'|'_')
				# generated testfile:
				grep -q ^"# from file 'openwrt-addons/etc/kalua_init" "$file" || {
					# but needs testing in '/tmp/loader'
					return 1
				}
			;;
			'output_udhcpc_script')
				# we test the output later
			;;
			*)
				return 1
			;;
		esac

		return 0
	}
}

function_too_large()
{
	local name="$1"
	local file="$2"
	local file_origin="$3"
	local codelines
	local border=45		# bigger than 1 readable screen / lines
	local bloatlines=6	# do not count boilerplate code (see creating tempfile)

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
			'#'*)	# ignore comments
			;;
			*)
				test ${#line} -gt $border && {
					i=$(( i + 1 ))
					test ${#line} -gt $max && max=${#line}
				}
			;;
		esac
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

	# test if 'rebuild' works (changed date-string in file - only 1 second accurate)
	sleep 1
	local hash1="$( md5sum '/tmp/loader' )"
	[ "$( id -u )" -eq 0 ] || {
		log "[ERROR] USER: '$USER' workaround needed sudo: $( ls -l '/tmp/loader' )"
		sudo chown $USER:$USER '/tmp/loader'
		log "[ERROR] see file permisions: $( ls -l /kalua/loader )"
		sudo chmod 0777 '/tmp/loader'
	}
	_ rebuild 'autotest'
	local hash2="$( md5sum '/tmp/loader' )"
	test "$hash1" = "$hash2" && {
		log "[ERROR] loader-hash did not changed during rebuild: $hash1"
		return 1
	}

	# test if loader is loaded 8-)
	_ t || return 1

	# list classes
	if [ $( _ | wc -l ) -gt 10 ]; then
		:
	else
		log "[ERROR] too few classes:"
		_

		return 1
	fi
}

run_test()
{
	local shellcheck_bin ignore file tempfile filelist ip hash1 hash2
	local codespell_bin size1 size2 line line_stripped i list name
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
	_netparam check
	if [ -e "$TMPDIR/NETPARAM" ]; then
		if grep -qv '='$ "$TMPDIR/NETPARAM"; then
			# show good vars
			grep -v '='$ "$TMPDIR/NETPARAM"
		else
			log "missing at least 1 filled vars in '$TMPDIR/NETPARAM'"
			cat "$TMPDIR/NETPARAM"
			return 1
		fi
	else
		log "missing '$TMPDIR/NETPARAM'"
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
# TODO #	# SC2039: In POSIX sh, echo flags are not supported.
		#  SC2039: In POSIX sh, string replacement is not supported.
		#  SC2039: In POSIX sh, 'let' is not supported.
		#  SC2039: In POSIX sh, 'local' is not supported. -> we need another SCxy for that
		#  SC2039: In POSIX sh, 'shopt' is undefined.
		#  SC2039: In POSIX sh, string indexing is undefined	  -> ${wmac:0:2}
		#  SC2039: In POSIX sh, string replacement is undefined.  -> ${1//,/.}"		// ',' -> '.'
		#  SC2039: In POSIX sh, ulimit -c is undefined.
		#  SC2039: In POSIX sh, HOSTNAME is undefined.
# TODO #		# SC2046: eval $( _http query_string_sanitize ) Quote this to prevent word splitting.
		# SC2086: ${CONTENT_LENGTH:-0} Double quote to prevent globbing and word splitting.
		#  - https://github.com/koalaman/shellcheck/issues/480#issuecomment-144514791
		# SC2155: local var="$( bla )" -> losing returncode
		#  - https://github.com/koalaman/shellcheck/issues/262
# TODO #		# SC2166: Prefer [ p ] && [ q ] as [ p -a q ] is not well defined.

		shellsheck_ignore()
		{
			printf 'SC1090,SC1091,'
			printf 'SC2016,SC2029,SC2031,SC2046,SC2086,SC2155,SC2166,SC2039'
		}

		log "testing with '$shellcheck_bin', ignoring: $( shellsheck_ignore )"
		filelist='/dev/shm/filelist'

		# first entry:
		echo >"$filelist" '/tmp/loader'

		mkdir -p '/dev/shm/generated_files'
		. openwrt-addons/etc/init.d/S51crond_fff+ >/dev/null
		file='/dev/shm/generated_files/output_udhcpc_script'
		output_udhcpc_script >"$file"
		echo >>"$filelist" "$file"

		ip="$( _net get_external_ip )"
		log "_weblogin htmlout_loginpage | ip=$ip"	# omit 2 lines header:
		file='/dev/shm/generated_files/weblogin_htmlout_loginpage'
		_weblogin htmlout_loginpage '' '' '' '' "http://$ip" '(cache)' | tail -n+3 >"$file"
		echo >>"$filelist" "$file"

		# collect all shellscripts:
		find >>"$filelist" 'tests' 'openwrt-addons' 'openwrt-build' 'openwrt-monitoring' -type f -not -iwholename '*.git*'

		$shellcheck_bin --help 2>"$tempfile"
		grep -q 'external-sources' "$tempfile" && shellcheck_bin="$shellcheck_bin --external-sources"
		log "[OK] shellcheck call: $shellcheck_bin ..."

		while read -r file; do {
			case "$file" in
				'openwrt-build/mybuild.sh')
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
					# strip non-printable (ascii-subset)
					tr -cd '\11\12\15\40-\176' <"$file" >"$tempfile"

					hash1="$( md5sum <"$tempfile" | cut -d' ' -f1 )"
					size1="$( wc -c <"$tempfile" )"
					cp "$file" "$tempfile"
					hash2="$( md5sum <"$tempfile" | cut -d' ' -f1 )"
					size2="$( wc -c <"$tempfile" )"

					# compare normal/stripped
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
#					sed -i 's/echo -n /printf /g' "$tempfile"		# do not use echo flags
#					sed -i 's/echo -en /printf /g' "$tempfile"		# dito
#					sed -i 's/local \([a-zA-Z]\)/\1/g' "$tempfile"		# do not use 'local $var'
#					sed -i 's/.*shopt.*/# &/g' "$tempfile"

					# SC2119/SC2120 - references arguments, but non are ever passed:
					sed -i 's/explode $/set -f;set +f -- $/g' "$tempfile"

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

						case "$file" in
							'openwrt-monitoring/meshrdf_generate_table.sh')
							;;
							*)
								good='false'
							;;
						esac
					fi

					count_files=$(( count_files + 1 ))

					if command -v codespell.py; then
						case "$file" in
							*'random_username')
#								codespell_bin="codespell.py --dictionary='$tempfile.dict'"
								codespell_bin='codespell.py'
#								echo 'churchs->churches, disabled: is a shoebrand' >"$tempfile.dict"
								sed -i 's/churchs/churches/g' "$tempfile"
							;;
							*)
								codespell_bin='codespell.py'
#								[ -e "$tempfile.dict" ] && rm -f "$tempfile.dict"
							;;
						esac

						# https://github.com/lucasdemarchi/codespell/issues/63
						if $codespell_bin "$tempfile" | wc -l | xargs test 0 -eq; then
							log "[OK] codespell.py '$file'"
						else
							log "[ERROR] try: codespell.py '$file'"
							codespell.py "$file"
							good='false'
						fi
					else
						log "[OK] no spellcheck - please install 'https://github.com/lucasdemarchi/codespell'"
					fi
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
						# TODO: do not double set
						echo "# nested function from file '$file'"
						ignore="$ignore,SC2154"		# VAR is referenced but not assigned
						ignore="$ignore,SC2034"		# VAR appears unused. Verify it or export it.
					else
						echo "# from file '$file'"
					fi

					show_shellfunction "$name" "$file" || return 1

					echo

					# otherwise we get SC2119
					if   show_shellfunction "$name" "$file" | fgrep -q "\$1"; then
						echo "$name \"\$@\""	# ...with args
					elif show_shellfunction "$name" "$file" | fgrep -q "\${1"; then
						echo "$name \"\$@\""	# ...with args
					elif show_shellfunction "$name" "$file" | fgrep -q "\$@"; then
						echo "$name \"\$@\""	# ...with args
					else
						echo "$name"		# call function without args
					fi
				} >"$tempfile"

				function_too_large "$name" "$tempfile" "$file" && func_too_large=$(( func_too_large + 1 ))
				function_too_wide  "$name" "$tempfile" "$file" && func_too_wide=$(( func_too_wide + 1 ))
				# TODO: test if file to wide

				# SC2039: https://github.com/koalaman/shellcheck/issues/354
#				sed -i 's/echo -n /printf /g' "$tempfile"		# do not use echo flags
#				sed -i 's/echo -en /printf /g' "$tempfile"		# dito
#				sed -i 's/local \([a-zA-Z]\)/\1/g' "$tempfile"		# do not use 'local $var'
#				sed -i 's/.*shopt.*/# &/g' "$tempfile"

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
		rm -fR '/dev/shm/generated_files'

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
