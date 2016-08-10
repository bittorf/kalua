#!/bin/sh

NETWORK="${1:-liszt28}"

log()
{
	logger -s -- "$0: host '$HOSTNAME': $1"
}

cat /var/www/scripts/map1.html

for FILE in /var/www/networks/$NETWORK/meshrdf/recent/????????????; do
	LATLON=
	. $FILE

	case "$LATLON" in
		''|'0,0'|','*)
			log "[ERROR] ignoring bogus values: '$LATLON'"
			continue
		;;
		'50.991342,11.332552'|'50.97389,11.31875')
#			log "[ERROR] ignoring default values: '$LATLON'"
			continue
		;;
		*)
#			echo "$LATLON | $HOSTNAME"
			LAT="$( echo "$LATLON" | cut -d',' -f1 )"
			LON="$( echo "$LATLON" | cut -d',' -f2 )"
#			log "[OK] using: $LAT / $LON"
		;;
	esac

	cat <<EOF 
    // LATLON='$LATLON'
    var iconFeature = new ol.Feature({
          geometry: new  
            ol.geom.Point(ol.proj.transform([$LON, $LAT] , 'EPSG:4326', 'EPSG:3857')),
        name: '$HOSTNAME',
        population: 4000,
        rainfall: 500
    });
    vectorSource.addFeature(iconFeature);

EOF

done

cat /var/www/scripts/map2.html
