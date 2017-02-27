#!/bin/sh
# tail -n1 "$TMPDIR/schoeneck.dot" | grep -q '}' || echo "}" >>$TMPDIR/schoeneck.dot; dot -Tpng $TMPDIR/schoeneck.dot > /var/www/1.png

# take screenshot into account:
# /var/www/networks/gnm/settings/2a40d30a6b01.screenshot.jpg

# dhsylt: haus34 -> zum KJC (=109)
# touch /var/www/networks/dhsylt/meshrdf/recent/dc9fdb0cc8c5

# http://www.fiendish.demon.co.uk/html/javascript/hidetablecols.html
# http://www.devcurry.com/2009/07/hide-table-column-with-single-line-of.html
# http://www.jordigirones.com/111-tablesorter-showhide-columns-widget.html

# NETWORK=marinabh; S=$(date); wget -O "/var/www/networks/$NETWORK/index.html" "http://127.0.0.1/networks/$NETWORK/meshrdf/?ORDER=hostname"; echo $S; date
#
# or
# cd /var/www/networks/schoeneck/meshrdf && /var/www/scripts/meshrdf_generate_table.sh


# TODO:
# for FILE in $( find /var/www/networks/ffweimar/meshrdf/recent -type f ); do . $FILE; echo $NODE; done | sort -n | uniq | while read LINE; do test $LINE -lt 970 && echo "$LINE"; done >/var/www/networks/ffweimar/all_nodes.txt

log()		# tail -f /var/log/messages
{
	local text="$1"
	local prio="$2"		# <empty> or 'debug'
	local ip message

	[ -n "$REMOTE_ADDR" ] && ip="[$REMOTE_ADDR] "
	message="${NETWORK:-network_unset}: ${ip}$text"
	
	# only log 'debug' when interactive:
	[ "$prio" = 'debug' -a -z "$SSH_CONNECTION" ] && return 0

#	echo "${NETWORK:-network_unset}: $1" >>$TMPDIR/log_monitoring.txt
	logger -t $0 -p user.info -s "$message"
}

TMPDIR='/var/run/kalua'		# is 'tmpfs'

UNIXTIME_SCRIPTSTART="$( date +%s )"

SPECIAL_ORDER_BY="$1"
FORM_MAC="$2"

COLOR_LOWRED="#E0ACAC"			# fixme! use words like 'very bad', 'good', etc.
COLOR_GOOD_GREEN="#11FF55"
COLOR_ORANGE="orange"
COLOR_LIGHT_GREY="#A4A4A4"
COLOR_LIGHT_CYAN="#81F7BE"
COLOR_LIGHT_BLUE="#819FF7"
COLOR_LIGHT_PURPLE="#8258FA"
COLOR_LIGHT_PINK="#DA81F5"
COLOR_LIGHT_RED="#F7819F"
COLOR_LIGHT_ORANGE="#F79F81"
COLOR_LIGHT_YELLOW="#F7BE81"
COLOR_LIGHT_GREEN="#A9F5BC"
COLOR_LIGHT_APPLE="#BEF781"
COLOR_LIGHT_BROWN="#B18904"
COLOR_DARK_YELLOW="#5F4C0B"
COLOR_DARK_GREEN="#669900"
COLOR_BRIGHT_GREEN="lime"

# TARBALL_TIME="$( stat --printf %Y "/var/www/firmware/ar71xx/images/testing/tarball.tgz" )"
# TARBALL_TIME=$(( $TARBALL_TIME / 3600 ))

			# log: git log $hash_old...$hash_new --pretty=oneline --abbrev-commit | grep ' kalua: '
			#      git log $hash_old...HEAD      --pretty=oneline --abbrev-commit | grep ' kalua: '
			# diff: git diff $hash_old --color
			# fixme! use git log
# TARBALL_TIME="375850"	# 8b1a78f51c2b70739f06ca3464d064ce6985605b
# TARBALL_TIME="376020"	# ad79bc32052146b6a53dedb04f61922dcb0e72fb
# TARBALL_TIME="376024"	# 079c243f4bd4e3b4791d8eb6b8ae7f9ba9c7a0e1
# TARBALL_TIME="376027"	# e4f77c78a75dacb31599954654e62625f22f2dec
# TARBALL_TIME="376090"	# c45939ab6b1d39f88cb88fcec062bf7180add6ca
# TARBALL_TIME="376142"	# 5ddfb3aa78c347161ba9566507a79f4c0cfd13d2
# TARBALL_TIME="376219"	# 0938cc215c7a8f36a8dd6ab7dc974dad2a69d774
# TARBALL_TIME="376622"	# f2a6c3ba229c6dd1ec5eca38c51fe5d069f2ab17
# TARBALL_TIME="376870"	# 6ecdac5878bf1f7c7c3febb2612c7bd0fe53a82f
# TARBALL_TIME="377252"	# 8429294159a25165848bb631b61e1099315e7575
# TARBALL_TIME="377276"
# TARBALL_TIME="377531"
# TARBALL_TIME="377608"	# b83959e349dfa7d90e5f100aab959d7f4ba3dc39
# TARBALL_TIME="377628"	# 7923a2e4c2ff7fb52d5f7001bbc78289bf7fadbb
# TARBALL_TIME="377777"	# ea8461cef99b71ef752d9265510ca916b459eea3
# TARBALL_TIME="377926"	# 4c941228a4d6686c12218889dddabb8a022d2495
# TARBALL_TIME="379387"	# 4fb22c9cb03f8dc0b0dc0744b27adbadcf87b87f
# TARBALL_TIME="381138"	# ca396bd65d98d953470e44f0f449b7b0d4cf4fe0
# TARBALL_TIME="381157"	# 31fa7cc9ea1811f8ba2742d4ebf35d1fcfee8348
# TARBALL_TIME="381402"	# c5e6bd7a18ca9d9ed590d146a6f413f27054bfc0
# TARBALL_TIME="381470"	# f129875d2f6f991cf2a75c4a846d44dbd891617b
# TARBALL_TIME="381489"	# 3a5cfbbda3dbb1fdcb3d949410a195d9623fe14f
# TARBALL_TIME="381924"	# a7ef6df7968eac7741c3b27ed5349cc2a80837ff
# TARBALL_TIME="381977"	# 8af170d894f90b60912e5abf72aa90c40509b4bb
# TARBALL_TIME="382003"	# 9df397a5d1e3b188ad020df1b05723f89b240c40
# TARBALL_TIME="382018"	# 1d6f93d657e5f2106ba494567d67b3ab5c6385d4
# TARBALL_TIME="382041"	# 89ade7a660c347ae5eafd8d8edb387b129499155
# TARBALL_TIME="382164"	# ccb813564270e36a60632e91a110b10ee0eb2776
# TARBALL_TIME="382337"	# a667fc4e7ab32a3918745397f9d60e5ca96ff99e
# TARBALL_TIME="382352"	# d2a6990110a78d09567125b7f0a6bf7611eed44b
# TARBALL_TIME="382358"	# a0982f9debbe148b117ff70685f509b14cd80677
# TARBALL_TIME="382362"	# 407b5411e263c468650d4c5e1bc0267e9ee3f418
# TARBALL_TIME="382373"	# 9d5cfa5736d1903bed6064d8a79bfb01e56dbe91
# TARBALL_TIME="382413"	# 1e7b60428ad4045405349487627d43de73388683
# TARBALL_TIME="382505"	# f2e16f08598eb1e79efaf4956ce8ec8d5db10087
# TARBALL_TIME="382522"	# c4f18cc5c341560fd1b855c24a25f1b32e21177d
# TARBALL_TIME="382643"	# ce2599a2e36fee89dea6b7e7c052bd32c8a6a803
# TARBALL_TIME="382663"	# dbcb723315f7e787aa8751a07118bb9e6a941c5f
# TARBALL_TIME="382695"	# 2d9a563c8ed525bd36342651a74a52f5cb92ef29
# TARBALL_TIME="382711"	# 457632da7b0943b52d5173153f2bc1e1f061dff5
# TARBALL_TIME="382843"	# 2e38e7bee845443656283b251865cc6ea5531c3c
# TARBALL_TIME="382885"	# d012337363192e033bcaae340faf37eb00cd3bdf
# TARBALL_TIME="383251"	# 220fc1f71b9dd532ff49534634c8f2cb5621198e
# TARBALL_TIME="383347"	# 80349695e39a665674f4cfe892e4221f12455e1f
# TARBALL_TIME="383422"	# 5a4f0344f88d90c8ba1f7ecc500ef0219d8f04ad
# TARBALL_TIME="383487"	# f0bb6d68c858730b06861d10b7ad4a7d0c161b9b
# TARBALL_TIME="383494"	# f79ec31c181dbc680dce503ef76f99fd7ff507ae
# TARBALL_TIME="383504"	# e066ecb17f2af437e0d8eb72c08df762ad49bb5d
# TARBALL_TIME="383512"	# 6449b33a91f90ce47c2305873c0dc081d9049f97
# TARBALL_TIME="383538"	# 5a9ff8e01de0392591cff3ad4be438d97bac8559
# TARBALL_TIME="383725"	# 4b4816a3fe4e05c80d68f52532867cb0f829ce69
# TARBALL_TIME="383872"	# 6bdf74021c6ab859fbab4a68975087732f4c1955
# TARBALL_TIME="383922"	# 9c6c2b9f0c2295d57cb0bc947b6359b009890df1
# TARBALL_TIME="383990"	# d6b5a76aa917351d755cd058394307ba954076cc
# TARBALL_TIME='384667'	# 9978d253cf0dc7cc7f35459a46e5a6016a2cfdef
# TARBALL_TIME='384835'	# e0a3769dd3851110e4482385fa0422924192db47
# TARBALL_TIME='384875'	# 099a018aeb87f0a446e8ea8efbc5b57f994b5456
# TARBALL_TIME='384929'	# e346998825bb28e7f5e269a1b4f2d8cf04eda4ee
# TARBALL_TIME='384959'	# 23cc1757102ddbd2e4cb0d27a56b3a702518fbd7
# TARBALL_TIME='385171'	# 8465e8771f68dac3bad6852a12b2d7c28bd2ccb4
# TARBALL_TIME='385184'	# 43b3bf00e5e4547d301e70823182335838ab3a3a
# TARBALL_TIME='385205'	# 1966ff525b5656f975ee2a23ce6da156bf18f982
# TARBALL_TIME='385405'	# 587eb7574a2107e6337b61b858302238e600d608
# TARBALL_TIME='385509'	# 93a7fd3c9dda63bab3f66650c18c799a74e2b299
# TARBALL_TIME='385522'	# 84c1ae849439ad04cefb4b90cae95ab8ec31ff13 (hotfix)
# TARBALL_TIME='385557'	# ad7f52e9d870e3a21f9d280eb15106c1bddf21bf (hotfix)
# TARBALL_TIME='385677'	# f73a26b5e388612975a6dfcf4f3066549a44744d
# TARBALL_TIME='385694'	# 61e1418f7f68617a6dcd47f37de9a8498b92fc4f
# TARBALL_TIME='385748'	# 9a7049d1dab00deba959913d35e7dd989071e663
# TARBALL_TIME='385772'	# f7b19d012efb2104aa7c1e96c110e5b781223934
# TARBALL_TIME='385782'	# a291e7b36aa361547f3384195b2a21243a8404c5 (hotfix)
# TARBALL_TIME='385940'	# 737a0236c404097c76c3fda1e2712c4771fe4dcc
# TARBALL_TIME='385964'	# 800a4406afd897e3ee16f7b1e0587709ce6dd1e3 (hotfix)
# TARBALL_TIME='386001'	# 14ab4b5458e25b99b0aa14b53feafb28a646e637 (hotfix)
# TARBALL_TIME='386061'	# 16e5d9a216df0dcb865fbb96dac34f9c5e11fcff
# TARBALL_TIME='386108'	# 1be59c0a46bde33c9bc52d1ee0c7f33970257173
# TARBALL_TIME='386155'	# 786d86b5ab52f57370a42b1651cb770b87232502 (hotfix)
# TARBALL_TIME='386584'	# dd66e68a87f140463c724638b95627e7d5d3fef8
# TARBALL_TIME='386612'	# 89461e1f2e540fc9b297ff64adfc4ea963559978
# TARBALL_TIME='386680'	# c946d311453a08a604141ce48e73bfe30e4624ce
# TARBALL_TIME='386749'	# 16d36382d558dee7f1524d7c3fb4126cafc78ff1
# TARBALL_TIME='386779'	# 819ffa5e72c5ca450de2cbcd5b9a291cb42d4d19
# TARBALL_TIME='386793'	# e91a7297c05b4d4f927d0ad0589b923120890d55
# TARBALL_TIME='387740'	# a78a3bf97d4fc362cdb58a13147c31fb9e83150c
# TARBALL_TIME='387787'
# TARBALL_TIME='387908'	# e56bdb3084c09d9f8da881d3567620df5b53e890
# TARBALL_TIME='387924'	# 9711319d25ef2745507c8adb60d08c82bde409cc
# TARBALL_TIME='387950'	# 935c8dc8a79d26ab90a5ed188ec76e16b8a7d5d7
# TARBALL_TIME='387969'	# a26e251412fe093a39630cfae43b0cf7e229046a
# TARBALL_TIME='388529'	# ee5bb81d19f9bc691ae91a174439d53ec0ca2d82
# TARBALL_TIME='389202'	# 04e66af860b707389b8c0d7314380dd2a5e14922
# TARBALL_TIME='389360'	# 457f68963bfe6676382eb254271b0518401a8770
# TARBALL_TIME='389439'	# 413f28e54f86dae555493c84c6ca131420a3a4d6
# TARBALL_TIME='390323'	# 040a29567c3b5ce5616038ac4a23e60e8c98ca4e
# TARBALL_TIME='390426'	# a3107c85b08d75498f467d7353ac7e080176f87a
# TARBALL_TIME='391244'	# dd4ebf19e4727113e4e1ba0535292771a6d5344f
# TARBALL_TIME='391429'	# 31f6c8ba3f032752257b7114847799d82b3df9e9
# TARBALL_TIME='391747'	# 903c1f26a6b3929f69d7b954179ff33f0dff3ba4
# TARBALL_TIME='391866'	# 0a7a0fecbd4f1ae5ad0e5809e960f68bc1bd2b3b
# TARBALL_TIME='391931'	# 1b2661b1610f24c43d9661df5a3372fd3fe0ee81
# TARBALL_TIME='392636'	# 4521ac00cc861cb0918b7bb2720eeed7e6da8655
# TARBALL_TIME='392730'	# 4a6df25d8b91605e52d9400519c185e017b3a326
# TARBALL_TIME='392947'	# 575575b1162728d92e14a0659f8e9eaaefa1bf52
# TARBALL_TIME='392973'	# fade95380a5ca2ec5a9770650792c9ab5233bd5b - boeser bug in ip2mac()
# TARBALL_TIME='393015'	# 94ebbae69ebbbd077477d97b3616bf9a5912f203
# TARBALL_TIME='393044'	# e372762cdd91798053c4ca701c45c1057f502b46
# TARBALL_TIME='393067'	# 198cc1bc720582fb8f9ba798175d8c6fafb00f2c
# TARBALL_TIME='393283'	# 5415ee5d9be50829e5902b31d8bbb67f8d027b4b
# TARBALL_TIME='393443'	# 753c05d14254d7611f519215a4f5548e736f4638
# TARBALL_TIME='393469'	# 168e3da346b8fa4594f86d0dbd245f3b6cc611fa
# TARBALL_TIME='393491'	# 69085609fabe9a6cce27d29bf489029442e78b44
# TARBALL_TIME='393544'	# 4c47be6290b597499a3d45e6cd18a6916a5fd72a (+ath5k)
# TARBALL_TIME='393667'	# 4d3c4edb5c859f0892e92929b52cc7282df6ed0c
# TARBALL_TIME='394123'	# c73679acaf0a01eb0c98ce6d9d0b8ed0d6ac39a8
# TARBALL_TIME='394617'	# e60f91649ebc97d27c5fdc21953ed2a896551b17
# TARBALL_TIME='394771'	# 0f45c5dd21f5d64baec2be93ac81e82db0ac3483
# TARBALL_TIME='394915'	# 902738296ce2ade3df7729cf0a783204042867ee
# TARBALL_TIME='395079'	# 1b0167281d355b461366465f13044f0aa6df65d9
# TARBALL_TIME='395102'	# 4606bff141c4702e75f3411b5274a3a75d2ca69f
# TARBALL_TIME='395324'	# a501128dd626314b36efbaf600dc3f82ae40cf46
# TARBALL_TIME='395417'	# 782765685738caaa714a2190702e0ed29021989b
# TARBALL_TIME='395588'	# 2e9a0138fa60fc228d92fcf39c6900c1c73eaa0c
# TARBALL_TIME='395781'	# 71b178421da5bd672e832a5430aeca59b406ab93
# TARBALL_TIME='395801'	# bf3679752d94578c1f06ddea5b3adbf01fffc13d
# TARBALL_TIME='395804'	# af3fa35882632b32e64afb27acab4b920a718130
# TARBALL_TIME='395945'	# f688242edb2031a79c16b526d546dc45e7d26bda
# TARBALL_TIME='395983'
# TARBALL_TIME='395997'	# ba208e25add903efa528defc1ff27940ca6a0227
# TARBALL_TIME='396093'	# 8e78780d05e25ef5732831b2e010724ea66ca58a
# TARBALL_TIME='396133'	# 9d330169e8de3b68aa034cc0134bd26cdc71a92a
# TARBALL_TIME='396158'	# a7d53dfd9fa1ba672029f513b0b15123538708fb
# TARBALL_TIME='396187'	# 004045d067a68c9254a1f44aa431f3085741c9f5
# TARBALL_TIME='396418'	# 085dc0f89865969923c927db0d2f832c22a53b35
# TARBALL_TIME='396595'	# 2e50d9a67357a76ea31898575d9600290f0ed62e
# TARBALL_TIME='396644'	# 127a5a8000a35348933cc7584d3e3e2e73e5d7aa
# TARBALL_TIME='397003'	# 93df9b842b20f076e9bdd02bff798d64307fdc47
# TARBALL_TIME='397015'	# 084f496aebd40d5f5130544cf8e943f06cd8a838
# TARBALL_TIME='397018'	# 20f5f6d07d47524dd03d27792efcb73eaf16a7e7
# TARBALL_TIME='397100'	# 0d3b71d322f5598b717267252fa4ab0b096603b8
# TARBALL_TIME='397165'	# 2b441df4612eecb60485aae42a85456c330c301d
# TARBALL_TIME='397433'	# 66c44c54e61f8eba4b7cc2938f0ab1082ecfdcd4
# TARBALL_TIME='397507'	# 1292f62f3f2059a38be850b42f25f2fb2bbb733a
# TARBALL_TIME='397531'	# d01d8e66a72e6caf4e6fd07bf936181626de8a9b
# TARBALL_TIME='397769'	# 57f048701c09aafe7aeecbcc86a09fe9a14f223d
# TARBALL_TIME='397859'	# 2c4fe46540382e24313a08f3c48e99257e362abc
# TARBALL_TIME='398156'	# 0bbab41f4714180c16b4308d5f7a1d13b6fad3e1
# TARBALL_TIME='398251'	# 27aeead42c8db465cbdb7ca501004b88c2b019cf
# TARBALL_TIME='398364'	# 2197dc6b08a549d00b27ded146d497af3e61a276
# TARBALL_TIME='398610'	# 4156286a7beb3c030c21cb312ca21604fec5a61d
# TARBALL_TIME='398774'	# 29c8e80a6f7b01f876da4f20020be083281cb080
# TARBALL_TIME='398780'	# 5b174a539918f5d5c09ad0a4a7a539e00f3df38e
# TARBALL_TIME='398893'	# 63c2872387cbaa0c04fecce62425e37482d98c3c
# TARBALL_TIME='398941'	# 4d842c71d3e63e7f635a3472f88c1f62aeb4a648
# TARBALL_TIME='399063'	# efcc08bddc97ddb8b891cc77bf8e80f8dc389032 // vor dem Urlaub 8-)
# TARBALL_TIME='399401'	# 0c4bff63b1d54ef9ab46c156a212515b34e14066 // nach dem Urlaub
# TARBALL_TIME='399549'	# bad70fcc693b30f40457edc6ed3f68b7c427f969 // vor slovenien + tarball path geaendert




LOCALTIME="$( date +%d%b%Y-%Huhr%M )"
LOCALUNIXTIME="$UNIXTIME_SCRIPTSTART"

OUT="$TMPDIR/meshrdf_temp_$$"

# FIXME! why do they exist?
ls -1t "$TMPDIR/meshrdf_temp_"* 2>/dev/null | grep -v "$( date "+ %b %d " )" | sed 's/^/rm /' >"$TMPDIR/RM"
command . "$TMPDIR/RM" && rm "$TMPDIR/RM"

# portforwarding / xoai during fetching 'cgi-bin-tool.sh?OPT=portforwarding_table'
[ -e "$TMPDIR/PORTFW" ] && rm "$TMPDIR/PORTFW"

REAL_OUT="./meshrdf.html"

get_network_name()
{
	local oldIFS="$IFS"
	local IFS='/'

	set -- $( pwd )

	while :; do {
		case "$1" in
			'networks')
				echo "$2"
				break
			;;
		esac

		shift
	} done
}


NETWORK="$( get_network_name )"
mkdir -p "$TMPDIR/networks/$NETWORK"

TOOLS="./tools.txt"
IPKG="./ipkg.txt" ; >$IPKG
DOTFILE="$TMPDIR/networks/$NETWORK/$NETWORK.dot"

HARDWARE_FILE="$TMPDIR/networks/$NETWORK/hardware.txt"
[ -e "$HARDWARE_FILE" ] && rm "$HARDWARE_FILE"

USECASE_FILE="$TMPDIR/networks/$NETWORK/usecase.txt"
[ -e "$USECASE_FILE" ] && rm "$USECASE_FILE"

# special overrride, e.g. schoeneck
[ -e "$TMPDIR/function_hostnames_$NETWORK" ] && rm "$TMPDIR/function_hostnames_$NETWORK"

log "[START] network '$NETWORK' for IP: '${REMOTE_ADDR:-empty}'"

case "$NETWORK" in
	'zumnorde'*)
		echo  >$OUT '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"'
		echo >>$OUT '	"http://www.w3.org/TR/html4/loose.dtd">'
		echo >>$OUT '<html><head><meta http-equiv="content-type" content="text/html; charset=UTF-8">'
		echo >>$OUT '<LINK REL="shortcut icon" TYPE="image/x-icon" HREF="/favicon.ico">'
		echo >>$OUT "<title>$NETWORK|meshRDF|$LOCALTIME|order=$SPECIAL_ORDER_BY</title>"
#		echo >>$OUT "<body bgcolor='crimson'><h1>server error - disc full (0% of 104.5 TB on /mnt/basti/zfs/tank/$NETWORK)</h1>"
		echo >>$OUT "<body bgcolor='lightgreen'><h1>Wartungsarbeiten - wir bitten um Geduld</h1>bittorf wireless ))&nbsp;&nbsp;<i>...your WiFi we care</i>"
		echo >>$OUT "</body><html>"

		cp "$OUT" "$REAL_OUT"
		rm "$OUT"

		exit 0
	;;
esac

FILE="/var/www/networks/$NETWORK/tarball/testing/tarball.tgz"
[ -e "$FILE" ] && {
	mkdir "$TMPDIR/untar"

	cd "$TMPDIR/untar"
	tar xzf "$FILE" './etc/variables_fff+' && . 'etc/variables_fff+'
	rm -fR 'etc'
	cd - >/dev/null
	rm -fR "$TMPDIR/untar"

	case "$NETWORK" in
		fparkssee)
			FFF_PLUS_VERSION=398383
		;;
	esac

	# TODO: respect 'stable' + 'beta'
	KALUA_VERSION_TESTING="${FFF_PLUS_VERSION:-0}"
	TARBALL_TIME="$KALUA_VERSION_TESTING"
#	echo "<!-- KALUA_VERSION_TESTING=$TARBALL_TIME -->"
}

touch "$TMPDIR/DETECTED_FAULTY_$NETWORK"

for FILE in $( find /var/www/networks/$NETWORK/vds -type f -name 'db_backup.tgz_*' ); do {
	BYTES=$( stat --printf="%s" "$FILE" )
	[ $BYTES -lt 500 ] && {
		log "FIXME! removing $FILE, $( stat --printf="%s" "$FILE" ) bytes"
		rm "$FILE"
	}
} done

FILE_FAILURE_OVERVIEW="./failure_overview.txt"
echo  >"${FILE_FAILURE_OVERVIEW}.tmp"		# for sorting HOSTNAME's
echo  >"$FILE_FAILURE_OVERVIEW" "Network overview - devices with failure:"
echo >>"$FILE_FAILURE_OVERVIEW" "Netzwerk Uebersicht - Geraete im Fehlerzustand:"
echo >>"$FILE_FAILURE_OVERVIEW" "-----------------------------------------------"

# logger "$0 building network $NETWORK"

last_remote_addr()
{
	local file ip r4
	local unixtime_max=0
	SUM_WIRELESS_CLIENTS=0

	for file in $( ls -1 /var/www/networks/$NETWORK/meshrdf/recent | grep "[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]"$ ); do { 

		r4=
		command . "/var/www/networks/$NETWORK/meshrdf/recent/$file"
		case "$r4" in
			[0-9]*)
				SUM_WIRELESS_CLIENTS=$(( SUM_WIRELESS_CLIENTS + r4 ))
			;;
		esac

		[ ${UNIXTIME:-0} -gt $unixtime_max ] && {
			unixtime_max="$UNIXTIME"
			ip="$PUBIP_REAL"
		}
	} done

	echo "$SUM_WIRELESS_CLIENTS" >"$TMPDIR/SUM_WIRELESS_CLIENTS"
	echo "$ip"
}

LAST_REMOTE_ADDR="$( last_remote_addr )"
read SUM_WIRELESS_CLIENTS <"$TMPDIR/SUM_WIRELESS_CLIENTS"
echo "$(date) | $SUM_WIRELESS_CLIENTS" >>"/var/www/networks/$NETWORK/media/SUM_WIRELESS_CLIENTS.txt"

cd "/var/www/networks/$NETWORK/meshrdf"				# fixme! or better use absolute paths everywhere?

echo     >$TOOLS '#!/bin/sh'
echo    >>$TOOLS '. /tmp/loader'
echo    >>$TOOLS ''
echo    >>$TOOLS '	cat >script.sh <<EOF'
echo    >>$TOOLS '. /tmp/loader'
echo	>>$TOOLS '# case "\$CONFIG_PROFILE" in *ap) touch /www/START_SYSUPGRADE.late ;; esac'
echo    >>$TOOLS '# killall dropbear'
echo	>>$TOOLS '# [ -e /www/SIMPLE_MESHNODE ] || { touch /www/SIMPLE_MESHNODE; rm /www/GOOD_MODULE_UNLOAD; reboot; }'
echo	>>$TOOLS '# [ -e $TMPDIR/fw ] && {'
echo	>>$TOOLS '# if cp $TMPDIR/fw /www; then'
echo    >>$TOOLS '# 	echo >>\$SCHEDULER_IMPORTANT "_firmware check_forced_upgrade"'
echo    >>$TOOLS '# else'
echo    >>$TOOLS '# 	rm $TMPDIR/fw'
echo    >>$TOOLS '# fi'
echo    >>$TOOLS '# }'
echo	>>$TOOLS '# _firmware update_pmu testing'
echo	>>$TOOLS '# uci set wireless.@wifi-iface[0].ssid="Hotel Berlin \$( uci get system.@profile[0].nodenumber )"; uci commit wireless'
echo	>>$TOOLS "# sed -i \"s/'etx_ff'/'etx_ffeth'/\" /etc/config/olsrd; echo 0 >$TMPDIR/STATS_OLSR_RESTARTS"
echo    >>$TOOLS "# echo 'autorun' >$TMPDIR/CRON_OVERLOAD"
echo	>>$TOOLS '# while :; do test \$(date +%M) = 44 && break; sleep 1; done; uci set wireless.radio0.channel=11; wifi; sleep 60'
echo    >>$TOOLS "# rm $TMPDIR/CRON_OVERLOAD"
echo	>>$TOOLS ''
echo    >>$TOOLS '# uci set olsrd.@meta[0].hnaslave=1; uci commit olsrd'
echo	>>$TOOLS '# uci set olsrd.@olsrd[0].LinkQualityAlgorithm=etx_ffeth'
echo	>>$TOOLS '# uci set olsrd.@Interface[0].Mode=ether; uci set olsrd.@Interface[1].Mode=mesh; uci commit olsrd'
echo    >>$TOOLS ''
echo	>>$TOOLS '# uname -a | grep -Fq " 3.14.29 " || {'
echo	>>$TOOLS '#	echo >\$SCHEDULER_IMPORTANT "_firmware check_forced_upgrade"'
echo	>>$TOOLS '#	_firmware update_pmu testing'
echo	>>$TOOLS '#	_watch monitoring'
echo	>>$TOOLS '# }'
echo	>>$TOOLS ''
echo	>>$TOOLS '# . $TMPDIR/loader; [ "\$( _system uptime min )" -gt 120 ] && reboot'
echo	>>$TOOLS '# touch "$TMPDIR/START_SYSUPGRADE"'
echo    >>$TOOLS '# rm "/etc/tarball_last_applied_hash"'
echo	>>$TOOLS '# scheduler -a ". $TMPDIR/loader; _firmware update_pmu testing"'
echo	>>$TOOLS '# scheduler -a "cron.upgrade_packages"'
echo	>>$TOOLS '# scheduler -a "cron.monitoring send_alive_message"'
echo	>>$TOOLS ''
echo	>>$TOOLS '# starts scp-ing a small file to originator/HNA, just for checking ssh-thrusting works'
echo	>>$TOOLS '# NN="\$( nvram get fff_node_number )";nvram get wan_hostname >$TMPDIR/NN;. $TMPDIR/loader; sleep "\$( _math random_integer 3 30 )"; scp -i /etc/dropbear/dropbear_dss_host_key $TMPDIR/NN $WIFIADR:$TMPDIR/COPYTEST/\$NN;rm $TMPDIR/NN'
echo    >>$TOOLS 'EOF'
echo    >>$TOOLS ''
echo    >>$TOOLS "chmod +x script.sh && grep -v ^# script.sh | sed -e 's/^[ ]*//g' -e 's/^[	]*//g' -e '/^$/d'"
echo    >>$TOOLS 'echo "really upload this file? press ENTER to go or CTRL+C to cancel";read KEY'
echo	>>$TOOLS ''
echo	>>$TOOLS 'ping_failed_10times() {'
echo	>>$TOOLS '	local i n=0'
echo	>>$TOOLS '	for i in 0 1 2 3 4 5 6 7 8 9; do if ping -qc 1 "$1" >/dev/null; then sleep 1; else n=$(( $n +1 )); fi; done'
echo	>>$TOOLS '	test $n -eq 10'
echo	>>$TOOLS '}'
echo	>>$TOOLS ''
echo    >>$TOOLS 'uptime_in_seconds()'
echo    >>$TOOLS '{'
echo    >>$TOOLS '	cut -d'.' -f1 /proc/uptime'
echo    >>$TOOLS '}'
echo    >>$TOOLS ''
echo    >>$TOOLS 'uptime_diff()'
echo    >>$TOOLS '{'
echo    >>$TOOLS '	echo $(( $(uptime_in_seconds) - $1 ))'
echo    >>$TOOLS '}'
echo    >>$TOOLS ''
echo    >>$TOOLS 'watch_sysupgrade() {		# fixme - node can reboot before sysupgrading starts, so detect reboot'
echo    >>$TOOLS '	local state t2 t1=$( uptime_in_seconds )'
echo    >>$TOOLS '	while true; do {'
echo    >>$TOOLS '		case "$state" in'
echo    >>$TOOLS '			sysupgrade_started)'
echo    >>$TOOLS '				if ping_failed_10times $WIFIADR; then'
echo    >>$TOOLS '					echo "waiting for appearing of node $WIFIADR"'
echo    >>$TOOLS '				else'
echo    >>$TOOLS '					echo "node $WIFIADR appeared: sysupgrade successful in $(uptime_diff $t1)s - $(date)"'
echo    >>$TOOLS '					break'
echo    >>$TOOLS '				fi'
echo    >>$TOOLS '			;;'
echo    >>$TOOLS '			*)'
echo    >>$TOOLS '				if ping_failed_10times $WIFIADR; then'
echo    >>$TOOLS '					state="sysupgrade_started"; t2=$( uptime_in_seconds )'
echo    >>$TOOLS '					echo "node $WIFIADR disappeared, sysupgrade started: $(date)"'
echo    >>$TOOLS '				else'
echo    >>$TOOLS '					echo "waiting since $(uptime_diff $t1)s for disappearing of node $WIFIADR (ping ok)"'
echo    >>$TOOLS '				fi'
echo    >>$TOOLS '			;;'
echo    >>$TOOLS '		esac'
echo    >>$TOOLS '	} done'
echo    >>$TOOLS '}'


echo	>>$TOOLS ''
echo    >>$TOOLS '# all nodes:'
printf  >>$TOOLS 'LIST="'

echo  >$OUT '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"'
echo >>$OUT '	"http://www.w3.org/TR/html4/loose.dtd">'
echo >>$OUT '<html><head><meta http-equiv="content-type" content="text/html; charset=UTF-8">'
echo >>$OUT '<LINK REL="shortcut icon" TYPE="image/x-icon" HREF="/favicon.ico">'
echo >>$OUT "<title>$NETWORK|meshRDF|$LOCALTIME|order=$SPECIAL_ORDER_BY|wireless:$SUM_WIRELESS_CLIENTS</title>"

echo >>$OUT '<script type="text/javascript">'
echo >>$OUT '<!-- stripped down version of http://kryogenix.org/code/browser/sorttable/ and applied crunchme'

#cat  >>$OUT '/var/www/scripts/sorttable.js_googleclosure.crunchme'
cat  >>$OUT '/var/www/scripts/sorttable.js_googleclosure'

echo >>$OUT '// -->'
echo >>$OUT '</script>'

echo >>$OUT '<style type="text/css">'
echo >>$OUT '<!-- '
echo >>$OUT 'table.sortable thead {'
echo >>$OUT '	background-color:#ffffff;'
echo >>$OUT '	color:#000000;'
echo >>$OUT '	font-weight: bold;'
echo >>$OUT '	cursor: default;'
echo >>$OUT '}'
echo >>$OUT '-->'
echo >>$OUT '</style>'

if [ "$( cat 2>/dev/null "/dev/shm/pingcheck/$NETWORK.faulty" )" = "sms" ]; then
	BODY_BGCOLOR="crimson"
	HEADLINE="<h3>heartbeat des Zentralger&auml;ts ausgefallen - Totalausfall seit $( date -d @$(stat -c "%Y" "/dev/shm/pingcheck/$NETWORK.faulty" ))</h3>"
else
	BODY_BGCOLOR=
	HEADLINE=
#	HEADLINE="<h3>Die Monitoring-Server hatten heute Nacht (Sonntag auf Montag) ein Problem, dies ist jedoch wieder behoben</h3>"
fi

echo >>$OUT "</head><body bgcolor='$BODY_BGCOLOR'>"

# checkout: http://stackoverflow.com/questions/7641791/javascript-library-for-human-friendly-relative-date-formatting
cat >>$OUT <<EOF
<p id='zeitstempel' data-timestamp_page='$UNIXTIME_SCRIPTSTART'> Datenbestand vom $( date "+%d.%b'%y-%H:%M" )</p>
<script type="text/javascript">
// tiny-relative-time.js
// Author: Max Albrecht <1@178.is>
// Public Domain

(function doTheRelativeTimestamp(update) {
  var timeStamp, unixDate, repeat, updater
  var viewing_secs = 0;
  // config
  repeat = true

  // main
  if (updater = RelativeTimestamper('zeitstempel')) {
    updater()
    if (repeat) setInterval(updater, 1000)
  }

  // lib
  function RelativeTimestamper(id) {
    if (timeStamp = document.getElementById(id)) {
      if (unixDate = timeStamp.getAttribute('data-timestamp_page')) {
        return updateTimestamp.bind(null,timeStamp, unixDate)
      }
    }
  }

  function updateTimestamp(node, seconds) {
    node.innerHTML = "Alter des Datenbestands: " + formatTimeDuration(timeAgo(seconds))
  }

  function timeAgo(seconds) {
    return ((new Date().getTime())/1000) - parseInt(seconds, 10)
  }

  function formatTimeDuration(seconds) {
    var d, h, m, s

    d = Math.floor(seconds / 86400)
    h = Math.floor((seconds % 86400) / 3600)
    m = Math.floor(((seconds % 86400) % 3600) / 60)
    s = Math.floor(((seconds % 86400) % 3600) % 60)

    // at 5:59, 10:59 ... sorry for hijacking this function. (basti)
    viewing_secs++;
    if (viewing_secs > 100 && s == 59 && ( m % 5 === 0 )) {
      location.reload();
    }

    return '' +
      ((d > 0) ? (d + ' Tage ') : ('')) +
      h + ' Stunde(n) ' +
      m + ' Minuten ' +
      s + ' Sekunden'
  }
}()) // <- self-executing module
</script>
EOF

echo >>$OUT "$HEADLINE<table cellspacing='1' cellpadding='1' border='1' class='sortable' id='haupt'><tr>"

NAME_ESSID="essid"
case "$NETWORK" in
	gnm)
		NAME_ESSID="temp"
	;;
esac

LIST="age pubssh/hostname version kernel git ram switch dhcp up wifiup olsrup klog speed Oin Oout load db"
LIST="$LIST hwmac $NAME_ESSID ch node profile storage nexthop tx(nh/gp) etx(nh) tx(nh) eff[%] m(nh) wifimode hop2gw cost2gw txpwr mrate"
LIST="$LIST gmode noise signal wifineighs wiredneighs speedTCP pfilter"

for COL in $LIST; do {

	printf '%s' "<th align='center'"

	LINK=
	LINK_START=
	LINK_END=
	LINK_TITLE=

	case "$COL" in
		"version")
			LINK="https://github.com/bittorf/kalua"
			LINK_TITLE="Alter in Tagen der Version des Kalua-Aufsatzes (Paketfilter/Loginseite)"
		;;
		"age")
			printf '%s' " title='vor wieviel Stunden, gab es die letzte aktive R&uuml;ckmeldung dieses Ger&auml;tes'"
		;;
		"kernel")
			LINK="http://kernel.org"
			LINK_TITLE="Linux-Kernel development"
		;;
		"git")
			LINK="http://nbd.name/gitweb.cgi?p=openwrt.git"
			LINK_TITLE="Development of the OpenWRT Linux-Distribution"
		;;
		"pubssh/hostname")
			printf '%s' " bgcolor='lime'"
		;;
		"m(nh)")
			printf '%s' " title='verwendete Modulationsart zum nexthop-Nachbarn (b|g|unbekannt)'"
		;;
	esac

	LINK_START="${LINK:+<a href='$LINK'${LINK_TITLE:+ title='}${LINK_TITLE}${LINK_TITLE:+'}>}"
	LINK_END="${LINK_START:+</a>}"

	printf '%s' "><small> ${LINK_START}${COL}${LINK_END} </small></th>"

} done >>$OUT
echo >>$OUT "</tr>"


hostname_sanitizer()
{
	local nodenumber_translate="$1"
	local file="$TMPDIR/function_hostnames_$NETWORK"
	local database="/var/www/networks/$NETWORK/$NETWORK-hostnames.sh"

#	hostnames_override() { :; }

	[ -e "$file" ] || {
		{
			echo '#!/bin/sh'
			echo "# generated @ $(date) from $0 for network $NETWORK"
			echo
			echo "hostnames_override()"	# each line is a function call to node()"
			echo "{"
			echo "	case \"\$1\" in"

			[ -e "$database" ] && {
			while read -r line; do {
				case "$line" in
					''|'#'*)
					;;
					*)
						# node 178 is HausB-1132-AP
						set -- $line
						echo "		$2) echo \":::$4\";;"
						
					;;
				esac
			} done <"$database"
			}

			echo "		*)"
			echo "			echo \"unknown_host\$1\""
			echo "		;;"
			echo "	esac"
			echo "}"
		} >"$file"

		.  "$file"
	}

	hostnames_override "$nodenumber_translate"
}

hostname_sanitizer 'dummy' >/dev/null	# inlude files, so we can call hostname_sanitizer()

func_update2color()
{
	local reason="$1"

	case "$reason" in
		'bad_version'*) echo 'crimson' ;;
		 stable) echo "green" ;;
	 	   beta) echo "orange" ;;
	  	testing) echo "#E0ACAC" ;;	# blassrot
		      *) echo "white" ;;
	esac
}

[ -n "$( ls -1 /var/www/networks/$NETWORK/meshrdf/recent/autonode* 2>/dev/null )" ] && rm /var/www/networks/$NETWORK/meshrdf/recent/autonode*
LIST_FILES="$( find /var/www/networks/$NETWORK/meshrdf/recent | grep "[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]"$ )"

for FILE in $LIST_FILES ; do {
	log "sourcing '$FILE'" debug
	command . "$FILE"

	grep -q ^"$WIFIMAC" ../ignore/macs.txt 2>/dev/null && {		# format: "0014bfbfb374    # linksys115"
		log "ignoring mac '$WIFIMAC'" debug
		continue
	}

	# fixme! touch each found neighbour?
#	echo "NEIGH: '$NEIGH'" >$TMPDIR/debug_table_$$

	C=0; for OBJ in $NEIGH; do {		# only when age is low
		C=$(( $C + 1 ))
		[ $C -eq 2 ] && {
			:
			#echo >"recent/autonode$OBJ" "NODE='$OBJ';UP='0';VERSION='0';REBOOT='0';WIFIMAC='112233445566';NEIGH='reference_from_$HOSTNAME';UNIXTIME='$LOCALUNIXTIME';HOST='-'"
		}

		[ $C -eq 8 ] && C=0		# fixme! wtf?!
	} done
} done
# unset IFS

#
# here we collect or allowed messages, so filtering must go here:
# TODO: use ARG1 for specific mac
#
LIST_FILES="$( find recent | grep "[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]"$ | sort )"
[ -n "$FORM_MAC" ] && {
	[ -e "recent/$FORM_MAC" ] && {
		LIST_FILES="recent/$FORM_MAC"
	}
}

# echo "<!-- pwd: '$( pwd )' list_files: '$LIST_FILES' -->" >>$OUT

ALL_NODENUMBERS=
DOUBLE_NODENUMBERS=
for FILE in $LIST_FILES LASTFILE; do {
	NODE=
	[ -e "$FILE" ] && {
		log "[double nodenumber] sourcing '$FILE'" debug
		. "$FILE"

		grep -sq ^"$WIFIMAC" ../ignore/macs.txt && {
			log "[double nodenumber] ignoring mac '$WIFIMAC'" debug
			continue
		}
	}

	case "$NODE" in
		''|0)
			log "[double nodenumber] ignoring mode '$MODE'" debug
			continue
		;;
	esac

	ALL_NODENUMBERS="$ALL_NODENUMBERS $NODE"
	case "$ALL_NODENUMBERS" in
		*" $NODE "*)
			DOUBLE_NODENUMBERS="$DOUBLE_NODENUMBERS $NODE "
		;;
	esac
} done

case "$NETWORK" in
	*'gnm'*|*'server'*)
		DOUBLE_NODENUMBERS=
	;;
esac

# chmod -R 777 /dev/shm/rrd ???
mkdir -p "/dev/shm/rrd"
mkdir -p "/dev/shm/rrd/$NETWORK"
rm 2>/dev/null /dev/shm/rrd/$NETWORK/*

for FILE in $LIST_FILES LASTFILE; do {
	[ $FILE = "LASTFILE" ] && {
		echo
		echo "<!-- node_lost ${NODE_LOST:-0} -->"
		echo "<!-- node_weak ${NODE_WEAK:-0} -->"
		echo "<!-- node_auto ${NODE_AUTO:-0} -->"
		echo "<!-- node_good ${NODE_GOOD:-0} -->"
		continue
	}

	secret=;D0=;k0=;k1=;k2=;k3=;u0=;w0=;w1=;w2=;w3=;t0=;t1=;n0=;d0=;d1=;i0=;i1=;i2=;i3=;i4=;i5=;i6=;r0=;r1=;r2=;r3=;r4=;r5=;r9=;h0=;h1=;h2=;h3=;h4=;h5=;h6=;h7=;s1=;s2=;v1=;v2=;NODE=;UP=;VERSION=;HOSTNAME=;WIFIMAC=;REBOOT=;CITY=;UPDATE=;NEIGH=;LATLON=;GWNODE=;TXPWR=;WIFIMODE=;CHANNEL=;COST2GW=;HOP2GW=;USERS=;MRATE=;LOAD=;HW=;UNIXTIME=;HUMANTIME=;FORWARDED=;SERVICES=;PUBIP_REAL=;PUBIP_SIMU=;MAIL=;PHONE=;SSHPUBKEYFP=;FRAG=;RTS=;GMODEPROT=;GW=;PROFILE=;NOISE=;RSSI=;GMODE=;ESSID=;BSSID=;WIFIDRV=;LOG=;OLSRVER=;OPTIMIZENLQ=;OPTIMIZENEIGH=;PORTFW=;WIFISCAN=;SENS=;PFILTER=

	# use real file, otherwise the stat-command is not useful
	[ -h "$FILE" ] && FILE="$( readlink -f "$FILE" )"

	log "[real] trying file '$FILE'" debug

	if [ -e "$FILE" ]; then
		LAST_UPDATE_UNIXTIME="$( stat --printf %Y "$FILE" )"
#		echo "<!-- worked on $FILE -->"
		command . "$FILE"


		# updates
		REMEMBER_VERSION="$VERSION"
		[ -e "${FILE}.changes" ] && . "${FILE}.changes"		# apply on top of main-dataset
		[ -z "$VERSION" ] && VERSION="$REMEMBER_VERSION"

		LATLON=		# FIXME!
				# default: 50.97389;11.31875

		case "$WIFIMAC" in
			827eb8dbbf0)		# RaspberryPi Max
				HW="Pandaboard"
			;;
		esac
	else
		log "[real] cannot work with '$FILE'" debug
		echo "<!-- NOT worked on $FILE -->"
		continue
	fi

	case "$NETWORK" in
		spbansin)
			case "$HOSTNAME" in
				'dhfleesensee-adhoc--68')
					HOSTNAME='Haus12-r1202-Traumdomizil'
				;;
			esac
		;;
		schoeneck)
			HOSTNAME_TEMP="$( hostname_sanitizer "$NODE" )"

			if [ -n "$HOSTNAME_TEMP" ]; then
				HOSTNAME="$HOSTNAME_TEMP"
			else
				HOSTNAME="miss${NODE}_${WIFIMAC}"
			fi
		;;
		apphalle)
			case "$NODE" in
				2) HOSTNAME='Haus2-OG5-Zimmer25' ;;
				3) HOSTNAME='Haupthaus-OG1-Buero' ;;
				4) HOSTNAME='Haupthaus-OG2z3-Kammer' ;;
				5) HOSTNAME='Haus2-OG2-Zimmer9' ;;
				6) HOSTNAME='Haupthaus-OG4-Zimmer32' ;;
				7) HOSTNAME='Haupthaus-OG5-Zimmer36' ;;
				8) HOSTNAME='Haus2-OG1-Zimmer3' ;;
				9) HOSTNAME='Haus2-OG6-KammerAP' ;;
				11) HOSTNAME='Haupthaus OG2-Zimmer16' ;;
				12) HOSTNAME='Haupthaus-OG3-Zimmer24' ;;
				13) HOSTNAME='Haupthaus-OG1z2-Kammer' ;;
				14) HOSTNAME='Haus2-OG6-KammerMESH' ;;
				47) HOSTNAME='Haus2-OG4-Zimmer18' ;;
			esac
		;;
	esac

#	case "$HW" in
#		'D-Link DIR-505'*)
#		;;
#		*)
#			continue
#		;;
#	esac

	grep -sq ^"$WIFIMAC" ../ignore/macs.txt && {				# format: "0014bfbfb374	   # linksys115"
		log "omitting $WIFIMAC/$HOSTNAME" debug

		if grep -q ^"$WIFIMAC	# autohide" '../ignore/macs.txt'; then
			# autohide / autounhide
			[ $(( UNIXTIME_SCRIPTSTART - LAST_UPDATE_UNIXTIME )) -lt 864000 ] && {
				grep -q ^"# $WIFIMAC	# younger than 10 days" '../ignore/macs.txt' || {
					# delete old and show comment: TODO: sms?
					sed -i "/^$WIFIMAC/d" '../ignore/macs.txt'
					echo "# $WIFIMAC	# younger than 10 days - auto_unhided @$( date )" >>'../ignore/macs.txt'
				}
			}
		else
			[ $(( UNIXTIME_SCRIPTSTART - LAST_UPDATE_UNIXTIME )) -lt 864000 ] && {
				set -x
				set +x "$WIFIMAC active but hidden"
			}
		fi

		case "$HOSTNAME" in
			*'--'*)
				# otherwise w3c-validator fails with:
				# invalid comment declaration: found digit outside comment but inside comment declaration
				echo "<!-- omitted: $WIFIMAC ('$( echo "$HOSTNAME" | sed 's/--/-/g' )') -->"
			;;
			*)
				echo "<!-- omitted: $WIFIMAC ('$HOSTNAME') -->"
			;;
		esac

		continue
	}

	rrdfile_for_hostname()
	{
		local rrd time

		# e.g.: traffic_RH-s31moskau-AP_2013aug23_04.00.png
		# with hostname RH-s31moskau-AP
		# or
		# xxxHausA-KellerZimmerEDV-MESH
		rrd="$( ls -1t /var/www/networks/$NETWORK/media/*_${HOSTNAME}_* 2>/dev/null | head -n1 )"

# logger -s "NETWORK: $NETWORK rrd: $rrd HOSTNAME: $HOSTNAME"
		[ -z "$rrd" ] && {
			# xxxHausA-KellerZimmerEDV-MESH -> HausA-KellerZimmerEDV-MESH
			local hostname="$( echo "$HOSTNAME" | cut -b4- )"
			rrd="$( ls -1t /var/www/networks/$NETWORK/media/*_${hostname}_* 2>/dev/null | head -n1 )"
# logger -s "NETWORK: $NETWORK rrd: $rrd HOSTNAME: $hostname"
			[ -z "$rrd" ] && {
				# xxxHausA-KellerZimmerEDV-MESH -> HausA-KellerZimmerEDV-MESH -> HausA-KellerZimmerEDV
				hostname="$( echo "$hostname" | sed 's/^\(.*\)-MESH/\1/' )"
				rrd="$( ls -1t /var/www/networks/$NETWORK/media/*_${hostname}_* 2>/dev/null | head -n1 )"
# logger -s "NETWORK: $NETWORK rrd: $rrd HOSTNAME: $hostname"
			}
		}
# logger -s "is rrd: $rrd"
		[ -z "$rrd" ] && return 1

		time=$( stat -c "%Y" "$rrd" )
		# no old shit:
		[ $(( $UNIXTIME_SCRIPTSTART - $time )) -gt 86400 ] && return 1

#		logger -s "found RRD: $rrd"
		basename "$rrd"
	}
#logger -s "cheching for rrd: $HOSTNAME"
	if [ -z "$HOSTNAME" ]; then
		log "bad hostname: '$HOSTNAME'" debug
		continue
	else
		touch "/dev/shm/rrd/$NETWORK/rrd_images"
		rrdfile_for_hostname "$HOSTNAME" >>"/dev/shm/rrd/$NETWORK/rrd_images"
#logger -s "NETWORK: $NETWORK $( ls -l "/dev/shm/rrd/$NETWORK/rrd_images" )"
	fi

	if [ "$WIFIMAC" = "112233445566" ]; then
		WIFIMAC="-"
		UNIXTIME="$( stat -c "%Y" $FILE )"					# last change
		NODE_AUTO="$(( $NODE_AUTO + 1 ))"
	else
		[ -e "recent/autonode$NODE" ] && {
#			printf '%s' "rm $NODE, " >>$TMPDIR/debug_table_$$
			rm "recent/autonode$NODE"		# now normal node
		}

		case "$v2" in
			40000)	# openwrt-revision

				case "$HW" in
					"disabled_TP-LINK TL-WR1043ND")
						REM_SPECIALGIT="r31465+tplink"		# was r30563
						printf '%s' "$NODE " >>"$TMPDIR/list_specialgit.$$"
					;;
				esac
			;;
		esac

		case "$NETWORK-$HW" in
			'schoeneck-TP-LINK TL-WR1043ND')
				case "$v2" in
					38679)
					;;
					*)
						REM_SPECIALGIT="$NETWORK-$HW"
						printf '%s' "$NODE " >>"$TMPDIR/list_specialgit.$$"
					;;
				esac
			;;
		esac

		case "$HW" in
			"disabled_TP-LINK TL-WR1043ND")
				echo "$HW" >"$TMPDIR/list_specialhw.txt"
				printf '%s' "$NODE " >>"$TMPDIR/list_specialhw.$$"
			;;
			'Ubiquiti Bullet M')
				echo "$HW" >"$TMPDIR/list_specialhw.txt"
				printf '%s' "$NODE " >>"$TMPDIR/list_specialhw.$$"
			;;
		esac

		if [ "$WIFIMODE" = "adhoc" ]; then
			printf '%s' "$NODE " >>"$TMPDIR/list_adhoc_mode.$$"
		else
			printf '%s' "$NODE " >>"$TMPDIR/list_ap_mode.$$"
		fi

		printf '%s' "$NODE " >>$TOOLS
	fi

	# fixme! if unixtime on node is unset, but monitoring works we should take delivery time
	LASTSEEN="$(( $LOCALUNIXTIME - ${UNIXTIME:=0} ))"

# abooooooow: error 2013dez10
#	[ "$VERSION" -ge 385184 ] || LASTSEEN=0

#	case "$NETWORK" in
#		boltenhagendh*)
#			case "$HOSTNAME" in
#				'DH'*)
#					LASTSEEN=0	# dorfhotel pause
#				;;
#				*)
#					LASTSEEN=0
#				;;
#			esac
#		;;
#	esac

	# 2 hours
	[ $LASTSEEN -gt 7200 ] && {
		[ $( stat -c "%Y" $FILE ) -gt $UNIXTIME ] && {
			UNIXTIME=$( stat -c "%Y" $FILE )
			LASTSEEN=$(( $LOCALUNIXTIME - $UNIXTIME ))
		}
	}

	[ $LASTSEEN -gt 350000 ] && {		# 97 hours
		LASTSEEN="$(( $LOCALUNIXTIME - $( stat -c "%Y" "$FILE" ) ))"		# Y = "last modification time"
	}

	log "LASTSEEN: $LASTSEEN" debug

	case "$NETWORK" in
		X-liszt28|X-gnm|X-apphalle|X-abtpark|X-ewerk|ilm1)
			# in minutes - please also adjust in _cell_lastseen()
			LASTSEEN="$(( $LASTSEEN /   60 ))"
			AGE_BORDER=9999
		;;
		*)
			# in hours
			LASTSEEN="$(( $LASTSEEN / 3600 ))"
			AGE_BORDER=99
		;;
	esac

	LASTSEEN_ORIGINAL="$LASTSEEN"
	[ "$LASTSEEN" -gt $AGE_BORDER ] && {
		DIRTY=0
		ALL_NETWORKS="$( ls -1 /var/www/networks | grep -v ^${NETWORK}$ )"
		for I in $ALL_NETWORKS; do {
			[ -e /var/www/networks/$I/meshrdf/recent/$WIFIMAC ] && {
				[ "$( stat -c "%Y" /var/www/networks/$I/meshrdf/recent/$WIFIMAC )" -gt "$( stat -c "%Y" $FILE )" ] && {
					rm $FILE
					echo
					echo "<!-- ###### deleted $WIFIMAC - $I also has this newer ##### -->"
					echo
					DIRTY=1
				}
			}
		} done
		[ $DIRTY = 1 ] && continue

		LASTSEEN="$AGE_BORDER"				# fixme! must be integer! (make humanreadable)
	}

	echo >>$IPKG "$WIFIMAC"

	WIFINEIGHS="$( echo $NEIGH | sed 's/[^~]//g' | wc -c )"
	WIFINEIGHS="$(( $WIFINEIGHS - 1 ))"

	WIREDNEIGHS="$( echo $NEIGH | sed 's/[^-]//g' | wc -c )"
	WIREDNEIGHS="$(( $WIREDNEIGHS - 1 ))"

	RSSI="$( echo $RSSI | sed 's/:/<br>/g' )"

	case $WIFIMODE in
		ap|master)
			BGCOLOR="#408080"
		;;
		client)
			BGCOLOR="#7fffd4"
		;;
#		hybrid)
#			BGCOLOR="yellow"
#		;;
		*)
			BGCOLOR="#C0C0C0"
		;;
	esac

	case $( echo $HOSTNAME | cut -b1-2 ) in
		EG) FILL="E0-" ;;
		KG) FILL="00-" ;;
		 *) FILL="" ;;		# for sorting with '${FILL}${HOSTNAME}'
	esac

	COST2GW_X="$( echo $COST2GW|sed 's/\.//g'|sed 's/[^0-9]//g' )"
	[ -n "$COST2GW_X" ] && [ $COST2GW_X -lt 10000 ] && COST2GW_X="0${COST2GW_X}"	# for sorting

func_cell_cost2gw ()
{
	local VALUE="$1"
	local NETWORK="$2"
	local IP

	if [ "$VALUE" = "10" ] || [ "$VALUE" = "1" ] || [ "$VALUE" = "1.00" ] || [ "$VALUE" = "0" ] || [ -z "$VALUE" -a "$NETWORK" = "rehungen" ]; then

		if [ "$PUBIP_SIMU" = "$PUBIP_REAL" ] || [ -z "$PUBIP_SIMU" ] ; then
			IP="$PUBIP_REAL"
		else
			IP="$PUBIP_SIMU/$PUBIP_REAL"
		fi

		printf '%s' "<td bgcolor='lightblue' align='center'><a href='http://${IP:-IPv4}/' title='${IP:-109.73.30.34}'> ${VALUE:-IPv4} </a></td>"	# fixme!
	else
		case "$NETWORK-$VALUE" in
			"rehungen-1.000")
				printf '%s' "<td bgcolor='lime'> $VALUE </td>"
			;;
			"rehungen-0.100")
				printf '%s' "<td bgcolor='green'> $VALUE </td>"
			;;
			"rehungen-"|rehungen-1.*|rehungen-2.*)
				printf '%s' "<td > $VALUE </td>"		# fixme! mcast_rate/cost!
			;;
			"rehungen-"*)
				printf '%s' "<td bgcolor=orange> $VALUE </td>"
			;;
			*)
				if test 2>/dev/null $VALUE -eq $VALUE; then
					if [ $VALUE -gt 2000 ]; then
						printf '%s' "<td bgcolor='crimson'> $VALUE </td>"
					else
						printf '%s' "<td> $VALUE </td>"
					fi
				else
					printf '%s' "<td> $VALUE </td>"
				fi
			;;
		esac
	fi
}

func_cell_wifimode ()
{
	local VALUE="$1"
	local WIFIDRV="$2"
	local COLOR=

	[ "$HW" = "Pandaboard" ] && { printf '%s' "<td>&nbsp;</td>"; return 0; }    # fixme!

#	if [ -n "$WIFIDRV" ]; then
#
#		case "$WIFIDRV" in
#			*2.6.36*)
#				printf '%s' "<td bgcolor=lime nowrap><a href='#' title='wifi:$WIFIDRV olsr:${OLSRVER:version_unknown}'> $VALUE </a></td>"
#			;;
#			*2.6.32.25*)
#				case "$OLSRVER" in
#					*etx_ffeth*)
#						COLOR="khaki"
#					;;
#					*)
#						COLOR="lightblue"
#					;;
#				esac
#
#				printf '%s' "<td bgcolor='$COLOR' nowrap><a href='#' title='wifi:$WIFIDRV olsr:${OLSRVER:version_unknown}'> $VALUE </a></td>"
#			;;
#			*)
#				printf '%s' "<td nowrap><a href='#' title='wifi:$WIFIDRV olsr:${OLSRVER:version_unknown}'> $VALUE </a></td>"
#			;;
#		esac
#	else

	case "$WIFIDRV" in
		*24026*) COLOR="lightblue" ;;
		*23885*) COLOR="khaki" ;;
		*24107*) COLOR="lime" ;;
	esac

	case "$OLSRVER" in
		*'2010-11-17'*) COLOR="pink" ;;
		*'ff1.6.36'*) COLOR="crimson" ;;
		*'0.5.6-r'*)
			case "$OLSRVER" in
				# https://lists.olsr.org/pipermail/olsr-users/2010-September/004179.html
				# https://lists.olsr.org/pipermail/olsr-users/2010-September/004163.html
				*'0.5.6-r1'*|*'0.5.6-r2'*|*'0.5.6-r3'*|*'0.5.6-r4'*|*'0.5.6-r5'*)
					COLOR="crimson"
				;;
			esac
		;;
		*'git_f73979c'*) COLOR="lightblue" ;;	# 2011-mar-23
	esac

	case "$WIFIDRV" in
		*adhocap*) COLOR="yellow" ;;
	esac

#		printf '%s' "<td title='$WIFIDRV $OLSRVER' nowrap bgcolor='$COLOR'>&nbsp;${OLSRVER}&nbsp;${VALUE}&nbsp;</td>"
		printf '%s' "<td title='$WIFIDRV $OLSRVER' nowrap bgcolor='$COLOR'>${VALUE}</td>"
#	fi
}

func_cell_hostname ()
{
	local HOSTNAME="$1"
	local WIFIMAC="$2"
	local MAIL="$3"
	local FILE="../registrator/recent/$WIFIMAC"
	local title bgcolor c1 c2
	local SIMULATE_OK='true'

	[ -n "$MAIL" ] && {
		MAIL="$( echo $MAIL | sed -e 's/@/ _(at)_/g' -e 's/\./ _DOT_ /g' )"
	}

	case "$MAIL" in
		"wlan-assistance"*|"")
			title="rot hinterlegte Hostnamen symbolisieren einen nicht fertig aufgebauten Vertrauensbaum, dies behebt sich von selbst nach ca. 60 Minuten"
		;;
		*)
			title="email: $MAIL"
		;;
	esac

	filesize_in_bytes()
	{
		stat --printf="%s" "$1"
	}

	if [ -e "$FILE" ]; then
		if [ $( filesize_in_bytes "$FILE" ) -lt 910 ]; then
			bgcolor='yellow'
			title="filesize: $( filesize_in_bytes "$FILE" )"
		else
			:
			# bgcolor='green'
		fi
	else
		[ "$NETWORK" = "gnm" ] || {
			bgcolor="$COLOR_ORANGE"
			title="datei $FILE existiert nicht?"

#			HOSTNAME="$(pwd)$FILE"
		}
	fi

	needs_better_name()
	{
		local hostname="$1"
		local hostname_enforced="$2"

		[ -n "$hostname_enforced" ] && hostname="$hostname_enforced"

		case "$hostname" in
			'wifimac'*)
				return 0
			;;
			"$NETWORK-"*"--"*)
				# e.g. liszt28-hybrid--798
				return 0
			;;
			*)
				case "$NETWORK" in
					'schoeneck')
						return 1
					;;
					*)
						[ -e "../settings/$WIFIMAC.hostname" ] || {	# autosafe for building mysettings.ipk
							mkdir -p ../settings
							echo "$HOSTNAME" >"../settings/$WIFIMAC.hostname"
						}						# FIXME! how to rewrite?
					;;
				esac

				return 1
			;;
		esac
	}

	case "$NETWORK" in
		schoeneck)
			case "$HOSTNAME" in
				'xxx'*)
#					HOSTNAME_ENFORCED=
				;;
				*)
#					[ -n "$HOSTNAME_ENFORCED" ] && {
#						HOSTNAME="$HOSTNAME_ENFORCED"
#						HOSTNAME_ENFORCED=
#					}
				;;
			esac
		;;
		*)
			if [ -e "../settings/$WIFIMAC.hostname" ]; then
				read HOSTNAME_ENFORCED <"../settings/$WIFIMAC.hostname"
			else
				HOSTNAME_ENFORCED=
			fi
		;;
	esac

	if needs_better_name "$HOSTNAME" "$HOSTNAME_ENFORCED" ; then
			printf '%s' "<td nowrap bgcolor='$bgcolor' title='$title'>"
			printf '%s' "<form action='' method='get'>"
			printf '%s' "<input type='text' value='$HOSTNAME' name='FORM_HOSTNAME'>"
			printf '%s' "<input type='hidden' name='FORM_HOSTNAME_SET' value='$WIFIMAC'>"
			printf '%s' "<input type='submit' value='OK'>"
			printf '%s' "</form>"
			printf '%s' "</td>"
	else
		[ -n "$HOSTNAME_ENFORCED" ] && {
			[ "$HOSTNAME_ENFORCED" = "$HOSTNAME" ] || {
				case "$HOSTNAME" in
					"$( echo "$PROFILE" | cut -d'_' -f1 )"*)	# hotello-K80_adhoc -> hotello-K80-adhoc/ap
						HOSTNAME="$HOSTNAME_ENFORCED"
					;;
					*'-vhs'|'No'[0-9]*)
						# use the enforced name and not the
						# real hostname (e.g. ffweimar-vhs or No1975)
						HOSTNAME="$HOSTNAME_ENFORCED"
					;;
					*)
						HOSTNAME="enforced/settings: $HOSTNAME_ENFORCED&nbsp;(&larr;$HOSTNAME = real)"
					;;
				esac

				# bgcolor='blue'
				title='Serverseitig erzwungener Hostname ist noch nicht applied'
			}
		}

		HOSTNAME_FOR_SORTING="$HOSTNAME"

		case "$NETWORK" in
			spbansin)
				case "$HOSTNAME" in
					*'-HYBRID'|*'-MESH'|*'-AP')
						HOSTNAME="${HOSTNAME%-*}"
					;;
				esac

				case "$HOSTNAME" in
					*'ueberHWR'*)
						HOSTNAME="$( echo "$HOSTNAME" | sed 's/^\(.*\)ueberHWR.*/\1HeizhausOben/' )"
					;;
					*'HWR'*)
						HOSTNAME="$( echo "$HOSTNAME" | sed 's/^\(.*\)HWR.*/\1Heizhaus-Zentrale/' )"
					;;
				esac

				c1="$COLOR_GOOD_GREEN"
				c2="$COLOR_BRIGHT_GREEN"
				case "$HOSTNAME" in
					'Haus12'*) bgcolor="$c1"; HOSTNAME_FOR_SORTING="12-$HOSTNAME";;
					'Haus11'*) bgcolor="$c2"; HOSTNAME_FOR_SORTING="11-$HOSTNAME";;
					'Haus10'*) bgcolor="$c1"; HOSTNAME_FOR_SORTING="10-$HOSTNAME";;
					'Haus9'*) bgcolor="$c2"; HOSTNAME_FOR_SORTING="09-$HOSTNAME";;
					'Haus8'*) bgcolor="$c1"; HOSTNAME_FOR_SORTING="08-$HOSTNAME";;
					'Haus7'*) bgcolor="$c2"; HOSTNAME_FOR_SORTING="07-$HOSTNAME";;
					'Haus6'*) bgcolor="$c1"; HOSTNAME_FOR_SORTING="06-$HOSTNAME";;
					'Haus4'*) bgcolor="$c2"; HOSTNAME_FOR_SORTING="04-$HOSTNAME";;
					'Haus3'*) bgcolor="$c1"; HOSTNAME_FOR_SORTING="03-$HOSTNAME";;
					'Haus2'*) bgcolor="$c2"; HOSTNAME_FOR_SORTING="02-$HOSTNAME";;
					'Haus1'*) bgcolor="$c1"; HOSTNAME_FOR_SORTING="01-$HOSTNAME";;
				esac

	                        SIMULATE_OK=
			;;
		esac

		read STORED_HOSTNAME 2>/dev/null <"$TMPDIR/goodhostname_$WIFIMAC"
		[ "$STORED_HOSTNAME" = "$HOSTNAME" -o ! -e "$TMPDIR/goodhostname_$WIFIMAC" ] || {
			echo "$HOSTNAME" >"$TMPDIR/goodhostname_$WIFIMAC"
		}

		[ -n "$SIMULATE_OK" ] && bgcolor=
		case "$HOSTNAME" in
			*'vhsRaum'*)
				printf '%s' "<td nowrap bgcolor='$bgcolor' title='$title'> $HOSTNAME - IP: $PUBIP_REAL</td>"
			;;
			*)
				printf '%s' "<td nowrap bgcolor='$bgcolor' title='$title'> $HOSTNAME </td>"
			;;
		esac
	fi
}

func_cell_disk_free ()
{
	local ARG1="${1:--1kb}"
	local usb_plugged_in="$2"
	local crit_border=130
	local USB OUT bgcolor

	case "$ARG1" in
		*"usbstorage.free.kb"*)
			USB="$( echo $ARG1 | sed -n 's/^.*usbstorage.free.kb:\([0-9]*\).*/\1/p' )"	# print numbers
			bgcolor="lime"
		;;
	esac

	head_and_color()
	{
		local bgcolor="$1"
		CELL_HAS_CONTENT="true"

		if [ -n "$bgcolor" ]; then
			printf '%s' "<td nowrap sorttable_customkey='$OUT' align='right'>"
		else
			printf '%s' "<td nowrap sorttable_customkey='$OUT' align='right' bgcolor='$bgcolor'>"
		fi
	}

	case "$ARG1" in
		*"flash.free.kb"*)
			OUT="$( echo $ARG1 | sed -n 's/^.*flash.free.kb:\([0-9]*\).*/\1/p' )"		# print numbers

			case "$ARG1" in
				*'M'|*'MB')
					OUT=$(( $OUT * 1024 ))
				;;
				*'G'|*'GB')
					OUT=$(( $OUT * 1024 * 1024 ))
				;;
			esac

			if [ ${OUT:-0} -le $crit_border ]; then
				head_and_color "crimson"

				[ -n "$USB" ] && {
					printf '%s' "$USB|"
				}

				printf '%s' "<font color='red'><b>"
				printf '%s' "$OUT"
				printf '%s' "</b></font>"

			else
				head_and_color "$bgcolor"

				[ -n "$USB" ] && {
					printf '%s' "$USB|"
				}

				[ $OUT -lt $crit_border ] && {
					printf '%s' "<font color='red'><b>"
				}

				printf '%s' "$OUT"

				[ $OUT -lt $crit_border ] && {
					printf '%s' "</b></font>"
				}
			fi
		;;
	esac

	case "$ARG1" in
		*".free."*)
			:
		;;
		"")
			:
		;;
		*)	# old style, e.g. 324kb

			OUT="$( echo $ARG1 | sed -n 's/\([0-9]*\)kb/\1/p' )"

			if [ $OUT -lt $crit_border ]; then
				head_and_color "crimson"
			else
				head_and_color "blue"
			fi

			printf '%s' "$OUT"
		;;
	esac

	[ -n "$CELL_HAS_CONTENT" ] || {
		printf '%s' "<td>&nbsp;"
	}

	[ "$usb_plugged_in" = "1" ] && {
		printf '%s' "&sup;"
	}

	printf '%s' "</td>"
}

func_cell_uptime ()
{
	local UPTIME="$1"
	local REBOOT_COUNT="$2"
	local reboot_reason="$3"

	local fwversion="${VERSION:-0}"
	local STARTDATE="$( date -d @$(( $UNIXTIME_SCRIPTSTART - (${UPTIME:=0} * 3600) )) )"
	local border_allowed_reboots=
	local seconds_per_day=86400

#	printf '%s' "<!-- uptime: $UPTIME REBOOT_COUNT: $REBOOT_COUNT fwversion: $fwversion STARTDATE: $STARTDATE -->"

	case "$fwversion" in
		*[!0-9]*)
			border_allowed_reboots=99	# fixme!
		;;
		*)
			border_allowed_reboots=$(( $fwversion * 3600 ))					# unixtime fwversion
			border_allowed_reboots=$(( $UNIXTIME_SCRIPTSTART - $border_allowed_reboots ))	# age in seconds of firmware
			border_allowed_reboots=$(( $border_allowed_reboots / $seconds_per_day ))	# age of firmware in days
			border_allowed_reboots=$(( $border_allowed_reboots * 4 ))			# allow 4 reboots per day
			[ $border_allowed_reboots -eq 0 ] && border_allowed_reboots=4
		;;
	esac

	printf '%s' "<td align='right' sorttable_customkey='${REBOOT_COUNT:=0}'"

	if [ "${REBOOT_COUNT:=0}" -gt $border_allowed_reboots ]; then
		if [ $REBOOT_COUNT -gt $(( $border_allowed_reboots * 10 )) ]; then
			printf '%s' " bgcolor='black'>"
		else
			printf '%s' " bgcolor='$COLOR_ORANGE'>"
		fi
	else
		if [ "$reboot_reason" = 'nightly_reboot' ]; then
			printf '%s' " bgcolor='$COLOR_BRIGHT_GREEN'>"
		else
			printf '%s' ">"
		fi
	fi

	printf '%s' "<a href='#' title='$reboot_reason@$STARTDATE|${REBOOT_COUNT}_reboots!/border=$border_allowed_reboots'> $UPTIME </a></td>"
}

cell_wifi_uptime()
{
	local wifi_dev="$1"
	local wifi_restart="${2:-0}"
	local wifi_uptime="$3"
	local restart_reason="$4"

	[ "$HW" = "Pandaboard" ] && { printf '%s' "<td>&nbsp;</td>"; return 0; }    # fixme!

	if   [ ${wifi_uptime:-0} -gt 3600 ]; then
		wifi_uptime="$(( $wifi_uptime / 3600 ))h"
	elif [ ${wifi_uptime:-0} -gt 60 ]; then
		wifi_uptime="$(( $wifi_uptime / 60 ))m"
	fi

	if   [ -z "$wifi_dev" ]; then
		printf '%s' "<td>&nbsp;</td>"
	elif [ "$wifi_dev" = "wlan0" -o "$wifi_dev" = "wlan0-1" -o "$wifi_dev" = "ath0" ]; then
		if [ "$wifi_restart" = "0" ]; then
			printf '%s' "<td bgcolor='lime' align='center'><small>ok</small></td>"
		else
			printf '%s' "<td title='$restart_reason' nowrap>$wifi_restart:$wifi_uptime</td>"
		fi
	else
		printf '%s' "<td title='$restart_reason' nowrap>$wifi_dev:$wifi_restart:$wifi_uptime</td>"
	fi
}

func_cell_uptime_olsr ()
{
	local LAST_RESTART_TIME="$1"
	local RESTART_COUNT="$2"	# off|5|batman off|batman 5
	local BOX_UPTIME="$3"		# [hours]

	[ "$HW" = "Pandaboard" ] && { printf '%s' "<td>&nbsp;</td>"; return 0; }    # fixme!

	case "$RESTART_COUNT" in
		*off|batman*)
			printf '%s' "<td align='center' bgcolor='lime' nowrap><small>$RESTART_COUNT</small></td>"
			case "$RESTART_COUNT" in
				*off)
					return 0
				;;
				*)
					return 0	# fixme!
				;;
			esac
		;;
	esac

	local BGCOLOR="crimson"
	local UNIT="min"
	local UNIXTIME_NOW="$UNIXTIME_SCRIPTSTART"

	local BOX_UPTIME_SEC="$(( ${BOX_UPTIME:=0} * 3600 ))"
	local UPTIME_OLSR="$(( $UNIXTIME_NOW - ${LAST_RESTART_TIME:=0} ))"

	[ $UPTIME_OLSR -ge $BOX_UPTIME_SEC -o $UPTIME_OLSR -lt 0 ] && {
		BGCOLOR=""
		UPTIME_OLSR=$BOX_UPTIME_SEC
	}

	UPTIME_OLSR=$(( $UPTIME_OLSR / 60 ))					#   [s] -> [min]

	[ $UPTIME_OLSR -gt 59 ] && {
		BGCOLOR="#E0ACAC"				# blassrot
		UPTIME_OLSR=$(( $UPTIME_OLSR / 60 ))		# [min] -> [h]
		UNIT="h"
	}

	BGCOLOR="#E0ACAC"	# blassrot

	[ $UPTIME_OLSR -gt 480 ] && BGCOLOR=""

	local percent
	local restart_per_day

	restart_too_often()
	{
		local uptime_in_days=$(( $BOX_UPTIME / 24 * 3 ))
		local border=$(( $uptime_in_days + 30 ))

#		restarts_per_day="$(( $RESTART_COUNT / $uptime_in_days )).$(( $RESTART_COUNT % $uptime_in_days ))"
		restarts_per_day="3"

		percent=$(( $RESTART_COUNT * 100 ))
		percent=$(( $percent / $border ))

		if [ $percent -gt 99 ]; then
			return 0
		else
			return 1
		fi
	}

	content()
	{
		echo "$UPTIME_OLSR$UNIT&nbsp;($RESTART_COUNT=${percent}%)"
	}

	if restart_too_often ; then

		printf '%s' "<td bgcolor='crimson' title='olsrd-restarts:$RESTART_COUNT' align='right'>$( content )</td>"
	else
		# keep calm when >12h
		[ $UPTIME_OLSR -ge 12 ] && RESTART_COUNT=0

		case "$RESTART_COUNT" in
			0|1)
				BGCOLOR="lime"
				printf '%s' "<td bgcolor='$BGCOLOR' title='olsrd-restarts:$RESTART_COUNT' align='center'><small>ok</small></td>"
			;;
			*)
				printf '%s' "<td bgcolor='$BGCOLOR' title='olsrd-restarts:$RESTART_COUNT' align='right'>$( content )</td>"
			;;
		esac
	fi
}

cell_klog()
{
	local rt_throttling="$1"
	local lines_boot="${2:-0}"
	local lines_log="${3:-0}"
	local coredumps="${4:-0}"
	local diff=$(( $lines_log - $lines_boot ))
	local bgcolor='lime'

	if [ -z "$rt_throttling" ]; then
		[ $diff -eq 0 ] || bgcolor='orange'

		if [ $coredumps -eq 0 -o $coredumps -eq -1 ]; then	# FIXME! bug in monitoring script: '-1'
			[ "$diff" = '0' ] && diff='&mdash;'
		else
			bgcolor='orange'
			[ "$diff" = '0' ] && diff=
			diff="$diff+$coredumps"
		fi

		printf '%s' "<td align='center' sorttable_customkey='$diff' bgcolor='$bgcolor' title='$lines_boot/$lines_log'>$diff</td>"
	else
		printf '%s' "<td align='right' sorttable_customkey='${rt_throttling}' title='$lines_boot/$lines_log'>RT:${rt_throttling}s</td>"
	fi
}

cell_speed()
{
	local bytes="$1"	# [bytes/s]
	local kbytes bgcolor

	if [ -z "$bytes" ]; then
		kbytes=
	else
		if [ $bytes -lt 1000 ]; then
			kbytes=1
		else
			kbytes=$(( $bytes / 1000 ))
		fi
	fi

	case "${NETWORK}_${WIFIMODE}" in
		schoeneck_adhoc)
			bytes=0
			kbytes="<small>OK</small>"
		;;
	esac

	case "$NODE" in
		2)			# typical inet-offer
			bytes=0
			kbytes="<small>OK</small>"
		;;
	esac

	[ -z "$bytes" ] && bgcolor="$COLOR_DARK_GREEN"
	case "$kbytes" in
		*'8888')
			bgcolor="$COLOR_GOOD_GREEN"
		;;
	esac

	printf '%s' "<td align='right' bgcolor='$bgcolor' sorttable_customkey='$bytes'>$kbytes</td>"
}

cell_olsr_wifi_in()
{
	local bytes="${1:-0}"

	[ "$HW" = "Pandaboard" ] && { printf '%s' "<td>&nbsp;</td>"; return 0; }    # fixme!

	printf '%s' "<td align='right'>$bytes</td>"
}

cell_olsr_wifi_out()
{
	local bytes="${1:-0}"
	local speed="$2"	# 6
	local metric="$3"	# etxff_eth
	local tip=
	local title="speed:$speed,metric:$metric"

	[ "$HW" = "Pandaboard" ] && { printf '%s' "<td>&nbsp;</td>"; return 0; }    # fixme!

	case "$metric" in
		'etx_ffeth'|'')
		;;
		*)
			tip="bgcolor='crimson'"
		;;
	esac

	[ ${speed:-0} -gt 6 ] && bytes="s${speed}-$bytes"

	tip="$tip title='$title'"

	printf '%s' "<td align='right' $tip nowrap>$bytes</td>"
}

func_cell_noise ()
{
	local NOISE="$1"
	local SENS="$2"
	local BGCOLOR

	[ "$HW" = "Pandaboard" ] && { printf '%s' "<td>&nbsp;</td>"; return 0; }    # fixme!

	if [ ${NOISE:--100} -gt -85 -a "$NOISE" != "0" ] ; then			# means lower than -85 (bad!)

		if [ "$SENS" = "1,nonwifi,user" ]; then
			
			BGCOLOR="$COLOR_LOWRED"
		else
			BGCOLOR="crimson"
		fi

		printf '%s' "<td bgcolor='$BGCOLOR' nowrap>${NOISE:--100}</td>"
	else
		printf '%s' "<td nowrap>${NOISE:--}</td>"
	fi
}

func_cell_nexthop()
{
	local nexthop="$1"
	local inet_offer="$2"
	local nexthop_temp
	local bgcolor

	nexthop_temp="$nexthop"

	case "$nexthop" in
		"")
		;;
		0)
			nexthop_temp="$NODE"
		;;
		*)
			case "$NETWORK" in
				boltenhagendh*)
					[ "$nexthop" = "2" ] && bgcolor="lime"
				;;
			esac
		;;
	esac

	hostname_minimize()
	{
		local name="$1"
		local nodenumber="$2"
		local temp_name

		lowercase()
		{
			echo "$1" | sed 'y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/'
		}

		case "$name" in
			'xxx'*)
				name="$( echo "$name" | sed -n 's/xxx\(.*\)/\1/p' )"
			;;
		esac

		case "$name" in
			'Haus'*)
				name="$( echo "$name" | sed -n 's/Haus\(.*\)/\1/p' )"
			;;
		esac

		case "$name" in
			'Konferenz'*)
				name="$( echo "$name" | sed -n 's/Konferenz\(.*\)/\1/p' )"
			;;
		esac

		case "$name" in
			'-'*)
				name="$( echo "$name" | sed -n 's/-\(.*\)/\1/p' )"
			;;
		esac

		case "$name" in
			*'-MESH')
				name="$( echo "$name" | sed -n 's/\(.*\)-MESH/\1/p' )"
			;;
		esac

		case "$name" in
			*'-AP')
				name="$( echo "$name" | sed -n 's/\(.*\)-AP/\1/p' )"
			;;
		esac

		case "$name" in
			'A-'*|'B-'*|'C-'*)
				temp_name="$( echo "$name" | cut -d'-' -f1 )"
				temp_name="$( lowercase "$temp_name" )"
				name="${temp_name}$( echo "$name" | cut -d'-' -f2 )"
			;;
		esac

		case "$name" in
			'schoeneck'*)
				name="$nodenumber"
			;;
		esac

		echo "$name"
	}

	do_dotfile()
	{
		# http://www.graphviz.org/doc/info/shapes.html
		# http://www.graphviz.org/doc/info/lang.html
		# http://www.graphviz.org/doc/info/attrs.html

		[ "$WIFIMODE" = "ap" ] && return 0

		local hostname="$HOSTNAME"
		local hostname_nexthop nodenumber_nexthop

		hostname_nexthop="unset"
		for FILE in $LIST_FILES LASTFILE; do {
       		 	[ -e "$FILE" ] && {
				nodenumber_nexthop="$( sed 's/;/\n/g' "$FILE" | grep ^'NODE=' | cut -d'"' -f2 )"

				[ "$NETWORK" = 'schoeneck' ] && {
					hostname_nexthop="$( hostname_sanitizer "$nodenumber_nexthop" )"
					if [ -n "$hostname_nexthop" ]; then
						:
					else
						hostname_nexthop="err$( sed 's/;/\n/g' "$FILE" | grep ^'HOSTNAME=' | cut -d'"' -f2 )"
					fi
				}

				[ "$nodenumber_nexthop" = "$nexthop" ] && break
			}
		} done

		[ -z "$GLOBAL_DOTFILE" ] && {
			GLOBAL_DOTFILE='true'
			echo  >"$DOTFILE" "digraph $NETWORK"
			echo >>"$DOTFILE" "{"
			echo >>"$DOTFILE" "	aKellerZimmerEDV [shape=\"box\", color=\"blue\"];"
			echo >>"$DOTFILE" "	LEGENDE [shape="box", color="lightblue", label=< Legende:<br/> Netzwerk Schoeneck<br/> Zeit $LOCALTIME >];"
			echo >>"$DOTFILE"
		}

		style()
		{
			local speed="$SENS"
			local media="$SENS"
			local linestyle label color

			case "$SENS" in
				*'/'*)
					# e.g. 1/1
					speed=0
				;;
				*','*)
					# e.g. 0,wifi,auto
					speed=0
				;;
				*'-'*)
					speed="$( echo "$speed" | cut -d'-' -f2 )"		# e.g. WIFI2-384
					media="$( echo "$media" | cut -d'-' -f1 )"
				;;
				*)
					media="WIFI"
				;;
			esac

			[ ${speed:=0} -lt 200 -a ${speed:=0} -gt 0 ] && color='red'

			case "$media" in
				'WAN'|'LAN')
					color='green'
					linestyle='bold'
				;;
				'WIFI')
					linestyle='solid'
				;;
				'WIFI2')
					linestyle='dashed'
				;;
				*)
					linestyle='dotted'
				;;
			esac

			printf '%s' "["
			printf '%s' "arrowhead=\"normal\", arrowtail=\"inv\", style=\"$linestyle\", label=\"$speed\""
			[ -n "$color" ] && printf '%s' ", color=\"$color\""
			printf '%s' "];"
		}

		echo "	$( hostname_minimize "$hostname" "$NODE" ) -> $( hostname_minimize "$hostname_nexthop" "$nodenumber_nexthop" ) $(style)" >>"$DOTFILE"
	}

	if [ "$NODE" = "$nexthop_temp" -a -z "$inet_offer" ]; then
		bgcolor='crimson'
	else
		do_dotfile
	fi

	case "$NETWORK" in
		dhsylt)
			bgcolor=
		;;
	esac

	printf '%s' "<td align='right' bgcolor='$bgcolor'>${nexthop}</td>"
}

cell_cost2nexthop()
{
	local qboth="$1"	# means: etx
	local mrate="${2:-6}"	# mbit

	printf '%s' "<td align='right'"
	case "$qboth" in
		"0.100"|"1.000")
			printf '%s' " bgcolor='$COLOR_BRIGHT_GREEN'"
		;;
		*)
			case "$mrate" in
				6)
					case "$qboth" in
						"1.0"*|"1.1"*|"1.2"*|"1.30"*)
							printf '%s' " bgcolor='$COLOR_DARK_GREEN'"
						;;
					esac
				;;
			esac
		;;
	esac
	printf '%s' ">$qboth</td>"
}

func_cell_nexthop_effective()		# and tx(nexthop)
{
	local NEXTHOP="$1"
	local OPTIMIZE_NEIGH="$2"
	local OPTIMIZE_NLQ="$3"
	local NETWORK="$4"
	local BGCOLOR=""

	# ~ 422 : 10.63.42.1 : 10.63.167.65 : COST : 2.123 : 1.234 : 1.678 : 1 : 12 : 5.5 : n
	local all devtype nodeid localip remoteip unit lq nlq qboth metric txrate txthroughput system

	all="$( echo $NEIGH | sed 's/[~=-]/\n&/g' | grep ^.${NEXTHOP}: | sed 's/[:]/ /g' | sed 's/[~=-]/& /' )"
	set -- ${all:-unset}

	txrate="${10}"
	txthroughput="${11}"
	system="${12}"
	qboth="$8"

	if [ -n "$txrate" -a "$txrate" != "0" ]; then
		NEXTHOP="${txthroughput}"

		case "$txrate" in
			0*)
			;;
			*)
				local percent
				printf '%s' "<!-- txthroughput: $txthroughput txrate: $txrate -->"

				case "$txrate" in
					*'.'*)
						txrate="$( echo "$txrate" | sed 's/\.//g' )"		# 5.5 -> 55
						txrate="$(( $txrate / 10 ))"				# 55 -> 5
					;;
				esac

				case "$txthroughput" in
					0.*)
						# fixme!
					;;
					*'.'*)
						percent=$( echo $txthroughput | sed 's/\.//g' )		# 67.4 -> 674
						percent=$(( $percent * 10 ))				# 67.4 * 100
						percent=$(( $percent / $txrate ))			# 67.4 * 100 / 243 = 27%
					;;
					[0-9]*)
						case "$percent" in
							[0-9]*)
								case "$txrate" in
									[0-9]*)
							percent=$(( $percent * 100 ))				# 32 * 100
							percent=$(( $percent / $txrate ))			# 32 * 100 / 54 = 59%
									;;
									*)
										percent="ERR:txrate:$txrate"
									;;
								esac
							;;
							*)
								percent="ERR:percent:$percent"
							;;
						esac

					;;
					*)
						percent="ERR:$txthroughput"
					;;
				esac

				percent="${percent}%"
			;;
		esac
	else
		NEXTHOP=
	fi


	case "$NETWORK-$NEXTHOP" in
		rehungen-0)
			NEXTHOP="bb"
			BGCOLOR="lime"
		;;
		rehungen-2)
			NEXTHOP="KG-1"
			BGCOLOR="green"
		;;
		rehungen-60)
			NEXTHOP="KG-2"
			BGCOLOR="green"
		;;
		rehungen-61)
			NEXTHOP="PUPP"
			BGCOLOR="green"
		;;
	esac

	if [ "xx" = "x${OPTIMIZE_NEIGH}${OPTIMIZE_NLQ}x" ]; then
		printf '%s' "<td align='right' bgcolor='$BGCOLOR'> $NEXTHOP </td>"
	else
		printf '%s' "<!-- OPTIMIZE_NEIGH: $OPTIMIZE_NEIGH -->"
		printf '%s' "<td align='right' bgcolor='$BGCOLOR'><a href='#' "
		printf '%s' "title='optimize&nbsp;2neigh:${OPTIMIZE_NEIGH:=best_wifi}&nbsp;2nlq:${OPTIMIZE_NLQ:=default}'>$NEXTHOP</a></td>"
	fi


	cell_cost2nexthop "$qboth" "$mrate"


	case "$txrate" in
		[0-9]*)
		;;
		*)
			txrate=
		;;
	esac

	printf '%s' "<td align='right'>$txrate</td>"

	printf '%s' "<td align='right'>${percent}</td>"

	case "$system" in
		n|g)
			:
		;;
		*)
			system=
		;;
	esac

	printf '%s' "<td align='center'> $system </td>"
}

func_cell_load ()
{
	local LOAD="$1"
	local BGCOLOR

	LOAD="$( echo ${LOAD:=0} | sed -ne 's/\.//' -e 's/^[0]*\([0-9]*\)/\1/p' )"
	
	[ ${LOAD:=0} -gt  60 ] && BGCOLOR="#E0ACAC"
	[ $LOAD      -gt  90 ] && BGCOLOR="crimson"

	if [ "$LOAD" -lt 100 ] ; then			# use awk-printf?

		if [ "$LOAD" -lt 10 ]; then

			LOAD="0.0$LOAD"					#    2 ->  0.02
		else
			LOAD="0.$LOAD"					#   12 ->  0.12
		fi
	else
		LOAD="$(( $LOAD / 100 )).$(( $LOAD % 100 ))"	# 1912 -> 19.12 | 912 ->  9.12
	fi

	LOAD="<small>${LOAD%.*}.</small>${LOAD#*.}"

	printf '%s' "<td bgcolor='$BGCOLOR' align='right'> $LOAD </td>"
}

cell_database()
{
	local lastline="$1"
	local authserver="$2"
	local bgcolor out

	[ -n "$lastline" -o -n "$authserver" ] && {
		bgcolor=" bgcolor='lime'"
	}

	if [ -n "$lastline" -a -n "$authserver" ]; then
		out="${lastline}|${authserver}"
	else
		out="${lastline}${authserver}"
	fi

	printf '%s' "<td align='center'${bgcolor}><small>${out:--}</small></td>"
}

_cell_firmwareversion_humanreadable()
{
	local update="$1"	# e.g. 'testing.Standard,kalua' or 'testing' or '0'
	local FWVERSION="$2"
	local openwrt_rev="$3"
	local secret="$4"	# builtin_secret / hex
	local TIME="$(( $UNIXTIME_SCRIPTSTART / 86400 ))"		# days
	local file_json prime_product prime_factor2 UPDATE= usecase= OUT=

	case "$update" in
		*'.'*)
			UPDATE="$(  echo "$update" | cut -d'.' -f1 )"
			usecase="$( echo "$update" | cut -d'.' -f2 )"

			echo "USECASE='$usecase'; HARDWARE='$HW'; WIFIMAC='$WIFIMAC'; OPENWRT_REV='$openwrt_rev';" >>"$USECASE_FILE"
		;;
		*)
			UPDATE="$update"
		;;
	esac

	[ -n "$HW" ] && {
		grep -sq ^"$HW"$ "$HARDWARE_FILE" || echo "$HW" >>"$HARDWARE_FILE"
	}

	# CODE_PROOF_OF_BOOT:
	[ -n "$secret" ] && {
		UPDATE="$(  echo "$update" | cut -d'.' -f1 )"		# e.g. testing
		usecase="$( echo "$update" | cut -d'.' -f2 )"
		file_json="../firmware/models/$HW/$UPDATE/$usecase/info.json"

		is_prime()
		{
			openssl prime $1 $2 | grep -q 'is prime'
		}

		grep -sq '"firmware_manually_checked": "false"' "$file_json" && {
			is_prime -hex "$secret" && {
				prime_product="$( grep '"firmware_code_proof_of_boot":' "$file_json" | cut -d'"' -f4 )"
				prime_factor2="$( echo "ibase=16; $prime_product / $secret" | BC_LINE_LENGTH=0 bc )"
				is_prime "$prime_factor2" && {
					sed -i 's/\(.*"firmware_manually_checked":\) "false"\(.*\)/\1 "true"\2/' "$file_json"
				}
			}
		}
	}

	unixtime2date()
	{
		awk -v UNIXTIME="$1" 'BEGIN { print strftime("%c", UNIXTIME) }'
	}

	if   [ -n "$( echo "$FWVERSION" | sed 's/[0-9]//g' )" ]; then
		OUT="$FWVERSION"

	elif [ -z "$FWVERSION" ] || [ "$FWVERSION" = "0" ]; then
		OUT="?"
	else
		OUT="$(( $FWVERSION / 24 ))"
		OUT="$(( $TIME - $OUT ))"

		if [ "$OUT" = "0" ]; then
			OUT="$( unixtime2date $(( $FWVERSION * 3600 )) )"
		else
			OUT="${OUT}&nbsp;d"
		fi
	fi

	local color="$( func_update2color $UPDATE )"
	[ "$TARBALL_TIME" = "$FWVERSION" ] && color='lime'
	[ "$FWVERSION" = '392973' ] && color='crimson'

	printf '%s' "<td bgcolor='$color' align='center' title='$VERSION.$UPDATE:$usecase' sorttable_customkey='$FWVERSION' nowrap>$OUT</td>"
}

hostname_from_monitoring_sanitized()	# used for send_mail_telegram() and related
{
	local mac="$1"
	local hostname file

	# enforced/settings: E1-Dachboden&nbsp;(&larr;4300er-flashprob = real)
	read -r hostname 2>/dev/null <"$TMPDIR/goodhostname_$mac"

	case "${hostname:=$HOSTNAME}" in
		'dhfleesensee-adhoc--68') hostname='Haus12-r1202-Traumdomizil' ;;
	esac

	case "$hostname" in
		*'ap--'[0-9]*|'enforcedsettings'*'real'|'enforced/settings: '*)
			# e.g. berlinle-ap--11
			# e.g. enforcedsettingsfernmeldemuseumLinksnbsplarrEG-WerkstattDannyreal
			# e.g. enforcedsettingsbauhaus-neufert-zweinbsplarrEG-Sommerbar-Emporereal
			# e.g. enforced/settings: EG-is1&nbsp;(&larr;mywifilan = real)
			file="/var/www/networks/$NETWORK/settings/$mac.hostname"
			read -r hostname 2>/dev/null <"$file"
		;;
	esac

	echo "${hostname:-$HOSTNAME}" | sed -e 's/^-//' -e 's/[^-a-zA-Z0-9]//g'
}

send_mail_telegram()
{
	local subject="$1"
	local message="$2"
	local list recipient hostname
	local url='http://bwireless.mooo.com/cgi-bin-tool.sh'
	local admin='network-status|npl.de'

	# needed for specific hostname->email actions
	hostname="$( hostname_from_monitoring_sanitized "$WIFIMAC" )"

	# TODO: set reply-to = admin
	# TODO: choose reason and translate according to recipient
	# TODO: use stored email from node

	case "$NETWORK" in
		paltstadt) list="$admin info|et-steinmetz.de info|weimar-pension-altstadt.de" ;;
		ewerk)
			case "$hostname" in
				*'vorfuehrraum'*|*'kino'*|*'cafe'*)
					list="$admin dh|lichthaus.info svenopel|gmx.de hansen|wastlhuber.de"
				;;
				*)
					list="$admin who-be|who-be.de"
				;;
			esac
		;;
		Xibfleesensee) list="$admin info|iberotel-fleesensee.de" ;;
		malchow*) list="$admin info|malchow-it.de" ;;
		monami) list="$admin frenzel|monami-weimar.de peter.frenzel|uni-weimar.de" ;;
		ffweimar-vhs)
			list="$admin frenzel|monami-weimar.de peter.frenzel|uni-weimar.de"
			[ $v2 -lt 38000 ] && list=	# openwrt-revision
		;;
		ffweimar-*)
			# TODO: do not double send / already send on main-network (e.g. ffweimar)
			list=
		;;
		neufert|bauhaus) list= ;;
		limona) list="$admin sven.rahaus|gmx.de" ;;
		amalienhof) list="$admin sven.rahaus|gmx.de info|amalienhof-weimar.de" ;;
		zwickau) list="$admin alrik.badstuebner|web.de" ;;
		ilm1) list="$admin stefanschlieter|gmail.com is.1|gmx.de andre-blue|gmx.de" ;;
		wagenplatz)
			case "$hostname" in
				'wagenplatz-richtung-BAMAG')
					list=		# ignore during winter/22-10uhr
				;;
				*)
					list="$admin platz_fabi|hotmail.com ferdinandhacke|web.de"
				;;
			esac
		;;
		server)
			case "$hostname" in
				'SCC')
					list="$admin bittorf1|uni-weimar.de"
				;;
			esac
		;;
		liszt28)
			case "$hostname" in
				'Musikschule'*)
					list="$admin info|musikschule-weimar.de"
				;;
				'wettertest')
					list="$admin bittorf1|uni-weimar.de"
				;;
				*'-vhs'*|*'wuschel-garten'*|*'Wuschel-NachbarNEU'*)
					list="$admin frenzel|monami-weimar.de peter.frenzel|uni-weimar.de"
					# TODO:
					message="$( echo "$message" | sed 's/liszt28/ffweimar-vhs/g' )"
				;;
				'CubieNAS')
					list="$admin koch_asl|yahoo.de"
				;;
				'X301wigo')
					case "$subject" in
						*'OK: Geraet:'*)
						;;
						*)
							list=
						;;
					esac
				;;
				'E2-ayse')
					list="$admin aysekurultay|gmail.com"
				;;
				'Frenze-oben'|'Frenze-unten')
					list="$admin sven.pasemann|gmx.de"
				;;
				'MountMeyer')
					list="$admin alrik.badstuebner|web.de"
				;;
				'Schl8hof9')
					list="$admin joerg.miething|googlemail.com"
				;;
				'liszt28-hybrid--798')
					list="$admin rene|r-hoffmann.de"
				;;
				'BaeckerRose'|'BaeckereiRose')
					# TODO - own network
					list="$admin info|et-steinmetz.de info|rose-weimar.de"
					message="$( echo "$message" | sed 's|liszt28|brose|g' )"
				;;
				*)
					list="$admin"
				;;
			esac

			case "$subject" in
				*'Erinnerung'*)
					list=	# TODO
				;;
			esac

			list=
		;;
		pension-ralfz) list="$admin rkleinert|ejbweimar.de" ;;
		aschbach) list="$admin njovicevic|cans.de rezeption|berghotel-aschbach.de" ;;
		giancarlo) list="$admin uve.giancarlo|t-online.de" ;;
		lisztwe|adagio|hentzel) list="$admin technik|hotel-adagio.de" ;;
		apphalle) list="$admin info|appartementhausamdom.de" ;;
		spbansin)
			case "$hostname" in
				'Haus9'*)
					list=
				;;
			esac

#			list="$admin office|seeparkbansin.de ecklebe|he-immobilien.de"

			case "$hostname" in
				'Haus12-r1202-Traumdomizil')
#					list="$list info|traumdomizil-usedom.de"
				;;
			esac
		;;
		xoai) list="$admin mb|mariobehling.de hp|fossasia.org" ;;
		berlinle)
			list="$admin hotel-berlin-leipzig|t-online.de"
			list=
		;;
		cvjm) list="$admin stefan.luense|schnelle-pc-hilfe.de info|cvjm-leipzig.de" ;;
		cospudener) list="$admin stefan.luense|schnelle-pc-hilfe.de" ;;
		schoeneck)
			list="$admin wolle.schuster|web.de info.vogtland|ifahotels.com"

			case "$hostname" in
				'KassenhausPicostation-MESH')
					list=
				;;
			esac
		;;
		extrawatt)
#			list="$admin matthias.golle|extrawatt-weimar.de"

			case "$hostname" in
				'240VoltPlugBuergel')
					list=
				;;
			esac
		;;
		tkolleg) list="$admin mail|detlefwagner.de" ;;
		marinabh)
			list="$admin schreyack|yachtwelt.de"
			list="$admin"	# TODO

			case "$hostname" in
				'marinabh-adhoc--17'|'Steg6uferseite-MESH') list= ;;
			esac
		;;
		abtpark) list="$admin stefan.luense|schnelle-pc-hilfe.de reserv|apark.de" ;;
		ejbw) list="$admin haustechnik|ejbweimar.de" ;;
		itzehoe) list="$admin hans-juergen.weidlich|stadtwerke-itzehoe.de huettendorf|stadtwerke-itzehoe.de" ;;
		wuensch) list="$admin p_s_wuensch|t-online.de" ;;
		leonardo) list="$admin info|hotel-leonardo.de" ;;
		rehungen)
			case "$hostname" in
				'nussberg73a-kindergarten') list="$admin ina.noettgen@gmx.de" ;; # 01512-7569004
			esac
		;;
		*) list="$admin" ;;
	esac

	# ignore known devices
	case "$NETWORK" in
		spbansin)
			case "$hostname" in
				Haus12-HeizhausOben|Haus11-hintenCHECK|Haus10-HeizhausObenCHECK|Haus9-hinten|Haus4-hinten)
					list=
				;;
			esac
		;;
		marinabh)
			case "$hostname" in
				Steg2uferseite)
					list=
				;;
			esac
		;;
	esac

	# do not complain if there is a fundamental problem
	[ -e "/dev/shm/pingcheck/$NETWORK.faulty" ] && {
		# TODO: only 1 router? also send mail...
		case "$NETWORK" in
			cvjm)
			;;
			*)
				return 1
			;;
		esac
	}

	case "$( date '+%H:%M' )" in
		'23'*|'00'*|'01'*|'02'*|'03'*|'04'*|'05'*|'06'*)
			case "$subject" in
				*'OK'*)
					# TODO - needs better concept
				;;
				*)
					# do not send error-mail between 23.00-06.59
					return 1
				;;
			esac
		;;
	esac

	# autoappend "verteiler"
	case "$list" in
		*' '*)
			message="$message\n\nVerteiler:\n"

			for recipient in $list; do {
				[ "$recipient" = "$admin" ] && recipient='technik|bittorf-wireless.de'

				recipient="$( echo "$recipient" | sed 's/|/@/g' )"
				message="$message- $recipient\n"
			} done
		;;
	esac

	# TODO: write into queue and make foolproof cronjob
	for recipient in $list; do {
		recipient="$( echo "$recipient" | sed 's/|/@/g' )"
		echo "$( date ): $recipient | $subject" >>"/var/www/networks/$NETWORK/log/mail.txt"
		log "telegram() to $recipient for node $WIFIMAC"

		curl -G --silent "$url" \
			--data-urlencode 'OPT=minimail' \
			--data-urlencode "RECIPIENT=$recipient" \
			--data-urlencode "SUBJECT=$subject" \
			--data-urlencode "MESSAGE=$message" >/dev/null || {
				echo "$( date ): ERROR $?" >>"/var/www/networks/$NETWORK/log/mail.txt"
			}
	} done
}

seconds2humanreadable()
{
        local seconds="$1"
        local humanreadable min sec hours days

        min=$(( seconds / 60 ))
        sec=$(( seconds % 60 ))

        if   [ $min -gt 1440 ]; then
                days=$(( min / 1440 ))
                min=$(( min % 1440 ))
                hours=$(( min / 60 ))
                min=$(( min % 60 ))
                humanreadable="${days}d ${hours}h ${min}min"
        elif [ $min -gt 60 ]; then
                hours=$(( min / 60 ))
                min=$(( min % 60 ))
                humanreadable="${hours}h ${min}min"
        elif [ $min -gt 0 ]; then
                if [ $min -gt 15 ]; then
                        humanreadable="${min}min"
                else
                        humanreadable="${min}min ${sec}sec"
                fi
        else
                humanreadable="${sec}sec"
        fi

        echo "$humanreadable"
}

_cell_lastseen()
{
	local LASTSEEN="$1"
	local HUMANTIME="$2"
	local inet_offer="$3"
	local OPTION=' title='
	local smsfile sms_timestamp sms_time sms_number bgcolor border hour
	local smsfile="../settings/${WIFIMAC}"
	local smsfile_kasse1="../settings/0a40cf496b01"
	local unixtime_now unixtime_file hostname alert_age
	local mailmarker="/dev/shm/${NETWORK}-${WIFIMAC}.mail"
	local subject_add=

	case "$NETWORK" in
		X-liszt28|X-apphalle|X-abtpark|X-apphalle|X-ewerk|ilm1)
			border=61	# min - normally every 15 mins a mini-update and every 60 mins a full
		;;
		gnm)
			smsfile="$smsfile.$HOSTNAME"	# individual
			border=52	# min
		;;
		*)
			border=1	# hour
		;;
	esac

	printf '%s' "<td align='left'"

	if [ $LASTSEEN -gt $border ]; then
		[ -e "$mailmarker" ] && {
			MAIL_AGE=$(( UNIXTIME_SCRIPTSTART - $( date +%s -r "$mailmarker" ) ))	# [sec]

			[ $MAIL_AGE -gt $(( 3600 * 6 )) ] && {
				# TODO: preserve first errortime?
				rm -f "$mailmarker"	# enforce resend

				ERROR_TIME="$( date +%s -r "recent/$WIFIMAC" )"		# last send
				ERROR_TIME=$(( UNIXTIME_SCRIPTSTART - ERROR_TIME ))	# [sec]
				ERROR_TIME="$( seconds2humanreadable "$ERROR_TIME" )"
				subject_add="(Erinnerung: gestoert seit $ERROR_TIME)"
			}
		}

		# TODO: code duplication, some lines later
		[ $LASTSEEN_ORIGINAL -gt 2160 ] && {
			# > 3 months unseen, so ignore
			echo "LASTSEEN_ORIGINAL:$LASTSEEN_ORIGINAL" >"$mailmarker"
		}

		[ -e "$mailmarker" ] || {
			echo "sendOK" >"$mailmarker"
			hostname="$( hostname_from_monitoring_sanitized "$WIFIMAC" )"

			SUBJECT="Technik/Netzwerk-Monitoring: $NETWORK / Stoerung Geraet: $hostname $subject_add"
			#
			L1="Bitte pruefen Sie das Geraet: $hostname $subject_add"
			L2="MAC-Adresse: $WIFIMAC"
			L3="Geraetetyp: $HW"
			#
			L4="Im Zweifel kurz stromlos machen."
			#
			L5="Beachten Sie auch die Gesamtuebersicht:"
			L6="http://intercity-vpn.de/networks/$NETWORK/"
			#
			L7="Danke fuer Ihr mitwirken."
			L8="Das automatische Monitoring-System."

			send_mail_telegram "$SUBJECT" "${L1}\n${L2}\n${L3}\n\n${L4}\n\n${L5}\n${L6}\n\n${L7}\n${L8}"
		}

		if [ -e "${smsfile}.lastsend" ]; then
			read sms_timestamp <"${smsfile}.lastsend"
			sms_time=$(( ($UNIXTIME_SCRIPTSTART - $sms_timestamp) / 60 ))	# how much minutes ago?
			bgcolor="yellow"
		elif [ -e "${smsfile}.sms" ]; then
			read sms_number <"${smsfile}.sms"
			bgcolor="yellow"
		else
			bgcolor="crimson"
		fi

		[ $LASTSEEN_ORIGINAL -gt 2160 ] && bgcolor="#8A0829"	# darkviolett > 3 months unseen

		if [ -e "${smsfile}.feedback" ]; then
#		 logger -s "NETWORK: '$NETWORK' smsfile already there: '${smsfile}.feedback'"
			sms_number="$sms_number FEEDBACK marked"
		else
			case "$NETWORK" in
				gnm)
					hour="$( date +%H )"
					[ "$HOSTNAME" = 'stranger' ] && hour='stranger'
					[ -e "${smsfile_kasse1}.feedback" ] && hour='kausalkette'
					[ -e "/var/www/networks/gnm/settings/${WIFIMAC}.screenshot.jpg" ] && {
						unixtime_file="$( date +%s -r "/var/www/networks/gnm/settings/${WIFIMAC}.screenshot.jpg" )"
						unixtime_now="$UNIXTIME_SCRIPTSTART"
						[ $(( ($unixtime_now - $unixtime_file) / 60 )) -gt $border ] || {
							hour="screenshot_new: $unixtime_file (now: $unixtime_now)"
						}
					}
					ls -1 "/var/www/networks/gnm/settings/"*.feedback 2>/dev/null >/dev/null && hour='feedback_already_set'

#					logger -s "NETWORK: '$NETWORK' will send sms maybe: hour=$hour, HOSTNAME=$HOSTNAME"
					case "$hour" in
						08|09|10|11|12|13|14|15|16)
							local append=
							case "$HOSTNAME" in
								event1*) append="f44" ;;
								event2*) append="f42" ;;
								event3*) append="f44" ;;
								event4*) append="f41" ;;
								event5*) append="f43" ;;
							esac

							/var/www/scripts/send_sms.sh \
								liszt28 "$WIFIMAC" \
								"Geraet tot: $NETWORK host: $HOSTNAME border: $border lastseen: $LASTSEEN call: 545347 $append" >/dev/null && touch "${smsfile}.feedback"
						;;
						*)
#							logger -s "will not send sms, no guest in hour '$hour' there from 19...6 o'clock"
						;;
					esac
				;;
			esac
		fi

		case "$WIFIMAC" in
			# X301
			00247e1272f3)
				bgcolor=
			;;
		esac

		printf '%s' " bgcolor='$bgcolor' title='MISS ${sms_number:-no_number}:$sms_time min ago, seit: ${LASTSEEN_ORIGINAL}h/$HUMANTIME'"
		echo >>"${FILE_FAILURE_OVERVIEW}.tmp" "$WIFIMAC $HOSTNAME (node: $NODE)"
	else
		[ -e "$mailmarker" ] && {
			unixtime_file="$( date +%s -r "$mailmarker" )"
			rm -f "$mailmarker"
			alert_age=$(( UNIXTIME_SCRIPTSTART - unixtime_file ))
			alert_age="$( seconds2humanreadable "$alert_age" )"
			hostname="$( hostname_from_monitoring_sanitized "$WIFIMAC" )"

			send_mail_telegram "Technik/Netzwerk-Monitoring: $NETWORK / OK: Geraet: $hostname (entstoert nach $alert_age)" \
					   "Das Geraet: ${hostname}\nist nach $alert_age wieder einsatzbereit.\n\nDanke fuer ihren Einsatz."
		}

		case "$NETWORK" in
			# only one router which does monitoring or ALL have inet-offer
			vivaldi|preskil|hotello-H09|cupandcoffee|paltstadt)
				[ -e "$TMPDIR/DETECTED_FAULTY_$NETWORK" ] && {
					rm "$TMPDIR/DETECTED_FAULTY_$NETWORK"
				}
			;;
			# one special node
			rehungen|spbansin)
				case "$HOSTNAME" in
					kindergarten-eschrank-MESH|*-HWR-*)
						[ -e "$TMPDIR/DETECTED_FAULTY_$NETWORK" ] && {
							rm "$TMPDIR/DETECTED_FAULTY_$NETWORK"
						}
					;;
				esac
			;;
			ffweimar*|galerie*|gnm)
				[ -e "$TMPDIR/DETECTED_FAULTY_$NETWORK" ] && {
					rm "$TMPDIR/DETECTED_FAULTY_$NETWORK"
				}
			;;
			*)
				[ -n "$inet_offer" ] || {
					[ -e "$TMPDIR/DETECTED_FAULTY_$NETWORK" ] && {
						rm "$TMPDIR/DETECTED_FAULTY_$NETWORK"
					}
				}
			;;
		esac

		# fixme! we must do this earlier
		# e.g. autohide or by accident
		grep ^"$WIFIMAC" '../ignore/macs.txt' && {
			sed -i "s/^$WIFIMAC/d" '../ignore/macs.txt'

			/var/www/scripts/send_sms.sh \
				liszt28 "$WIFIMAC" \
				"autohide-back again: $NETWORK wifimac: $WIFIMAC hostname: $HOSTNAME" >/dev/null
		}

		printf '%s' " title='letzte OK-Meldung: $( date -d @$LAST_UPDATE_UNIXTIME )'"

		[ -e "${smsfile}.feedback" ] && {
			rm "${smsfile}.feedback"
			# gnm / individual report
			[ -e "${smsfile}.$HOSTNAME.feedback" ] && rm "${smsfile}.$HOSTNAME.feedback"

			case "$NETWORK" in
				apphalle|castelfalfi|leonardo|schoeneck|extrawatt|olympia|aschbach|dhsylt|boltenhagendh|rehungen|marinabh)
				;;
				gnm)
					/var/www/scripts/send_sms.sh \
						liszt28 "$WIFIMAC" \
						"Geraet wieder am Leben: $NETWORK wifimac: $WIFIMAC hostname: $HOSTNAME" >/dev/null
				;;
				*)
					/var/www/scripts/send_sms.sh \
						liszt28 admin \
						"Geraet wieder am Leben: $NETWORK wifimac: $WIFIMAC hostname: $HOSTNAME" >/dev/null
				;;
			esac
		}
	fi

#	case "$NETWORK" in
#		leonardo)
#			[ -n "$HOSTNAME" ] && {
#				echo "$HOSTNAME" >>$TMPDIR/hostnames_leonardo.txt
#			}
#		;;
#	esac

	printf '%s' " sorttable_customkey='$LAST_UPDATE_UNIXTIME'>$LASTSEEN</td>"

	if   [ $LASTSEEN -gt 98 ]; then
		NODE_LOST=$(( $NODE_LOST + 1 ))
	elif [ $LASTSEEN -gt 2 ]; then
		NODE_WEAK=$(( $NODE_WEAK + 1 ))
	else
		NODE_GOOD=$(( $NODE_GOOD + 1 ))
	fi
}

_cell_sensitivity()
{
	local sens="$1"		# e.g. WIFI2-2345
	local key line

	[ "$HW" = "Pandaboard" ] && { printf '%s' "<td>&nbsp;</td>"; return 0; }    # fixme!

	case "${sens:--}" in
		"0,wifi,auto")
			printf '%s' "<td nowrap"
		;;
		"?,wifi,auto")
			printf '%s' "<td nowrap bgcolor='crimson'"
		;;
		*)
			printf '%s' "<td nowrap bgcolor='$COLOR_LOWRED'"
		;;
	esac

	case "$sens" in
		'LAN-'*)   key=10000 ;;
		'WAN-'*)   key=20000 ;;
		'WIFI-'*)  key=30000 ;;
		'WIFI2-'*) key=40000 ;;
		[0-9]*)	   key=0; sens="non-$sens" ;;	# only speed, no interface-information
		*)         key=50000 ;;
	esac

	sens="$( echo "$sens" | while read line; do printf '%s' "$line"; done )"

	case "$sens" in
		*'/'*)
			# e.g. '1/1'
		;;
		*','*)
			# e.g. '0,wifi,auto'
		;;
		*'-'*)
#			logger -s "rechne mit: sens: $sens"
			test 2>/dev/null "$( echo "$sens" | cut -d'-' -f2 )" -eq "$( echo "$sens" | cut -d'-' -f2 )" && {
#				logger -s "drin: sens: $sens"
				key=$(( $key + $( echo "$sens" | cut -d'-' -f2 ) ))
			}
		;;
	esac

#	logger -s "key: '$key'"
#	logger -s "sens: '$sens'"
#	logger -s "title='$key-$sens'>$sens</td>"
	printf '%s' " sorttable_customkey='$key' title='$key-$sens'>$sens</td>"
}

_cell_txpower ()
{
	local TXPOWER="${1:-0}"
	
	printf '%s' "<td align='right' "

	[ "$TXPOWER" -gt 50 ] && printf '%s' "bgcolor='$COLOR_LOWRED'"

	printf '%s' "> $TXPOWER </td>"
}

_cell_signal ()
{
	local RSSI="$1"
	local WIFIMODE="$2"		# ap|adhoc|client
	local BGCOLOR

	case "$WIFIMODE" in
		adhoc)
			[ ${RSSI:--50} -lt -81 ] && BGCOLOR="$COLOR_LOWRED"
		;;
		*)
			[ ${RSSI:-0} -lt 0 ] && BGCOLOR="$COLOR_GOOD_GREEN"
		;;
	esac

#	printf '%s' "<!-- JAAA '$RSSI' '$WIFIMODE' '$BGCOLOR' -->"
	printf '%s' "<td"

	[ -n "$BGCOLOR" ] && printf '%s' " bgcolor='$BGCOLOR'"

	printf '%s' " nowrap>${RSSI:--}</td>"
}

func_cell_pfilter ()
{
	local PFILTER="$1"

	case "$PFILTER" in
		*'FREE'*|*'OOPS0'*|*'olsrign'*)
			printf '%s' "<td nowrap bgcolor=crimson> $PFILTER </td>"
		;;
		*'noNAT'*)
			printf '%s' "<td nowrap bgcolor=lime> $PFILTER </td>"
		;;
		'HNA'*)
			printf '%s' "<td nowrap bgcolor=lime> $PFILTER </td>"
		;;
		'loss'*)
			case "$PFILTER" in
				'loss0.0.0'*)
					printf '%s' "<td nowrap bgcolor=green> $PFILTER </td>"
				;;
				*)
					  if echo "$PFILTER" | grep -Fq  ".0 olsrign" ; then

						printf '%s' "<td nowrap bgcolor=green> $PFILTER </td>"

					elif echo "$PFILTER" | grep -Fq ".10 olsrign" ; then

						printf '%s' "<td nowrap bgcolor=green> $PFILTER </td>"
					else
						printf '%s' "<td nowrap bgcolor=orange> $PFILTER </td>"
					fi
				;;
			esac
		;;
		*)
			printf '%s' "<td nowrap> ${PFILTER:--}</td>"
		;;
	esac
}	

_cell_profile ()
{
	local PROFILE="$1"
	local WIFIMODE="$2"
	local BSSID="$3"

	[ "$HW" = "Pandaboard" ] && { printf '%s' "<td>&nbsp;</td>"; return 0; }    # fixme!

	case "$PROFILE" in
		"$NETWORK"*)
			PROFILE="$( echo $PROFILE | sed "s/${NETWORK}_//" )"
		;;
	esac

	printf '%s' "<td nowrap>"

#	case "$WIFIMODE" in
#		adhoc|hybrid)
			printf '%s' "<a href='#' title='BSSID=\"$BSSID\"'>$PROFILE</a>"
#		;;
#		*)
#			printf '%s' "$PROFILE"
#		;;
#	esac

	printf '%s' "</td>"
}

global_wired_neigh_color()
{
	local ipoctett="$1"
	local dir="$TMPDIR/global_wired_neigh_color_$$"
	local file="$dir/$ipoctett"
	local color

#	mkdir -p "$dir"

	if [ -e "$file" ]; then
		read color <"$file"
	else
		color="yellow"
	fi

	echo "$color"
}

_cell_wired_neighs ()
{
	local NEIGHS="$1"
	local NETWORK="$2"
	local sorted_neighs="$3"

	local BGCOLOR append

	  if [ "$NEIGHS" = "-1" ]; then

		BGCOLOR="$COLOR_LOWRED"

	elif [ "$NETWORK" = "rehungen" -a "$NEIGHS" = "0" ]; then

		BGCOLOR="$COLOR_LOWRED"
	else
		BGCOLOR=
	fi

	[ -n "$sorted_neighs" ] && {
		append="$( echo "$sorted_neighs" | sed 's/\.//g' )"
		append="${append}|"

		case "$sorted_neighs" in
			*"."*)
				local color
				color="$( echo "$sorted_neighs" | cut -d'.' -f3 )"
				color="$( printf "%X\n" "$color" )"
				BGCOLOR="$( global_wired_neigh_color "$color" )"
			;;
		esac
	}

	printf '%s' "<td bgcolor='$BGCOLOR' align='center'>${append}${NEIGHS}</td>"
}

_cell_mrate ()
{
	local MRATE="$1"
	local WIFIMODE="$2"
	local NETWORK="$3"
	local BGCOLOR=

	[ "$HW" = "Pandaboard" ] && { printf '%s' "<td>&nbsp;</td>"; return 0; }    # fixme!

	case "$WIFIMODE" in
		ap|client)
			[ "$MRATE" != "auto" ] && BGCOLOR='crimson'
		;;
		*)
			case $NETWORK in
				rehungen)
					case $MRATE in
						12)
							BGCOLOR='green'
						;;
						9)
							BGCOLOR="brown"		
						;;
					esac
				;;
			esac
		;;
	esac

	printf '%s' "<td BGCOLOR='$BGCOLOR' align='center'> $MRATE </td>"
}


_cell_switch()
{
	local plugs="$1"
	local cost2gw="$2"
	local hardware="$3"
	local inet_offer="$4"
	local inet_offer_down="$5"
	local inet_offer_up="$6"
	local lan_dhcp_ignore="$7"

	local linebreak='&#10;'
	local i=0
	local real_port=-1
	local char spacer color speed duplex
	local cellspacing speed_printed symetric hostname
	local subject_add=

	if [ ${#plugs} -eq 1 ]; then		# e.g. ubnt bullet
		plugs=".--.${plugs}.--."
		cellspacing="0"
	else
		cellspacing="1"
	fi

	inet_offer_down=$(( ${inet_offer_down:-0} * 8 ))
	inet_offer_up=$(( ${inet_offer_up:-0} * 8 ))
	inet_offer="${inet_offer}${linebreak}down=${inet_offer_down}Kbit/s"
	inet_offer="${inet_offer}${linebreak}up=${inet_offer_up}Kbit/s"

	local is_poe_powered=
	local global_bgcolor='white'
	local global_tooltip=
	case "$lan_dhcp_ignore" in
		1)
			global_bgcolor='grey'
		;;
		*)
			global_bgcolor='white'

			case "$NETWORK" in
				'spbansin'*)
					case "$HOSTNAME" in
						*'-HWR-'*)
							local mailmarker="/dev/shm/${WIFIMAC}.mail_pppoe"

							# do not give false positives, when only 1 dataset is missing
							if [ $inet_offer_down -eq 0 -a $inet_offer_up -eq 0 ]; then
								global_bgcolor='crimson'
								global_tooltip="ADSL broken:$inet_offer"

		[ -e "$mailmarker" ] && {
			MAIL_AGE=$(( UNIXTIME_SCRIPTSTART - $( date +%s -r "$mailmarker" ) ))	# [sec]

			[ $MAIL_AGE -gt $(( 3600 * 6 )) ] && {
				# this forces a resend
				rm -f "$mailmarker"
				subject_add="(Erinnerung)"
			}
		}

		[ -e "$mailmarker" ] || {
			touch "$mailmarker"
			hostname="$( hostname_from_monitoring_sanitized "$WIFIMAC" )"

			SUBJECT="Technik/Netzwerk-Monitoring: $NETWORK / Stoerung DSL-Modem an $hostname $subject_add"
			#
			L1="Bitte pruefen Sie das DSL-Modem an: $hostname $subject_add"
			L2="Modellbezeichnung: Allnet ALL-0333CJ"
			#
			L3="Im Zweifel kurz stromlos machen bzw."
			L4="die Deutsche Telekom zur Entstoerung anrufen."
			#
			L5="Beachten Sie auch die Gesamtuebersicht:"
			L6="http://intercity-vpn.de/networks/$NETWORK/"
			#
			L7="Danke fuer Ihr mitwirken."
			L8="Das automatische Monitoring-System."

			case "$hostname" in
				'Haus3-Heizhaus-Zentrale')
					# FIXME!
				;;
				*)
			send_mail_telegram "$SUBJECT" "${L1}\n${L2}\n\n${L3}\n${L4}\n\n${L5}\n${L6}\n\n${L7}\n${L8}"
				;;
			esac
		}
							else
		[ -e "$mailmarker" ] && {
			rm "$mailmarker"
			hostname="$( hostname_from_monitoring_sanitized "$WIFIMAC" )"

			send_mail_telegram "Technik/Netzwerk-Monitoring: $NETWORK / OK: DSL-Modem an $hostname" \
					   "Das DSL-Modem an ${hostname}\nist wieder einsatzbereit.\n\nDanke fuer ihren Einsatz."
		}
							fi
						;;
					esac
				;;
			esac
		;;
	esac

	case "$plugs" in
		*'Z'*)	# unknown port state
			global_bgcolor='crimson'
			global_tooltip='maybe switch broken?'
		;;
	esac

	case "$NETWORK" in
		leonardo)
			case "$NODE" in
				# konferenz|eg-flur|e3-flur|e1-flur
				6|26|2|27|7|36|9|35)
					is_poe_powered='true'
					# port1=6|26 ???
					# port2=
					# port3=
					# port4=
				;;
			esac
		;;
		giancarlo)
			case "$NODE" in
				# E1-rezeption,E2-service,E3-service,E4-kamin
				5|6|10|14)
					is_poe_powered='true'
				;;
			esac
		;;
	esac

	case "$plugs" in
		'-.----')
			[ -n "$is_poe_powered" ] && {
				global_bgcolor='crimson'
				global_tooltip='maybe switch/cable broken?'
			}
		;;
	esac

	printf '%s' "<td title='$global_tooltip' bgcolor='$global_bgcolor'>"
	printf '%s' "<table cellspacing='$cellspacing' cellpadding='0'><tr>"

	while [ $i -lt ${#plugs} ]; do {
		i=$(( $i + 1 ))
		real_port=$(( $real_port + 1 ))
		char="$( echo "$plugs" | cut -b $i )"

		if [ $cellspacing -eq 0 ]; then			# only 1 port (bullet)
			name='oneLANonly'
		else
			case "$real_port" in
				0) name="WAN" ;;
				*) name="LAN${real_port}" ;;
			esac
		fi

		case "$char" in
			a|b|c)
				duplex="half"
				spacer="&frac12;"
			;;
			x|X|"-"|A|B|C)
				duplex="full"
				spacer="&nbsp;"
			;;
			".")
				duplex=
				spacer="&thinsp;"

				[ -n "$is_poe_powered" ] && {
					# Powered via PoE-Splitter: unicode / electrical arrow
					spacer='&#x26a1;'
					char='PoE'
				}
			;;
			'Z')
				spacer='?'
			;;
		esac

		case "$char" in
			'PoE')
				color='yellow'
				speed='Power-over-Ethernet'
			;;
			a|A)
				color="#99FF99"
				speed="10mbit"
			;;
			b|B)
				color="#00FF00"
				speed="100mbit"
			;;
			c|C)
				color="#00CC00"
				speed="1gbit"
			;;
			'x')
				color="#00FF00"
				speed="100mbit"
			;;
			'X')
				color="#00CC00"
				speed="1gbit"
			;;
			'.')
				color="white"
				speed=
				name="Luecke"
				real_port=$(( $real_port - 1 ))
			;;
			'-')
				color="black"
				speed="unplugged"
			;;
		esac

		must_be_printed()
		{
			test ${v2:-99} -eq 0 && return 0	# VPN-server = OPENWRT_REV = 0

			case "$inet_offer" in
				*':wifi:'*)
					return 1
				;;
			esac

			[ ${inet_offer_down:-0} -gt 0 ] || {
				case "$inet_offer" in
					*":wan:"*|*":lan:"*)
					;;
					*)
						return 1
					;;
				esac
			}

			test -z "$speed_printed" && {
#				logger -s "do-speed: '$speed' mac: $WIFIMAC inet_offer: '$inet_offer'"

local newline='
'
				case "$inet_offer" in
					*"$newline"*)
#						logger -s "do-speed: has newline: '$inet_offer'"

						local list_words="$inet_offer"
						local word
						inet_offer=

						for word in $list_words; do {
							inet_offer="${inet_offer}${word}"
						} done

#						logger -s "do-speed: now: '$inet_offer'"
					;;
				esac

				speed_printed="true"
			}
		}

		[ -n "$speed" -a "$speed" != "unplugged" -a "$speed" != 'Power-over-Ethernet' ] && {
			speed="${speed}${duplex}duplex"

			must_be_printed && {
				local symbol should_down should_up

				case "$inet_offer" in
					*'pppoe'*)
						symbol="&diams;"	# filled diamond
					;;
					*)
						symbol="&loz;"		# unfilled Raute ("lozenge")
					;;
				esac

				speed="$speed,internet${linebreak}IP:${PUBIP_REAL},${linebreak}$inet_offer"
				spacer="<a href='http://${PUBIP_REAL}'>${symbol}</a>"

printf '%s' "<!-- speed: $speed :speed -->"
printf '%s' "<!-- spacer: $spacer :spacer -->"

				#  typical:
				#    64/  64(1*64)	[ISDN]
				#   384/  64(1*64)	[DSL-light]
				#   512/ 128(2*64)	// mauritius? -> 768/384
				#   768/ 128(2*64)
				#  1024/ 128(2*64)
				#  1536/ 192(3*64)
				#  2048/ 256(4*64)
				#  2560/ 320(5*64)
				#  3072/ 384(6*64)
				#  4........(7*64)
				#  5........(8*64)
				#  6144/ 576(9*64)
				#        640(10*64)
				#        704(11*64)
				#        768(12*64)
				#        832(13*64)	// special: B01-16.000er = 9.216/832 (vodafone)
				#        896(14*64)
				#        960(15*64)
				# 16384/1024(16*64)
				# -''--/1600(25*64)	// hotello-B01
				# 16384/2048(32*64)	// telekom?
				#
				# 32768/2048(32*64)	[primacom32]
				# 51200/10240(160*64)	[VDSL]

				case "$PROFILE" in
					dhsylt*|boltenhagen*)
						should_down=9000	# companyconnect: ~8512
						should_up=7500		# companyconnect: ~7360
					;;
					extrawatt*)
						should_down=384
						should_up=64
					;;
					preskil*)
						should_down=768
						should_up=384
					;;
					versiliaje*)
						should_down=1024
						should_up=128
					;;
					satama)
						should_down=2048
						should_up=192		# special!
					;;
					versiliaje*)
						should_down=2048	# 91% - 1928...1944
						should_up=256		# 81% - 208...244
					;;
					spbansin*)
						should_down=2000	# real: 2000
						should_up=200		# real: 192
					;;
					marinapark*)
						should_down=2048
						should_up=384
					;;
					vivaldi*)
						should_down=2048
						should_up=2048
						symetric="true"
					;;
					aschbach*)			# special!
						should_down=3072
						should_up=256
					;;
					fparkssee*)
						should_down=3072
						should_up=384		# special!
					;;
					schoeneck*)
						should_down=3072
						should_up=384
					;;
					ejbw*)
						symetric="true"

						case "$WIFIMAC" in
							d85d4cd50b9c)
								should_down=16384	# 16mbit
								should_up=13312		# 13mbit
							;;
							*)
								should_down=4096
								should_up=4096
							;;
						esac
					;;
					itzehoe*)
						should_down=6144
						should_up=320		# special!
					;;
					liszt28*)
						case "$NODE" in
							99)
								should_down=6144
								should_up=576
							;;
							# ? | KG-f36
							22|276)
								should_down=16384
								should_up=1024
							;;
						esac
					;;
					apphalle*|lisztwe*|adagio*)
						should_down=6144
						should_up=576

#						case "$PROFILE" in
#							itzehoe*)
#								should_up=384	# normally for 3mbit
#							;;
#						esac
					;;
					monami*|paltstadt*|limona*|olympia*|elephant*)
						should_down=16384
						should_up=1024
					;;
					hotello-B01*|hotello-K80*|hotello-H09*)		# vodafone
						should_down=9216
						should_up=832
					;;
					leonardo*)
						should_down=32768
						should_up=2048
					;;
					rehungen*)
						should_down=45000	# 51200
						should_up=9500		# 10240
					;;
				esac

				local marker_bad_down marker_bad_up
				local correction_value_downstream="93"	# 93%
				local correction_value_upstream="81"	# 81%
				[ "$symetric" = "true" ] && correction_value_upstream="$correction_value_downstream"

				[ -n "$should_down" -a "${should_down:-0}" -gt 0 ] && {
					should_down="$(( (($should_down * 100) * $correction_value_downstream) / 10000 ))"	# 93%
					[ $inet_offer_down -ge $should_down ] || {
						speed="${linebreak}SlowDownlink(target:$should_down/$(( ($inet_offer_down * 100) / $should_down ))%)-${linebreak}$speed"
						marker_bad_down="true"
						color="orange"
					}
				}

				[ -n "$should_up" -a "${should_up:-0}" -gt 0 ] && {
					should_up="$(( (($should_up * 100) * $correction_value_upstream) / 10000 ))"	# 81%
					[ $inet_offer_up -ge $should_up ] || {
						speed="SlowUplink(target:$should_up/$(( ($inet_offer_up * 100) / $should_up ))%)-$speed"
						marker_bad_up="true"
						color="orange"
					}
				}

				[ "$marker_bad_up" = "true" -a "$marker_bad_down" = "true" ] && {
					color='crimson'
				}
			}
		}

		text2port()
		{
			local text="$1"
			local position= char= ascii= sum= value=

			while [ ${position:=1} -le ${#text} ]; do {
				char="$( echo "$text" | cut -b $position )"
				ascii="$( printf '%d' "'$char" )"
				value=$(( ( $ascii * 17 ) / 3 ))        # nearly no collisions in testsuite
				sum=$(( ${sum:-1025} + $value ))
				position=$(( $position + 1 ))
			} done

			[ ${sum:=1025} -gt 65535 ] && sum="65535"
			echo "${sum:-1025}"
		}

		local config_profile="$PROFILE"
		local hostname="$HOSTNAME"
		local ssh_port="$( text2port "${config_profile}${hostname}" )"
		local hint="use_sshport:${ssh_port}"

		printf '%s' "<td bgcolor='$color' title='${hint}${linebreak}${name}${linebreak}${speed:+:}${speed}'><tt>$spacer</tt></td>"
	} done

	[ $i -eq 0 ] && printf '<td>&nbsp;</td>'	# valid html

	printf '%s' "</tr></table>"
	printf '%s' "</td>"
}

cell_dhcp()
{
	local script="$1"
	local out="&nbsp;"
	local color=

	[ -n "$script" ] && {
		color="$COLOR_BRIGHT_GREEN"
		out="&nbsp;"
	}

	printf '%s' "<td align='center' bgcolor='$color'>${out}</td>"
}

cell_essid()
{
	local list_essid="$1"
	local rssi0="$2"
	local rssi1="$3"
	local rssi2="$4"
	local rssi3="$5"
	local wifi_clients="$6"
	local wired_clients="$7"
	local essid bgcolor rssi spacer title wired_clients_formatted
	local i=0

	printf '%s' "<td nowrap><table cellspacing='1' cellpadding='0' border='0'><tr>"

	[ "$NETWORK" = "gnm" ] && {
		case "$list_essid" in
			5*|6*|7*|8*)
				bgcolor="$COLOR_LOWRED"
			;;
		esac
	}

	local symbol_Nary_times='&#x00d7;'

	[ -n "$wired_clients" ] && {
		if [ $wired_clients -gt 0 ]; then
			local symbol_wired='&#x27db'
			wired_clients_formatted="${symbol_wired}${symbol_Nary_times}${wired_clients}&nbsp;|&nbsp;"
		else
			wired_clients_formatted=
		fi
	}

	if [ -n "$wifi_clients" ]; then
		if [ $wifi_clients -gt 0 ]; then
			local symbol_antenna='&#x16c9;'
			printf '%s' "<td>${wired_clients_formatted}${symbol_antenna}${symbol_Nary_times}${wifi_clients}&nbsp;|&nbsp;</td>"
		else
			if [ -n "$wired_clients_formatted" ]; then
				printf '%s' "<td>${wired_clients_formatted}</td>"
			else
				printf '<td>&nbsp;</td>'
			fi
		fi
	else
		printf '<td>&nbsp;</td>'
	fi

	[ -z "$list_essid" ] && {
		printf '%s' "<td>&nbsp;</td>"
	}

	list()
	{
		echo $1 | sed 's/ /%/g' | sed 's/|/\n/g'
	}

	[ -z "$( list "$list_essid" )" ] && {
		printf '%s' "<td>&nbsp;</td>"
	}

	for essid in $( list "$list_essid" ) ; do {

		essid="$( echo "$essid" | sed 's/%/ /g' )"

		eval "rssi=\"\$rssi${i}\"; i=$(( $i + 1 ))"	# i++

		case "$rssi" in
			'')
				[ "$NETWORK" = "gnm" ] || {
					bgcolor=
					title=
				}
			;;
			*)
				if [ ${#essid} -le 3 ]; then
					# adhoc
					bgcolor=
					title=
				else
					# ap
					bgcolor="lime"
					title="Signal:$rssi,$wifi_clients,$wired_clients"
				fi

				case "$essid" in
					'ffintern'*|'intern'*)
						bgcolor=
						title=
					;;
				esac
			;;
		esac

		[ $i -gt 1 ] && {
			printf '%s' "<td>&nbsp;|&nbsp;</td>"
		}

		case "$essid" in
			*'Wartungsmodus'*|*'maintenance'*)
				bgcolor='crimson'
			;;
		esac

		printf '%s' "<td bgcolor='$bgcolor' title='$title'>${essid}</td>"
	} done

	printf '%s' "</tr></table></td>"
}

cell_channel()
{
	local channel="$1"

	[ "$HW" = "Pandaboard" ] && { printf '%s' "<td>&nbsp;</td>"; return 0; }    # fixme!

	local color
	local color_a="#819FF7"		# blue
	local color_b="#64FE2E"		# green
	local color_c="#F781F3"		# pink
	local color_d="#F4FA58"		# yellow

	case "$NETWORK" in
		hotello*)
			case "$channel" in
				1) color="$color_a" ;;
				4) color="$color_b" ;;
				7) color="$color_c" ;;
				11)color="$color_d" ;;
			esac
		;;
		*)
			color=
		;;
	esac

	printf '%s' "<td align='right' bgcolor='$color'> $channel </td>"
}

cell_node()
{
	local node="$1"
#	local append=

	case "$DOUBLE_NODENUMBERS" in
		*" $node "*)
#			case "$NETWORK" in
#				*)
#					[ "$LASTSEEN" = "0" ] || rm "recent/$WIFIMAC"	# mac address has slightly changed
#				;;
#			esac
			local file node2 wifimac unixtime remove replace

#rrr
			for file in $LIST_FILES ; do {
				file="$( pwd )/$file"
#logger -s "cell_node: checking file '$file'"
				[ -e "$file" ] || continue
#				. "$file"
#logger -s "cell_node: included $file"
				grep -sq ^"$WIFIMAC" ../ignore/macs.txt && continue

				node2="$(    sed 's/;/\n/g' "$file" | grep ^'NODE='     | cut -d'"' -f2 )"
				wifimac="$(  sed 's/;/\n/g' "$file" | grep ^'WIFIMAC='  | cut -d'"' -f2 )"
				unixtime="$( sed 's/;/\n/g' "$file" | grep ^'UNIXTIME=' | cut -d'"' -f2 )"
#logger -s "cell_node: f: '$file' WM: $WIFIMAC node $node2/$node wifimac: $WIFIMAC/$wifimac unixtime: $unixtime"
				# search my 'brother'-node, same number diff mac

#				[ "$node2" = "$node" -a "$WIFIMAC" != "$wifimac" ] && {
#					# 2 cases:
#					# normal MAC - younger than - 02:MAC -> delete 02:MAC
#					# normal MAC -   older than - 02:MAC -> copy content to 'normal MAC' and remove 02:MAC
#
#					if [ $UNIXTIME -gt $unixtime ]; then
#						case "$WIFIMAC" in
#							02*)
#								replace="$( pwd )/recent/$WIFIMAC"
#								logger -s "myself $WIFIMAC is newer than $wifimac in file '$file', mv '$replace' to '$file'"
#								mv "$replace" "$file"
#							;;
#							*)
#								logger -s "myself $WIFIMAC is newer than $wifimac in file '$file', rm '$file'"
#								rm "$file"
#							;;
#						esac
#					else
#						case "$WIFIMAC" in
#							02*)
#								remove="$( pwd )/recent/$WIFIMAC"
#								logger -s "myself $WIFIMAC is older than $wifimac in file '$file', REMOVING '$remove'"
#								rm "$remove"
#							;;
#							*)
#								logger -s "myself $WIFIMAC is older than $wifimac in file '$file'"
#							;;
#						esac
#					fi
#				}
			} done

			printf '%s' "<td align='right' bgcolor='$COLOR_LIGHT_RED'><big>$node${append}</big></td>"
		;;
		*)
			printf '%s' "<td align='right'> $node </td>"
		;;
	esac
}

_cell_wifi_neighs ()
{
	local WIFINEIGHS="$1"
	local NEIGH="$2"
	local wifimode="$3"

	local HINT="Anzahl der OLSR-Funknachbarn, es wird ausdruecklich empfohlen Funkbedingungen derart zu schaffen, dass mindestens 2 nutzbare Partner per Funk verfuegbar sind."
	local COLOR=

	[ ${WIFINEIGHS:-0} -gt 9 ] && COLOR="$COLOR_LOWRED"

	[ "${WIFINEIGHS:-0}" = "0" ] && {
		[ "$wifimode" = "adhoc" ] && {
			COLOR="crimson"
		}
	}

	# fixme! WIFI+WIRED=0? crimson!
	printf '%s' "<td align='center' bgcolor='$COLOR'><a href='#' title='$HINT DEBUG=$NEIGH'> $WIFINEIGHS </a></td>"
}

html_comment()		# for sorting
{
	printf '%s' "<!-- $( echo $1 | sed 's/-//g' ) -->"
	return 0

	local comment="$1"

	case "$comment" in
		*"--"*)
			comment="${comment//--/}"	# remove double dash
		;;
	esac

	printf '%s' "<!-- $comment -->"
}

# idee: keine stoerung = hostname
# stoerung = age2 (kaputte oben)

case "$NETWORK" in
	liszt28|ffweimar)
		SPECIAL_ORDER_BY='age'
	;;
	boltenhagendh)
		SPECIAL_ORDER_BY='age2'
	;;
	*)
		SPECIAL_ORDER_BY='hostname'
	;;
esac

	case "$SPECIAL_ORDER_BY" in
		node)
			html_comment "$( printf "%05d" $NODE )"
		;;
		load)
			html_comment "$LOAD"
		;;
		mac)
			html_comment "$WIFIMAC"
		;;
		age)
			BLA=$(( 99999999 - $LASTSEEN_ORIGINAL ))
			VALUE="$( printf "%10d" ${BLA:-0} )"
			html_comment "$VALUE"		# newest on top
		;;
		age2)
			VALUE="$( printf "%10d" ${LASTSEEN_ORIGINAL:-0} )"
			html_comment "$VALUE"		# oldest on top
		;;
		cost)
			html_comment "$COST2GW_X"
		;;
		uptime)
			html_comment "$( printf "%10d" $UP )"
		;;
		version)
			html_comment "$VERSION"
		;;
		essid)
			html_comment "$( printf "%03d" $( printf '%s' "$ESSID" | sed 's/[^0-9]//g' ) )"
		;;
		txpower)
			html_comment "$TXPWR"
		;;
		sens)
			html_comment "$( echo $SENS | sed 's/mb//' )"
		;;
		*)
			# we must 'clean/sanitize' the hostname first
			func_cell_hostname "$HOSTNAME" "$WIFIMAC" "$MAIL" >/dev/null

			html_comment "${FILL}${HOSTNAME_FOR_SORTING}"
		;;
	esac


	case "$WIFIMODE" in
		*adhocap*|*apap*)
			BGCOLOR="#408080"	# same like ap
		;;
	esac

	printf '%s' "<tr bgcolor='$BGCOLOR'>"

	HUMANTIME="$( date -d @$LAST_UPDATE_UNIXTIME )"

	_cell_lastseen "$LASTSEEN" "$HUMANTIME" "$i1" 
	func_cell_hostname "$HOSTNAME" "$WIFIMAC" "$MAIL"
	_cell_firmwareversion_humanreadable "$UPDATE" "$VERSION" "$v2" "$secret"

	good_git_color()
	{
		local rev="${1:-0}"

		case "$HOSTNAME" in
			'ewerk-'*)
				case "$rev" in
					49276)
						# kultursymposium
						echo "$COLOR_BRIGHT_GREEN"
					;;
					*)
					;;
				esac

				return 0
			;;
		esac

		case "$rev" in
			28879|29366)			# brcm47xx + ar71xx
				echo "$COLOR_BRIGHT_ORANGE"
			;;
			33502|33556|33726|32582|35052)		# linksys/buffi/dell x 2 | tplink | bullet M | tplink
				echo "$COLOR_BRIGHT_GREEN"
			;;
			# 32060|32055|34054|35724|35300		# atheros | tpl | tpl | bulletM | tplinkNEU
			44150)		# ar71xx
				echo "$COLOR_BRIGHT_GREEN"
			;;
			31182|30823|30563|31465|33160|33616|30671) # linksys/buffi/dell | linksys/buffi/dell | tplink | tplink | tplink | tplink | bullet M
				echo "$COLOR_DARK_GREEN"
			;;
			99999)
				echo "$COLOR_DARK_GREEN"
			;;
			*)
				if   [ $rev -ge 34794 -a $rev -lt 34815 ]; then
					func_update2color 'bad_version:broken_sysupgrade'
				elif [ $rev -ge 40293 -a $rev -lt 40503 ]; then
					func_update2color 'bad_version:broken_wifi_regdb'
				elif [ $rev -ge 45040 -a $rev -lt 45189 ]; then
					func_update2color 'bad_version:uci_broken'
				elif [ $rev -ge 44918 -a $rev -lt 45790 ]; then
					# reset to defaults / firstboot by accident
					# https://dev.openwrt.org/ticket/19564
					# internally fixed since ~45790
					func_update2color 'bad_version:fstools_broken'
#				elif [ $rev -ge 44946 -a $rev -lt 45579 ]; then
#					# fixed in $TMPDIR/loader and used from r45579+
#					# https://dev.openwrt.org/ticket/19539 - visible on dualradio-routers
#					func_update2color 'bad_version:uci_lists_broken'
				elif [ $rev -gt 46435 -a $rev -lt 47455 ]; then
					# https://dev.openwrt.org/ticket/20556
					# needs more testing, something with linklocal IPv4/macvlan does not work
					func_update2color 'bad_version:macvlanIPv4_broken'
				elif [ $rev -gt 44150 ]; then
					func_update2color 'testing'
				else
					return 1
				fi
			;;
		esac
	}

	kernel_color()
	{
		case "$1" in
			"3.2.5"|"3.3.3"|"3.7.3"|"3.7.9"|"3.2.9"|'3.10.28')	# 4 x ar71xx | brcm47xx
				echo "$COLOR_DARK_GREEN"
			;;
			"3.2.13")				# brcm47xx
				echo "$COLOR_BRIGHT_GREEN"
			;;
			'3.14.29'|'3.18.8'|'4.1.16')		# ar71xx
				echo "$COLOR_BRIGHT_GREEN"
			;;
			"3.4.0"*)				# pandaboards
				echo "$COLOR_BRIGHT_GREEN"
			;;
			*)
				echo "$COLOR_LIGHT_PINK"
			;;
		esac
	}

	kernel_timestamp()	# http://de.wikipedia.org/wiki/Linux_(Kernel)#Versionsgeschichte_ab_Version_2.6
	{
		# files generated via '/var/www/scripts/read_kernel_release_dates.sh'
		if [ -e "/var/www/kernel_history/${1:-no_input}" ]; then
			cat "/var/www/kernel_history/$1"
		else
			# 1 jan 1992		// 7 Feb 2012    date --date "2012-11-26 00:00:00" +%s
			echo "694220400"
		fi
	}

	local kmajor="$( echo "$v1" | cut -d'-' -f1 )"		# e.g. 3.0.0
	local kminor="$( echo "$v1" | cut -d'-' -f2 )"		# e.g. -15-generic	// fixme!
	local kerneltime="$( kernel_timestamp "$kmajor" )"
	local kerneldate="$( date -d @$kerneltime | sed 's/ /_/g' )"
	local sortkey="sorttable_customkey='$(( $kerneltime / 3600 ))'"		# small integer
	local title="$kminor/$(( ($UNIXTIME_SCRIPTSTART - $kerneltime) / 86400 ))days_old:$v1=$kerneldate"

	# kernel
	printf '%s' "<td bgcolor='$( kernel_color "$v1" )' $sortkey title='$title'><small>$kmajor</small></td>"
	# git
	printf '%s' "<td bgcolor='$( good_git_color "$v2" )' align='right'><small>$v2</small></td>"	

cell_ram()				# fixme! this must be a graph, which is red/green
{					# fixme! convert all to kilobytes
	local ram_size="$1"
	local ram_free="$2"
	local ram_free_after_flush="$3"
	local zram_reads="$4"
	local zram_writes="$5"
	local zram_memusage="$6"
	local zram_compressed_size="$7"
	local ram_option="$8"		# 1 = existing '/www/SIMPLE_MESHNODE'
	local bgcolor obj

	local linebreak='&#10;'
	local color_lightgreen="lime"
	local color_forestgreen="#99cc33"
	local color_alarm="crimson"

	case "$ram_size" in
		12*|13*)
			if [ ${#ram_size} -eq 5 ]; then			# 129xx|13xxx Kilobytes
				if   [ -z "$zram_memusage" ]; then
					bgcolor="$color_alarm"		# means: zram not enabled
				elif [ "$zram_memusage" -lt 320000 ]; then	# pppoe needs 285k, others ~210k
					bgcolor="$color_lightgreen"
				else
					:
				fi
			else
				bgcolor="$color_forestgreen"
			fi	
		;;
		*)
			bgcolor="$color_lightgreen"
		;;
	esac

#	[ ${zram_writes:-0} -gt 1 -a $ram_size -gt 16384 ] && {
#		bgcolor="blue"
#	}

	printf '%s' "<td sorttable_customkey='$ram_size' align='right' bgcolor='$bgcolor' title='"

	[ "$ram_option" = "1" ] && printf '%s' "SIMPLE_MESHNODE:"

	printf '%s' "size:${ram_size}${linebreak}"
	printf '%s' "-free:${ram_free}${linebreak}"
	printf '%s' "-free_flushed:${ram_free_after_flush}${linebreak}"
	printf '%s' "-zram_r/w:${zram_reads}/${zram_writes}${linebreak}"
	printf '%s' "-zram_memusage/compressed:${zram_memusage}/${zram_compressed_size}"

	printf '%s' "'><small>"

	[ "$ram_option" = "1" ] && printf '%s' "s"		# 1 = existing '/www/SIMPLE_MESHNODE'

	printf '%s' "$(( ${ram_size:-0} / 1000 ))M</small></td>"
}

	cell_ram "$h1" "$h2" "$h3" "$h4" "$h5" "$h6" "$h7" "$h0"

	_cell_switch "$s1" "$COST2GW" "$HW" "$i0:$i1:$i2:$i5:${linebreak}down=${i3}KB/s:up=${i4}KB/s" "$i3" "$i4" "$s2"

	cell_dhcp "$D0"
	func_cell_uptime "$UP" "$REBOOT" "$r9"

	cell_wifi_uptime "$w0" "$w1" "$w2" "$w3"

	func_cell_uptime_olsr "${OLSRRESTARTTIME:-0}" "${OLSRRESTARTCOUNT:-0}" "$UP"
	cell_klog "$k0" "$k1" "$k2" "$k3"
	cell_speed "$i6"
	cell_olsr_wifi_in "$t0"
	cell_olsr_wifi_out "$t1" "$t2" "$t3"

	func_cell_load "$LOAD"
	cell_database "$d0" "$d1"


	case "$WIFIMAC" in
		b827eb8dbbf0)
			HW="RaspberryPi"
		;;
	esac

	case "$HW" in				# order like in /etc/init.d/apply_profile.code
		"Linksys WRT54G:GS:GL"|"Linksys WRT54G/GS/GL") hwcolor="$COLOR_LIGHT_GREEN" ;;
		"RaspberryPi"|"Ubiquiti Bullet M") hwcolor="$COLOR_LIGHT_BLUE" ;;
		"TP-LINK TL-WR1043ND") hwcolor="$COLOR_LIGHT_PURPLE" ;;	# 647002 = v1.2 | f8d111 = v1.1 | 
		"Buffalo WHR-HP-G54") hwcolor="$COLOR_LIGHT_PINK" ;;
		"SPW500V") hwcolor="yellow" ;;
		"ASUS WL-HDD") hwcolor="yellow" ;;
		"ASUS WL-500g Premium V2") hwcolor="yellow" ;;
		"ASUS WL-500g Premium") hwcolor="yellow" ;;
		"Dell TrueMobile 2300") hwcolor="yellow" ;;
		"Ubiquiti RouterStation Pro") hwcolor="yellow" ;;
		"4G Systems MTX-1 Board") hwcolor="$COLOR_LIGHT_RED" ;;
		"Buffalo WZR-HP-AG300H") hwcolor="$COLOR_LIGHT_ORANGE" ;;
		"Ubiquiti Nanostation M") hwcolor="$COLOR_LIGHT_YELLOW" ;;
		"Ubiquiti Nanostation2") hwcolor="$COLOR_LIGHT_BROWN" ;;
		"Ubiquiti PicoStation2") hwcolor="$COLOR_LIGHT_APPLE" ;;
		"Ubiquiti Picostation M2HP"|"Ubiquiti PicoStation M2HP") hwcolor="$COLOR_LIGHT_GREY" ;;
		"Ubiquiti PicoStation5") hwcolor="$COLOR_LIGHT_GREEN" ;;
		"Pandaboard") hwcolor="#408080" ;;
		*) hwcolor="white" ;;
	esac

	locally_administered=
	case "$WIFIMAC" in
		?'2'*|?'3'*|?'6'*|?'7'*|?'a'*|?'b'*|?'e'*|?'f'*|?'A'*|?'B'*|?'E'*|?'F'*)
			locally_administered='&lowast;&nbsp;'
			hwcolor="white"
		;;
	esac

	printf '%s' "<td bgcolor='$hwcolor' sorttable_customkey='$HW-$WIFIMAC'><small><a href='meshrdf/recent/$WIFIMAC' title='$HW'>${locally_administered}$WIFIMAC</a></small></td>"

	case "$WIFIMAC" in
		b827eb8dbbf0)
			HW="Pandaboard"
		;;
	esac

case "$NETWORK" in
	xoai)
		# howto: 1 mac with 2 pics? -> just count up?
		case "$WIFIMAC" in
			19|'6470028b2260') PORT=7534 ;; # F5-front / 00:1a:97:01:8b:19
			18|'6470028b1286') PORT=7234 ;; # F4-back  / 00:1a:97:01:84:03
			16|'6470028b1ba2') PORT= ;; # F6-front / 00:1a:97:01:8b:16
			14|'54e6fcf5b97c') PORT= ;; # F3-front / 00:1a:97:01:8b:1e
			 9|'b0487ac5dc58') PORT= ;; # F4-front / 00:1a:97:01:84:07
			 8|'f4ec38c9c32c') PORT=7783 ;; # F3-back  / 
			 7|'f6ec38c9bfc0') PORT= ;; # F5-back  /
			 6|'b2487abecab8') PORT=7528 ;; # F2-back  /
			 5|'f8d111a9c98c') PORT=7495 ;; # F2-front /
			 4|'f6ec38c9bede') PORT=7522 ;; # GF-kitchen /
			 3|'f8d111a9c4aa') PORT=7466      ;; # GF-reception /
			 2|'a0f3c17492b7') PORT=      ;; # GF-central-inetoffer /
			*)
				PORT=
			;;
		esac

		[ -e "$TMPDIR/PORTFW" ] || {
			echo  >"$TMPDIR/PORTFW" 'case "$WIFIMAC" in'
			wget -qO - "http://$LAST_REMOTE_ADDR/cgi-bin-tool.sh?OPT=portforwarding_table" | grep -F 'port: 80 ' | sed -n 's/^### \(.*\)/\1/p' >>"$TMPDIR/PORTFW"
			echo >>"$TMPDIR/PORTFW" '	*) PORT= ;; esac'
			echo >>"$TMPDIR/PORTFW" '#'
			sed -i 's/://g' "$TMPDIR/PORTFW"

			cp "$TMPDIR/PORTFW" "$TMPDIR/PORTFW.$NETWORK"
		}
		. "$TMPDIR/PORTFW"


		[ -n "$PORT" ] && {
			# http://ffmpeg.gusari.org/static/32bit/ffmpeg.static.32bit.latest.tar.gz
			FFMPEG='/usr/local/bin/ffmpeg'
			FFMPEG_OPT1='-nostdin -an -f mjpeg -timeout 10M -probesize 32 -analyzeduration 32 -i'
			FFMPEG_OPT2='-vframes 1 -y'
			URL="$LAST_REMOTE_ADDR:$PORT/cgi/mjpg/mjpeg.cgi"
			URL_PROTECTED="http://$URL"
			URL="http://admin:admin@$URL"
			DEST="/var/www/networks/$NETWORK/settings/$WIFIMAC.screenshot.jpg"
			echo "$URL_PROTECTED" >"${DEST}.link"

			echo "# $(date) $FFMPEG $FFMPEG_OPT1 '$URL' $FFMPEG_OPT2 '$DEST'" >>"$TMPDIR/PORTFW"
			# fetching a single JPG from MJPEG
			$FFMPEG $FFMPEG_OPT1 "$URL" $FFMPEG_OPT2 "$DEST" 	# || echo "err $?" >>$TMPDIR/BLA
			echo "# $(date): $?" >>"$TMPDIR/PORTFW"
		}

		PORT=
	;;
esac

	cell_essid "$ESSID" "$r0" "$r1" "$r2" "$r3" "$r4" "$r5"
	cell_channel "$CHANNEL"
	cell_node "$NODE"

	_cell_profile "$PROFILE" "$WIFIMODE" "$BSSID"
	func_cell_disk_free "$SERVICES" "$u0"

	func_cell_nexthop		"$GWNODE" "$i1"
	func_cell_nexthop_effective	"$GWNODE" "$OPTIMIZENEIGH" "$OPTIMIZENLQ" "$NETWORK"
	
	func_cell_wifimode "$WIFIMODE" "$WIFIDRV"

	printf '%s' "<td align='center'> $HOP2GW </td>"
	
	func_cell_cost2gw "$COST2GW" "$NETWORK"
	_cell_txpower "$TXPWR"	
	_cell_mrate "$MRATE" "$WIFIMODE" "$NETWORK"

	[ "$HW" = "Pandaboard" ] && GMODE=    # fixme!
	printf '%s' "<td> $GMODE </td>"
	
	func_cell_noise "$NOISE" "$SENS"
	_cell_signal "$RSSI" "$WIFIMODE"
	_cell_wifi_neighs "$WIFINEIGHS" "$NEIGH" "$WIFIMODE"
	_cell_wired_neighs "$WIREDNEIGHS" "$NETWORK" "$n0"
	_cell_sensitivity "$SENS"
	func_cell_pfilter "$PFILTER"

	echo    "</tr>"

} done | sort -rn >>$OUT

ROUTER_ALL="$( ls -1 recent/ | grep "[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]"$ | wc -l )"
ROUTER_OMITTED="$( grep -s 'omitted:' "$OUT" | wc -l )"
ROUTER_COUNT=$(( $ROUTER_ALL - $ROUTER_OMITTED ))

FILESIZE_DATA="$( stat -c %s meshrdf.txt )"
FILESIZE_DATA="$(( ${FILESIZE_DATA:-0} / 1048576 )).$( echo $(( ${FILESIZE_DATA:-0} % 1048576 )) | cut -b1-2 )mb"

# DIRSIZE_VDS="$( du -sh ../vds/ | sed -n 's/^\([0-9,]*.\).*/\1/p' )"
DIRSIZE_VDS="$( du -sh ../vds/ )"

NODE_GOOD="$( grep -s 'node_good' "$OUT" | cut -d' ' -f3 )"
NODE_WEEK="$( grep -s 'node_weak' "$OUT" | cut -d' ' -f3 )"
NODE_LOST="$( grep -s 'node_lost' "$OUT" | cut -d' ' -f3 )"
NODE_AUTO="$( grep -s 'node_auto' "$OUT" | cut -d' ' -f3 )"

[ -e  ../log/log.txt ] && tail -n 50 ../log/log.txt >../log/log_short.txt

LB="/networks/$NETWORK"

DSL_PROTO="http"
PORT80=
PORT443=
case $NETWORK in
	tkolleg|schoeneck)
		PORT80=10080
		PORT443=10443
	;;
	zumnorde)
		PORT80=10080
		PORT443=10443
	;;
	ejbw)
		PORT80=20080
		PORT443=20443
	;;
	aschbach)
		PORT80=5480
		PORT443=5443
		PORT_DSL=8080
	;;
	hotello*)
		PORT443=22443
		PORT_DSL=8080
		
	;;
	olympia*)
		PORT443=22443
		PORT_DSL=450
		DSL_PROTO="https"
	;;
	leonardo*)
		PORT80=10080
		PORT443=10443
	;;
esac

[ -n "$PORT80"  ] && PORT80=":$PORT80"
[ -n "$PORT443" ] && PORT443=":$PORT443"

SPLASH="cgi-bin-welcome.sh?REDIRECTED=1"
TRAFFIC="traffic.png"

# todo: only show links, that are working
ADDLINK="- <a title='copy of open source developer environment' href='https://github.com/bittorf/kalua'>weblogin</a>:&nbsp;"
ADDLINK="$ADDLINK<a href='http://${LAST_REMOTE_ADDR}${PORT80}/$SPLASH'>http</a>/<a href='https://${LAST_REMOTE_ADDR}${PORT443}/$SPLASH'>https</a>"
ADDLINK="$ADDLINK/<a href='http://${LAST_REMOTE_ADDR}${PORT80}/cgi-bin/userdb'>userdb</a>"
ADDLINK="$ADDLINK/<a href='https://${LAST_REMOTE_ADDR}${PORT443}/cgi-bin/userdb'>userdb-SSL</a>"
ADDLINK="$ADDLINK/<a href='http://${LAST_REMOTE_ADDR}${PORT80}/$TRAFFIC'>Traffic</a>"
ADDLINK="$ADDLINK/<a href='https://${LAST_REMOTE_ADDR}${PORT443}/$TRAFFIC'>TrafficSSL</a>"
[ -n "$PORT_DSL" ] && {
	ADDLINK="$ADDLINK/<a href='${DSL_PROTO}://${LAST_REMOTE_ADDR}:${PORT_DSL}/'>WebUI DSL-Router</a>"
}

case $NETWORK in
	ejbw-pbx)
		read LAST_REMOTE_ADDR </var/www/networks/ejbw/meshrdf/recent/002590382edc.pubip
	;;
esac

case $NETWORK in
	vivaldi|ejbw-pbx)
		ADDLINK="$ADDLINK - <a href='http://${LAST_REMOTE_ADDR}${PORT80}/status.html'>local_monitoring</a>"
	;;
esac

free_disk_space()
{
	local partition="/dev/xvda1"
	local blocks space

	blocks="$( df | sed -n "s#^${partition}[^0-9]*[0-9]*[^0-9]*[0-9]*[^0-9]*\([0-9]*\).*#\1#p" )"

	echo "$(( ${blocks:-1} / 1024 ))M"		# megabytes
}

monitoring_data_per_day()
{
	local bytes_one_alive_cycle_all_routers bytes

	bytes_one_alive_cycle_all_routers="$( du --bytes recent | sed -n 's/^\([0-9]*\).*/\1/p' )"

	bytes="${bytes_one_alive_cycle_all_routers:-0}"
	bytes="$(( $bytes * 4 * 24 ))"				# each 15 mins, 24 hours
	bytes="$(( $bytes / 1024 / 1024 ))"			# megabytes

	echo "${bytes}mb/day"
}


UNIXTIME_SCRIPTREADY="$( date +%s )"
if [ -e "$TMPDIR/lastready/$NETWORK.lastready" ]; then
	read UNIXTIME_SCRIPTLASTREADY <"$TMPDIR/lastready/$NETWORK.lastready"
else
	UNIXTIME_SCRIPTLASTREADY="$UNIXTIME_SCRIPTREADY"
fi
# disk full?
test -z "$UNIXTIME_SCRIPTLASTREADY" && UNIXTIME_SCRIPTLASTREADY="$UNIXTIME_SCRIPTREADY"
# UNIXTIME_SCRIPTLASTREADY="${UNIXTIME_SCRIPTLASTREADY:-$UNIXTIME_SCRIPTREADY}"

mkdir -p "$TMPDIR/lastready"	# chmod -R 777
echo "$UNIXTIME_SCRIPTREADY" >"$TMPDIR/lastready/$NETWORK.lastready"

DURATION_BUILDTIME=$(( $UNIXTIME_SCRIPTREADY - $UNIXTIME_SCRIPTSTART ))
DURATION_BUILDCYCLE=$(( $UNIXTIME_SCRIPTREADY - $UNIXTIME_SCRIPTLASTREADY ))
if [ $DURATION_BUILDCYCLE -lt 180 ]; then
	DURATION_BUILDCYCLE="$DURATION_BUILDCYCLE sec"
else
	DURATION_BUILDCYCLE="$(( $DURATION_BUILDCYCLE / 60 )) min"
fi

show_screenshots()
{
	local file mac time title title_short hostname i=0
	local table_start=1

	# fixme! sort by hostname | group by hostname prefix

	list()
	{
		for file in /var/www/networks/$NETWORK/settings/*.screenshot.jpg; do {
			[ -e "$file" ] || continue
			hostname="$( cat "$( echo "$file" | cut -d'.' -f1 ).hostname" )"
			echo "$hostname $file"
		} done | sort | cut -d' ' -f2
	}

	for file in $( list ); do {
		[ "$table_start" = 1 ] && {
			printf '%s' "<table cellspacing='0' cellpadding='0' border='0'><tr>"
			table_start=0
		}

		[ -e "$file" ] || continue
		mac="$( basename "$file" | cut -b 1-12 )"
		grep -sq ^"$mac" "/var/www/networks/$NETWORK/ignore/macs.txt" && continue

		has_exif_metadata()
		{
			strings "$1" | grep -q ^"UNIXTIME:"
		}

		if has_exif_metadata "$file"; then
			time="$( strings "$file" | grep ^"UNIXTIME:" | cut -d':' -f2 )"
		else
			time="$( stat --printf %Y "$file" )"
		fi

		time_diff="$(( ($UNIXTIME_SCRIPTSTART - $time) / 60 ))"
		time_human="-${time_diff}min-$( date -d @$time )"
		title="$( cat "$( dirname "$file" )/${mac}.hostname" )_ago:$time_human"
		title="$( echo "$title" | sed 's/beamer/tagebuchbeamer/' )"

		title_short="$( echo "$title" | cut -d':' -f1 )"
		case "$title_short" in
			*"_ago")
				title_short="$( echo "$title_short" | cut -d'_' -f1 )"

				if   [ $time_diff -gt 999 ]; then
					title_short="<font color='red'><b>$title_short - veryold</b></font>"
				elif [ $time_diff -gt 240 ]; then
					title_short="<font color='red'><b>$title_short - ${time_diff}min!!!</b></font>"
				else
					if has_exif_metadata "$file"; then
						time_diff="$(( $UNIXTIME_SCRIPTSTART - $time ))"
						title_short="${title_short}<small> - vor ${time_diff} sec/EXIF</small>"
					else
						title_short="${title_short}<small> - vor ${time_diff} min</small>"
					fi
				fi
			;;
		esac

		local linkdest="$LB/settings/$mac.screenshot.jpg"
		local width height
		case "$NETWORK" in
			gnm)
				width="273px"
				height="153px"
			;;
			xoai|*)
				width='240px'	# 601 / 2.5
				height='180px'	# 451 / 2.5
				linkdest="/var/www/networks/$NETWORK/settings/$mac.screenshot.jpg.link"
				[ -e "$linkdest" ] && read linkdest <"$linkdest"
#				[ -e "$linkdest.link" ] && read linkdest <"$linkdest.link"
			;;
		esac

		printf '%s' "<td>$title_short<br><a href='$linkdest' type='image/jpeg' title='$title'>"
		printf '%s' "<img src='$LB/settings/$mac.screenshot.jpg' width='$width' height='$height' alt='screenshot of $mac' border='1'>"
		printf '%s' "</a></td>"

		case "$title_short" in
			*beamer*|event5of5*|kasse2*)
				printf '%s' "</tr><tr>"
			;;
		esac

		case "$NETWORK" in
			xoai)
				i=$(( $i + 1 ))

				[ $i -eq 4 ] && {
					i=0
					printf '%s' "</tr><tr>"
				}
			;;
		esac
	} done

	[ "$table_start" = 0 ] && {
		printf '%s' "</tr></table>"
	}
}

show_rrdimages()
{
	local file
	local source="/dev/shm/rrd/$NETWORK/rrd_images"

	if [ -e "$source" ]; then
		while read file; do {
			echo "<img border='0' alt='$file' src='$LB/media/$file'>"
		} done <"$source"
	else
		echo "<h3>no RRD files found in '$source'"
	fi
}

[ $ROUTER_COUNT -gt 0 ] && PERCENT_GOOD=$(( (${NODE_GOOD:-0} * 100) / $ROUTER_COUNT ))
[ $PERCENT_GOOD -gt 80 ] && touch "/dev/shm/${NETWORK}_good_over_80percent"
[ $PERCENT_GOOD -lt 50 -a -e "/dev/shm/${NETWORK}_good_over_80percent" ] && {
	touch "$TMPDIR/DETECTED_FAULTY_$NETWORK"
}

LINK_GIT_COMMITS="http://www.datenkiste.org/cgi-bin/gitweb.cgi?p=fff;a=summary"
LINK_GIT_COMMITS="https://github.com/bittorf/kalua/commits/master"

echo >>$OUT "</table><h3>$ROUTER_COUNT routers in list <small>(${NODE_GOOD} good = ${PERCENT_GOOD}%, ${NODE_WEEK} weak, ${NODE_LOST} lost, autodetected ${NODE_AUTO} of these, $ROUTER_OMITTED <a href='$LB/ignore/macs.txt'>omitted</a>)</small> - <a href='$LB/log/log.txt'>Systemlog</a> (<a href='$LB/log/log_short.txt'>kurz</a>) - <a href='$LB/meshrdf/netjson.html'>TopologyMap</a> - <a href='$LINK_GIT_COMMITS'>ChangeLog/GIT</a> - <a href='firmware'>Firmware</a> - <a href='$LB/meshrdf/tools.txt'>Shell-Wizards</a> - <a href='http://wireless.subsignal.org/index.php?title=Software-Betatest'>Wiki</a> - <a href='$LB/meshrdf/meshrdf.txt'>monitoring.data <small>($FILESIZE_DATA)</small></a> - <a href='$LB/vds'>VDS-Data <small>(${DIRSIZE_VDS:-0M})</small></a> - <a href='$LB/packages'>Packages</a> -<small> IPv4: $LAST_REMOTE_ADDR ($LAST_REMOTE_ADDR_NODE)</small>-<small> FreeSpace: $( free_disk_space ) </small><small>${ADDLINK} generated: $LOCALTIME in $DURATION_BUILDTIME sec | each $DURATION_BUILDCYCLE - monitraff: $( monitoring_data_per_day )</small> - <small><a href='$LB/meshrdf/$FILE_FAILURE_OVERVIEW'>ErrorOverview.txt</a></small> - <small>DoubleIPs: '${DOUBLE_NODENUMBERS:-none}'</small></h3>$( show_screenshots )<br>$( show_rrdimages )"
 

cat >>$OUT <<EOF
<script type="text/javascript">
<!-- force presort for specific row
var myTH = document.getElementsByTagName("th")[1];
sorttable.innerSortFunction.apply(myTH, []);
// -->
</script>
EOF

echo >>$OUT "</body></html>"

# log "copying '$OUT' = ('$( ls -l "$OUT" )') to '$REAL_OUT.temp' pwd: '$(pwd)'"
cp "$OUT" "$REAL_OUT.temp" 2>$TMPDIR/uuu2 1>$TMPDIR/uuu1 >$TMPDIR/uuu || log "error copy: $? $( cat $TMPDIR/uuu $TMPDIR/uuu1 $TMPDIR/uuu2 )"
rm $TMPDIR/uuu $TMPDIR/uuu1 $TMPDIR/uuu2
rm "$OUT" || log "error remove"
# log "copying '$REAL_OUT.temp' = ('$(  ls -l "$REAL_OUT.temp" )') to '$REAL_OUT'"
cp "$REAL_OUT.temp" "$REAL_OUT" 2>$TMPDIR/uuu2 1>$TMPDIR/uuu1 >$TMPDIR/uuu || log "error copy: $? $( cat $TMPDIR/uuu $TMPDIR/uuu1 $TMPDIR/uuu2 )"
rm $TMPDIR/uuu $TMPDIR/uuu1 $TMPDIR/uuu2
# log "see here: '$( ls -l "$REAL_OUT" )'"

bla()
{
	local line p1 p2 p p_old

	sort "${FILE_FAILURE_OVERVIEW}.tmp" | while read line; do {
		p1="$( echo "$line" | cut -d'-' -f1 )"
		p2="$( echo "$line" | cut -d'-' -f1 )"
		p="${p1}-${p2}"		# HausA-1234

		[ "$p" = "$p_old" ] || echo "$LINE"
		p_old="$p"

	} done >>"$FILE_FAILURE_OVERVIEW"
}

sort "${FILE_FAILURE_OVERVIEW}.tmp" >>"$FILE_FAILURE_OVERVIEW"

case "$NETWORK" in
	apphalle|castelfalfi|leonardo|schoeneck|extrawatt|olympia|aschbach|boltenhagendh|rehungen|vivaldi|marinabh)
		SMS_ALLOWED=
	;;
	preskil|gnm)
		SMS_ALLOWED=
	;;
	vivaldi)
		case "$( date +%H )" in
			03|04|05)
				SMS_ALLOWED=
			;;
			*)
				SMS_ALLOWED="true"
			;;
		esac
	;;
	*)
		SMS_ALLOWED="true"
	;;
esac

case "$NETWORK" in
	schoeneck)
		echo "}" >>"$TMPDIR/schoeneck.dot"
		dot -Tpng "$TMPDIR/schoeneck.dot" >"$TMPDIR/schoeneck.png"
		# needs: chmod -R 777 /var/www/networks/schoeneck/media
		cp "$TMPDIR/schoeneck.png" "/var/www/networks/schoeneck/media/map_topology_$LOCALTIME.png"
	;;
esac

if [ -e "$TMPDIR/DETECTED_FAULTY_$NETWORK" ]; then
	[ -e "$TMPDIR/IS_FAULTY_$NETWORK" ] || {
		[ ${NODE_GOOD:-0} -gt 0 ] && {
			touch "$TMPDIR/IS_FAULTY_$NETWORK"
			echo >>$TMPDIR/faulty_history.txt "$(date): $NETWORK is faulty now"
			[ -n "$SMS_ALLOWED" ] && /var/www/scripts/send_sms.sh "$NETWORK" "admin-$MAC" "error_gateway"
		}
	}
else
	[ -e "$TMPDIR/IS_FAULTY_$NETWORK" ] && {
		echo >>$TMPDIR/faulty_history.txt "$(date): $NETWORK is GOOD again"
		rm "$TMPDIR/IS_FAULTY_$NETWORK"
		[ -n "$SMS_ALLOWED" ] && /var/www/scripts/send_sms.sh "$NETWORK" "admin-$MAC" "error_fixed"
	}
fi

echo >>$TOOLS '"'
echo >>$TOOLS
echo >>$TOOLS '# adhoc:'
echo >>$TOOLS "# LIST='$( cat 2>/dev/null $TMPDIR/list_adhoc_mode.$$ && rm $TMPDIR/list_adhoc_mode.$$ )'"
echo >>$TOOLS '# ap:'
echo >>$TOOLS "# LIST='$( cat 2>/dev/null $TMPDIR/list_ap_mode.$$ && rm $TMPDIR/list_ap_mode.$$ )'"
echo >>$TOOLS "# special_git: '$REM_SPECIALGIT'"
echo >>$TOOLS "# LIST='$( cat 2>/dev/null $TMPDIR/list_specialgit.$$ && rm $TMPDIR/list_specialgit.$$ )'"
echo >>$TOOLS "# special_hardware: '$( cat $TMPDIR/list_specialhw.txt )'"
echo >>$TOOLS "# LIST='$( cat 2>/dev/null $TMPDIR/list_specialhw.$$ && rm $TMPDIR/list_specialhw.$$ )'"
echo >>$TOOLS
echo >>$TOOLS 'ERROR='
echo >>$TOOLS '[ -n "$1" ] && LIST="$1"'
echo >>$TOOLS ''
echo >>$TOOLS '# we can see with "ls -l $TMPDIR/COPYTEST", if scp-ing a small file works'
echo >>$TOOLS '#mkdir -p $TMPDIR/COPYTEST && echo "created dir $TMPDIR/COPYTEST"; for NODE in $LIST; do touch $TMPDIR/COPYTEST/$NODE; done'
echo >>$TOOLS ''
echo >>$TOOLS 'I=0; for NODE in $LIST;do I=$(( $I + 1 )); done; ALL=$I; I=0'
echo >>$TOOLS 'for NODE in $LIST ;do {'
echo >>$TOOLS ''
echo >>$TOOLS '	eval "$( _ipsystem get $NODE )"; I=$(( $I + 1 ))'
echo >>$TOOLS '# WIFIADR=192.168.\$NODE.1'
echo >>$TOOLS '# for I in $(seq 1 256); do ip a del 10.10.$I.130/25 dev $LANDEV; done'
echo >>$TOOLS '# ip a a 10.10.${NODE}.130/25 dev $LANDEV; WIFIADR=$LANADR'
echo >>$TOOLS '	echo "trying node \"$NODE @${WIFIADR}\", which is $I/$ALL ($(( ($I * 100) / $ALL ))%)"'
echo >>$TOOLS "#	case \"\$( uci get wireless.@wifi-iface[0].ssid )\" in *[0-9]) /sbin/uci set wireless.@wifi-iface[0].ssid='Network \$NODE (maintenance)'; /sbin/uci commit wireless; /sbin/wifi ;; esac"
echo >>$TOOLS '#	ssh -i /etc/dropbear/dropbear_dss_host_key "${WIFIADR}" "pidof crond || /etc/init.d/*crond_fff+ start" || {'
echo >>$TOOLS '#		ERROR="$ERROR $NODE"'
echo >>$TOOLS '#	}'
echo >>$TOOLS
echo >>$TOOLS "#	if _tool remote \$WIFIADR command 1 YOURPASS 'echo >>\$SCHEDULER_IMPORTANT \"_firmware update_pmu\"'; then"
echo >>$TOOLS '#	if scp -p -i /etc/dropbear/dropbear_dss_host_key $TMPDIR/fw ${WIFIADR}:/tmp ; then'
echo >>$TOOLS '#	ping -c 5 $WIFIADR; _tool remote $WIFIADR startshell'
echo >>$TOOLS '	if scp -p -i /etc/dropbear/dropbear_dss_host_key "script.sh" "${WIFIADR}:$TMPDIR/.autorun"; then'
echo >>$TOOLS '		: # watch_sysupgrade'
echo >>$TOOLS '	else'
echo >>$TOOLS '		ERROR="$ERROR $NODE"'
echo >>$TOOLS '	fi'
echo >>$TOOLS '#	else'
echo >>$TOOLS '#		ERROR="$ERROR $NODE"'
echo >>$TOOLS '#	fi'
echo >>$TOOLS ''
echo >>$TOOLS '} done && rm script.sh'
echo >>$TOOLS "test -n \"\$ERROR\" && echo \"please enter sh $TOOLS '\$ERROR'\""


RECIPE="$USECASE_FILE.firmware_baking_recipe.sh"
TAB='	'

# TODO: different values for different networks - and: keep history
MODE_STABLE_REV=44150
MODE_STABLE_FEEDSTIME='2015-01-25 23:40'
MODE_BETA_REV=49276
MODE_BETA_FEEDSTIME='2016-04-30 16:54'
MODE_TESTING_REV=3582	# LEDE
MODE_TESTING_FEEDSTIME=
BUILD_ID="firmware@bittorf-wireless.com"
BUILD_SCRIPT_URL='https://raw.githubusercontent.com/bittorf/kalua/master/openwrt-build/build.sh'
BUILD_SCRIPT_START="$( date )"

[ -s "$TMPDIR/build.sh" ] || {
	if wget --no-check-certificate -O "$TMPDIR/build.sh" "$BUILD_SCRIPT_URL"; then
		# because a 0-byte file gives no error when executed O_o
		test -s "$TMPDIR/build.sh" && chmod +x "$TMPDIR/build.sh"
	else
		rm -fR "$TMPDIR/build.sh"
	fi
}


usecase_hash()		# see: _firmware_get_usecase()
{
	local usecase="$1"
	local oldIFS="$IFS"; IFS=','; set -- $usecase; IFS="$oldIFS"

	# print each word without appended version @...
	# output the same hash, no matter in which order the words are
	while [ -n "$1" ]; do {
		echo "${1%@*}"
		shift
	} done | LC_ALL=C sort | md5sum | cut -d' ' -f1
}

hardware_is_valid()
{
	local hardware="$1"
	local cache="$TMPDIR/build-hardware_valid.txt"

	grep -q ^"is__valid:$hardware|"$ "$cache" && return 0
	grep -q ^"not_valid:$hardware|"$ "$cache" && return 1

	if $TMPDIR/build.sh --hardware "$hardware" check_valid >/dev/null; then
		echo "is__valid:$hardware|" >>"$cache"
		return 0
	else
		echo "not_valid:$hardware|" >>"$cache"
		return 1
	fi
}

usecase_is_valid()
{
	local usecase="$1"
	local cache="$TMPDIR/build-usecase_valid.txt"

	grep -q ^"is__valid:$usecase|"$ "$cache" && return 0
	grep -q ^"not_valid:$usecase|"$ "$cache" && return 1

	if $TMPDIR/build.sh --usecase "$usecase" check_valid >/dev/null; then
		echo "is__valid:$usecase|" >>"$cache"
		return 0
	else
		echo "not_valid:$usecase|" >>"$cache"
		return 1
	fi
}

mode2rev()
{
	case "$1" in
		'stable')
			echo "$MODE_STABLE_REV"
		;;
		'beta')
			echo "$MODE_BETA_REV"
		;;
		'testing')
			echo "$MODE_TESTING_REV"
		;;
	esac
}

sh -n "$USECASE_FILE" && cd .. && {
	SERVER="root@intercity-vpn.de:$PWD"
	mkdir -p 'firmware'

	echo '#!/bin/sh'
	echo "# generated for network '$NETWORK' @$BUILD_SCRIPT_START from $0"
	echo '#'
	echo '# firmware updatemodes:'
	echo "# - stable..............: r$MODE_STABLE_REV"
	echo "# - beta................: r$MODE_BETA_REV"
	echo "# - testing/avantgarde..: r$MODE_TESTING_REV (LEDE)"
	echo '#'
	echo '# prepare your env with e.g.:'
	echo "# export PATH=\"~:\$PATH\""
	echo '# mkdir -p YOUR_BUILD_DIR && cd YOUR_BUILD_DIR'
	echo '#'
	echo "# URL='$BUILD_SCRIPT_URL'"
	echo "# wget -O build.sh \"\$URL\" && chmod +x build.sh"
	echo "# ./build.sh --openwrt trunk --download_pool \$HOME/openwrt_dl"
	echo "# ./build.sh --openwrt lede  --download_pool \$HOME/openwrt_dl"
	echo '#'
	echo "# and copy your public key for upload to: $( echo "$SERVER" | cut -d':' -f1 )"
	echo '# and execute this script:'
	echo
	echo 'export FAILED='
	echo

	# TODO: show stats: count different models, different usecases, overall jobs and estimated build-time

	[ "$NETWORK" = 'liszt28' ] && echo >>"$USECASE_FILE" "USECASE='Standard-4mb,kalua'; HARDWARE='UML'; WIFIMAC='112233445566';"

	ALREADY_WRITTEN=
	STABLE=0;BETA=0;TESTING=0;OVERALL=0;OVERALL_READY=0
	while read -r LINE; do {
		# USECASE='Standard,LuCIfull,debug,kalua'; HARDWARE='TP-LINK TL-WR1043ND'; WIFIMAC='6670025c2045';
		# USECASE=''; HARDWARE='TP-LINK TL-WR1043ND'; WIFIMAC='f8d111a9cec8';
		USECASE=;HARDWARE=;WIFIMAC=;OPENWRT_REV=;
		eval $LINE

		[ -z "$USECASE" ] && {
			case "$HARDWARE" in
				'Ubiquiti Nanostation2'|'Ubiquiti Nanostation5')
					USECASE='Standard-4mb,kalua'
				;;
				*)
					USECASE='Standard,kalua'
				;;
			esac
		}

		# enforce a usecase:
		case "$NETWORK" in
			'itzehoe') USECASE='Standard,kalua' ;;
		esac

		case "$USECASE" in
			'Standard,'*)
				case "$USECASE" in
					*'USBstorage,'*)
						# this is already an auto-included sub-usecase
						USECASE="$( echo "$USECASE" | sed 's/USBstorage,//g' )"
					;;
				esac
			;;
		esac

		# ugly fixes for netnet:
		case "$USECASE" in
			*'MinstrelBlues,'*)
				USECASE="$( echo "$USECASE" | sed 's/MinstrelBlues,//g' )"
			;;
			*'MinstrelRhapsody'*)
				USECASE="$( echo "$USECASE" | sed 's/MinstrelRhapsody,//g' )"
			;;
			'Standard,musl,kalua')
				USECASE='Standard,kalua'
			;;
			'Small,noOPKG,noPPPoE,noDebug,OLSRd,kalua')
				USECASE='Standard-4mb,kalua'
			;;
			'Small,noSSH,noOPKG,noPPPoE,OLSRd,kalua')
				USECASE='Standard-4mb,kalua'
			;;
			'Small,squash256,noSSH,noOPKG,noPPPoE,noDebug,OLSRd,kalua')
				USECASE='Standard-4mb,kalua'
			;;
			'Small,noPPPoE,OLSRd,kalua')
				USECASE='Standard-4mb,kalua'
			;;
			'Small,vtun,noSSH,noOPKG,noPPPoE,noDebug,OLSRd,kalua')
				USECASE='Standard-4mb,vtun,kalua'
			;;
			'Small,USBprinter,noOPKG,noPPPoE,noDebug,OLSRd,kalua')
				USECASE='Standard-4mb,USBprinter,kalua'
			;;
		esac

		USECASE_HASH="$( usecase_hash "$USECASE" )"

		case "$HARDWARE" in
			'toomuchreboots-'*)
				HARDWARE="$( echo "$HARDWARE" | cut -b16- )"
			;;
		esac

		# ugly fixes for testnet:
		case "$NETWORK: $HARDWARE" in
			'liszt28: T-Mobile InternetBox') HARDWARE='T-Mobile InternetBox TMD SB1-S';;
			'liszt28: TP-LINK TL-WDR3600/4300/4310') HARDWARE='TP-LINK TL-WDR4300';;
			'liszt28: Ubiquiti Bullet M') HARDWARE='Ubiquiti Bullet M5';;
		esac

		case "$HARDWARE - $USECASE" in
			'Ubiquiti Bullet5 - Standard,kalua') USECASE='Standard-4mb,kalua' ;;
		esac

		hardware_is_valid "$HARDWARE" || {
			[ $OPENWRT_REV -eq 0 ] || echo "# DEBUG: hardware invalid: '$HARDWARE' - see: $WIFIMAC"
			continue
		}

		usecase_is_valid "$USECASE" || {
			echo "# DEBUG: usecase invalid: '$USECASE' - see: $WIFIMAC"
			continue
		}

		WRITTEN_HASH="$( echo "$HARDWARE+$USECASE_HASH" | md5sum | cut -d'-' -f1 )"
		case "$ALREADY_WRITTEN" in *"$WRITTEN_HASH"*) continue;; *) ALREADY_WRITTEN="$ALREADY_WRITTEN $WRITTEN_HASH";; esac

		# 'Linksys WRT54G/GS/GL' -> 'Linksys WRT54G:GS:GL'
		HARDWARE_FILENAME="$( echo "$HARDWARE" | tr '/' ':' )"

		for MODE in stable beta testing; do {
			REV="$( mode2rev "$MODE" )"
			OVERALL=$(( OVERALL + 1 ))

			case "$MODE" in
				'stable')
					REV_JSON="$REV"
					BUILD_DIR='openwrt'
					STABLE=$(( STABLE + 1 ))
					FNAME="s$STABLE"
					FEEDSTIME="$MODE_STABLE_FEEDSTIME"
				;;
				'beta')
					REV_JSON="$REV"
					BUILD_DIR='openwrt'
					BETA=$(( BETA + 1 ))
					FNAME="b$BETA"
					FEEDSTIME="$MODE_BETA_FEEDSTIME"
				;;
				'testing')
					REV_JSON=$(( REV + 1000000 ))
					BUILD_DIR='source'
					TESTING=$(( TESTING + 1 ))
					FNAME="t$TESTING"
					FEEDSTIME="$MODE_TESTING_FEEDSTIME"
				;;
			esac

			JSON="$PWD/firmware/models/$HARDWARE_FILENAME/$MODE/.$USECASE_HASH/info.json"
			USECASE_DIR="$PWD/firmware/models/$HARDWARE_FILENAME/$MODE/$USECASE"

			[ -d "$USECASE_DIR" ] || mkdir -p "$USECASE_DIR"
			[ -e "$JSON" ] || {
				mkdir -p "$( dirname "$JSON" )"
				{
					echo '{'
					echo "  \"firmware_rev\": \"0\""
					echo "}"
				} >"$JSON"
				cp "$JSON" "$USECASE_DIR/"
			}

# for new we only accept "CODE_PROOF_OF_BOOT" messages
#			[ $REV_JSON -eq $OPENWRT_REV ] && {
#				grep -q '"firmware_manually_checked": "false"' "$JSON" && {
#					sed -i 's/\(.*"firmware_manually_checked":\) "false"\(.*\)/\1 "true"\2/' "$JSON"
#				}
#			}

			HIDE=
			if   grep -q "\"firmware_md5\": \"deadbeef\"" "$JSON"; then
				:
			elif grep -q "\"firmware_rev\": \"$REV_JSON\"," "$JSON"; then
				HIDE='#'	# # already build
			fi

			echo "$FNAME() {"

			if [ -n "$HIDE" ]; then
				OVERALL_READY=$(( OVERALL_READY + 1 ))
				echo "${TAB}[ \"\$1\" = 'force' ] || return 0${TAB}# already built"
			else
				echo "${TAB}echo; echo '=== next_image: $FNAME ==='; echo"
			fi

			echo
			echo "${TAB}cd '$BUILD_DIR' && git checkout 'master' && test -e '.config' && rm -fR bin/ && make clean || true && \\"
			echo "${TAB}../build.sh \\"
			echo "${TAB}${TAB}--buildid '$BUILD_ID' \\"

			if [ -n "$FEEDSTIME" ]; then
				echo "${TAB}${TAB}--openwrt 'r$REV' --feedstime '$FEEDSTIME' \\"
			else
				echo "${TAB}${TAB}--openwrt 'r$REV' \\"
			fi

			echo "${TAB}${TAB}--hardware '$HARDWARE' --usecase '$USECASE' \\"
			echo "${TAB}${TAB}--release $MODE '$SERVER' || FAILED=\"\$FAILED $FNAME\""
			echo "${TAB}git stash; test -e 'LICENSE' && cd .."
			echo '}'
			echo
		} done
	} done <"$USECASE_FILE"

	I=0
	echo "stable() {"
		printf '%s' "$TAB"; while [ $I -lt $STABLE ]; do I=$(( I + 1 )); printf '%s' "s$I;"; done; echo
	echo "}"
	echo

	I=0
	echo "beta() {"
		printf '%s' "$TAB"; while [ $I -lt $BETA ]; do I=$(( I + 1 )); printf '%s' "b$I;"; done; echo
	echo "}"
	echo

	I=0
	echo "testing() {"
		printf '%s' "$TAB"; while [ $I -lt $TESTING ]; do I=$(( I + 1 )); printf '%s' "t$I;"; done; echo
	echo "}"
	echo

	echo 'all() { stable; beta; testing; }'
	echo
	echo "update() { wget -O build_all.sh http://intercity-vpn.de/networks/$NETWORK/firmware/build_all.sh; }"
	echo
	echo "# overall stable + beta + testing: $STABLE + $BETA + $TESTING = $OVERALL images"
	echo "# already build: $OVERALL_READY images"
	echo "# still needed: $(( OVERALL - OVERALL_READY )) images"
	echo '#'
	echo "# START: $BUILD_SCRIPT_START"
	echo "# READY: $( date )"
} >"$RECIPE" && cp "$RECIPE" 'firmware/build_all.sh'

generate_build_matrix()
{
	cd "$PWD/firmware/models" || return

	local bgcolor_model bgcolor_mode bgcolor_usecase color
	local color_ok='lightgreen'
	local color_bad='crimson'
	local color_unbuild='white'
	local color_untrushted='#ccffb3'

	echo '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"'
	echo '		"http://www.w3.org/TR/html4/loose.dtd">'
	echo "<html><head><title>build-matrix $NETWORK @$( date )</title><META HTTP-EQUIV=\"content-type\" CONTENT=\"text/html; charset=ISO-8859-15\"></head><body>"
	echo '<table cellspacing=1 cellpadding=1 border=0>'
	echo "<thead><tr bgcolor='lightblue'><td>&nbsp;</td><td>hardware</td><td>update</td><td>usecase</td><td>OK</td></thead><tbody>"

	MODEL_NO=0
	ls -1 | while read -r MODEL; do {
		cd "$MODEL" && {
			MODEL_NO=$(( MODEL_NO + 1 ))
			printf '%s' "<tr><td bgcolor='lightblue'>$MODEL_NO</td><td bgcolor='$color_ok'><a href='models/$MODEL'>$MODEL</a></td>"

			for MODE in stable beta testing; do {
				cd "$MODE" && {
					[ "$MODE" = 'stable' ] || printf '%s' '<tr bgcolor='$color_ok'><td>&nbsp;</td><td>&nbsp;</td>'
					printf '%s' "<td bgcolor='$color_ok'>$MODE</td>"

					ls -1 | while read -r USECASE; do {
						if   [ -e "$USECASE/info.buildlog.tar.xz" ]; then
							color="$color_bad"
							CELL_FLASHED="<td bgcolor='$color' align='center'><a href"
							CELL_FLASHED="$CELL_FLASHED='models/$MODEL/$MODE/$USECASE/info.buildlog.tar.xz'>log</a></td>"
						elif [ -e "$USECASE/info.json" ]; then
							if   grep -q '"firmware_md5": "deadbeef"' "$USECASE/info.json"; then
								color="$color_bad"
								CELL_FLASHED="<td bgcolor='$color_unbuild' align='center'>&ndash;</td>"
							elif grep -q '"firmware_manually_checked": "true"' "$USECASE/info.json"; then
								color="$color_ok"
								CELL_FLASHED="<td bgcolor='$color_ok' align='center'>&#10004;</td>"	# OK
							elif grep -q '"firmware_rev": "0"' "$USECASE/info.json"; then
								color="$color_unbuild"
								CELL_FLASHED="<td bgcolor='$color_unbuild' align='center'>&ndash;</td>"
							else
								color="$color_ok"
								CELL_FLASHED="<td bgcolor='$color_untrushted' align='center'>&ndash;</td>"
							fi
						else
							# no build-attempt for now
							color="$color_unbuild"
							CELL_FLASHED="<td bgcolor='$color_unbuild' align='center'>&ndash;</td>"
						fi

						if [ "$FIRST_PRINTED" ]; then
							printf '%s' '<tr bgcolor='$color_ok'><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td>'
							printf '%s' "<td bgcolor='$color'>$USECASE<br></td>$CELL_FLASHED</tr>"
						else
							FIRST_PRINTED='true'
							printf '%s' "<td bgcolor='$color'>$USECASE<br></td>$CELL_FLASHED</tr>"
						fi
					} done
					cd ..
				}
			} done
			cd ..
		}
	} done

	echo '</tbody></table></body></html>'
}

generate_build_matrix >'firmware/build_all.html'

log "[READY] network '$NETWORK' in $DURATION_BUILDTIME sec"
