#!/bin/sh

list_networks()
{
	find /var/www/networks/ -type d -name registrator | cut -d'/' -f5 | sort
}

case "$1" in
	list)
		echo "# when called with <start>, this will loop over these networks (wait some seconds)"
		list_networks
	;;
	start)
		APPLY="/var/www/scripts/apply_pubkeys_from_network-registrator_to_auth_keys.sh"

		for network in $( list_networks ); do {
			$APPLY $network
		} done

		$APPLY join_all
	;;
	*)
		echo "Usage: $0 <start|list>"
		echo "# loops over all networks and allows EACH router to connect to us"
	;;
esac
