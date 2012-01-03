kalua - build mesh-networks _without_ pain
==========================================

* community: http://wireless.subsignal.org
* monitoring: http://intercity-vpn.de/networks/dhfleesensee/
* documentation: [API](http://wireless.subsignal.org/index.php?title=Firmware-Dokumentation_API)

needing support?
join the [club](http://blog.maschinenraum.tk) or ask for [consulting](http://bittorf-wireless.de)


how to build this from scratch on a debian server
-------------------------------------------------

	sudo apt-get update
	LIST="build-essential libncurses5-dev m4 flex git git-core zlib1g-dev unzip subversion gawk python libssl-dev quilt screen"
	for PACKAGE in $LIST; do sudo apt-get install $PACKAGE; done

	# now login as non-root user
	git clone git://nbd.name/openwrt.git
	git clone git://nbd.name/packages.git
	cd openwrt
	git clone git://github.com/bittorf/kalua.git
	
	make menuconfig				# simply select exit, (just for init)
	make package/symlinks
	
	kalua/openwrt-build/mybuild.sh gitpull
	kalua/openwrt-build/mybuild.sh select_hardware_model

	kalua/openwrt-build/mybuild.sh set_build_openwrtconfig
	make menuconfig
	make kernel_menuconfig

	kalua/openwrt-build/mybuild.sh set_build_kernelconfig
	kalua/openwrt-build/mybuild.sh applymystuff "ffweimar" "adhoc" "42"
	kalua/openwrt-build/mybuild.sh make 		# needs some hours
	
	# flash your image via TFTP
	FW="/path/to/your/baked/firmware_file"
	IP="your.own.router.ip"
	while :; do atftp --trace --option "timeout 1" --option "mode octet" --put --local-file $FW $IP && break; sleep 1; done


how to development directly on a router
------------------------------------------

	opkg update
	opkg install git

	echo  >/tmp/gitssh.sh '#!/bin/sh'
	echo >>/tmp/gitssh.sh 'logger -s "$0: $*"'
	echo >>/tmp/gitssh.sh 'ssh -i /etc/dropbear/dropbear_dss_host_key $*'

	chmod +x /tmp/gitssh.sh
	export GIT_SSH="/tmp/gitssh.sh"		# dropbear needs this for public key authentication

	git config --global user.name >/dev/null || {
		git config --global user.name "Firstname Lastname"
		git config --global user.email "your_email@youremail.com"
		git config --edit --global
	}

	mkdir -p /tmp/dev; cd /tmp/dev
	git clone <this_repo>
	kalua/openwrt-build/mybuild.sh build_kalua_update_tarball
	cd /; tar xvzf /tmp/tarball.tgz; rm /tmp/tarball.tgz

	cd /tmp/dev/kalua
	git add <changed_files>
	git commit -m "decribe changes"
	git push ...

