# shellcheck disable=SC2034 shell=bash
#
# SPDX-FileCopyrightText: Majaahh
# SPDX-License-Identifier: Apache-2.0
#

AUDIO_BLOBS=( "APDV_AUDIO_SLSI.bin" "AP_AUDIO_SLSI.bin" "calliope_sram.bin" "vts.bin" )
FIRMWARE_BLOBS=( "NPU.bin" "mfc_fw.bin" "os.checked.bin" )

# Exceptions
if [[ "$MODEL" == "SC-53C" ]]; then
    FIRMWARE_BLOBS+=( "nfc/libsn100u_fw.so" )
fi

echo "346B" | grep -q "$MODEL" && AUDIO_BLOBS=( "calliope_sram.bin" "vts.bin" )
