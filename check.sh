#!/bin/bash
# shellcheck disable=SC1090,SC2115,SC2317
#
# SPDX-FileCopyrightText: Majaahh
# SPDX-License-Identifier: Apache-2.0
#

# [
_PRINT_USAGE()
{
    echo "Usage: scripts/check <MODEL/CSC> [arguments]"
    echo "Arguments:"
    echo "--check-only    Checks if current contains latest/forced firmwares only"
    echo "-f,--force      Forces dirs overwrite"
    echo "--wifi-only     Marks device as WiFi only"
    echo "-u,--upload     Commits and uploads to GitHub"
    echo "-f,--firmware   Forces specific firmware"
}

WRITE_BLOB_ENTRIES()
{
    local OUT="$1"
    local PREFIX="$2"
    local WITH_SHA="$3"
    shift 3

    local SRC_PREFIX DST_PREFIX
    local SHA

    if [[ "$PREFIX" == *:* ]]; then
        SRC_PREFIX="${PREFIX%%:*}"
        DST_PREFIX="${PREFIX#*:}"
    else
        SRC_PREFIX="vendor/firmware"
        DST_PREFIX="$PREFIX"
    fi

    for i in "$@"; do
        local SRC_PATH="${SRC_PREFIX}/${i}"
        local DST_PATH="${DST_PREFIX}/${i}"

        if [[ "$WITH_SHA" == "true" ]]; then
            if [[ -f "$FW_OUT_DIR/$SRC_PATH" ]]; then
                SHA="|$(sha1sum "$FW_OUT_DIR/$SRC_PATH" | awk '{print $1}')"
            else
                SHA=""
            fi
        else
            SHA=""
        fi

        if [[ "$PREFIX" == *:* ]]; then
            echo "${SRC_PATH}:${DST_PATH}${SHA}" >> "$OUT"
        else
            echo "${DST_PATH}${SHA}" >> "$OUT"
        fi
    done
}

APPEND_CURRENT_FIRMWARE()
{
    local CURRENT_FILE="$1"
    local ENTRY="$2"
    local TMP

    mkdir -p "$(dirname "$CURRENT_FILE")"

    if [[ -f "$CURRENT_FILE" ]]; then
        TMP="$(mktemp)"
        {
            printf '%s\n' "$ENTRY"
            cat "$CURRENT_FILE"
        } | awk -F/ '
        {
            fw = $NF

            code = substr(fw, length(fw)-4)

            os    = substr(code,1,1)
            year  = substr(code,2,1)
            month = substr(code,3,1)
            incr  = substr(code,4)

            printf "%s %s %s %s | %s\n", os, year, month, incr, $0
        }' \
        | sort -r \
        | cut -d'|' -f2- \
        | sed 's/^ //' \
        | uniq > "$TMP"

        mv "$TMP" "$CURRENT_FILE"
    else
        printf '%s\n' "$ENTRY" > "$CURRENT_FILE"
    fi
}

UPLOAD_RELEASE_ASSET()
{
    local DIR="$1"
    local NAME
    NAME="$(basename "$DIR")"

    if grep -Fxq "$NAME" <<< "$EXISTING_RELEASE_ASSETS"; then
        return 0
    fi

    gh release upload "$TAG" "$DIR" --repo "$REPO" || exit 1
}

STRING="$1"
UPDATE=true
AP_TAR=""
BL_TAR=""
CSC_TAR=""
BOARD=""
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
UPLOAD=false
FIRMWARE=""
LATEST_FW=""
CHECK_ONLY=false
SRC_DIR="$(pwd)"
OUT_DIR="$SRC_DIR/out"
# ]

if [[ -z "$STRING" ]]; then
    _PRINT_USAGE
    exit 1
fi

# https://github.com/salvogiangri/UN1CA/blob/3.0.0/scripts/utils/firmware_utils.sh#L136-L149
MODEL="$(cut -d "/" -f 1 -s <<< "$STRING")"
if [[ -z "$MODEL" ]]; then
    _PRINT_USAGE
    exit 1
fi

CSC="$(cut -d "/" -f 2 -s <<< "$STRING")"
if [[ -z "$CSC" ]]; then
    _PRINT_USAGE
    exit 1
elif [[ "${#CSC}" != "3" ]]; then
    exit 1
fi

LATEST_FW="$(samfwdl checkupdate "$MODEL" "$CSC")"

shift
while [[ "$1" == "-"* ]]; do
    if [[ "$1" == "--check-only" ]]; then
        CHECK_ONLY=true
    elif [[ "$1" == "-f" ]] || [[ "$2" == "--force" ]]; then
        FORCE=true
    elif [[ "$1" == "--firmware" ]]; then
        if [[ -z "$2" ]]; then
            echo "Missing argument for $1"
            exit 1
        fi
        FIRMWARE="$2"
        shift
    elif [[ "$1" == "-u" ]] || [[ "$1" == "--upload" ]]; then
        UPLOAD=true
    else
        echo "Unknown argument: $1"
        _PRINT_USAGE
        exit 1
    fi

    shift
done

if [[ -z "$FIRMWARE" ]]; then
    FIRMWARE="$LATEST_FW"
fi

LATEST_SHORTVERSION="$(echo "$FIRMWARE" | cut -d'/' -f1)"
LATEST_CSCVERSION="$(echo "$FIRMWARE" | cut -d'/' -f2)"
TMP_DIR="$OUT_DIR/tmp-$LATEST_SHORTVERSION"
FW_DIR="$OUT_DIR/fw-$LATEST_SHORTVERSION"
FW_OUT_DIR="$OUT_DIR/fw_out-$LATEST_SHORTVERSION"
OMC="$(echo "$FIRMWARE" \
        | cut -d/ -f2 \
        | sed "s/^$(echo "$MODEL" | sed -E 's/^SM-//; s/-//g')//" \
        | cut -c1-3)"

if ! $FORCE && [[ -d "$FW_OUT_DIR" ]]; then
    echo "Firmware out dir exists, use -f to overwrite"
    exit 1
fi

if [[ -f "$SRC_DIR/current/${MODEL}_${CSC}_${OMC}" ]]; then
    if grep -Fxq "$FIRMWARE" "$SRC_DIR/current/${MODEL}_${CSC}_${OMC}"; then
        UPDATE=false
    fi
fi

if $CHECK_ONLY || ! $UPDATE; then
    if [[ -n "$GITHUB_ACTIONS" ]] && $UPDATE; then
        echo "update=1" >> "$GITHUB_ENV"
    fi
    exit 0
fi

if [[ -d "$FW_DIR" ]]; then
    if [[ "$(find "$FW_DIR" -name "BL*")" ]] && \
        [[ "$(find "$FW_DIR" -name "AP*")" ]] && \
        [[ "$(find "$FW_DIR" -name "CSC*")" ]] && \
        [[ "$(find "$FW_DIR" -name "HOME_CSC*")" ]]; then
        echo "Latest firmware is already extracted, skipping download."
        SKIP_DOWNLOAD=true
    fi
fi

if ! $SKIP_DOWNLOAD; then
    for i in {1..10}; do
        if [[ -d "$FW_DIR" ]]; then
            rm -rf "$TMP_DIR"
        fi
        mkdir -p "$TMP_DIR"

        samfwdl download "$MODEL" "$CSC" --force-firmware --firmware "$FIRMWARE" -o "$TMP_DIR" --decrypt || {
            rm -rf "$TMP_DIR"
            exit 1
        }
        STATUS=$?

        if [[ $STATUS == 0 ]]; then
            break
        fi

        if [[ "$i" == 10 ]]; then
            exit 1
        fi

        sleep 5
    done
fi

if [[ -d "$TMP_DIR" ]]; then
    if [[ "$(find "$TMP_DIR" -name "*.zip" | tail -n 1)" ]]; then
        if [[ -d "$FW_DIR" ]]; then
            rm -rf "$FW_DIR"
        fi
        mkdir -p "$FW_DIR"
        unzip "$(find "$TMP_DIR" -name "*.zip" | tail -n 1)" -d "$FW_DIR" && rm -rf "$TMP_DIR" || exit 1
fi
fi

AP_TAR="$(find "$FW_DIR" -name "AP*")"
BL_TAR="$(find "$FW_DIR" -name "BL*")"
CSC_TAR="$(find "$FW_DIR" -name "CSC*")"

if [[ ! -d "$FW_OUT_DIR" ]]; then
    mkdir -p "$FW_OUT_DIR"
fi

if [[ ! "$(find "$FW_OUT_DIR" -maxdepth 1 -type f -name "*.pit")"  ]]; then
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
    ( cd "$TMP_DIR" && tar -cf "$FW_OUT_DIR/${LATEST_SHORTVERSION}_patched_vbmeta.tar" "vbmeta.img" && rm -f "vbmeta.img" || exit 1 ) || exit 1
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
    if [[ -d "$FW_OUT_DIR/$i" ]]; then
        continue
    fi

    if [[ -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR" || exit 1
    fi
    mkdir -p "$TMP_DIR"

    mkdir -p "$FW_OUT_DIR/$i" "$TMP_DIR/mount" || exit 1

    if ! "$SRC_DIR/tools/lpunpack" -p "$i" "$FW_OUT_DIR/super.img" "$TMP_DIR"; then
        "$SRC_DIR/tools/lpunpack" -p "${i}_a" "$FW_OUT_DIR/super.img" "$TMP_DIR" || {
            rm -rf "$FW_OUT_DIR/$i"
            exit 1
        }
        mv "$TMP_DIR/${i}_a.img" "$TMP_DIR/$i.img" || {
            rm -rf "$FW_OUT_DIR/$i"
            exit 1
        }
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

    echo "Compressing $i image"
    ( cd "$TMP_DIR" && 7z a -tzip -mx=0 -mmt="$(nproc --all)" -snl "$FW_OUT_DIR/${LATEST_SHORTVERSION}_$i.zip" "$i.img" ) || exit 1
    rm -f "$TMP_DIR/$i.img"

    echo "Compressing extracted $i"
    ( cd "$FW_OUT_DIR" && 7z a -tzip -mx=0 -mmt="$(nproc --all)" -snl "$FW_OUT_DIR/${LATEST_SHORTVERSION}_$i-extracted.zip" "$i" ) || exit 1

    if [[ "$i" == "vendor" ]]; then
        grep -r "ro.product.board" "$FW_OUT_DIR/vendor/build.prop" | cut -d'=' -f2 > "$FW_OUT_DIR/board.txt"
        echo "Compressing firmware and TEEgris firmware"
        ( cd "$FW_OUT_DIR/vendor" && 7z a -tzip -mx=0 -mmt="$(nproc --all)" -snl "$FW_OUT_DIR/${LATEST_SHORTVERSION}_firmware_tee.zip" "firmware" "tee" ) || exit 1
    elif [[ "$i" == "product" ]]; then
        grep -r "ro.product.build.version.release" "$FW_OUT_DIR/product/etc/build.prop" | cut -d'=' -f2 | head -n 1 > "$FW_OUT_DIR/android.txt"
    fi

    while IFS= read -r i; do
        if [[ "$(stat -c%s "$i")" -ge "2147483647" ]]; then
            rm -f "$i"
        fi
    done < <(find "$FW_OUT_DIR" -maxdepth 1 -type f -name "${LATEST_SHORTVERSION}_$i-extracted*.zip")

    rm -rf "$TMP_DIR" || exit 1
done

BOARD="$(cat "$FW_OUT_DIR/board.txt")"

if [[ ! -f "$FW_OUT_DIR/${LATEST_SHORTVERSION}_kernel.tar" ]]; then
    FILES=("boot.img" "dtbo.img" "init_boot.img" "vendor_boot.img" "recovery.img")
    BL_LIST="$(tar -tf "$BL_TAR")"
    AP_LIST="$(tar -tf "$AP_TAR")"

    if [[ ! -d "$TMP_DIR" ]]; then
        mkdir -p "$TMP_DIR" || exit 1
    fi

    for i in "${FILES[@]}"; do
        LZ4="$i.lz4"
        SRC=""

        if grep -qx "$LZ4" <<< "$BL_LIST"; then
            SRC="$BL_TAR"
        elif grep -qx "$LZ4" <<< "$AP_LIST"; then
            SRC="$AP_TAR"
        else
            continue
        fi

        echo "Extracting $i from $(basename "$SRC")"
        tar -C "$TMP_DIR" -xf "$SRC" "$LZ4" || exit 1

        echo "Decompressing $i"
        lz4 --rm -q -f -d "$TMP_DIR/$LZ4" "$TMP_DIR/$i" || exit 1
        OUT_FILES+=("$i")
    done

    echo "Compressing kernel images"
    ( cd "$TMP_DIR" && tar cf "$FW_OUT_DIR/${LATEST_SHORTVERSION}_kernel.tar" "${OUT_FILES[@]}" && rm -f "${OUT_FILES[@]}" || exit 1 ) || exit 1

    rm -rf "$TMP_DIR" || exit 1
fi

if [[ ! -d "$TMP_DIR" ]]; then
    mkdir -p "$TMP_DIR" || exit 1
fi

echo "Checking bootloader lock status"
BL_LOCK=false

tar -C "$TMP_DIR" -xf "$BL_TAR" "sboot.bin.lz4" || exit 1
lz4 --rm -q -f -d "$TMP_DIR/sboot.bin.lz4" "$TMP_DIR/sboot.bin" || exit 1

if strings "$TMP_DIR/sboot.bin" | grep -q androidboot.other; then
    BL_LOCK=true
fi

rm -f "$TMP_DIR/sboot.bin"

PROPRIETARY_FILES_FILE="$SRC_DIR/proprietary-files/$MODEL/$LATEST_SHORTVERSION"
FILE_CONTEXT_FILE="$SRC_DIR/file_context/$MODEL/$LATEST_SHORTVERSION"
FS_CONFIG_FILE="$SRC_DIR/fs_config/$MODEL/$LATEST_SHORTVERSION"

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
} > "$PROPRIETARY_FILES_FILE"

if [[ ${#AUDIO_BLOBS[@]} -gt 0 ]]; then
    {
        echo ""
        echo "# Audio - Firmware"
    } >> "$PROPRIETARY_FILES_FILE"
    WRITE_BLOB_ENTRIES "$PROPRIETARY_FILES_FILE" "vendor/firmware" "" "${AUDIO_BLOBS[@]}"
fi
if [[ ${#FIRMWARE_BLOBS[@]} -gt 0 ]]; then
    {
        echo ""
        echo "# Firmware"
    } >> "$PROPRIETARY_FILES_FILE"
    WRITE_BLOB_ENTRIES "$PROPRIETARY_FILES_FILE" "vendor/firmware" "" "${FIRMWARE_BLOBS[@]}"
fi

{
    echo ""
    echo "# Security - TEEgris - Firmware" >> "$PROPRIETARY_FILES_FILE"
} >> "$PROPRIETARY_FILES_FILE"
for i in "${TEEGRIS_BLOBS[@]}"; do
    echo "vendor/tee/$i" >> "$PROPRIETARY_FILES_FILE"
done

{
    echo "" >> "$PROPRIETARY_FILES_FILE"
    echo "# Pinned" >> "$PROPRIETARY_FILES_FILE"
} >> "$PROPRIETARY_FILES_FILE"
if [[ ${#AUDIO_BLOBS[@]} -gt 0 ]]; then
    {
        echo ""
        echo "# Audio - Firmware - from $MODEL - $LATEST_SHORTVERSION"
    } >> "$PROPRIETARY_FILES_FILE"
    WRITE_BLOB_ENTRIES "$PROPRIETARY_FILES_FILE" "vendor/firmware" true "${AUDIO_BLOBS[@]}"
fi
if [[ ${#FIRMWARE_BLOBS[@]} -gt 0 ]]; then
    {
        echo ""
        echo "# Firmware - from $MODEL - $LATEST_SHORTVERSION"
    } >> "$PROPRIETARY_FILES_FILE"
    WRITE_BLOB_ENTRIES "$PROPRIETARY_FILES_FILE" "vendor/firmware" true "${FIRMWARE_BLOBS[@]}"
fi

{
    echo ""
    echo "# Security - TEEgris - Firmware - from $MODEL - $LATEST_SHORTVERSION"
} >> "$PROPRIETARY_FILES_FILE"
for i in "${TEEGRIS_BLOBS[@]}"; do
    echo "vendor/tee/$i|$(sha1sum "$FW_OUT_DIR/vendor/tee/$i" | awk '{print $1}')" >> "$PROPRIETARY_FILES_FILE"
done

{
    echo ""
    echo "# Pinned with path to model"
} >> "$PROPRIETARY_FILES_FILE"
if [[ ${#AUDIO_BLOBS[@]} -gt 0 ]]; then
    {
        echo ""
        echo "# Audio - Firmware - from $MODEL - $LATEST_SHORTVERSION"
    } >> "$PROPRIETARY_FILES_FILE"
    WRITE_BLOB_ENTRIES "$PROPRIETARY_FILES_FILE" "vendor/firmware/$MODEL" true "${AUDIO_BLOBS[@]}"
fi
if [[ ${#FIRMWARE_BLOBS[@]} -gt 0 ]]; then
    {
        echo ""
        echo "# Firmware - from $MODEL - $LATEST_SHORTVERSION"
    } >> "$PROPRIETARY_FILES_FILE"
    WRITE_BLOB_ENTRIES "$PROPRIETARY_FILES_FILE" "vendor/firmware/$MODEL" true "${FIRMWARE_BLOBS[@]}"
fi

{
    echo ""
    echo "# Security - TEEgris - Firmware - from $MODEL - $LATEST_SHORTVERSION"
} >> "$PROPRIETARY_FILES_FILE"
for i in "${TEEGRIS_BLOBS[@]}"; do
    echo "vendor/tee/$MODEL/$i|$(sha1sum "$FW_OUT_DIR/vendor/tee/$i" | awk '{print $1}')" >> "$PROPRIETARY_FILES_FILE"
done

{
    echo ""
    echo "# With path to model"
} >> "$PROPRIETARY_FILES_FILE"
if [[ ${#AUDIO_BLOBS[@]} -gt 0 ]]; then
    {
        echo ""
        echo "# Audio - Firmware"
    } >> "$PROPRIETARY_FILES_FILE"
    WRITE_BLOB_ENTRIES "$PROPRIETARY_FILES_FILE" "vendor/firmware:vendor/firmware/$MODEL" "" "${AUDIO_BLOBS[@]}"
fi
if [[ ${#FIRMWARE_BLOBS[@]} -gt 0 ]]; then
    {
        echo ""
        echo "# Firmware"
    } >> "$PROPRIETARY_FILES_FILE"
    WRITE_BLOB_ENTRIES "$PROPRIETARY_FILES_FILE" "vendor/firmware:vendor/firmware/$MODEL" "" "${FIRMWARE_BLOBS[@]}"
fi

{
    echo ""
    echo "# Security - TEEgris - Firmware"
} >> "$PROPRIETARY_FILES_FILE"
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
    echo "vendor/tee/$i 0 0 644 capabilities=0x0" >> "$FS_CONFIG_FILE"
done

{
    echo ""
    echo "# Path to model"
    echo "vendor/tee_$MODEL 0 2000 755 capabilities=0x0"
} >> "$FS_CONFIG_FILE"

for i in "${TEEGRIS_BLOBS[@]}"; do
    echo "vendor/tee_$MODEL/$i 0 0 644 capabilities=0x0" >> "$FS_CONFIG_FILE"
done

{
    echo "Android Version: $(cat "$FW_OUT_DIR/android.txt")"
    echo "Board: $BOARD"
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

if ! $UPLOAD; then
    exit 0
fi

git pull origin "$BRANCH" --ff-only

TAG="${LATEST_SHORTVERSION}_${CSC}_${OMC}"

APPEND_CURRENT_FIRMWARE "$SRC_DIR/current/${MODEL}_${CSC}_${OMC}" "$FIRMWARE"

git add \
  "$SRC_DIR/current/${MODEL}_${CSC}_${OMC}" \
  "$PROPRIETARY_FILES_FILE" \
  "$FILE_CONTEXT_FILE" \
  "$FS_CONFIG_FILE" || exit 1

if ! git diff --cached --quiet; then
    if [[ "$(whoami)" == "Maja" ]]; then
        git commit -s -S -m "samsung: $MODEL: $LATEST_SHORTVERSION ($CSC)" || exit 1
    else
        git commit -m "samsung: $MODEL: $LATEST_SHORTVERSION ($CSC)" || exit 1
    fi
fi

gh release delete "$TAG" --repo "$REPO" -y 2>/dev/null || true
git push origin --delete "$TAG" 2>/dev/null || true
git tag -d "$TAG" 2>/dev/null || true

git tag "$TAG" || exit 1

git push origin "$BRANCH" || {
    git pull origin "$BRANCH" --ff-only || exit 1
    git push origin "$BRANCH" || exit 1
}

git push origin "$TAG" || exit 1

RELEASE_NAME="$LATEST_SHORTVERSION - $MODEL - $CSC - $OMC"

gh release create "$TAG" \
    --repo "$REPO" \
    --title "$RELEASE_NAME" \
    --notes-file "$FW_OUT_DIR/versions.txt" || exit 1

for i in "$BL_TAR" \
    "$(find "$FW_DIR" -name "CP*")" \
    "$(find "$FW_DIR" -name "HOME_CSC*")"; do
    if [[ -f "$i" ]]; then
        UPLOAD_RELEASE_ASSET "$i"
    fi
done

while read -r i; do
    if [[ -f "$i" ]]; then
        UPLOAD_RELEASE_ASSET "$i"
    fi
done < <(find "$FW_OUT_DIR" -maxdepth 1 -type f -size -2147483647c ! -name '*.txt')
