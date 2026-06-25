#!/bin/bash
# diy-part2.sh

set -e

echo "========================================="
echo "[Part2] 替换组件 & 清理冲突包"
echo "========================================="

# =============================================
# 1. 替换 golang → 26.x
# =============================================
echo ""
echo ">>> 替换 golang → 26.x ..."

if [ ! -d "./feeds/packages/lang" ]; then
    echo "  ❌ ERROR: feeds/packages/lang 不存在，请确认 feeds update 已执行"
    exit 1
fi

rm -rf ./feeds/packages/lang/golang
git clone --depth=1 --single-branch \
    --branch "26.x" \
    https://github.com/sbwml/packages_lang_golang \
    feeds/packages/lang/golang
echo "  ✓ golang 26.x 替换完成"

# =============================================
# 2. 清理 dae/daed luci 前端冲突
#
# 说明：
#   defconfig/mt7981-ax3000_dae.config 已包含 daed 后端配置
#   kenzok8/openwrt-daede feed 提供 luci-app-daede 前端
#   只需删除 luci feed 中可能存在的旧版前端
#   ❌ 不能删除 feeds/packages/net/dae 和 daed（后端）
# =============================================
echo ""
echo ">>> 清理 dae/daed 旧版 luci 前端..."

[ -d "./feeds/luci/applications/luci-app-dae" ] && {
    rm -rf ./feeds/luci/applications/luci-app-dae
    echo "  ✓ 删除 luci-app-dae 旧前端"
}
[ -d "./feeds/luci/applications/luci-app-daed" ] && {
    rm -rf ./feeds/luci/applications/luci-app-daed
    echo "  ✓ 删除 luci-app-daed 旧前端"
}
echo "  ✓ 保留 feeds/packages/net/dae（后端）"
echo "  ✓ 保留 feeds/packages/net/daed（后端）"

# =============================================
# 3. 清理 smpackage 冲突包
# =============================================
echo ""
echo ">>> 清理 smpackage 冲突包..."

if [ -d "./feeds/smpackage" ]; then
    # 与仓库主 feeds 重复的基础包
    rm -rf ./feeds/smpackage/{base-files,dnsmasq,firewall*,fullconenat,\
libnftnl,nftables,ppp,opkg,ucl,upx,vsftpd*,miniupnpd-iptables,wireless-regdb}
    echo "  ✓ 基础冲突包清理完成"

    # 递归依赖问题包
    echo ">>> 清理 smpackage 递归依赖问题包..."
    for pkg in \
        luci-app-fchomo \
        luci-app-kodexplorer \
        luci-app-nekobox \
        luci-app-nat6-helper \
        natmap \
        luci-app-qbittorrent qbittorrent \
        luci-app-ua2f ua2f \
        luci-app-torbp tor \
        luci-app-alist \
        mentohust \
        minieap \
        kmod-oaf \
        strongswan; do
        [ -d "./feeds/smpackage/$pkg" ] && {
            rm -rf "./feeds/smpackage/$pkg"
            echo "  ✓ 删除 $pkg"
        }
    done
    echo "  ✓ 递归依赖问题包清理完成"
else
    echo "  ⚠ feeds/smpackage 不存在，跳过"
fi

echo ""
echo "✓ [Part2] 完成，准备执行 feeds install -a"
