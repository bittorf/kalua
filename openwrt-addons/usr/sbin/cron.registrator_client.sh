#!/bin/sh
. /tmp/loader
. /usr/share/libubox/jshn.sh

URL_BASE="http://reg.weimarnetz.de"

MAC="$( _net dev2mac $WIFIDEV )"
MAC="$( _sanitizer do "$MAC" urlvalue )"
PASS="$( _ssh key_public_fingerprint_get )"
PASS="$( _sanitizer do "$PASS" urlvalue )"
NETWORK="$( echo "$CONFIG_PROFILE" | cut -d'_' -f1 )"

eval $( _ipsystem do "$NODENUMBER" | grep ^"NODE_NUMBER_RANDOM=" )
[ "$NODE_NUMBER_RANDOM" = "false" ] && {
	URL="$URL_BASE/PUT/$NETWORK/knoten/$NODENUMBER?mac=${MAC}&pass=${PASS}"
	_log do heartbeat daemon info "$URL"
	eval $( jshn -r "$( wget -qO - "$URL" )" )

	if test 2>/dev/null "$JSON_VAR_status" -eq 401; then
		_log do error daemon alert "somebody has your number '$NODENUMBER'"
	else
		_log do heartbeat daemon info "OK"
		exit 0
	fi
}

URL="$URL_BASE/POST/$NETWORK/knoten?mac=${MAC}&pass=${PASS}"
eval $( jshn -r "$( wget -qO - "$URL" )" )

if test 2>/dev/null "$JSON_VAR_status" -lt 400; then
	if test 2>/dev/null "$JSON_TABLE1_number" -gt 1 ; then
		echo "zahl: '$JSON_TABLE1_number'"
		if _ipsystem do "$JSON_TABLE1_number" >/dev/null ; then
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

