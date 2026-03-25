FILES=("boot.img" "dtbo.img" "init_boot.img" "vendor_boot.img" "recovery.img")
OUT_FILES=()

for i in "${FILES[@]}"; do
    if tar xf "$BL_TAR" "$i.lz4" 2>/dev/null; then
        tar xf "$BL_TAR" "$i.lz4" || exit 1
    fi

    if tar xf "$AP_TAR" "$i.lz4" 2>/dev/null; then
        tar xf "$AP_TAR" "$i.lz4" || exit 1
    fi

    if [[ -f "$i.lz4" ]]; then
        lz4 --rm -q -f -d "$i.lz4" "$i" || exit 1
        OUT_FILES+=("$i")
    fi
done

tar cf "${LATEST_SHORTVERSION}_kernel.tar" "${OUT_FILES[@]}"
