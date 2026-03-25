BL_LOCK="False"

# TODO
# Workaround for A57
if [[ "$MODEL" == "A576"* ]]; then
    tar xf "$AP_TAR" "vendor_boot.img.lz4"
    lz4 --rm -q -f -d "vendor_boot.img.lz4" "vendor_boot.img"

    strings "vendor_boot.img" | grep -q androidboot.other && BL_LOCK="True"
else
    tar xf "$BL_TAR" "sboot.bin.lz4"
    lz4 --rm -q -f -d "sboot.bin.lz4" "sboot.bin"

    strings "sboot.bin" | grep -q androidboot.other && BL_LOCK="True"
fi

echo "bl_lock=$BL_LOCK" >> "$GITHUB_ENV"
