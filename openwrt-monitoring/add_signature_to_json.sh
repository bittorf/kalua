#!/bin/sh

NETWORK="$1"
UPDATEMODE="$2"
MODEL="$3"
USECASE="$4"
#
NICK="$5"
SIGNATURE="$6"

if [ ${#SIGNATURE} -ne 100 ]; then
	echo "error: signature-length: ${#SIGNATURE} bytes - should be 100"
	echo
	echo "Usage: $0 <network> <updatemode> <model> <usecase> <nick> <signature>"
	exit 1
else
	FILE_JSON="/var/www/networks/$NETWORK/firmware/models/$MODEL/$UPDATEMODE/$USECASE/info.json"
	[ -e "$FILE_JSON" ] || {
		echo "can not find: '$FILE_JSON'"
		exit 1
	}
fi

add_signature_to_json()
{
	local file_json="$1"
	local nick="$2"
	local signature="$3"

	grep -sFq "$signature" "$file_json" && return 0
	test ${#signature} -eq 100 || return 1
	# FIXME: check if sig is valid/fits to sha256

	sed -i "s|\"firmware_sha256_signatures\": {|&\n    \"$nick\": \"$signature\",|" "$file_json"
}

mark_as_manually_checked()
{
	local file_json="$1"

	sed -i 's/"firmware_manually_checked": "false"/"firmware_manually_checked": "true"/' "$file_json"
}

add_signature_to_json "$FILE_JSON" "$NICK" "$SIGNATURE" && {
	mark_as_manually_checked "$FILE_JSON"
}
