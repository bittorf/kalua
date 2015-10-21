#!/bin/sh

# on server we must distinguish 4 cases:
# - we send secret/password + nodenumber only ("reservation forever")
# OK - we send secret + mac ("give me a nodenumber")
# OK - we send all values ("heartbeat")
# OK - we send nothing, which outputs a humanreadable table/stats
# ...move nodenumber to another router with other passphrase

mac=;hash=;node=;remote=
QUERY="$1"
# /usr/bin/logger -t registrator2 -p daemon.info "$QUERY"

mac_is_wellformed()	# mac-address without colon's or minus
{
	local mac="$1"
	local hex="0-9a-fA-F"

	case "$mac" in
		[$hex][$hex][$hex][$hex][$hex][$hex][$hex][$hex][$hex][$hex][$hex][$hex])
			return 0
		;;
                *)
			return 1
		;;
	esac
}

secret_is_known()
{
	local hash="$1"

	if [ -e "secrets/$hash" ]; then
		return 0
	else
		mkdir -p "secrets"
		return 1
	fi
}

node_is_known()
{
	local node="$1"

	if [ -e "nodes/$node" ]; then
		return 0
	else
		mkdir -p "nodes"
		return 1
	fi
}

heartbeat_acceptable()
{
	local mac="$1"
	local hash="$2"
	local node="$3"
	local file="heartbeats/${node}_${mac}_${hash}"

	if [ -e "$file" ]; then
		touch "$file"
		return 0
	else
		mkdir "heartbeats"
		return 1
	fi
}

if [ -n "$QUERY" ]; then
	eval $QUERY

	if [ -z "${mac}${hash}${node}" ]; then
		OUTPUT="OK - output stats"
	else
		if mac_is_wellformed "$mac"; then
			if secret_is_known "$hash"; then
				if node_is_known "$node"; then
					if heartbeat_acceptable "$@"; then
						OUTPUT="OK - heartbeat accepted"
					else
						OUTPUT="ERROR - combination invalid"
					fi
				else
					:
				fi
			else
				OUTPUT="OK - secret unknown, handout new nodenumber"
			fi
		else
			OUTPUT="ERROR - mac not wellformed, must be e.g. 11aa22bb33cc"
		fi
	fi
else
	OUTPUT="ERROR - called from commandline"
fi

echo "$OUTPUT - IP: '$remote'"

exit 0
