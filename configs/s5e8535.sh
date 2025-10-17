# Main
AUDIO_BLOBS=( "calliope_sram.bin" )
FIRMWARE_BLOBS=( "mfc_fw.bin" "os.checked.bin" "pablo_icpufw.bin" )

# Exceptions
echo "A146" | grep -q ${MODEL} && \
    FIRMWARE_BLOBS+=( "setfile_3l6.bin" "setfile_gc02m1.bin" "setfile_gc02m2.bin" "setfile_hi1336.bin" "setfile_jn1.bin" "setfile_sc201.bin" "setfile_sc201_macro.bin" )
