#!/bin/sh

URL="${1:-https://github.com/bittorf/kalua.git}"
DIR="/tmp/updater_$$"

mkdir "$DIR"
cd "$DIR" || exit
git clone "$URL"
cp kalua/openwrt-monitoring/* /var/www/scripts/
cd .. || exit
rm -fR "$DIR"
