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
    cd ${i}_mount
    sudo find -xdev -type d -print0 | while IFS= read -r -d '' dir; do
        sudo mkdir -p "../${i}/${dir#$SRC/}"
    done
    sudo find -xdev -type f -print0 | sudo rsync -aHAX --no-inc-recursive --from0 --files-from=- . ../${i}/
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
