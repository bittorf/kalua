#!/bin/sh

FILE="$1"

[ -z "$FILE" ] && {
	echo "Sense: will strip all lines which begin with a comment"
	echo "Usage: $0 <file>"
	exit 1
}

sed -i -n '/^[^#]/p' "$FILE"

# kernel.config
# ar71xx:   ./build_dir/linux-ar71xx_generic/linux-2.6.39.4/.config
# brcm47xx: ./build_dir/linux-brcm47xx/linux-3.0.3/.config
#
# openwrt.config
# .config
