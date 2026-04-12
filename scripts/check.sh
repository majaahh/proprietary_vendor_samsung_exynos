#!/bin/bash
# shellcheck disable=SC1090
#
# SPDX-FileCopyrightText: Majaahh
# SPDX-License-Identifier: Apache-2.0
#

# [
_PRINT_USAGE()
{
    echo "Usage: scripts/check <MODEL/CSC> [arguments]"
    echo "Arguments:"
    echo "-f,--force    Forces dirs overwrite"
    echo "--wifi-only   Marks device as WiFi only"
}

WRITE_BLOB_ENTRIES()
{
    local OUT="$1"
    local PREFIX="$2"
    local SUFFIX="$3"
    local WITH_SHA="$4"
    local SHA=""
    local PREFIX_BEFORE
    local PREFIX_AFTER
    shift 4

    if [[ "$PREFIX" == *:* ]]; then
        PREFIX_BEFORE="${PREFIX%%:*}"
        PREFIX_AFTER=":${PREFIX#*:}"
    else
        PREFIX_BEFORE="$PREFIX"
        PREFIX_AFTER=""
    fi

    for i in "$@"; do
        if [[ "$WITH_SHA" == true ]]; then
            SHA=":$(sha1sum "$(find "$FW_OUT_DIR" -type f -name "$i")" | awk '{print $1}')"
        fi

        echo "$PREFIX_BEFORE/${i}${PREFIX_AFTER}${SUFFIX}${SHA}" >> "$OUT"
    done
}

STRING="$1"
WIFI_ONLY=false
UPDATE=true
CURRENT=""
AP_TAR=""
BL_TAR=""
CSC_TAR=""
BOARD=""
ANDROID=""
BL_LOCK=false
OUT_FILES=()
PROPRIETARY_FILES_FILE=""
FILE_CONTEXT_FILE=""
FS_CONFIG_FILE=""
BRANCH=""
TAG=""
TEEGRIS_BLOBS=()
SKIP_DOWNLOAD=false
FORCE=false
SRC_DIR="$(pwd)"
OUT_DIR="$SRC_DIR/out"
# ]

if [[ -z "$STRING" ]]; then
    _PRINT_USAGE
    exit 1
fi

MODEL="$(cut -d "/" -f 1 -s <<< "$STRING")"
if [[ -z "$MODEL" ]]; then
    echo "No device model value found in \"$STRING\""
    _PRINT_USAGE
    exit 1
fi

CSC="$(cut -d "/" -f 2 -s <<< "$STRING")"
if [[ -z "$CSC" ]]; then
    echo "No CSC value found in \"$STRING\""
    _PRINT_USAGE
    exit 1
elif [[ "${#CSC}" != "3" ]]; then
    echo "CSC not valid in \"$STRING\": $CSC"
    exit 1
fi

LATEST_FW="$(samfwdl checkupdate "$MODEL" "$CSC" | awk -F/ '{print $1"/"$2"/"$3}')"
LATEST_SHORTVERSION="$(echo "$LATEST_FW" | cut -d'/' -f1)"
LATEST_CSCVERSION="$(echo "$LATEST_FW" | cut -d'/' -f2)"
TMP_DIR="$OUT_DIR/tmp-$LATEST_SHORTVERSION"
FW_DIR="$OUT_DIR/fw-$LATEST_SHORTVERSION"
FW_OUT_DIR="$OUT_DIR/fw_out-$LATEST_SHORTVERSION"
OMC="$(echo "$LATEST_FW" \
        | cut -d/ -f2 \
        | sed "s/^$(echo "$MODEL" | sed -E 's/^SM-//; s/-//g')//" \
        | cut -c1-3)"

shift
while [[ "$1" == "-"* ]]; do
    if [[ "$1" == "-f" ]] || [[ "$2" == "--force" ]]; then
        FORCE=true
    elif [[ "$1" == "--wifi-only" ]]; then
        WIFI_ONLY=true
    else
        echo "Unknown argument: $1"
        _PRINT_USAGE
        exit 1
    fi

    shift
done


if ! $FORCE && [[ -d "$FW_OUT_DIR" ]]; then
    echo "Firmware out dir exists, use -f to overwrite"
    exit 1
fi

mkdir -p "$FW_OUT_DIR" "$OUT_DIR" "$TMP_DIR"

if $WIFI_ONLY; then
    LATEST_FW="$(echo "$LATEST_FW" | awk -F/ '{print $1"/"$2"/"}')"
fi

if [[ -f "$SRC_DIR/current/${MODEL}_${CSC}_${OMC}" ]]; then
    CURRENT="$(cat "$SRC_DIR/current/${MODEL}_${CSC}_${OMC}")"
    if [[ "$LATEST_FW" == "$CURRENT" ]]; then
        UPDATE=false
    fi
fi

if [[ "$LATEST_FW" == "fe" ]] || \
        [[ "$LATEST_FW" == "S731BXXS6AZCH/S731BOXM6AZCH/S731BXXS6AZCH" ]] || \
        [[ "$LATEST_FW" == "S921BXXUDZZD5/S921BOXMDZZD5/S921BXXUDDZD5" ]] || \
        [[ "$LATEST_FW" == "S921NKSSECZCH/S921NOKRECZCH/S921NKSSECZCH" ]] || \
        [[ "$LATEST_FW" == "S926BXXUDZZD5/S926BOXMDZZD5/S926BXXUDDZD5" ]] || \
        [[ "$LATEST_FW" == "S926NKSSECZCH/S926NOKRECZCH/S926NKSSECZCH" ]]; then
    UPDATE=false
fi

if ! $UPDATE; then
    exit 0
fi

if [[ -d "$FW_DIR" ]]; then
    if [[ "$(find "$FW_DIR" -name "BL*")" ]] && \
        [[ "$(find "$FW_DIR" -name "AP*")" ]] && \
        [[ "$(find "$FW_DIR" -name "CP*")" ]] && \
        [[ "$(find "$FW_DIR" -name "CSC*")" ]] && \
        [[ "$(find "$FW_DIR" -name "HOME_CSC*")" ]]; then
        echo "Latest firmware is already extracted, skipping download."
        SKIP_DOWNLOAD=true
    fi
fi

if ! $SKIP_DOWNLOAD; then
    for i in {1..10}; do
        if [[ -d "$FW_DIR" ]]; then
            rm -rf "$FW_DIR"
        fi
        mkdir -p "$FW_DIR"

        samfwdl download "$MODEL" "$CSC" -o "$TMP_DIR" --decrypt || rm -rf "$FW_DIR"
        STATUS=$?

        if [[ $STATUS -eq 0 ]]; then
            break
        fi

        if [[ "$i" -eq 10 ]]; then
            exit 1
        fi

        sleep 5
    done

    unzip "$(find "$TMP_DIR" -name "*.zip" | tail -n 1)" -d "$FW_DIR" && rm -rf "$TMP_DIR" || exit 1
fi

AP_TAR="$(find "$FW_DIR" -name "AP*")"
BL_TAR="$(find "$FW_DIR" -name "BL*")"
CSC_TAR="$(find "$FW_DIR" -name "CSC*")"

if [[ ! -f "$FW_OUT_DIR/*.pit"  ]]; then
   echo "Extracting PIT"
   tar --wildcards --exclude="*/*" -C "$FW_OUT_DIR" -xf "$CSC_TAR" "*.pit" || exit 1 
fi

if [[ ! -f "$FW_OUT_DIR/${LATEST_SHORTVERSION}_patched_vbmeta.tar" ]]; then
    echo "Extracting vbmeta image"
    mkdir -p "$TMP_DIR"
    tar -C "$TMP_DIR" -xf "$AP_TAR" "vbmeta.img.lz4" || exit 1

    echo "Decompressing vbmeta image"
    lz4 -q -f -d "$TMP_DIR/vbmeta.img.lz4" "$TMP_DIR/vbmeta.img" && rm -f "$TMP_DIR/vbmeta.img.lz4" || exit 1

    echo "Patching vbmeta image"
    printf '\x03' | dd of="$TMP_DIR/vbmeta.img" bs=1 seek=123 count=1 conv=notrunc &> /dev/null || exit 1

    echo "Packing vbmeta image"
    ( cd "$TMP_DIR" && tar cf "$FW_OUT_DIR/${LATEST_SHORTVERSION}_patched_vbmeta.tar" "vbmeta.img" && rm -f "vbmeta.img" || exit 1 ) || exit 1
    rm -rf "$TMP_DIR" || exit 1
fi

if [[ ! -f "$FW_OUT_DIR/super.img" ]]; then
    echo "Extracting super image"
    mkdir -p "$TMP_DIR"
    tar -C "$TMP_DIR" -xf "$AP_TAR" "super.img.lz4" || exit 1

    echo "Decompressing super image"
    lz4 --rm -q -f -d "$TMP_DIR/super.img.lz4" "$TMP_DIR/super.img" || exit 1

    echo "Converting super to image"
    simg2img "$TMP_DIR/super.img" "$TMP_DIR/super_raw.img" && mv -f "$TMP_DIR/super_raw.img" "$FW_OUT_DIR/super.img" || exit 1
fi

for i in "product" "vendor"; do
    mkdir -p "$FW_OUT_DIR/$i" "$TMP_DIR/mount" || exit 1

    if ! "$SRC_DIR/tools/lpunpack" -p "$i" "$FW_OUT_DIR/super.img" "$TMP_DIR"; then
        "$SRC_DIR/tools/lpunpack" -p "${i}_a" "$FW_OUT_DIR/super.img" "$TMP_DIR" || exit 1
        mv "${i}_a" "$i" || exit 1
    fi

    sudo mount "$TMP_DIR/$i.img" "$TMP_DIR/mount" || exit 1
    sudo cp -a -T "$TMP_DIR/mount" "$FW_OUT_DIR/$i" || exit 1

    sudo chown -hR "$(whoami):$(whoami)" "$FW_OUT_DIR/$i" || exit 1
    sudo umount "$TMP_DIR/mount" && rm -rf "$TMP_DIR/mount" || exit 1

    if [[ "$i" == "product" ]]; then
        PROP="product/etc/build.prop"
    else
        PROP="$i/build.prop"
    fi

    cp -a "$FW_OUT_DIR/$PROP" "$FW_OUT_DIR/${LATEST_SHORTVERSION}_$i.prop"

    #echo "Compressing $i image"
    #( cd "$FW_OUT_DIR" && zip -r9 "$FW_OUT_DIR/${LATEST_SHORTVERSION}_$i.zip" "$TMP_DIR/$i.img" && rm -f "$TMP_DIR/$i.img" || exit 1 ) || exit 1

    #echo "Compressing extracted $i"
    #( cd "$FW_OUT_DIR" && zip -r9 "$FW_OUT_DIR/${LATEST_SHORTVERSION}_$i-extracted.zip" "$i" || exit 1 ) || exit 1

    #if [[ "$i" == "vendor" ]]; then
    #    echo "Compressing firmware and TEEgris firmware"
    #    ( cd "$FW_OUT_DIR/vendor" && zip -r9 "$FW_OUT_DIR/${LATEST_SHORTVERSION}_firmware_tee.zip" "firmware" "tee" || exit 1 ) || exit 1
    #fi

    while IFS= read -r i; do
        if [[ "$(stat -c%s "$i")" -ge "2147483647" ]]; then
            rm -f "$i"
        fi
    done < <(find "$FW_OUT_DIR" -maxdepth 1 -type f -name "${LATEST_SHORTVERSION}_$i-extracted*.zip")

    rm -rf "$TMP_DIR" || exit 1
done

BOARD="$(grep -r "ro.product.board" "$FW_OUT_DIR/vendor/build.prop" | cut -d'=' -f2)"

if [[ ! -f "$FW_OUT_DIR/${LATEST_SHORTVERSION}_kernel.tar" ]]; then
    FILES=("boot.img" "dtbo.img" "init_boot.img" "vendor_boot.img" "recovery.img")
    OUT_FILES=()

    for i in "${FILES[@]}"; do
        if tar xf "$BL_TAR" "$i.lz4" 2>/dev/null; then
            echo "Extracting $i"
            tar xf "$BL_TAR" "$TMP_DIR/$i.lz4" || exit 1
        fi
        if tar xf "$AP_TAR" "$i.lz4" 2>/dev/null; then
            echo "Extracting $i"
            tar xf "$AP_TAR" "$TMP_DIR/$i.lz4" || exit 1
        fi
        if [[ -f "$i.lz4" ]]; then
            echo "Decompressing $i"
            lz4 --rm -q -f -d "$TMP_DIR/$i.lz4" "$TMP_DIR/$i" || exit 1
            OUT_FILES+=("$i")
        fi
    done

    echo "Compressing kernel images"
    ( cd "$TMP_DIR" && tar cf "$FW_OUT_DIR/${LATEST_SHORTVERSION}_kernel.tar" "${OUT_FILES[@]}" && rm -f "${OUT_FILES[@]}" || exit 1 ) || exit 1
fi

echo "Checking bootloader lock status"
BL_LOCK=false

tar xf "$BL_TAR" "sboot.bin.lz4"
lz4 --rm -q -f -d "sboot.bin.lz4" "sboot.bin"

if strings "sboot.bin" | grep -q androidboot.other; then
    BL_LOCK=true
fi

PROPRIETARY_FILES_FILE="$SRC_DIR/proprietary-files/$MODEL/$LATEST_SHORTVERSION.txt"
FILE_CONTEXT_FILE="$SRC_DIR/file_context/$MODEL/$LATEST_SHORTVERSION.txt"
FS_CONFIG_FILE="$SRC_DIR/fs_config/$MODEL/$LATEST_SHORTVERSION.txt"

if [[ ! -d "$SRC_DIR/proprietary-files/$MODEL" ]]; then
    mkdir -p "$SRC_DIR/proprietary-files/$MODEL"
fi
if [[ ! -d "$SRC_DIR/file_context/$MODEL" ]]; then
    mkdir -p "$SRC_DIR/file_context/$MODEL"
fi
if [[ ! -d "$SRC_DIR/fs_config/$MODEL" ]]; then
    mkdir -p "$SRC_DIR/fs_config/$MODEL"
fi
if [[ -f "$SRC_DIR/configs/$BOARD.sh" ]]; then
    source "$SRC_DIR/configs/$BOARD.sh"
fi

echo "Generating basic proprietary-files list"
mapfile -t TEEGRIS_BLOBS < <(find "$FW_OUT_DIR/vendor/tee" -type f | sed -e "s|$FW_OUT_DIR/vendor/tee/||" -e "s|^\./||" | sort)

{
    echo "#"
    echo "# SPDX-FileCopyrightText: Majaahh"
    echo "# SPDX-License-Identifier: Apache-2.0"
    echo "#"
    echo ""
} > "$PROPRIETARY_FILES_FILE"

if [[ ${#AUDIO_BLOBS[@]} -gt 0 ]]; then
    echo "# Audio - Firmware" >> "$PROPRIETARY_FILES_FILE"
    WRITE_BLOB_ENTRIES "$PROPRIETARY_FILES_FILE" "vendor/firmware" "" "${AUDIO_BLOBS[@]}"
fi
if [[ ${#FIRMWARE_BLOBS[@]} -gt 0 ]]; then
    echo "# Firmware" >> "$PROPRIETARY_FILES_FILE"
    WRITE_BLOB_ENTRIES "$PROPRIETARY_FILES_FILE" "vendor/firmware" "" "${FIRMWARE_BLOBS[@]}"
fi

echo "Security - TEEgris - Firmware" >> "$PROPRIETARY_FILES_FILE"
for i in "${TEEGRIS_BLOBS[@]}"; do
    echo "vendor/tee/$i" >> "$PROPRIETARY_FILES_FILE"
done

{
    echo "" >> "$PROPRIETARY_FILES_FILE"
    echo "# Pinned" >> "$PROPRIETARY_FILES_FILE"
} >> "$PROPRIETARY_FILES_FILE"
if [[ ${#AUDIO_BLOBS[@]} -gt 0 ]]; then
    echo "# Audio - Firmware - from $MODEL - $LATEST_SHORTVERSION" >> "$PROPRIETARY_FILES_FILE"
    WRITE_BLOB_ENTRIES "$PROPRIETARY_FILES_FILE" "vendor/firmware" "" "${AUDIO_BLOBS[@]}" true
fi
if [[ ${#FIRMWARE_BLOBS[@]} -gt 0 ]]; then
    echo "# Firmware - from $MODEL - $LATEST_SHORTVERSION" >> "$PROPRIETARY_FILES_FILE"
    WRITE_BLOB_ENTRIES "$PROPRIETARY_FILES_FILE" "vendor/firmware" "" "${FIRMWARE_BLOBS[@]}" true
fi

echo "Security - TEEgris - Firmware - from $MODEL - $LATEST_SHORTVERSION" >> "$PROPRIETARY_FILES_FILE"
for i in "${TEEGRIS_BLOBS[@]}"; do
    echo "vendor/tee/$i:$(sha1sum "$FW_OUT_DIR/vendor/tee/$i" | awk '{print $1}')" >> "$PROPRIETARY_FILES_FILE"
done

{
    echo ""
    echo "# Pinned with path to model"
} >> "$PROPRIETARY_FILES_FILE"
if [[ ${#AUDIO_BLOBS[@]} -gt 0 ]]; then
    echo "# Audio - Firmware - from $MODEL - $LATEST_SHORTVERSION" >> "$PROPRIETARY_FILES_FILE"
    WRITE_BLOB_ENTRIES "$PROPRIETARY_FILES_FILE" "vendor/firmware/$MODEL" "" "${AUDIO_BLOBS[@]}" true
fi
if [[ ${#FIRMWARE_BLOBS[@]} -gt 0 ]]; then
    echo "# Firmware - from $MODEL - $LATEST_SHORTVERSION" >> "$PROPRIETARY_FILES_FILE"
    WRITE_BLOB_ENTRIES "$PROPRIETARY_FILES_FILE" "vendor/firmware/$MODEL" "" "${FIRMWARE_BLOBS[@]}" true
fi

echo "Security - TEEgris - Firmware - from $MODEL - $LATEST_SHORTVERSION" >> "$PROPRIETARY_FILES_FILE"
for i in "${TEEGRIS_BLOBS[@]}"; do
    echo "vendor/tee/$MODEL/$i:$(sha1sum "$FW_OUT_DIR/vendor/tee/$i" | awk '{print $1}')" >> "$PROPRIETARY_FILES_FILE"
done

{
    echo ""
    echo "# With path to model"
} >> "$PROPRIETARY_FILES_FILE"
if [[ ${#AUDIO_BLOBS[@]} -gt 0 ]]; then
    WRITE_BLOB_ENTRIES "$PROPRIETARY_FILES_FILE" "vendor/firmware:vendor/firmware/$MODEL" "${AUDIO_BLOBS[@]}"
fi
if [[ ${#FIRMWARE_BLOBS[@]} -gt 0 ]]; then
    WRITE_BLOB_ENTRIES "$PROPRIETARY_FILES_FILE" "vendor/firmware:vendor/firmware/$MODEL" "${FIRMWARE_BLOBS[@]}"
fi

echo "Security - TEEgris - Firmware - from $MODEL - $LATEST_SHORTVERSION" >> "$PROPRIETARY_FILES_FILE"
for i in "${TEEGRIS_BLOBS[@]}"; do
    echo "vendor/tee/$i:vendor/tee/$MODEL/$i" >> "$PROPRIETARY_FILES_FILE"
done

echo "Generating basic file_context-vendor"
{
    echo "#"
    echo "# SPDX-FileCopyrightText: Majaahh"
    echo "# SPDX-License-Identifier: Apache-2.0"
    echo "#"
    echo ""
    echo "/vendor/tee u:object_r:tee_file:s0"
} > "$FILE_CONTEXT_FILE"

for i in "${TEEGRIS_BLOBS[@]}"; do
    echo "/vendor/tee/$i u:object_r:tee_file:s0" >> "$FILE_CONTEXT_FILE"
done

{
    echo ""
    echo "# Path to model"
    echo "/vendor/tee_$MODEL u:object_r:tee_file:s0"
} >> "$FILE_CONTEXT_FILE"

for i in "${TEEGRIS_BLOBS[@]}"; do
    echo "/vendor/tee_$MODEL/$i u:object_r:tee_file:s0" >> "$FILE_CONTEXT_FILE"
done

echo "Generating basic fs_config-vendor"
{
    echo "#"
    echo "# SPDX-FileCopyrightText: Majaahh"
    echo "# SPDX-License-Identifier: Apache-2.0"
    echo "#"
    echo ""
    echo "vendor/tee 0 2000 755 capabilities=0x0"
} > "$FS_CONFIG_FILE"

for i in "${TEEGRIS_BLOBS[@]}"; do
    echo "vendor/tee/$i 0 0 644 capabilities=0x0" >> "$FILE_CONTEXT_FILE"
done

{
    echo ""
    echo "# Path to model"
    echo "vendor/tee_$MODEL 0 2000 755 capabilities=0x0"
} > "$FS_CONFIG_FILE"

for i in "${TEEGRIS_BLOBS[@]}"; do
    echo "vendor/tee_$MODEL/$i 0 0 644 capabilities=0x0" >> "$FILE_CONTEXT_FILE"
done

ANDROID="$(grep -r "ro.product.build.version.release" "$FW_OUT_DIR/product/etc/build.prop" | cut -d'=' -f2)"
{
    echo "Android Version: $ANDROID"
    # TODO
    if [[ ! "$MODEL" =~ SM-A576 ]]; then
        echo "Bootloader Lock: $BL_LOCK"
    fi
    echo "AP version: $LATEST_SHORTVERSION"
    echo "CSC version: $LATEST_CSCVERSION"
} > "$FW_OUT_DIR/versions.txt"

if [[ -n "$GITHUB_ACTIONS" ]]; then
    git config --local user.email "41898282+github-actions[bot]@users.noreply.github.com"
    git config --local user.name "github-actions[bot]"
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" == "HEAD" ]]; then
    echo "Detached HEAD; cannot determine current branch." >&2
    exit 1
fi

exit 0

git pull origin "$BRANCH" --ff-only
TAG="${LATEST_SHORTVERSION}_${CSC}_${OMC}"

if gh release view "$TAG" &>/dev/null; then
    gh release delete "$TAG" -y
fi
if git ls-remote --tags origin | grep -q "refs/tags/$TAG"; then
    git push origin --delete "$TAG"
fi
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    git tag -d "$TAG"
fi

echo "$LATEST_FW" > "$SRC_DIR/current/${MODEL}_${CSC}_${OMC}"
git add "$SRC_DIR/current/${MODEL}_${CSC}_${OMC}"
git add "$SRC_DIR/proprietary-files/$MODEL/$LATEST_SHORTVERSION.txt"
git add "$SRC_DIR/file_context/$MODEL/$LATEST_SHORTVERSION.txt"
git add "$SRC_DIR/fs_config/$MODEL/$LATEST_SHORTVERSION.txt"

if [[ "$(whoami)" == "Maja" ]]; then
    COMMAND="git commit -s -S -m"
else
    COMMAND="git commit -m"
fi
$COMMAND "samsung: ${MODEL}: ${LATEST_SHORTVERSION}"

git tag "$TAG"

if ! git push origin "$BRANCH" "$TAG"; then
    git pull origin "$BRANCH" --ff-only
    git push origin "$BRANCH" "$TAG"
fi
