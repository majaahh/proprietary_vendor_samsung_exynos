# Mount vendor
mkdir -p vendor/mount vendor/tee
sudo mount vendor.img vendor/mount

# Get firmware and tee
cp -rfa vendor/mount/tee vendor
cd vendor || exit 1

cp -fa build.prop "../${LATEST_SHORTVERSION}_vendor.prop"
zip -r0 --store "${LATEST_SHORTVERSION}_firmware_tee.zip" "firmware" "tee"
mv -f "${LATEST_SHORTVERSION}_firmware_tee.zip" "../"
