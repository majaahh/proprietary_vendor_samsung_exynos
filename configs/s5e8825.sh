# Main
AUDIO_BLOBS=( "APDV_AUDIO_SLSI.bin" "AP_AUDIO_SLSI.bin" "calliope_sram.bin" "vts.bin" )
FIRMWARE_BLOBS=( "NPU.bin" "mfc_fw.bin" "os.checked.bin" )

# Exceptions
echo "SC-53C" | grep -q ${MODEL} && FIRMWARE_BLOBS+=( "nfc/libsn100u_fw.so" )
echo "346B" | grep -q ${MODEL} && AUDIO_BLOBS=( "calliope_sram.bin" "vts.bin" )
