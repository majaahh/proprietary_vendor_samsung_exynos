print_entry_fs() {
    local path="$1"
    local gid="$2"
    local mode="$3"
    echo "$path 0 $gid $mode capabilities=0x0"
}

generate_entries() {
    local base="$1"
    local gid_dir="2000"
    local gid_file="0"
    print_entry_fs "$base" "$gid_dir" "755"
    find "$base" -printf '%P\n' | sort | while read -r relpath; do
        [ -z "$relpath" ] && continue
        fullpath="$base/$relpath"
        outpath="${fullpath#./}"
        if [ -d "$fullpath" ]; then
            print_entry_fs "$outpath" "$gid_dir" "755"
        elif [ -f "$fullpath" ]; then
            print_entry_fs "$outpath" "$gid_file" "644"
        fi
    done
}

BLOBS=( "calliope_sram.bin" "mfc_fw.bin" "NPU.bin" "os.checked.bin" "vts.bin" )
! sudo grep -q "m34" "vendor/mount/build.prop" && BLOBS+=("AP_AUDIO_SLSI.bin" "APDV_AUDIO_SLSI.bin")
[[ ! -d "fs_config/$BOARD" ]] && mkdir -p "fs_config/$BOARD"

generate_entries "vendor/tee" > "fs_config/$BOARD/fs.${MODEL}_${CSC}_${OMC}"

mkdir -p vendor/tee/${MODEL}
cp -rfa vendor/tee_old/* vendor/tee/${MODEL}

{
    echo ""
    echo "# Custom Path"
    echo "vendor/firmware/${MODEL} 0 0 644 capabilities=0x0"
    generate_entries "vendor/tee/${MODEL}"
} >> "fs_config/$BOARD/fs.${MODEL}_${CSC}_${OMC}"

rm -rf vendor/tee_old
