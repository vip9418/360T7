#!/bin/bash
#
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
# Executed after: git clone source
# Executed before: ./scripts/feeds update -a
#

set -e

echo "=========================================="
echo "  DIY Part 1: Pre-feeds customization"
echo "=========================================="

# -----------------------------------------------
# 【工具函数】UPDATE_PACKAGE
# 用途: 安全地从 GitHub 克隆包并替换 feeds 中的旧版本
# 参数:
#   $1 PKG_NAME   - 包名
#   $2 PKG_REPO   - GitHub 仓库 (user/repo)
#   $3 PKG_BRANCH - 分支名
#   $4 PKG_SPECIAL - 特殊处理模式 (pkg/name/留空)
#   $5 额外搜索清理名称列表
# -----------------------------------------------
UPDATE_PACKAGE() {
    local PKG_NAME=$1
    local PKG_REPO=$2
    local PKG_BRANCH=$3
    local PKG_SPECIAL=$4
    local PKG_LIST=("$PKG_NAME" $5)
    local REPO_NAME=${PKG_REPO#*/}

    echo ""
    echo ">>> Processing: $PKG_NAME from $PKG_REPO @ $PKG_BRANCH"

    # 清理 feeds 中的同名旧目录
    for NAME in "${PKG_LIST[@]}"; do
        echo "  Search & remove: $NAME"
        local FOUND_DIRS
        FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ \
            -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null || true)
        if [ -n "$FOUND_DIRS" ]; then
            while read -r DIR; do
                rm -rf "$DIR"
                echo "  Deleted: $DIR"
            done <<< "$FOUND_DIRS"
        else
            echo "  Not found in feeds: $NAME (skip)"
        fi
    done

    # 清理本地已有克隆
    [ -d "./$REPO_NAME" ] && rm -rf "./$REPO_NAME"

    # 克隆仓库 (浅克隆，节省时间和磁盘)
    echo "  Cloning: https://github.com/$PKG_REPO (branch: $PKG_BRANCH)"
    if ! git clone --depth=1 --single-branch \
        --branch "$PKG_BRANCH" \
        "https://github.com/$PKG_REPO.git"; then
        echo "  ERROR: Failed to clone $PKG_REPO"
        return 1
    fi

    # 特殊处理模式
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

# -----------------------------------------------
# 【Step 1】添加 daede feeds 源到 feeds.conf.default
# 使用 src-git 方式集成，feeds update/install 会自动
# 解析 Makefile 依赖链，比手动 clone 更可靠
# -----------------------------------------------
echo ""
echo "=== Step 1: Adding daede feed source ==="

# 防止重复添加
if ! grep -q "openwrt-daede" feeds.conf.default; then
    echo "src-git daede https://github.com/kenzok8/openwrt-daede.git^main" \
        >> feeds.conf.default
    echo "✓ daede feed source added"
else
    echo "✓ daede feed source already exists, skip"
fi

# -----------------------------------------------
# 【Step 2】替换 Golang 为最新版本 (26.x)
# 必须在 feeds update 之前执行，确保版本一致性
# dae/daed 编译依赖较新的 Go 版本
# -----------------------------------------------
echo ""
echo "=== Step 2: Replacing Golang to 26.x ==="

rm -rf ./feeds/packages/lang/golang
git clone --depth=1 --single-branch \
    --branch "26.x" \
    https://github.com/sbwml/packages_lang_golang \
    feeds/packages/lang/golang
echo "✓ Golang 26.x ready"

# -----------------------------------------------
# 【Step 3】预清理 feeds 中与 daede 冲突的旧包
# 必须在 feeds update 之前执行
# -----------------------------------------------
echo ""
echo "=== Step 3: Cleaning conflicting packages from feeds ==="

# 清理 luci feeds 中的旧版 dae 相关包
rm -rf ./feeds/luci/applications/luci-app-dae
rm -rf ./feeds/luci/applications/luci-app-daed

# 清理 packages feeds 中的旧版 dae 核心包
rm -rf ./feeds/packages/net/dae
rm -rf ./feeds/packages/net/daed

echo "✓ Conflicting packages cleaned"

echo ""
echo "=========================================="
echo "  DIY Part 1 Complete"
echo "=========================================="
