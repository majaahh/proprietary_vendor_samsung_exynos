tar xvf "$AP_TAR" "vbmeta.img.lz4"

lz4 -q -f -d "vbmeta.img.lz4" "vbmeta.img" && rm -f "vbmeta.img.lz4"

# TODO
# shellcheck disable=SC2059
printf "$(printf '\\x%02X' 3)" | dd of="vbmeta.img" bs=1 seek=123 count=1 conv=notrunc &> /dev/null

tar cvf "${LATEST_SHORTVERSION}_patched_vbmeta.tar" "vbmeta.img" && rm -f vbmeta.img
