#!/bin/sh
. /tmp/loader
. /usr/share/libubox/jshn.sh

URL_BASE="http://reg.weimarnetz.de"

MAC="$( _net dev2mac $WIFIDEV )"
MAC="$( _sanitizer do "$MAC" urlvalue )"
PASS="$( _ssh key_public_fingerprint_get )"
PASS="$( _sanitizer do "$PASS" urlvalue )"
NETWORK="$( echo "$CONFIG_PROFILE" | cut -d'_' -f1 )"
[ "$NETWORK" = 'liszt28' ] && NETWORK='ffweimar'

# try to get existing nodenumber from config
NODENUMBER="$( uci get system.@profile[0].nodenumber )"

# get the config for "NODE_NUMBER_RANDOM"
eval $( _ipsystem do "$NODENUMBER" | grep ^"NODE_NUMBER_RANDOM=" )

# only if RANDOM is set to false, …
[ "$NODE_NUMBER_RANDOM" = "false" ] && {

	# API call is: Send an 'Update' for our NODENUMBER, with MAC and PASS.
	# - if the NODENUMBER did not exist, it will be created with the supplied data
	# - if the NODENUMBER did exist,
	#     - and the PASS did not match: Error
	#     - and PASS did match: Success (and extension of lease in registrator)
	URL="$URL_BASE/PUT/$NETWORK/knoten/$NODENUMBER?mac=${MAC}&pass=${PASS}"
	_log do heartbeat daemon info "$URL"

	# call API and convert JSON answer to shell variables
	eval $( jshn -r "$( wget -qO - "$URL" )" )

	# check if we've got HTTP Status 401 'Not Authorized'
	case "$JSON_VAR_status" in
		'401')
			# TODO: resetting the number here would auto-recover lost passwords
			#       and asign new NODENUMBER on next try. like this:
			# uci delete system.@profile[0].nodenumber
			_log do registrator daemon alert "[ERR] somebody has your number '$NODENUMBER'"
		;;
		'200')
			_log do heartbeat daemon info "OK"
			exit 0
		;;
		*)
			_log do heartbeat daemon alert "[ERR] HTTP-Status: '$JSON_VAR_status'"
			exit 0
		;;
	esac
}

# API call is: Send a 'Create', with MAC and PASS.
# - successful answer *always* contains our NODENUMBER
# - if a new NODENUMBER was registered for us, status is 201 Created
# - if a NODENUMBER with same MAC already existed, status is 303 Redirect
URL="$URL_BASE/POST/$NETWORK/knoten?mac=${MAC}&pass=${PASS}"

# call API and convert JSON answer to shell variables
eval $( jshn -r "$( wget -qO - "$URL" )" )

# if the status is >400, there was some kind of error
if test 2>/dev/null "$JSON_VAR_status" -lt 400; then
	# check if the answer contains a NODENUMBER
	if test 2>/dev/null "$JSON_TABLE1_number" -gt 1 ; then
		echo "zahl: '$JSON_TABLE1_number'"
		# check with `_ipsystem` if it is a *valid* NODENUMBER
		if _ipsystem do "$JSON_TABLE1_number" >/dev/null ; then
			# TODO: does one of these already save the number to uci ???
			NETWORK="$( echo "$CONFIG_PROFILE" | cut -d'_' -f1 )"
			MODE="$( echo "$CONFIG_PROFILE" | cut -d'_' -f2 )"
			/etc/init.d/apply_profile.code "$NETWORK" "$MODE" "$JSON_TABLE1_number"
		else
			_log do error daemon info "nodenumber invalid: '$JSON_TABLE1_number'"
		fi
	else
		_log do error daemon info "number format wrong: '$JSON_TABLE1_number'"
	fi
else
	_log do error daemon info "message: '$JSON_VAR_msg'"
fi
