#!/bin/sh

OUT="/tmp/doit.sh"

[ -z "$1" ] && {
	echo "Usage: $0 start"
	echo "	this generates a bash file into '$OUT'"
	echo "	and starts this with 'sh $OUT && rm $OUT'"
	echo "	this will create the file /var/www/macs/[a-f0-9]x6"

	exit 1
}

URL_SOURCE="http://standards.ieee.org/regauth/oui/oui.txt"
DIR_DEST="/var/www/macs/"
TEMP="/tmp/oui.txt"

logger -s "downloading '$URL_SOURCE' to '$TEMP'"
[ -e "$TEMP" ] || {
	wget -O "$TEMP" "$URL_SOURCE" || exit 1
}

mkdir -p /var/www/macs
chmod -R 777 /var/www/macs

logger -s "generating '$OUT'"
awk -v DIR_DEST="$DIR_DEST" '{

	if(s!=1 && substr($0,1,8) ~ /[0-9a-zA-Z-]*/){
		MAC=substr($0,1,8)
		MAC=tolower(MAC)
		gsub(/[^0-9a-f]/, "", MAC)
		if(length(MAC)==6){
			print "[ -e "DIR_DEST""MAC" ] || logger -s \"new mac "MAC"\" && cat >"DIR_DEST""MAC" <<EOF"
			s=1
		}
	}
	if(s==1){
		if(length($0)==0){
			s=0
			print "EOF"
			print
		}
		else {
			if($0 ~ /(hex)/){
				OUT=substr($0,index($0,"(hex)")+5)
				sub( /^ +/, "", OUT )	# space
				sub( /^	+/, "", OUT )	# tab
				gsub("`", "^", OUT )	# backtick
				print OUT
				FIRSTLINE=OUT
			}
			else if($0 ~ /(base 16)/){
				OUT=substr($0,index($0,"(base 16)")+9)
				sub( /^ +/, "", OUT )
				sub( /^	+/, "", OUT )
				gsub("`", "^", OUT )

				if(FIRSTLINE != OUT && length(OUT)>1)
					print OUT	# never happens
			}
			else{
				OUT=$0
				sub( /^ +/, "", OUT )
				sub( /^	+/, "", OUT )
				gsub("`", "^", OUT )
				
				if(LASTLINE != OUT)
					print OUT

				LASTLINE=OUT
			}
		}
	}
}' "$TEMP" >"$OUT"
# rm "$TEMP"

logger -s "[OK] generated '$OUT'"
