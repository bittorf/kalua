#!/bin/sh

URL="http://download.berlin.freifunk.net/ipkg/packages/"
LIST="$( wget -qO - "$URL" |
	  sed -n 's/^.*<a href=\"\([a-zA-Z0-9\._-]*\)[^a-zA-Z0-9\._-].*/\1/p' |
	   grep ^".*\.ipk$"
)"

for FILE in $LIST; do {
	wget -q "${URL}${FILE}"
} done

