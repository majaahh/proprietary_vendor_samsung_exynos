{
    echo "ap_tar=$(find "." -name "AP*")"
    echo "bl_tar=$(find "." -name "BL*")"
    echo "cp_tar=$(find "." -name "CP*")"
    echo "csc_tar=$(find "." -name "CSC*")"
    echo "home_csc_tar=$(find "." -name "HOME_CSC*")"
} >> "$GITHUB_ENV"
