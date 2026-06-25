#!/bin/bash
# diy-part1.sh
# ========================================
# 执行时机：feeds update -a 之前
# 职责：仅写入 feeds.conf.default
# 严禁：操作任何 feeds/ 目录（此时不存在）
# 适配：VIKINGYFY/immortalwrt owrt 分支
#       标准 immortalwrt upstream fork
#       使用 immortalwrt/packages + immortalwrt/luci
# ========================================

set -e

echo "========================================="
echo "[Part1] 写入自定义 feed 源"
echo "========================================="

# VIKINGYFY owrt 分支的 feeds.conf.default 继承自标准 immortalwrt：
# src-git packages https://github.com/immortalwrt/packages.git
# src-git luci     https://github.com/immortalwrt/luci.git
# src-git routing  https://github.com/openwrt/routing.git
# src-git telephony https://github.com/openwrt/telephony.git
# src-git video    https://github.com/openwrt/video.git
# ↓ 在此基础上追加自定义 feed

# 追加 daede feed（dae/daed 代理工具）
if ! grep -q "openwrt-daede" feeds.conf.default; then
    echo "src-git daede https://github.com/kenzok8/openwrt-daede.git^main" \
        >> feeds.conf.default
    echo "  ✓ daede feed 已添加"
else
    echo "  - daede feed 已存在，跳过"
fi

# 追加 small-package feed（kenzok8 插件集）
if ! grep -q "small-package" feeds.conf.default; then
    echo "src-git smpackage https://github.com/kenzok8/small-package" \
        >> feeds.conf.default
    echo "  ✓ smpackage feed 已添加"
else
    echo "  - smpackage feed 已存在，跳过"
fi

echo ""
echo ">>> 当前 feeds.conf.default 内容："
cat feeds.conf.default

echo ""
echo "✓ [Part1] 完成，准备执行 feeds update -a"
