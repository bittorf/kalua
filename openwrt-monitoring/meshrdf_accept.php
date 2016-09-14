<?php

error_reporting(E_ALL ^ E_NOTICE);		// meldet alle fehler ausser E_NOTICE = vorgabe von php.ini
// error_reporting(E_ALL);		// haufenweise: 'PHP Notice:  Undefined index: optimizenlq in /var/www/scripts/meshrdf_accept.php on line 64'

if(isset($_GET["refresh"])) {		// refresh='true' -> monitoring_heartbeat
	$mac = strval($_GET["mac"]);

	if (file_exists("recent/$mac")) {
		touch("recent/$mac");

		// ?refresh=true&mac=14cc20ed2513&up=10&h2=98926592&load=14&version=396349&r4=0&r5=1

		$v0 = $_SERVER["REMOTE_ADDR"];
		$v1 = strval($_GET["up"]);		// uptime
		$v2 = strval($_GET["h2"]);		// ram_free
		$v3 = strval($_GET["load"]);		// load
		$v4 = strval($_GET["version"]);		// kalua-version
		$r4 = strval($_GET["r4"]);		// wifi-clients
		$r5 = strval($_GET["r5"]);		// wired-clients

		file_put_contents("recent/".$mac.".changes", "UP=".$v1.";LOAD=".$v3.";h2=".$v2.";VERSION=".$v4.";r4=".$r4.";r5=".$r5.";PUBIP_REAL=".$v0.";");
		print("REFRESHED");

	} else {
		print("UNKNOWN");
	}

	exit;
}

if(isset($_GET["log"]) ){
//	$length = strlen($_SERVER['QUERY_STRING']);
//	system("echo ".$length." >>/tmp/JJJ");
	$message  = strval($_GET["log"]);	// e.g. 'error xy'
	$hostname = strval($_GET["hostname"]);	// e.g. 'paltstadt-hybrid'
	$mac	  = strval($_GET["mac"]);	// e.g. '112233445566'
	$rev	  = strval($_GET["rev"]);	// e.g. '12345'
	$config   = strval($_GET["config"]);	// e.g. 'apphalle_ap'
	$time	  = strval($_GET["time"]);	// e.g. '1421667011'

	# TMPDIR=/var/run/kalua
	$file = '/var/run/kalua/monilog.txt' ;
	file_put_contents($file, $time.' '.$config.' '.$rev.' '.$hostname.' '.$mac.' '.$message . PHP_EOL, FILE_APPEND | LOCK_EX);

	print "OK";
	exit;
};

if(!isset($_GET["log"]) && !isset($_GET["local"]) ){
	$formorderby = $_GET["ORDER"];
	$form_mac = $_GET["FORM_MAC"];

	if(isset($_GET["FORM_HOSTNAME_SET"])) {
		$WIFIMAC = $_GET["FORM_HOSTNAME_SET"];
		$HOSTNAME = $_GET["FORM_HOSTNAME"];
		system("mkdir -p ../settings");
		system("echo ".$HOSTNAME." >../settings/".$WIFIMAC.".hostname ;");
	};

	system("./generate_table.sh \"".$formorderby."\" \"".$form_mac."\"");
	include("meshrdf.html");

//	system("/var/www/scripts/meshrdf_generate_map.sh >/tmp/map.txt");
//	system("dot 1>/dev/null 2>/dev/null -Goverlap=scale -Gsplines=true -Gstart=3 -v -Tsvg -o /tmp/map.svg /tmp/map.txt");
//	system("dot 1>/dev/null 2>/dev/null -Goverlap=scale -Gsplines=true -Gstart=3 -v -Tpng -o /tmp/map.png /tmp/map.txt");
//	system("dot 1>/dev/null 2>/dev/null -Goverlap=scale -Gsplines=true -Gstart=3 -v -Tpdf -o /tmp/map.pdf /tmp/map.txt");
//	system("cp /tmp/map.svg .;cp /tmp/map.png .;cp /tmp/map.pdf .");

	exit;
};

$e0 = strval($_GET["e0"]);			// how many error's during send for this monitoring-message
$e1 = strval($_GET["e1"]);			// how many error's during send for all monitoring-messages since last reboot

$D0 = strval($_GET["D0"]);			// dhcpscript: bool (off/on)

$k0 = strval($_GET["k0"]);			// seconds from klog when RT throttling was activated
$k1 = strval($_GET["k1"]);			// linecount dmesg.boot
$k2 = strval($_GET["k2"]);			// linecount dmesg.log
$k3 = strval($_GET["k3"]);			// linecount coredumps

$u0 = strval($_GET["u0"]);			// usb plugged in? 1=yes

$w0 = strval($_GET["w0"]);			// name wifidev
$w1 = strval($_GET["w1"]);			// restarts
$w2 = strval($_GET["w2"]);			// uptime
$w3 = strval($_GET["w3"]);			// last reason for restart

$t0 = strval($_GET["t0"]);			// olsr_wifi_in
$t1 = strval($_GET["t1"]);			// olsr_wifi_out
$t2 = strval($_GET["t2"]);			// olsr_speed
$t3 = strval($_GET["t3"]);			// olsr_metric

$d0 = strval($_GET["d0"]);			// database last line
$d1 = strval($_GET["d1"]);			// enforced database auth server

$i0 = strval($_GET["i0"]);			// inet: proto
$i1 = strval($_GET["i1"]);			// inet: interface
$i2 = strval($_GET["i2"]);			// inet: ip/pre
$i3 = strval($_GET["i3"]);			// inet: downstream [kbyte/s]
$i4 = strval($_GET["i4"]);			// inet: upstream [kbyte/s]
$i5 = strval($_GET["i5"]);			// inet: gateway-ip
$i6 = strval($_GET["i6"]);			// inet: speed to authserver

$r0 = strval($_GET["r0"]);			// rssi wlan0
$r1 = strval($_GET["r1"]);			// rssi wlan1
$r2 = strval($_GET["r2"]);			// rssi wlan2
$r3 = strval($_GET["r3"]);			// rssi wlan3
$r4 = strval($_GET["r4"]);			// wifi_clients_sum
$r5 = strval($_GET["r5"]);			// wired_clients_sum
$r9 = strval($_GET["r9"]);			// reboot_reason

$h0 = strval($_GET["h0"]);			// simple_meshnode = 1
$h1 = strval($_GET["h1"]);			// ram_size
$h2 = strval($_GET["h2"]);			// ram_free
$h3 = strval($_GET["h3"]);			// ram_free flushed
$h4 = strval($_GET["h4"]);			// zram reads
$h5 = strval($_GET["h5"]);			// zram writes
$h6 = strval($_GET["h6"]);			// zram memory_needed
$h7 = strval($_GET["h7"]);			// zram_compressed_size

$s1 = strval($_GET["s1"]);			// switch
$s2 = strval($_GET["s2"]);			// lan-dhcp-ignore

$v1 = strval($_GET["v1"]);			// kernel
$v2 = strval($_GET["v2"]);			// git

$n0 = strval($_GET["n0"]);			// wired neighs sorted

$wifiscan = strval($_GET["wifiscan"]);		//
$sens = strval($_GET["sens"]);			// sensitivity
$log = strval($_GET["log"]);			// double quotes are correctly esacaped: " -> \"
$wifidrv = strval($_GET["wifidrv"]);		// wifidriver (name+version)
$up = intval($_GET["up"]);
$node = intval($_GET["node"]);			//
$version = strval($_GET["version"]);		//
$reboot = intval($_GET["reboot"]);		//
$city = intval($_GET["city"]);			//
$mac = strval($_GET["mac"]);			// wifimac
$update = strval($_GET["update"]);		//
$hostname = strval($_GET["hostname"]);		//
$neigh = strval($_GET["neigh"]);		//
$latlon = strval($_GET["latlon"]);		//
$gwnode = intval($_GET["gwnode"]);		//
$txpwr = intval($_GET["txpwr"]);		//
$wifimode = strval($_GET["wifimode"]);		//
$channel = intval($_GET["channel"]);		//
$etx2gw = strval($_GET["etx2gw"]);		//
$hop2gw = intval($_GET["hop2gw"]);		//
$users = strval($_GET["users"]);		//
$mrate = strval($_GET["mrate"]);		//
$load = strval($_GET["load"]);			//
$hw = strval($_GET["hw"]);			//
$unixtime = strval($_GET["time"]);		//
$humantime = strval($_GET["local"]);		//
$forwarded = strval($_GET["forwarded"]);	//
$services = strval($_GET["services"]);		//
$remoteaddr = $_SERVER["REMOTE_ADDR"];		//
$mail = strval($_GET["mail"]);			//
$phone = strval($_GET["phone"]);		//
$pubkey = strval($_GET["pubkey"]);		//
$frag = strval($_GET["frag"]);			//
$rts = strval($_GET["rts"]);			//
$gmode = strval($_GET["gmode"]);		//
$gmodeprot = strval($_GET["gmodeprot"]);	//
$gw = strval($_GET["gw"]);			//
$pubip = strval($_GET["pubip"]);		//
$profile = strval($_GET["profile"]);		//
$noise = strval($_GET["noise"]);		//
$rssi = strval($_GET["rssi"]);			//
$essid = strval($_GET["essid"]);		//
$bssid = strval($_GET["bssid"]);		//
$olsrver = strval($_GET["olsrver"]);		//
$optimizenlq = strval($_GET["optimizenlq"]);	// 0...1000
$optimizeneigh = strval($_GET["optimizeneigh"]); // 10.63.186.1 or 'gateway'
$portfw = strval($_GET["portfw"]);		// ...
$pfilter = strval($_GET["pfilter"]);
$olsrrestartcount = strval($_GET["olsrrestartcount"]);
$olsrrestarttime = strval($_GET["olsrrestarttime"]);

$script = "./meshrdf_accept.sh 1>/dev/null 2>/dev/null 'WIFISCAN=\"\";D0=\"".$D0."\";e0=\"".$e0."\";e1=\"".$e1."\";k0=\"".$k0."\";k1=\"".$k1."\";k2=\"".$k2."\";k3=\"".$k3."\";u0=\"".$u0."\";w0=\"".$w0."\";w1=\"".$w1."\";w2=\"".$w2."\";w3=\"".$w3."\";t0=\"".$t0."\";t1=\"".$t1."\";t2=\"".$t2."\";t3=\"".$t3."\";d0=\"".$d0."\";n0=\"".$n0."\";d1=\"".$d1."\";i0=\"".$i0."\";i1=\"".$i1."\";i2=\"".$i2."\";i3=\"".$i3."\";i4=\"".$i4."\";i6=\"".$i6."\";i5=\"".$i5."\";r0=\"".$r0."\";r1=\"".$r1."\";r2=\"".$r2."\";r3=\"".$r3."\";r4=\"".$r4."\";r5=\"".$r5."\";r9=\"".$r9."\";h0=\"".$h0."\";h1=\"".$h1."\";h2=\"".$h2."\";h3=\"".$h3."\";h4=\"".$h4."\";h5=\"".$h5."\";h6=\"".$h6."\";h7=\"".$h7."\";s2=\"".$s2."\";s1=\"".$s1."\";v1=\"".$v1."\";v2=\"".$v2."\";NODE=\"".$node."\";UP=\"".$up."\";VERSION=\"".$version."\";HOSTNAME=\"".$hostname."\";WIFIMAC=\"".$mac."\";REBOOT=\"".$reboot."\";CITY=\"".$city."\";UPDATE=\"".$update."\";NEIGH=\"".$neigh."\";LATLON=\"".$latlon."\";GWNODE=\"".$gwnode."\";TXPWR=\"".$txpwr."\";WIFIMODE=\"".$wifimode."\";CHANNEL=\"".$channel."\";COST2GW=\"".$etx2gw."\";HOP2GW=\"".$hop2gw."\";USERS=\"".$users."\";MRATE=\"".$mrate."\";LOAD=\"".$load."\";HW=\"".$hw."\";UNIXTIME=\"".$unixtime."\";HUMANTIME=\"".$humantime."\";FORWARDED=\"".$forwarded."\";SERVICES=\"".$services."\";PUBIP_REAL=\"".$remoteaddr."\";PUBIP_SIMU=\"".$pubip."\";MAIL=\"".$mail."\";PHONE=\"".$phone."\";SSHPUBKEYFP=\"".$pubkey."\";FRAG=\"".$frag."\";RTS=\"".$rts."\";GMODEPROT=\"".$gmodeprot."\";GW=\"".$gw."\";PROFILE=\"".$profile."\";NOISE=\"".$noise."\";RSSI=\"".$rssi."\";GMODE=\"".$gmode."\";ESSID='\''".$essid."'\'';BSSID=\"".$bssid."\";WIFIDRV=\"".$wifidrv."\";LOG=\"".$log."\";OLSRVER=\"".$olsrver."\";OPTIMIZENLQ=\"".$optimizenlq."\";OPTIMIZENEIGH=\"".$optimizeneigh."\";PORTFW=\"".$portfw."\";PFILTER=\"".$pfilter."\";OLSRRESTARTTIME=\"".$olsrrestarttime."\";OLSRRESTARTCOUNT=\"".$olsrrestartcount."\";SENS=\"".$sens."\"' || logger $0 error $? during meshrdf_accept.sh in $( pwd )";

system($script);
print "OK";

?>
