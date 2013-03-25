#!/bin/sh

SCRIPT="/usr/sbin/patch.rcS.template"
FILE="/etc/init.d/rcS"
TEMP="/tmp/newfile"

head -n3 "$FILE" >"$TEMP"
cat "$SCRIPT" >>"$TEMP"
sed -n '4,99p' "$FILE" >>"$TEMP"

sh -n "$TEMP" && {
	cp "$TEMP" "$FILE" && rm "$TEMP"
}
