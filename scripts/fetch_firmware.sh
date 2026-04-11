LATEST_FW="$(samfwdl checkupdate "$MODEL" "$CSC" | awk -F/ '{print $1"/"$2"/"$3}')"
UPDATE=0
LS=$(echo "$LATEST_FW" | cut -d'/' -f1)
LC=$(echo "$LATEST_FW" | cut -d'/' -f2)
CURRENT=""
OMC="$(echo "$LATEST_FW" \
    | cut -d/ -f2 \
    | sed "s/^$(echo "$MODEL" | sed -E 's/^SM-//; s/-//g')//" \
    | cut -c1-3)"

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

if [[ "$LATEST_FW" == "F766BXXU9ZZD3/F766BOXM9ZZD3/F766BXXU9BZD1" ]] || \
    [[ "$LATEST_FW" == "F766U1UES8AZB6/F766U1OYM8AZB6/F766U1UES8AZB6" ]] || \
    [[ "$LATEST_FW" == "S731BXXS6AZCH/S731BOXM6AZCH/S731BXXS6AZCH" ]] || \
    [[ "$LATEST_FW" == "S921BXXUDZZD5/S921BOXMDZZD5/S921BXXUDDZD5" ]] || \
    [[ "$LATEST_FW" == "S921NKSSECZCH/S921NOKRECZCH/S921NKSSECZCH" ]] || \
    [[ "$LATEST_FW" == "S926BXXUDZZD5/S926BOXMDZZD5/S926BXXUDDZD5" ]] || \
    [[ "$LATEST_FW" == "S926NKSSECZCH/S926NOKRECZCH/S926NKSSECZCH" ]]; then
    UPDATE=0
fi

{
    echo "latest_version=$LATEST_FW"
    echo "latest_shortversion=$LS"
    echo "latest_cscversion=$LC"
    echo "update=$UPDATE"
    echo "omc=$OMC"
} >> "$GITHUB_ENV"
