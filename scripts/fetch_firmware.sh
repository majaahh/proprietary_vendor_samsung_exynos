LATEST_FW="$(./tools/samloader -m "$MODEL" -r "$CSC" check | awk -F/ '{print $1"/"$2"/"$3}')"
UPDATE=0
LS=$(echo "$LATEST_FW" | cut -d'/' -f1)
LC=$(echo "$LATEST_FW" | cut -d'/' -f2)
CURRENT=""
OMC="$(echo "$LATEST_FW" \
| cut -d/ -f2 \
| sed "s/^$(echo "$MODEL" | sed -E 's/^SM-//; s/-//g')//" \
| cut -c1-3
)"

if [[ "$IS_WIFI" == true ]]; then
    LATEST_FW="$(echo "$LATEST_FW" | awk -F/ '{print $1"/"$2"/"}')"
fi

if [[ -f "current/current.${MODEL}_${CSC}_${OMC}" ]]; then
    CURRENT=$(cat "current/current.${MODEL}_${CSC}_${OMC}")
else
    UPDATE=1
fi

if [[ -n "$CURRENT" ]]; then
    if [[ "$LATEST_FW" != "$CURRENT" ]]; then
        UPDATE=1
    fi
fi

{
    echo "latest_version=$LATEST_FW"
    echo "latest_shortversion=$LS"
    echo "latest_cscversion=$LC"
    echo "update=$UPDATE"
    echo "omc=$OMC"
} >> "$GITHUB_ENV"
