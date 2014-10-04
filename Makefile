LASTCOMMIT:=$(shell git log -1 --pretty=format:%ct )
LAST_COMMIT_IN_HOURS:=$(shell echo $$((${LASTCOMMIT}/3600)) )
compile: cleandir copy version

copy:
	mkdir ipkg-install
	cp -r openwrt-addons/* ipkg-install/
	cp openwrt-build/apply_profile ipkg-install/etc/init.d/
	cp openwrt-build/apply_profile.code ipkg-install/etc/init.d/
	cp openwrt-build/apply_profile.code.definitions ipkg-install/etc/init.d/
	cp openwrt-build/apply_profile.watch ipkg-install/etc/init.d/
	cp openwrt-patches/regulatory.bin ipkg-install/etc/init.d/apply_profile.regulatory.bin

version:
	@echo FFF_PLUS_VERSION=${LAST_COMMIT_IN_HOURS} > ipkg-install/etc/variables_fff+
	@echo FFF_VERSION=3.0.0 >> ipkg-install/etc/variables_fff+

cleandir:
	rm -rf ipkg-install
