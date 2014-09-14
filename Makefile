compile: cleandir copy

copy:
	mkdir ipkg-install
	cp -r openwrt-addons/* ipkg-install/
	cp openwrt-build/apply_profile ipkg-install/etc/init.d/
	cp openwrt-build/apply_profile.code ipkg-install/etc/init.d/
	cp openwrt-build/apply_profile.code.definitions ipkg-install/etc/init.d/
	cp openwrt-build/apply_profile.watch ipkg-install/etc/init.d/
	cp openwrt-patches/regulatory.bin ipkg-install/etc/init.d/apply_profile.regulatory.bin

cleandir:
	rm -rf ipkg-install
