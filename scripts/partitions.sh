tar xf "$AP_TAR" "super.img.lz4"
lz4 --rm -q -f -d "super.img.lz4" "super.img"
simg2img "super.img" "super_raw.img" && mv -f "super_raw.img" "super.img"

for i in "product" "vendor"; do
    mkdir -p "$i" "$i-tmp"

    ./tools/lpunpack -p "$i" "super.img" "." || true
    [[ ! -f "$i.img" ]] && ./tools/lpunpack "super.img"
    [[ -f "${i}_a.img" ]] && mv -f "${i}_a.img" "$i.img"

    sudo mount "$i.img" "$i-tmp"

    (
    cd "$i-tmp" || exit 1

    sudo find -xdev -type d -print0 | while IFS= read -r -d '' d; do
        sudo mkdir -p "../$i/${d#"$SRC"/}"
    done

    sudo find -xdev -type f -print0 | sudo rsync -aHAX --no-inc-recursive --from0 --files-from=- "." "../$i/"
    ) || exit 1

    # https://github.com/salvogiangri/UN1CA/blob/fifteen/scripts/extract_fw.sh#L135-L136
    sudo chown -hR "$(whoami):$(whoami)" "$i"
    sudo umount "$i-tmp"
    rm -rf "$i-tmp"

    if [[ "$MODEL" != "S94"* ]]; then
        zip -r9 "${LATEST_SHORTVERSION}_$i.zip" "$i.img"
        zip -r9 "${LATEST_SHORTVERSION}_$i-extracted.zip" "$i"
    fi

    rm -f "*.img"
done

echo "board=$(grep -r "ro.product.board" "vendor/build.prop" | cut -d'=' -f2)" >> "$GITHUB_ENV"
