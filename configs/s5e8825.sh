# shellcheck disable=SC2034 shell=bash
#
# SPDX-FileCopyrightText: Majaahh
# SPDX-License-Identifier: Apache-2.0
#

AUDIO_BLOBS=( "APDV_AUDIO_SLSI.bin" "AP_AUDIO_SLSI.bin" "calliope_sram.bin" "vts.bin" )
FIRMWARE_BLOBS=( "NPU.bin" "mfc_fw.bin" "os.checked.bin" )

# Exceptions
if [[ "$MODEL" == *"346B"* ]]; then
    AUDIO_BLOBS=( "calliope_sram.bin" "vts.bin" )
fi
