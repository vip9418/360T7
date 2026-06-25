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

# =============================================
# 1. 添加 daede feed（你原有的）
# =============================================
if ! grep -q "openwrt-daede" feeds.conf.default; then
    echo "src-git daede https://github.com/kenzok8/openwrt-daede.git^main" \
        >> feeds.conf.default
fi

# =============================================
# 2. 添加 small-package feed（新增）
# =============================================
if ! grep -q "small-package" feeds.conf.default; then
    echo "src-git smpackage https://github.com/kenzok8/small-package" \
        >> feeds.conf.default
fi

# =============================================
# 3. 更新 golang 到 26.x（你原有的）
# =============================================
rm -rf ./feeds/packages/lang/golang
git clone --depth=1 --single-branch \
    --branch "26.x" \
    https://github.com/sbwml/packages_lang_golang \
    feeds/packages/lang/golang

# =============================================
# 4. 删除原 feeds 中与 small-package 冲突的包
# =============================================
# 删除 dae/daed 相关冲突（你原有的）
rm -rf ./feeds/luci/applications/luci-app-dae
rm -rf ./feeds/luci/applications/luci-app-daed
rm -rf ./feeds/packages/net/dae
rm -rf ./feeds/packages/net/daed

# 删除 small-package feed 中与主 feeds 冲突的基础包
rm -rf ./feeds/smpackage/{base-files,dnsmasq,firewall*,fullconenat,libnftnl,nftables,ppp,opkg,ucl,upx,vsftpd*,miniupnpd-iptables,wireless-regdb}

echo ""
echo "✓ All feeds and packages configured."
