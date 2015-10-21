#!/bin/sh

NETWORK="$1"
BASE="/var/www/networks"
DIR="$BASE/$NETWORK/meshrdf/recent"

FILE="$( ls -t1 "$DIR" | head -n1 )"
FILE="$DIR/$FILE"

UNIXTIME_RECENT="$( find "$FILE" -printf "%T@" | cut -d'.' -f1 )"
UNIXTIME_NOW="$( date +%s )"

echo "$UNIXTIME_RECENT"
echo "$UNIXTIME_NOW"
