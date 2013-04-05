#!/bin/sh

SCRIPT="/usr/sbin/patch.rcS.template"
FILE="/etc/init.d/rcS"
TEMP="/tmp/newfile"

head -n3 "$FILE" >"$TEMP"
cat "$SCRIPT" >>"$TEMP"
sed -n '4,99p' "$FILE" >>"$TEMP"

sh -n "$TEMP" && {
	if mv "$TEMP" "$FILE"; then
		chmod +x "$FILE"
	else
		cp "/rom$FILE" "$FILE"
		rm "$TEMP"
	fi
}
