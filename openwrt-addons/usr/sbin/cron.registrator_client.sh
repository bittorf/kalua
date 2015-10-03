#!/bin/sh
. /tmp/loader
. /usr/share/libubox/jshn.sh

OPTION="$1"
[ "$OPTION" = 'show_next_free' ] || unset OPTION	# only for debug

NETWORK="${CONFIG_PROFILE%_*}"
case "$NETWORK" in
	# share same IP-space
	'ffweimar'|'liszt28'|'paltstadt'|'ilm1')
		NETWORK='ffweimar'
	;;
	*)
		return 0
	;;
esac

URL_BASE='http://reg.weimarnetz.de'
PASS="$( _ssh key_public_fingerprint_get )"
PASS="$( _sanitizer do "$PASS" urlvalue )"

if [ -e '/www/monitoring.wifimac' ]; then
	read MAC <'/www/monitoring.wifimac'
else
	MAC="$( _net dev2mac "$WIFIDEV" )"
	MAC="$( _sanitizer do "$MAC" urlvalue )"
fi

if [ "$( _ipsystem getvar 'NODE_NUMBER_RANDOM' )" = 'false' -a -z "$OPTION" ]; then

	# API call is: Send an 'Update' for our NODENUMBER, with MAC and PASS.
	# - if the NODENUMBER did not exist, it will be created with the supplied data
	# - if the NODENUMBER did exist,
	#     - and the PASS did not match: Error
	#     - and PASS did match: Success (and extension of lease in registrator)
	URL="$URL_BASE/PUT/$NETWORK/knoten/$NODENUMBER?mac=${MAC}&pass=${PASS}"
	HTTP_ANSWER="$( _wget do "$URL" 30 )"

	# call API and convert JSON answer to shell variables
	# answer e.g.:
	# {
	#  "status": 200,
	#  "message": "updated",
	#  "result": {
	#    "number": 261,
	#    "mac": "106f3f0e318e",
	#    "last_seen": 1395749203533,
	#    "network": "ffweimar",
	#    "location": "/ffweimar/knoten/261"
	#  }
	# }
	#
	# or:
	#
	# {
	#  "status": 201,
	#  "message": "Created!",
	#  "result": {
	#    "number": 269,
	#    "mac": "6466b3ded9d7",
	#    "last_seen": 1395752262820,
	#    "network": "ffweimar",
	#    "location": "/ffweimar/knoten/269"
	#  }
	# }

	JSON_VAR_status=;JSON_VAR_message=
	json_load "$HTTP_ANSWER"
	json_get_var 'JSON_VAR_status' 'status'
	json_get_var 'JSON_VAR_message' 'message'

	# check if we've got HTTP Status 401 'Not Authorized'
	case "$JSON_VAR_status" in
		'401')
			# {
			#   "status": 401,
			#   "msg": "Unauthorized!",
			#   "result": "Wrong $PASS"
			# }

			# TODO: resetting the number here would auto-recover lost passwords
			#       and assign new NODENUMBER on next try. like this:
			#	uci delete system.@profile[0].nodenumber
			_log do registrator daemon alert "[ERR] somebody has your number '$NODENUMBER' or your pass/sshkey-fingerprint has changed"

			# API call is: Send a 'Create', with MAC and PASS.
			# - successful answer *always* contains our NODENUMBER
			# - if a new NODENUMBER was registered for us, status is 201 Created
			# - if a NODENUMBER with same MAC already existed, status is 303 Redirect
			URL="$URL_BASE/POST/$NETWORK/knoten?mac=${MAC}&pass=${PASS}"
			HTTP_ANSWER="$( _wget do "$URL" 30 )"

			# call API and convert JSON answer to shell variables
			#
			# {
			#   "status": 404,
			#   "msg": "Not Found!",
			#   "result": "Network liszt28 not found!"
			# }
			#
			# {
			#   "status": 303,
			#   "msg": "MAC already registered!",
			#   "result": {
			#     "number": 808,
			#     "mac": "00049fef0101",
			#     "last_seen": 1414295261121,
			#     "network": "ffweimar",
			#     "location": "/ffweimar/knoten/808"
			#   }
			# }
			#
			# {
			#   "status": 201,
			#   "message": "Created!",
			#   "result": {
			#     "number": 4,
			#     "mac": "345678123499",
			#     "last_seen": 1417554501131,
			#     "network": "ffweimar",
			#     "location": "/ffweimar/knoten/4"
			#   }
			# }

			JSON_VAR_status=;JSON_VAR_message=;JSON_VAR_result_number=
			json_load "$HTTP_ANSWER"
			json_get_var 'JSON_VAR_status' 'status'
			json_get_var 'JSON_VAR_message' 'message'
			json_get_var 'JSON_VAR_result_number' 'number'

			# if the status is >400, there was some kind of error
			if test "${JSON_VAR_status:-0}" -lt 400 2>/dev/null; then
				# check if the answer contains a NODENUMBER
				if test "$JSON_VAR_result_number" -gt 1 -a "$JSON_VAR_result_number" != "$NODENUMBER" 2>/dev/null; then
					_log do registrator daemon alert "[OK] new nodenumber: '$JSON_VAR_result_number'"
					# check with `_ipsystem` if it is a *valid* NODENUMBER
					if _ipsystem do "$JSON_VAR_result_number" >/dev/null ; then
						# TODO: does one of these already save the number to uci ???
						NETWORK="$( echo "$CONFIG_PROFILE" | cut -d'_' -f1 )"
						MODE="$( echo "$CONFIG_PROFILE" | cut -d'_' -f2 )"
						/etc/init.d/apply_profile.code "$NETWORK" "$MODE" "$JSON_VAR_result_number"
					else
						_log do error daemon info "nodenumber invalid: '$JSON_VAR_result_number'"
					fi
				else
					_log do error daemon info "new number invalid: '$JSON_VAR_result_number'"
				fi
			else
				_log do error daemon info "message: '$JSON_VAR_message'"
			fi
		;;
		'201')
			_log do heartbeat daemon alert "OK: HTTP-Status: '$JSON_VAR_status' -> '$JSON_VAR_message'"
			_log do heartbeat daemon alert "OK: HTTP-Answer: '$HTTP_ANSWER'"
		;;
		'200')
			_log do heartbeat daemon info 'OK'
		;;
		*)
			_log do heartbeat daemon alert "[ERR] HTTP-Status: '$JSON_VAR_status' -> '$JSON_VAR_message'"
			_log do heartbeat daemon alert "[ERR] HTTP-Answer: '$HTTP_ANSWER'"
		;;
	esac

	# cleanup env-space
	unset HTTP_ANSWER
	json_cleanup
else
	[ "$OPTION" = 'show_next_free' ] || return 0

	# FIXME! ask with wrong ssh-key
	URL="http://reg.weimarnetz.de/$NETWORK/list"
	FILE="/tmp/LIST_NODES_REGISTRATED"
	_wget do "$URL" >"$FILE"

	# fully loaded? JSON must be closed correctly:
	if [ "$( tail -n1 "$FILE" )" = '}' ]; then
		NODENUMBER_TRY=290	# fixme! hardcoded, till we have this function in the API
		NODENUMBER_MAX=969	# fixme! see ipsystem_ffweimar() every ipsystem() should implement this var
		NODENUMBER_NEW=

		# ...
		# {
		#    "number": 10,
		#    "created_at": 1370952204310,
		#    "last_seen": 1370952204310
		# },
		# ...

		while [ $NODENUMBER_TRY -lt $NODENUMBER_MAX ]; do {
			if fgrep -q "\"number\": $NODENUMBER_TRY," "$FILE"; then
				NODENUMBER_TRY=$(( NODENUMBER_TRY + 1 ))
			else
				NODENUMBER_NEW="$NODENUMBER_TRY"
				break
			fi
		} done
		rm "$FILE"

		if [ "$OPTION" = 'show_next_free' ]; then
			_log do request_nodenumber daemon info "next free nodenumber is '$NODENUMBER_NEW'"
		else
			if [ -n "$NODENUMBER_NEW" ]; then
				_log do request_nodenumber daemon alert "apply new nodenumber '$NODENUMBER_NEW'"

				NETWORK="${CONFIG_PROFILE%_*}"
				MODE="${CONFIG_PROFILE#*_}"
				/etc/init.d/apply_profile.code "$NETWORK" "$MODE" "$NODENUMBER_NEW"
			else
				_log do request_nodenumber daemon info "could not get new nodenumber"
			fi
		fi
	else
		_log do load_reglist daemon info "[ERR] invalid download from '$URL' to '$FILE'"
	fi
fi
