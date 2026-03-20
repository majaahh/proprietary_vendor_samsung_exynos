# Get firmware
C=1
while true; do
    samfwdl download "$MODEL" "$CSC" -o firmware --decrypt
    STATUS=$?

    if [[ $STATUS -eq 0 ]]; then
        break
    fi

    if [[ "$C" -gt 10 ]]; then
        exit 1
    fi

    echo "[Attempt: $C] Download failed (status: $STATUS), retrying in 5 seconds..."
    sleep 5
    ((C++))
done

FW="$(find "firmware" -name "*.zip" | tail -n 1)"
unzip "$FW" || exit 1
rm -rf "firmware"
