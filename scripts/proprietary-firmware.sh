mkdir bl
cd bl
tar xvf ../${BL_TAR}
tar xvf ../${CP_TAR}
lz4 -d -m *.lz4
rm -rf *.lz4
for i in *; do
    mv $i ${i}_${MODEL}
done

BL_LOCK="False"
strings "sboot.bin_${MODEL}" | grep -q androidboot.other && BL_LOCK="True"
echo "bl_lock=$BL_LOCK" >> "$GITHUB_ENV"

rm -f "vbmeta.img"*

[[ ! -d "../proprietary-firmware/$BOARD" ]] && mkdir -p "../proprietary-firmware/$BOARD"
propfile="../proprietary-firmware/$BOARD/firmware.${MODEL}_${CSC}_${OMC}"

{
    echo "# Firmware for model ${MODEL} - from Samsung package version ${LATEST_SHORTVERSION}"
    sha1sum * | awk '{print $2 "|" $1}'
    echo ""
} > "$propfile"

echo "${LATEST_SHORTVERSION}" >> "version_${MODEL}"
{
    echo "# Files containing Samsung package version for supported models"
    sha1sum "version_${MODEL}" | awk '{print $2 "|" $1}'
} >> "$propfile"

zip -r0 --store "../${LATEST_SHORTVERSION}_BL_CP-los.zip" .
