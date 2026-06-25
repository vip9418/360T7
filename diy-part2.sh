#!/bin/bash
# diy-part2.sh

set -e

echo "========================================="
echo "[Part2] 替换组件 & 清理 feeds 冲突包"
echo "========================================="

# =============================================
# 1. 替换 golang → 26.x
#    原因：immortalwrt/packages 内置的 golang 版本
#          与部分新包不兼容，sbwml 维护的 26.x 更稳定
# =============================================
echo ""
echo ">>> 替换 golang → 26.x ..."

if [ ! -d "./feeds/packages/lang" ]; then
    echo "  ⚠ WARNING: feeds/packages/lang 目录不存在"
    echo "    请确认 feeds update -a 已正确执行"
    exit 1
fi

rm -rf ./feeds/packages/lang/golang
git clone --depth=1 --single-branch \
    --branch "26.x" \
    https://github.com/sbwml/packages_lang_golang \
    feeds/packages/lang/golang
echo "  ✓ golang 26.x 替换完成"

# =============================================
# 2. 清理 dae/daed 与 immortalwrt/packages 的冲突
#    VIKINGYFY owrt 使用 immortalwrt/packages，
#    其中可能已包含旧版 dae/daed，需先清除
#    再由 daede feed 提供新版本
# =============================================
echo ""
echo ">>> 清理 dae/daed 冲突包..."

# luci 侧
[ -d "./feeds/luci/applications/luci-app-dae" ] && \
    rm -rf ./feeds/luci/applications/luci-app-dae && \
    echo "  ✓ 删除 feeds/luci/applications/luci-app-dae"

[ -d "./feeds/luci/applications/luci-app-daed" ] && \
    rm -rf ./feeds/luci/applications/luci-app-daed && \
    echo "  ✓ 删除 feeds/luci/applications/luci-app-daed"

# packages 侧
[ -d "./feeds/packages/net/dae" ] && \
    rm -rf ./feeds/packages/net/dae && \
    echo "  ✓ 删除 feeds/packages/net/dae"

[ -d "./feeds/packages/net/daed" ] && \
    rm -rf ./feeds/packages/net/daed && \
    echo "  ✓ 删除 feeds/packages/net/daed"

echo "  ✓ dae/daed 冲突清理完成"

# =============================================
# 3. 清理 smpackage 与标准 immortalwrt feeds 的冲突
#    VIKINGYFY owrt 使用官方 immortalwrt/packages
#    和 immortalwrt/luci，smpackage 中以下包与之重复
#    必须删除否则 feeds install 报冲突错误
# =============================================
echo ""
echo ">>> 清理 smpackage 冲突基础包..."

if [ -d "./feeds/smpackage" ]; then
    rm -rf ./feeds/smpackage/{base-files,dnsmasq,firewall*,\
fullconenat,libnftnl,nftables,ppp,opkg,ucl,upx,\
vsftpd*,miniupnpd-iptables,wireless-regdb}
    echo "  ✓ smpackage 冲突基础包清理完成"
else
    echo "  ⚠ WARNING: feeds/smpackage 目录不存在"
    echo "    请确认 small-package feed 已在 feeds.conf.default 中添加"
    echo "    且 feeds update -a 已正确执行"
fi

echo ""
echo "✓ [Part2] 完成，准备执行 feeds install -a"
