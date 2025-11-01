F="vendor "

for i in "boot" "init_boot" "vendor_boot" "recovery"; do
    if [[ -f "$i.img" ]]; then
        ./tools/unpack_bootimg --boot_img ${i}.img --out ${i} > ${i}.txt
        rm -f ${i}.img
        F+="${i} ${i}.txt "
    fi
done

mkdir -p dtbo
(
cd dtbo

../tools/mkdtboimg dump ../dtbo.img --dtb dtbo > ../dtbo.txt

for i in dtbo*; do
    ../tools/dtc -I dtb -O dts $i -o $i &>/dev/null
done
)

F+="dtbo dtbo.txt"

zip -r9 ${LATEST_SHORTVERSION}_dump-AOSP.zip ${F}
