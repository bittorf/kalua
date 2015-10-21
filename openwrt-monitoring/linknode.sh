#!/bin/sh

NETWORK_ORIG="$1"
NETWORK_FAKE="$2"
SHORT_MAC="$3"

if [ -z "$SHORT_MAC" ]; then
	echo "Usage: $0 <network_real> <network_fake> <short_mac>"
	echo
	echo "e.g..: $0 ffweimar ffweimar-vhs 64700259413e"
	echo
	echo ""
	echo "e.g..: for MAC in 64700259413e 647002592e92 64700259411a 647002f39394 64700259405c 64700259405a; do $0 ffweimar ffweimar-vhs \$MAC; done"
	echo
	echo "e.g.:"
	echo 'NW="ffweimar-jagemanns"; [ -d "/var/www/networks/$NW" ] || /var/www/scripts/apply_new_network.sh "$NW"'
	echo "LIST='647002e29827 647002e297b1 647002d3237f 647002d32441'"
	echo "for MAC in \$LIST; do $0 ffweimar \$NW \$MAC; done"

	exit 1
else
	echo "Linking $SHORT_MAC"

	cd /var/www/networks/$NETWORK_FAKE/meshrdf/recent || exit
	ln -s /var/www/networks/$NETWORK_ORIG/meshrdf/recent/$SHORT_MAC "$SHORT_MAC"
	cd /var/www/networks/$NETWORK_FAKE/registrator/recent || exit
	ln -s /var/www/networks/$NETWORK_ORIG/registrator/recent/$SHORT_MAC "$SHORT_MAC"
fi
