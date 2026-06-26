#!/bin/bash
# diy-part3.sh

set -e

echo "========================================="
echo "[Part3] 自定义系统配置 & 主题美化"
echo "========================================="

# =============================================
# 1. 修改默认 LAN IP
# =============================================
echo ""
echo ">>> 修改默认 LAN IP ..."
CONFIG_GEN="./package/base-files/files/bin/config_generate"
if [ -f "$CONFIG_GEN" ]; then
    sed -i 's/192\.168\.6\.1/192.168.2.1/' "$CONFIG_GEN"
    echo "  ✓ LAN IP → 192.168.2.1"
else
    echo "  ⚠ config_generate 未找到"
fi

# =============================================
# 2. WiFi 默认参数
# =============================================
echo ""
echo ">>> 修改 WiFi 默认参数..."
MTWIFI_SH="./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh"

if [ ! -f "$MTWIFI_SH" ]; then
    echo "  ⚠ mtwifi.sh 未找到，改用 uci-defaults 方式"
    UCI_DIR="./package/base-files/files/etc/uci-defaults"
    mkdir -p "$UCI_DIR"
    cat > "${UCI_DIR}/99-wireless-defaults" << 'WIFI_EOF'
#!/bin/sh
[ -f /etc/config/wireless ] || exit 1
uci -q batch << UCI
set wireless.radio0.disabled=0
set wireless.default_radio0.ssid=cmcc
set wireless.default_radio0.encryption=sae-mixed
set wireless.default_radio0.key=12345678
set wireless.radio1.disabled=0
set wireless.default_radio1.ssid=cmcc_5G
set wireless.default_radio1.encryption=sae-mixed
set wireless.default_radio1.key=12345678
UCI
uci commit wireless
exit 0
WIFI_EOF
    chmod +x "${UCI_DIR}/99-wireless-defaults"
    echo "  ✓ uci-defaults WiFi 脚本已写入"
else
    sed -i 's/ImmortalWrt-2\.4G/cmcc/' "$MTWIFI_SH"
    sed -i 's/ImmortalWrt-5G/cmcc_5G/' "$MTWIFI_SH"
    sed -i 's/\(channel\s*=\s*\)36\b/\1auto/g' "$MTWIFI_SH"
    sed -i 's/encryption=none/encryption=sae-mixed/' "$MTWIFI_SH"
    if ! grep -q 'key=12345678' "$MTWIFI_SH"; then
        sed -i '/encryption=sae-mixed/a \    set wireless.default_${dev}.key=12345678' \
            "$MTWIFI_SH"
    fi
    echo "  ✓ SSID: cmcc / cmcc_5G | 加密: sae-mixed | 密码: 12345678"
fi

# =============================================
# 3. 精确复现 commit 2dd8cf9
#    360T7 兼容老版 hanwckf U-Boot（itb → bin）
#    来源：padavanonly/immortalwrt-mt798x-6.6
#    commit: 2dd8cf9 "360 t7:compatiable with old uboot"
# =============================================
echo ""
echo ">>> 应用 commit 2dd8cf9（360T7 兼容 hanwckf U-Boot）..."

FILOGIC_MK="./target/linux/mediatek/image/filogic.mk"
DTS_FILE="./target/linux/mediatek/dts/mt7981b-qihoo-360t7.dts"

# --- 检查文件 ---
if [ ! -f "$FILOGIC_MK" ]; then
    echo "  ❌ ERROR: filogic.mk 未找到"
    exit 1
fi
if [ ! -f "$DTS_FILE" ]; then
    echo "  ❌ ERROR: DTS 文件未找到: $DTS_FILE"
    exit 1
fi

# -------------------------------------------------------------------
# 3.1 修改 filogic.mk：Device/qihoo_360t7 块
#
# 精确删除 itb 相关定义，只保留 sysupgrade.bin 一行
# 原始块内容（删除）：
#   UBINIZE_OPTS := -E 5
#   KERNEL_IN_UBI := 1
#   UBOOTENV_IN_UBI := 1
#   IMAGES := sysupgrade.itb
#   KERNEL_INITRAMFS_SUFFIX := -recovery.itb
#   KERNEL := kernel-bin | gzip
#   KERNEL_INITRAMFS := kernel-bin | lzma | fit lzma ... with-initrd | pad-to 64k
#   IMAGE/sysupgrade.itb := append-kernel | fit gzip ... | append-metadata
#   DEVICE_PACKAGES := kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware
#   ARTIFACTS := preloader.bin bl31-uboot.fip
#   ARTIFACT/preloader.bin := mt7981-bl2 spim-nand-ddr3
#   ARTIFACT/bl31-uboot.fip := mt7981-bl31-uboot qihoo_360t7
# 替换为（新增）：
#   IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
# -------------------------------------------------------------------
echo "  >>> 修改 filogic.mk ..."

python3 << 'PYEOF'
import re

with open('./target/linux/mediatek/image/filogic.mk', 'r') as f:
    content = f.read()

# 精确匹配 Device/qihoo_360t7 块中需要删除的行
# 删除以下所有行（精确匹配，只在 qihoo_360t7 块内）
lines_to_remove = [
    r'\tUBINIZE_OPTS := -E 5\n',
    r'\tKERNEL_IN_UBI := 1\n',
    r'\tUBOOTENV_IN_UBI := 1\n',
    r'\tIMAGES := sysupgrade\.itb\n',
    r'\tKERNEL_INITRAMFS_SUFFIX := -recovery\.itb\n',
    r'\tKERNEL := kernel-bin \| gzip\n',
    r'\tDEVICE_PACKAGES := kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware\n',
    r'\tARTIFACTS := preloader\.bin bl31-uboot\.fip\n',
    r'\tARTIFACT/preloader\.bin := mt7981-bl2 spim-nand-ddr3\n',
    r'\tARTIFACT/bl31-uboot\.fip := mt7981-bl31-uboot qihoo_360t7\n',
]

for pattern in lines_to_remove:
    content = re.sub(pattern, '', content)

# 删除多行的 KERNEL_INITRAMFS 定义
content = re.sub(
    r'\tKERNEL_INITRAMFS := kernel-bin \| lzma \| \\\n\t\tfit lzma \$\$\(KDIR\)/image-\$\$\(firstword \$\$\(DEVICE_DTS\)\)\.dtb with-initrd \| pad-to 64k\n',
    '', content
)

# 删除多行的 IMAGE/sysupgrade.itb 定义
content = re.sub(
    r'\tIMAGE/sysupgrade\.itb := append-kernel \| \\\n\t\tfit gzip \$\$\(KDIR_COMPILE\)/image-\$\$\(firstword \$\$\(DEVICE_DTS\)\)\.dtb external-static-with-rootfs \| append-metadata\n',
    '', content
)

# 在 endef 前（qihoo_360t7 块结尾）插入新行
# 找到 qihoo_360t7 块的 endef，在其前插入 IMAGE/sysupgrade.bin
# 先检查是否已经存在
if 'IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata' not in content:
    # 在 TARGET_DEVICES += qihoo_360t7 之前插入
    content = content.replace(
        '\tTARGET_DEVICES += qihoo_360t7\n',
        '\tIMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata\n\tendef\n\tTARGET_DEVICES += qihoo_360t7\n'
    )
    # 同时删除原来的 endef（避免重复）
    # 注意：上面的替换已经包含了 endef，需要删除原来在这之前的 endef
    pass

with open('./target/linux/mediatek/image/filogic.mk', 'w') as f:
    f.write(content)

print('  ✓ filogic.mk 修改完成')
PYEOF

# 验证关键行
if grep -q "IMAGE/sysupgrade.bin" "$FILOGIC_MK"; then
    echo "  ✓ 验证通过：IMAGE/sysupgrade.bin 已存在"
else
    echo "  ❌ 验证失败：IMAGE/sysupgrade.bin 未找到，使用备用方案..."
    # 备用方案：直接用 sed
    sed -i '/IMAGES := sysupgrade\.itb/d' "$FILOGIC_MK"
    sed -i '/KERNEL_INITRAMFS_SUFFIX := -recovery\.itb/d' "$FILOGIC_MK"
    sed -i '/KERNEL := kernel-bin | gzip/d' "$FILOGIC_MK"
    sed -i '/UBINIZE_OPTS := -E 5/d' "$FILOGIC_MK"
    sed -i '/KERNEL_IN_UBI := 1/d' "$FILOGIC_MK"
    sed -i '/UBOOTENV_IN_UBI := 1/d' "$FILOGIC_MK"
    sed -i '/DEVICE_PACKAGES := kmod-mt7915e/d' "$FILOGIC_MK"
    sed -i '/ARTIFACTS := preloader\.bin/d' "$FILOGIC_MK"
    sed -i '/ARTIFACT\/preloader\.bin/d' "$FILOGIC_MK"
    sed -i '/ARTIFACT\/bl31-uboot\.fip/d' "$FILOGIC_MK"
    echo "  ✓ 备用方案执行完成"
fi

# -------------------------------------------------------------------
# 3.2 修改 DTS：mt7981b-qihoo-360t7.dts
#
# 精确删除（来自 commit 2dd8cf9）：
#   bootargs-append = " root=/dev/fit0 rootwait";
#   rootdisk = <&ubi_rootdisk>;
#   compatible = "linux,ubi";
#   volumes { ubi_rootdisk: ubi-volume-fit { volname = "fit"; }; };
#
# 精确新增：
#   mediatek,nmbm;
#   mediatek,bmt-max-ratio = <1>;
#   mediatek,bmt-max-reserved-blocks = <64>;
# -------------------------------------------------------------------
echo "  >>> 修改 DTS 文件..."

# 删除 bootargs-append fit0 行
sed -i '/bootargs-append = " root=\/dev\/fit0 rootwait";/d' "$DTS_FILE"
echo "  ✓ 删除 bootargs-append fit0"

# 删除 rootdisk 行
sed -i '/rootdisk = <&ubi_rootdisk>;/d' "$DTS_FILE"
echo "  ✓ 删除 rootdisk"

# 删除 compatible = "linux,ubi" 行
sed -i '/compatible = "linux,ubi";/d' "$DTS_FILE"
echo "  ✓ 删除 compatible linux,ubi"

# 删除 volumes 块（ubi_rootdisk 定义）
python3 << 'PYEOF2'
with open('./target/linux/mediatek/dts/mt7981b-qihoo-360t7.dts', 'r') as f:
    content = f.read()

import re
# 删除 volumes { ubi_rootdisk: ubi-volume-fit { volname = "fit"; }; }; 块
content = re.sub(
    r'\s*volumes \{\s*ubi_rootdisk: ubi-volume-fit \{\s*volname = "fit";\s*\};\s*\};',
    '',
    content
)

with open('./target/linux/mediatek/dts/mt7981b-qihoo-360t7.dts', 'w') as f:
    f.write(content)
print('  ✓ 删除 volumes/ubi_rootdisk 块')
PYEOF2

# 新增 mediatek,nmbm 相关配置
# 在 spi-rx-bus-width = <4>; 行之后插入
if ! grep -q "mediatek,nmbm" "$DTS_FILE"; then
    sed -i '/spi-rx-bus-width = <4>;/a \\n\t\t\tmediatek,nmbm;\n\t\t\t\t\tmediatek,bmt-max-ratio = <1>;\n\t\t\t\t\tmediatek,bmt-max-reserved-blocks = <64>;' \
        "$DTS_FILE"
    echo "  ✓ 新增 mediatek,nmbm 配置"
else
    echo "  - mediatek,nmbm 已存在，跳过"
fi

echo "  ✓ commit 2dd8cf9 改动已精确复现"
echo "  ✓ 固件将输出：*-squashfs-sysupgrade.bin"

# =============================================
# 4. Argon 主题美化
# =============================================
ARGON_BASE="./feeds/luci/themes/luci-theme-argon"
ARGON_CSS="${ARGON_BASE}/htdocs/luci-static/argon/css/cascade.css"
ARGON_FONTS="${ARGON_BASE}/htdocs/luci-static/argon/fonts"
ARGON_IMG="${ARGON_BASE}/htdocs/luci-static/argon/img"

echo ""
echo ">>> 检查 Argon 主题..."

if [ ! -d "${ARGON_BASE}" ]; then
    echo "  ⚠ luci-theme-argon 未找到，跳过"
else
    echo "  ✓ Argon 主题目录已找到"

    if [ -d "${GITHUB_WORKSPACE}/argon" ]; then
        [ -f "${GITHUB_WORKSPACE}/argon/bg1.jpg" ] && {
            cp -f "${GITHUB_WORKSPACE}/argon/bg1.jpg" "${ARGON_IMG}/bg1.jpg"
            echo "  ✓ 背景图已替换"
        }
        [ -d "${GITHUB_WORKSPACE}/argon/fonts" ] && [ -d "${ARGON_FONTS}" ] && {
            rm -f "${ARGON_FONTS}/TypoGraphica"*
            cp -f "${GITHUB_WORKSPACE}/argon/fonts/"* "${ARGON_FONTS}/"
            echo "  ✓ 字体已替换"
        }
    fi

    if [ -f "${ARGON_CSS}" ]; then
        echo ">>> 修改 Argon CSS..."

        if ! grep -q "@keyframes shine" "${ARGON_CSS}"; then
            sed -i '/@keyframes anim-fade-in/i\
@keyframes shine {\
  0% { background-position: -200% center; }\
  100% { background-position: 200% center; }\
}\
' "${ARGON_CSS}"
            echo "  ✓ shine 关键帧已注入"
        fi

        sed -i '/\.main-left \.sidenav-header \.brand {/,/}/c\
.main-left .sidenav-header .brand {\
  display: block; margin: 0; font-size: 1.8rem;\
  font-family: "TypoGraphica"; text-decoration: none;\
  text-align: center; cursor: default;\
  background: linear-gradient(120deg,#00fff7,#007cf0,#ff4ecd,#00fff7);\
  background-size: 300% 300%; -webkit-background-clip: text;\
  -webkit-text-fill-color: transparent;\
  animation: shine 5s linear infinite;\
}' "${ARGON_CSS}"

        sed -i '/\.brand {/,/}/ s/margin: 50px auto 100px 50px;/margin: 50px auto 100px auto;/' \
            "${ARGON_CSS}"

        sed -i '/^\.login-page \.login-container \.login-form \.brand \.icon {/,/^}/d' \
            "${ARGON_CSS}"

        sed -i '/\.login-page \.login-container \.login-form \.brand \.brand-text {/,/}/c\
.login-page .login-container .login-form .brand .brand-text {\
  margin-right: 0px; font-size: 2.6rem; font-weight: 400;\
  font-family: "TypoGraphica", sans-serif; word-break: break-word;\
  background: linear-gradient(120deg,#00fff7,#007cf0,#ff4ecd,#00fff7);\
  background-size: 300% 300%; -webkit-background-clip: text;\
  -webkit-text-fill-color: transparent;\
  animation: shine 5s linear infinite;\
}' "${ARGON_CSS}"

        sed -i '/\.login-page \.login-container \.login-form \.cbi-button-apply {/,/}/c\
.login-page .login-container .login-form .cbi-button-apply {\
  width: 100% !important; min-height: 45px; margin: 30px 0 100px;\
  padding: 10px 0; font-size: 15px; font-weight: 600;\
  text-align: center; letter-spacing: .35rem;\
  background: rgba(0,0,0,0); backdrop-filter: blur(8px);\
  border: none; border-radius: 9999px; outline: none;\
  cursor: pointer; transition: all 0.25s ease; position: relative;\
}' "${ARGON_CSS}"

        sed -i '/\.login-page \.login-container \.login-form \.cbi-button-apply:hover {/,/}/c\
.login-page .login-container .login-form .cbi-button-apply:hover {\
  box-shadow: 0 0 0 2px rgba(255,255,255,0.5);\
}' "${ARGON_CSS}"

        sed -i '/a:active {/,/}/ s/var(--primary)/#dddddd/g' "${ARGON_CSS}"
        echo "  ✓ CSS 修改完成"
    fi

    FOOTER_LOGIN="${ARGON_BASE}/ucode/template/themes/argon/footer_login.ut"
    [ -f "${FOOTER_LOGIN}" ] && {
        sed -i '/<footer/,/<\/footer>/ { /<a class="luci-link"/d }' "${FOOTER_LOGIN}"
        echo "  ✓ Footer 链接已删除"
    }

    SYSAUTH="${ARGON_BASE}/ucode/template/themes/argon/sysauth.ut"
    [ -f "${SYSAUTH}" ] && {
        sed -i 's#<img src="{{ media }}/img/argon.svg" class="icon">##g' "${SYSAUTH}"
        echo "  ✓ SVG 图标已删除"
    }
fi

echo ""
echo "✓ [Part3] 完成"
