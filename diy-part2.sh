#!/bin/bash
# diy-part2.sh

set -e

echo "========================================="
echo "[Part2] 替换组件 & 清理 feeds 冲突包"
echo "========================================="

# =============================================
# 1. 替换 golang → 26.x
# =============================================
echo ""
echo ">>> 替换 golang → 26.x ..."

if [ ! -d "./feeds/packages/lang" ]; then
    echo "  ❌ ERROR: feeds/packages/lang 不存在，feeds update 可能未执行"
    exit 1
fi

rm -rf ./feeds/packages/lang/golang
git clone --depth=1 --single-branch \
    --branch "26.x" \
    https://github.com/sbwml/packages_lang_golang \
    feeds/packages/lang/golang
echo "  ✓ golang 26.x 替换完成"

# =============================================
# 2. 清理 dae/daed 与 luci feed 的冲突
#
# ⚠️  关键修复说明：
#    daede feed 是一体包（dae内核 + daed + luci-app-daede）
#    只删除旧的 luci 前端（会与 daede 的 luci-app-daede 冲突）
#    ❌ 绝对不能删除 feeds/packages/net/dae 和 daed！
#       daede feed 提供的 luci-app-daede 依赖这两个后端包
#       删除后会导致：
#       WARNING: luci-app-daede has a dependency on 'dae', which does not exist
# =============================================
echo ""
echo ">>> 清理 dae/daed luci 前端冲突（仅删 luci 层，保留后端）..."

# 只删除旧版 luci 前端，由 daede feed 的 luci-app-daede 替代
[ -d "./feeds/luci/applications/luci-app-dae" ] && {
    rm -rf ./feeds/luci/applications/luci-app-dae
    echo "  ✓ 删除 feeds/luci/applications/luci-app-dae（旧前端）"
}

[ -d "./feeds/luci/applications/luci-app-daed" ] && {
    rm -rf ./feeds/luci/applications/luci-app-daed
    echo "  ✓ 删除 feeds/luci/applications/luci-app-daed（旧前端）"
}

# ✅ 保留 feeds/packages/net/dae 和 daed（后端包，daede 的 luci-app 依赖它们）
echo "  ✓ 保留 feeds/packages/net/dae（后端，daede 依赖）"
echo "  ✓ 保留 feeds/packages/net/daed（后端，daede 依赖）"

# =============================================
# 3. 清理 smpackage 与主 feeds 冲突的基础包
# =============================================
echo ""
echo ">>> 清理 smpackage 冲突基础包..."

if [ ! -d "./feeds/smpackage" ]; then
    echo "  ⚠ WARNING: feeds/smpackage 不存在，跳过"
else
    # 与 immortalwrt 主 feeds 重复的基础系统包
    rm -rf ./feeds/smpackage/{base-files,dnsmasq,firewall*,fullconenat,\
libnftnl,nftables,ppp,opkg,ucl,upx,vsftpd*,miniupnpd-iptables,wireless-regdb}
    echo "  ✓ 基础冲突包清理完成"

    # =============================================
    # 4. 清理 smpackage 中有递归依赖问题的包
    #    来源：make defconfig 时出现的 kconfig 递归依赖 error
    #    这些 error 不会阻断编译，但会污染 .config 解析
    #    最佳做法：直接删除这些有问题的包
    # =============================================
    echo ""
    echo ">>> 清理 smpackage 中有递归依赖问题的包..."

    # luci-app-fchomo（自依赖）
    rm -rf ./feeds/smpackage/luci-app-fchomo
    echo "  ✓ 删除 luci-app-fchomo（自依赖循环）"

    # luci-app-kodexplorer / php8 循环
    rm -rf ./feeds/smpackage/luci-app-kodexplorer
    echo "  ✓ 删除 luci-app-kodexplorer（php8 循环依赖）"

    # luci-app-nat6-helper（自依赖）
    rm -rf ./feeds/smpackage/luci-app-nat6-helper
    echo "  ✓ 删除 luci-app-nat6-helper（自依赖循环）"

    # natmap（自依赖）
    rm -rf ./feeds/smpackage/natmap
    echo "  ✓ 删除 natmap（自依赖循环）"

    # luci-app-qbittorrent / qbittorrent 循环
    rm -rf ./feeds/smpackage/luci-app-qbittorrent
    rm -rf ./feeds/smpackage/qbittorrent
    echo "  ✓ 删除 luci-app-qbittorrent + qbittorrent（循环依赖）"

    # luci-app-ua2f / ua2f 循环
    rm -rf ./feeds/smpackage/luci-app-ua2f
    rm -rf ./feeds/smpackage/ua2f
    echo "  ✓ 删除 luci-app-ua2f + ua2f（循环依赖）"

    # luci-app-torbp / tor 循环
    rm -rf ./feeds/smpackage/luci-app-torbp
    rm -rf ./feeds/smpackage/tor
    echo "  ✓ 删除 luci-app-torbp + tor（循环依赖）"

    # luci-app-alist（自依赖）
    rm -rf ./feeds/smpackage/luci-app-alist
    echo "  ✓ 删除 luci-app-alist（自依赖循环）"

    # mentohust（自依赖）
    rm -rf ./feeds/smpackage/mentohust
    echo "  ✓ 删除 mentohust（自依赖循环）"

    # minieap（自依赖）
    rm -rf ./feeds/smpackage/minieap
    echo "  ✓ 删除 minieap（自依赖循环）"

    # kmod-oaf（自依赖）
    rm -rf ./feeds/smpackage/kmod-oaf
    echo "  ✓ 删除 kmod-oaf（自依赖循环）"

    # strongswan 循环（minimal ↔ mod-openssl）
    rm -rf ./feeds/smpackage/strongswan
    echo "  ✓ 删除 strongswan（minimal ↔ mod-openssl 循环）"

    echo "  ✓ 递归依赖问题包清理完成"
fi

echo ""
echo "✓ [Part2] 完成，准备执行 feeds install -a"
