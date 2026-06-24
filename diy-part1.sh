#!/bin/bash

set -e

UPDATE_PACKAGE() {
    local PKG_NAME=$1
    local PKG_REPO=$2
    local PKG_BRANCH=$3
    local PKG_SPECIAL=$4
    local PKG_LIST=("$PKG_NAME" $5)
    local REPO_NAME=${PKG_REPO#*/}

    echo ""
    echo ">>> Processing: $PKG_NAME from $PKG_REPO @ $PKG_BRANCH"

    for NAME in "${PKG_LIST[@]}"; do
        local FOUND_DIRS
        FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ \
            -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null || true)
        if [ -n "$FOUND_DIRS" ]; then
            while read -r DIR; do
                rm -rf "$DIR"
                echo "  Deleted: $DIR"
            done <<< "$FOUND_DIRS"
        fi
    done

    [ -d "./$REPO_NAME" ] && rm -rf "./$REPO_NAME"

    if ! git clone --depth=1 --single-branch \
        --branch "$PKG_BRANCH" \
        "https://github.com/$PKG_REPO.git"; then
        echo "  ERROR: Failed to clone $PKG_REPO"
        return 1
    fi

    if [[ $PKG_SPECIAL == "pkg" ]]; then
        find "./$REPO_NAME"/*/ -maxdepth 3 -type d \
            -iname "*$PKG_NAME*" -prune \
            -exec cp -rf {} ./ \;
        rm -rf "./$REPO_NAME/"
    elif [[ $PKG_SPECIAL == "name" ]]; then
        mv -f "$REPO_NAME" "$PKG_NAME"
    fi

    echo "  ✓ $PKG_NAME installed"
}

if ! grep -q "openwrt-daede" feeds.conf.default; then
    echo "src-git daede https://github.com/kenzok8/openwrt-daede.git^main" \
        >> feeds.conf.default
fi

rm -rf ./feeds/packages/lang/golang
git clone --depth=1 --single-branch \
    --branch "26.x" \
    https://github.com/sbwml/packages_lang_golang \
    feeds/packages/lang/golang

rm -rf ./feeds/luci/applications/luci-app-dae
rm -rf ./feeds/luci/applications/luci-app-daed
rm -rf ./feeds/packages/net/dae
rm -rf ./feeds/packages/net/daed
