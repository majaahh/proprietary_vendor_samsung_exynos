set -e

# Get OMC
PREFIX=$(echo "$MODEL" | sed 's/^SM-//; s/-//g')

OMC="$(
curl -s --retry 3 -m 3 https://fota-cloud-dn.ospserver.net/firmware/$CSC/$MODEL/version.xml \
| grep -oP '<latest[^>]*>\K[^<]+' \
| cut -d/ -f2 \
| sed "s/^$PREFIX//" \
| cut -c1-3
)"

UPDATE=0
LATEST_FW=$(curl --fail --retry 100 --retry-delay 5 http://fota-cloud-dn.ospserver.net/firmware/${CSC}/${MODEL}/version.xml \
  | grep latest | sed 's/^[^>]*>//' | sed 's/<.*//')
LS=$(echo $LATEST_FW | cut -d'/' -f1)
LC=$(echo $LATEST_FW | cut -d'/' -f2)
[[ -z "current/current.${MODEL}_${CSC}_${OMC}" ]] && UPDATE=1
[[ "$UPDATE" != "true" ]] && CURRENT=$(cat current/current.${MODEL}_${CSC}_${OMC}) || UPDATE=1
[[ $LATEST_FW != $CURRENT ]] && UPDATE=1

echo "latest_version=$LATEST_FW" >> $GITHUB_ENV
echo "latest_shortversion=$LS" >> $GITHUB_ENV
echo "latest_cscversion=$LC" >> $GITHUB_ENV
echo "update=$UPDATE" >> $GITHUB_ENV
echo "omc=$OMC" >> $GITHUB_ENV
