# Get firmware
C=1
while true; do
    ./tools/samloader -m "${MODEL}" -r "${CSC}" download -o "fw.zip"
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

unzip "fw.zip"
rm -rf "fw.zip"
