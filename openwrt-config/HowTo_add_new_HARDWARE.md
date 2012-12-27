How to add a new router model to fastbuilder
--------------------------------------------

	git clone --depth 1 git://nbd.name/openwrt.git
	cd openwrt
	REPONAME="weimarnetz" && REPOURL="git://github.com/weimarnetz/weimarnetz.git"
	git clone $REPOURL

	rm .config
	make menuconfig (and exit + safe)
	make menuconfig (click your hardware + wifidriver + specials + exit + safe)

	NAME="my new router model"
	FILE="$REPONAME/openwrt-config/config_HARDWARE.${NAME}.txt"
	$REPONAME/openwrt-build/mybuild.sh config_diff >"$FILE"

