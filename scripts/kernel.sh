FILES=("boot.img" "dtbo.img" "init_boot.img" "vendor_boot.img" "recovery.img")
F=""

for i in "${FILES[@]}"; do
    if [[ "$1" == "init_boot.img" ]]; then
        tar xvf ${BL_TAR} ${i}.lz4 || true
    else
        tar xvf ${AP_TAR} ${i}.lz4 || true
    fi
    if [[ -f "${i}.lz4" ]]; then
        lz4 -d ${i}.lz4 ${i}
        rm -f ${i}.lz4
        F+="$i "
    fi
done

tar cvf ${LATEST_SHORTVERSION}_kernel.tar ${F}
