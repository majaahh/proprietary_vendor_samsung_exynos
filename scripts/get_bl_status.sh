# TODO
if [[ "$MODEL" =~ "SM-A576" ]]; then
    exit 0
fi

BL_LOCK="False"

tar xf "$BL_TAR" "sboot.bin.lz4"
lz4 --rm -q -f -d "sboot.bin.lz4" "sboot.bin"

strings "sboot.bin" | grep -q androidboot.other && BL_LOCK="True"

echo "bl_lock=$BL_LOCK" >> "$GITHUB_ENV"
