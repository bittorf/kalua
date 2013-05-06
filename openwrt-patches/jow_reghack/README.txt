The reghack utility replaces the regulatory domain rules in the driver binaries
with less restrictive ones. The current version also lifts the 5GHz radar
channel restrictions in ath9k.

How to use:

ssh root@openwrt

cd /tmp/
wget http://luci.subsignal.org/~jow/reghack/reghack.elf
chmod +x reghack.elf
cp /lib/modules/*/ath.ko .
cp /lib/modules/*/cfg80211.ko .
./reghack.elf ath.ko
./reghack.elf cfg80211.ko
mv *.ko /lib/modules/*/
reboot

