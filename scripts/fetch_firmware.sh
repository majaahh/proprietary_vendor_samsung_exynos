ARGS="-i ${IMEI}"
[[ -n "${SERIAL}" ]] && ARGS="-s ${SERIAL}"

# Prepare samloader
python3 -m venv py_env
source "py_env/bin/activate"
pip3 install git+https://github.com/ananjaser1211/samloader.git
mkdir -p "${MODEL}_${CSC}"

# Get firmware
C=1
while true; do
    samloader -m ${MODEL} -r ${CSC} ${ARGS} download -O "${MODEL}_${CSC}"
    ZIP_FILE="$(find "${MODEL}_${CSC}" -name "*.zip" | sort -r | head -n 1)"
    if [[ ! "$ZIP_FILE" ]] || [[ ! -f "$ZIP_FILE" ]]; then
        if [[ "$C" -gt 10 ]]; then
            exit 1
        fi
        echo -e "[Attempt: $C] Download failed, retrying in 5 seconds..."
        sleep 5
        ((C++))
    else
        break
    fi
done

(
cd "${MODEL}_${CSC}"
unzip *".zip" 
rm -rf *".zip"
)

deactivate
rm -rf "py_env"
