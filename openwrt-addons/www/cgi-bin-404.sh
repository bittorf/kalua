#!/bin/sh

ERROR=302

case "$HTTP_USER_AGENT" in
	"")							# ignore unknown requests from WAN
		. /tmp/NETPARAM
		[ "$SERVER_ADDR" = "$WANADR" ] && ERROR=403	# fixme! better use SERVER_NAME?
	;;
	"Microsoft NCSI")	# microsoft captive portel checker -> _http spoof_captive_portal_checker_microsoft
		ERROR=403
	;;
	"CaptiveNetworkSupport"*)	# apple captive portel checker -> _http spoof_captive_portal_checker_apple
		ERROR=403
	;;
	"htcUPCTLoader"|"Microsoft BITS"*|"ZoneAlarm"*|*"youtube"*|*"YouTube"*|"WifiHotspot"|"Skype WISPr"|*"Apple-PubSub"*|*"XProtectUpdater"*|"MPlayer"*|"Microsoft-CryptoAPI"*|"WinHttp-Autoproxy-Service"*|"Windows-Update-Agent"*)
		ERROR=403
	;;
esac

case "$HTTP_HOST" in
	*"google-analytics"*|"appenda.com"|"init.ess.apple.com"|"media.admob.com"|*".googleapis.com"|"catalog.zune.net"|*".ggpht.com")
		HTTP_USER_AGENT="$HTTP_HOST ($HTTP_USER_AGENT)"
		ERROR=403
	;;
	"liveupdate.symantecliveupdate.com"|"update.services.openoffice.org")
		HTTP_USER_AGENT="$HTTP_HOST ($HTTP_USER_AGENT)"
		ERROR=403
	;;
	"cnfg.montiera.com"|"img.babylon.com")		# invoked by search.babylon.com
		HTTP_USER_AGENT="BabylonToolbar ($HTTP_USER_AGENT)"
		ERROR=403
	;;
	"fxfeeds.mozilla.com"|"stats.avg.com"|"toolbar.avg.com")
		HTTP_USER_AGENT="LiveBookmarks ($HTTP_USER_AGENT)"
		ERROR=403
	;;
esac

/bin/busybox logger "$0: ERROR${ERROR} for IP '$REMOTE_ADDR' with HTTP_HOST/USER_AGENT: '$HTTP_HOST'/'$HTTP_USER_AGENT'"

case "$ERROR" in
	403)
		cat <<EOF
Status: 403 Forbiddden
Connection: close

EOF
	;;
	302)
		case "$REMOTE_ADDR" in
			"::"|127.*|10.*|192.168.*|172.16.*)
				read SERVER_IP <"/tmp/WIFIADR"
			;;
			*)
				read SERVER_IP 2>/dev/null </tmp/MY_PUBLIC_IP || {
					URL="$( uci get system.@monitoring[0].url )/getip"
					SERVER_IP="$( wget -qO - "$URL" )"
					echo "$SERVER_IP" >/tmp/MY_PUBLIC_IP
				}
			;;
		esac

		DESTINATION="http://$SERVER_IP/cgi-bin-welcome.sh?REDIRECTED=1"

		cat <<EOF
Status: 302 Temporary Redirect
Connection: close
Cache-Control: no-cache
Content-Type: text/html
Location: $DESTINATION

<HTML><HEAD>
<TITLE>302 Temporary Redirect</TITLE>
<META HTTP-EQUIV="cache-control" CONTENT="no-cache">
<META HTTP-EQUIV="pragma" CONTENT="no-cache">
<META HTTP-EQUIV="expires" CONTENT="0">
<META HTTP-EQUIV="refresh" CONTENT="0; URL=$DESTINATION">
</HEAD><BODY>
<H1>302 - Temporary Redirect</H1>
<P>click <A HREF="$DESTINATION">here</A> if you are not redirected automatically.</P>
</BODY></HTML>
EOF
	;;
esac
