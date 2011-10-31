#!/bin/sh

FILE="$1"

[ -z "$FILE" ] && {
	echo "Sense: will strip all lines which begin with a comment"
	echo "Usage: $0 <file>"
	exit 1
}

sed -i -n '/^[^#]/p' "$FILE"
