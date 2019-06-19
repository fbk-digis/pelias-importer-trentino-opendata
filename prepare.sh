#!/bin/bash
#
TMP="./tmp/"
TMPDB="${TMP}db.sqlite"
DATA="./data/openaddresses/"
DATA2="./data/polylines/"

CSV_CIV="${TMP}trento_civici.csv"
CSV_STRADE="${TMP}trento_strade.csv"
CSV_NOMI="${TMP}trento_strade_nomi.csv"
CSV_CIV2="${TMP}rovereto_civici.csv"
CSV_STRADE2="${TMP}rovereto_strade.csv"

rm -f $TMPDB "${DATA}.*" "${DATA2}.*"

#TRENTO CIVICI
rm -f $CSV_CIV
ogr2ogr -f "CSV" -lco GEOMETRY=AS_XY -s_srs EPSG:3044 -t_srs EPSG:4326 $CSV_CIV "${TMP}TRENTO_CIVICI_SHP/civici_web.shp"
##contains columns X,Y as lon,lat
mv $CSV_CIV "$CSV_CIV.tmp"
csvformat -U 1 "$CSV_CIV.tmp" > $CSV_CIV
rm -fr "$CSV_CIV.tmp"

#TRENTO STRADE GEOMETRIE
rm -f $CSV_STRADE
ogr2ogr -f "CSV" -lco GEOMETRY=AS_WKT -s_srs EPSG:3044 -t_srs EPSG:4326 $CSV_STRADE "${TMP}TRENTO_STRADE_SHP/grafo_web.shp"
##contains column "WKT" as a WKT LineString
#quoteall
mv $CSV_STRADE "$CSV_STRADE.tmp"
csvformat -U 1 "$CSV_STRADE.tmp" > $CSV_STRADE
rm -fr "$CSV_STRADE.tmp"

#ROVERETO CIVICI
rm -f $CSV_CIV2
ogr2ogr -f "CSV" -lco GEOMETRY=AS_WKT -s_srs EPSG:3044 -t_srs EPSG:4326 $CSV_CIV2 "${TMP}ROVERETO_CIVICI_SHP/Civici.shp"
##contains column "WKT" as a WKT MultiPoint
mv $CSV_CIV2 "$CSV_CIV2.tmp"
csvformat -U 1 "$CSV_CIV2.tmp" > "$CSV_CIV2.tmp2"
#calculate centroid for multipoint
node csvWkt2Centroid.js "$CSV_CIV2.tmp2" > "$CSV_CIV2.centroid.tmp2"
csvformat -U 1 "$CSV_CIV2.centroid.tmp2" > $CSV_CIV2
rm -fr "$CSV_CIV2.tmp" "$CSV_CIV2.tmp2" "$CSV_CIV2.centroid.tmp2"

#ROVERETO STRADE GEOMETRIE
rm -f $CSV_STRADE2
ogr2ogr -f "CSV" -lco GEOMETRY=AS_WKT -s_srs EPSG:3044 -t_srs EPSG:4326 $CSV_STRADE2 "${TMP}ROVERETO_STRADE_SHP/Strade.shp"
##contains column "WKT" as a WKT Polygon
mv $CSV_STRADE2 "$CSV_STRADE2.tmp"
csvformat -U 1 "$CSV_STRADE2.tmp" > $CSV_STRADE2
rm -fr "$CSV_STRADE2.tmp"
#TODO csvWkt2LatLon.js


#trento strade nomi
echo "convert to utf8..."
mv $CSV_NOMI "${TMP}TRENTO_STRADE_NOMI.win.csv"
iconv -f WINDOWS-1252 -t UTF-8//TRANSLIT "${TMP}TRENTO_STRADE_NOMI.win.csv" -o "${TMP}TRENTO_STRADE_NOMI.utf.csv"
#quoteall, tab delimited char
csvformat --tabs -U 1 "${TMP}TRENTO_STRADE_NOMI.utf.csv" > $CSV_NOMI
rm -f "${TMP}TRENTO_STRADE_NOMI.win.csv" "${TMP}TRENTO_STRADE_NOMI.utf.csv"

#import geometries
#spatialite_tool -i -shp $INSHP -d $TMPDB -c UTF-8 -t shp -s 4326 -g geom

echo -e ".mode csv\n.separator ,\n.import ${CSV_CIV} trento_civici" | sqlite3 $TMPDB
echo -e ".mode csv\n.separator ,\n.import ${CSV_STRADE} trento_strade" | sqlite3 $TMPDB
echo -e ".mode csv\n.separator ,\n.import ${CSV_CIV2} rovereto_civici" | sqlite3 $TMPDB
echo -e ".mode csv\n.separator ,\n.import ${CSV_STRADE2} rovereto_strade" | sqlite3 $TMPDB
echo -e ".mode csv\n.separator ,\n.import ${CSV_NOMI} trento_strade_nomi" | sqlite3 $TMPDB
rm -f $CSV_CIV $CSV_CIV2 $CSV_STRADE $CSV_STRADE2 $CSV_NOMI

SQL1="SELECT CAST(Y AS real) AS lat, CAST(X AS real) AS lon, civico_alf AS number, cap AS zipcode, Appellativo||' '||Prenome||' '||Denominazione AS street FROM trento_civici,trento_strade_nomi WHERE trento_civici.strada = trento_strade_nomi.'Codice via';"
echo -e ".header on\n.mode csv\n${SQL1}" | spatialite $TMPDB > $CSV_CIV
csvformat -U 1 $CSV_CIV > "${DATA}trento_civici.csv"
rm -f $CSV_CIV

SQL2="SELECT WKT, Appellativo||' '||Prenome||' '||Denominazione AS street FROM trento_strade,trento_strade_nomi WHERE trento_strade.codice = trento_strade_nomi.'Codice via';"
echo -e ".header on\n.mode csv\n${SQL2}" | spatialite $TMPDB > $CSV_STRADE
CSV_POLY="${TMP}trento_strade_polyline.csv"
csvformat -U 1 $CSV_STRADE > $CSV_POLY
node csv2polyline.js $CSV_POLY > "${DATA2}trento_strade_polyline.0sv"
#rm -f $CSV_POLY

SQL3="SELECT CAST(LAT AS real) AS lat, CAST(LON AS real) AS lon, NUMERO_CIV AS number, DUG_ISTAT||' '||TOPONIMO_I AS street FROM rovereto_civici,rovereto_strade WHERE rovereto_civici.CODICE_VIA = rovereto_strade.Cod_strada;"
echo -e ".header on\n.mode csv\n${SQL3}" | spatialite $TMPDB > $CSV_CIV2
csvformat -U 1 $CSV_CIV2 > "${DATA}rovereto_civici.csv"
rm -f $CSV_CIV2



#spatialite_tool -e -d $1 -t shape -g geom -k -type LINESTRING
#TODO import nomi giusti da csv spatialite_tool -i -shp $1 -d $1.sqlite -t shape -s 4326 -g geom -c UTF-8
#generate pelias polyline
#JOIN civici nomi
#csvjoin -c "strada,Codice_via" trento_civici.csv trento_strade.csv > join.csv
#csvcut -c "X,Y,civico_alf,cap,Appellativo,Prenome,Denominazione" join.csv > cut.csv
#rename columns in pelias openaddresses format
#non serve cat cut.csv | csvsql --query "SELECT X AS lon, Y AS lat, civico_alf AS number, cap AS zipcode, Appellativo||' '||Prenome||' '||Denominazione AS street FROM stdin" > out.csv
