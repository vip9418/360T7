#!/bin/bash
# diy-part1.sh
# ⚠️ 执行时机：feeds update 之前
# ✅ 职责：只允许修改 feeds.conf.default
# ❌ 严禁：操作 feeds/ 目录（此时不存在）

set -e

echo "========================================="
echo "[Part1] 写入自定义 feed 源"
echo "========================================="

# 添加 daede feed
if ! grep -q "openwrt-daede" feeds.conf.default; then
    echo "src-git daede https://github.com/kenzok8/openwrt-daede.git^main" \
        >> feeds.conf.default
    echo "  ✓ daede feed 已添加"
else
    echo "  - daede feed 已存在，跳过"
fi

# 添加 small-package feed
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
echo "✓ [Part1] 完成"
