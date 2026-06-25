#!/bin/bash
# diy-part2.sh
# ⚠️ 执行时机：feeds update 之后、feeds install 之前
# ✅ 职责：替换 golang、清理所有冲突包
# ❌ 严禁：修改 .config 或 package/ 源码树

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
        # ✅ 修复：使用 ./ 相对路径（脚本在 openwrt/ 目录下执行）
        FOUND_DIRS=$(find ./feeds/luci/ ./feeds/packages/ \
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

echo "========================================="
echo "[Part2] 清理冲突包 & 替换组件"
echo "========================================="

# =============================================
# 1. 替换 golang → 26.x
#    ✅ feeds update 后 feeds/packages/ 已存在
# =============================================
echo ""
echo ">>> 替换 golang → 26.x ..."
rm -rf ./feeds/packages/lang/golang
git clone --depth=1 --single-branch \
    --branch "26.x" \
    https://github.com/sbwml/packages_lang_golang \
    feeds/packages/lang/golang
echo "  ✓ golang 26.x 替换完成"

# =============================================
# 2. 清理 dae/daed 旧版冲突
#    ✅ feeds update 后这些目录已存在
# =============================================
echo ""
echo ">>> 清理 dae/daed 冲突包..."
rm -rf ./feeds/luci/applications/luci-app-dae
rm -rf ./feeds/luci/applications/luci-app-daed
rm -rf ./feeds/packages/net/dae
rm -rf ./feeds/packages/net/daed
echo "  ✓ dae/daed 冲突清理完成"

# =============================================
# 3. 清理 smpackage 与主 feeds 冲突的基础包
#    ✅ feeds update 后 feeds/smpackage/ 已存在
# =============================================
echo ""
echo ">>> 清理 smpackage 冲突基础包..."
rm -rf ./feeds/smpackage/{base-files,dnsmasq,firewall*,fullconenat,libnftnl,nftables,ppp,opkg,ucl,upx,vsftpd*,miniupnpd-iptables,wireless-regdb}
echo "  ✓ smpackage 冲突清理完成"

echo ""
echo "✓ [Part2] 完成，可以执行 feeds install"
