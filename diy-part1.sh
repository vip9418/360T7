#!/bin/bash
# diy-part1.sh

set -e

echo "========================================="
echo "[Part1] 写入自定义 feed 源"
echo "========================================="

echo ">>> 原始 feeds.conf.default："
cat feeds.conf.default
echo ""

# daede feed：提供 luci-app-daede 前端
# dae/daed 后端由仓库自带，defconfig 已配置
if ! grep -q "openwrt-daede" feeds.conf.default; then
    echo "src-git daede https://github.com/kenzok8/openwrt-daede.git^main" \
        >> feeds.conf.default
    echo "  ✓ daede feed 已添加"
else
    echo "  - daede feed 已存在，跳过"
fi

# smpackage feed：提供 openclash 等插件
if ! grep -q "small-package" feeds.conf.default; then
    echo "src-git smpackage https://github.com/kenzok8/small-package" \
        >> feeds.conf.default
    echo "  ✓ smpackage feed 已添加"
else
    echo "  - smpackage feed 已存在，跳过"
fi

echo ""
echo ">>> 修改后 feeds.conf.default："
cat feeds.conf.default

echo ""
echo "✓ [Part1] 完成"
