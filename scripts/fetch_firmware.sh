# Prepare samloader
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
git clone "https://github.com/topjohnwu/samloader-rs.git"
(
cd "samloader-rs"
cargo build --release
cp -fa "target/release/samloader" "../"
)

# Get firmware
C=1
while true; do
    ./samloader -m "${MODEL}" -r "${CSC}" download -o "fw.zip"
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
