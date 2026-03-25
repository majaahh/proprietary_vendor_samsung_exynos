# Config
git config --local user.email "41898282+github-actions[bot]@users.noreply.github.com"
git config --local user.name "github-actions[bot]"

# Pull
git pull origin "$GHR" --ff-only

# Tag and release
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

# Commit
echo "$LATEST_VERSION" > "current/current.${MODEL}_${CSC}_${OMC}"
git add "current/current.${MODEL}_${CSC}_${OMC}"
git add "proprietary-files/$BOARD/proprietary.${MODEL}_${CSC}_${OMC}"
git add "file_context/$BOARD/file.${MODEL}_${CSC}_${OMC}"
git add "fs_config/$BOARD/fs.${MODEL}_${CSC}_${OMC}"
git commit -m "samsung: ${MODEL}: ${LATEST_SHORTVERSION}"
git tag "${LATEST_SHORTVERSION}_${CSC}_${OMC}"
