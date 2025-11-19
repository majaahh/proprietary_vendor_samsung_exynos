tar xvf ${AP_TAR} super.img.lz4
lz4 -d super.img.lz4 super.img
rm -f super.img.lz4
simg2img super.img super_raw.img
rm -f super.img
mv -f super_raw.img super.img

for i in "product" "vendor"; do
    mkdir -p ${i} ${i}_mount

    ./tools/lpunpack -p ${i} super.img . || true
    [[ ! -f "${i}.img" ]] && ./tools/lpunpack super.img
    [[ -f "${i}_a.img" ]] && mv -f "${i}_a.img" "${i}.img"

    sudo mount ${i}.img ${i}_mount

    (
    cd "${i}_mount"

    TMPFILE=$(mktemp)

    sudo find -xdev -print0 > "$TMPFILE"

    sudo awk -v RS='\0' '/\/$/ {print}' "$TMPFILE" \
        | while IFS= read -r dir; do
            sudo mkdir -pv "../${i}/${dir}"
        done

    sudo rsync -aHAXv --progress --from0 --files-from="$TMPFILE" . "../${i}/"

    rm -f "$TMPFILE"
    )

    # https://github.com/salvogiangri/UN1CA/blob/fifteen/scripts/extract_fw.sh#L135-L136
    sudo chown -hR "$(whoami):$(whoami)" ${i}
    sudo umount ${i}_mount
    rm -rf ${i}_mount

    zip -r9 ${LATEST_SHORTVERSION}_${i}.zip ${i}.img
    zip -r9 ${LATEST_SHORTVERSION}_${i}-extracted.zip ${i}

    rm -f odm*.img product*.img vendor*img vendor_dlkm*.img system*.img || true
done

BOARD="$(grep -r "ro.product.board" vendor/build.prop | cut -d'=' -f2)"
echo "board=$BOARD" >> "$GITHUB_ENV"
