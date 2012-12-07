How to add a new router model to fastbuilder
--------------------------------------------

	git clone --depth 1 git://nbd.name/openwrt.git
	cd openwrt
	git clone git://github.com/bittorf/kalua.git

	rm .config
	make menuconfig (and exit + safe)
	make menuconfig (click your hardware + wifidriver + specials + exit + safe)

	NAME="my new router model"
	FILE="kalua/openwrt-config/config_HARDWARE.${NAME}.txt"

	# not essential, but makes it possible to fully automate everything:
	echo  >"$FILE" "# factory:    \$filename of generated image"
	echo >>"$FILE" "# sysupgrade: \$filename of generated image"

	# not essential, but good for debugging a fat build:
	echo >>"$FILE" "# flash_blocksize: 64k"
	echo >>"$FILE" "# flash_blocks_overall: 64"		# e.g. 1mb = 8 blocks, 8 mb = 64 blocks
	echo >>"$FILE" "# flash_blocks_lost: 2"			# e.g. bootloader, cfe, platform-data
	echo >>"$FILE" "# flash_blocks_enforced_kernel: 12"	# e.g. TL-1043ND kernel always uses 12 blocks

	kalua/openwrt-build/mybuild.sh config_diff >>"$FILE"

