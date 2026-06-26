#!/bin/bash
# diy-part3.sh
# 执行时机：feeds install 之后
# 适配：padavanonly/immortalwrt-mt798x-6.6 @ openwrt-24.10-6.6

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
#    "360 t7:compatiable with old uboot"
#    来源：padavanonly/immortalwrt-mt798x-6.6
#    改动：filogic.mk + mt7981b-qihoo-360t7.dts
#    目的：兼容 hanwckf U-Boot，输出 .bin 格式
# =============================================
echo ""
echo ">>> 精确复现 commit 2dd8cf9..."

FILOGIC_MK="./target/linux/mediatek/image/filogic.mk"
DTS_FILE="./target/linux/mediatek/dts/mt7981b-qihoo-360t7.dts"

# 检查文件是否存在
if [ ! -f "$FILOGIC_MK" ]; then
    echo "  ❌ ERROR: filogic.mk 未找到: $FILOGIC_MK"
    exit 1
fi
if [ ! -f "$DTS_FILE" ]; then
    echo "  ❌ ERROR: DTS 未找到: $DTS_FILE"
    exit 1
fi

# ── 3.1 修改 filogic.mk ──────────────────────────────────────
echo "  >>> 修改 filogic.mk..."

# 删除 Device/qihoo_360t7 块内的 itb 相关行
sed -i '/define Device\/qihoo_360t7/,/^endef/{
    /UBINIZE_OPTS := -E 5/d
    /KERNEL_IN_UBI := 1/d
    /UBOOTENV_IN_UBI := 1/d
    /IMAGES := sysupgrade\.itb/d
    /KERNEL_INITRAMFS_SUFFIX := -recovery\.itb/d
    /KERNEL := kernel-bin | gzip/d
    /KERNEL_INITRAMFS := kernel-bin | lzma/d
    /fit lzma.*with-initrd/d
    /IMAGE\/sysupgrade\.itb/d
    /fit gzip.*external-static-with-rootfs/d
    /DEVICE_PACKAGES := kmod-mt7915e/d
    /ARTIFACTS := preloader\.bin/d
    /ARTIFACT\/preloader\.bin/d
    /ARTIFACT\/bl31-uboot\.fip := mt7981/d
}' "$FILOGIC_MK"

# 在 TARGET_DEVICES += qihoo_360t7 行之前插入新的 IMAGE 定义
# 使用 \t 确保缩进与原文件一致
if ! grep -q "IMAGE/sysupgrade.bin := sysupgrade-tar" "$FILOGIC_MK"; then
    sed -i '/TARGET_DEVICES += qihoo_360t7/i\\tIMAGE\/sysupgrade.bin := sysupgrade-tar | append-metadata' \
        "$FILOGIC_MK"
    echo "  ✓ 新增 IMAGE/sysupgrade.bin 定义"
else
    echo "  - IMAGE/sysupgrade.bin 已存在，跳过"
fi

# 验证修改结果
if grep -q "IMAGE/sysupgrade.bin" "$FILOGIC_MK"; then
    echo "  ✓ filogic.mk 修改验证通过"
else
    echo "  ❌ filogic.mk 修改失败，请检查原文件结构"
    grep -n "qihoo_360t7" "$FILOGIC_MK" || true
    exit 1
fi

# ── 3.2 修改 DTS ─────────────────────────────────────────────
echo "  >>> 修改 DTS 文件..."

# 删除 fit0 rootfs 挂载相关行
sed -i '/bootargs-append = " root=\/dev\/fit0 rootwait";/d' "$DTS_FILE"
echo "  ✓ 删除 bootargs-append fit0"

sed -i '/rootdisk = <&ubi_rootdisk>;/d' "$DTS_FILE"
echo "  ✓ 删除 rootdisk"

sed -i '/compatible = "linux,ubi";/d' "$DTS_FILE"
echo "  ✓ 删除 compatible linux,ubi"

# 删除 volumes 块（多行）
sed -i '/volumes {/{
    :loop
    /};/!{
        N
        b loop
    }
    /ubi_rootdisk/d
    d
}' "$DTS_FILE"
echo "  ✓ 删除 volumes/ubi_rootdisk 块"

# 新增 mediatek,nmbm 相关配置（在 spi-rx-bus-width = <4> 之后）
if ! grep -q "mediatek,nmbm" "$DTS_FILE"; then
    sed -i '/spi-rx-bus-width = <4>;/a \\t\t\t\tmediatek,nmbm;\n\t\t\t\t\tmediatek,bmt-max-ratio = <1>;\n\t\t\t\t\tmediatek,bmt-max-reserved-blocks = <64>;' \
        "$DTS_FILE"
    echo "  ✓ 新增 mediatek,nmbm 配置"
else
    echo "  - mediatek,nmbm 已存在，跳过"
fi

echo "  ✓ commit 2dd8cf9 精确复现完成"
echo "  ✓ 固件将输出：qihoo_360t7-squashfs-sysupgrade.bin"

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
    echo "    请确认 config 中已启用 CONFIG_PACKAGE_luci-theme-argon=y"
else
    echo "  ✓ Argon 主题目录已找到"

    # 4.1 背景图 & 字体
    if [ -d "${GITHUB_WORKSPACE}/argon" ]; then
        echo ">>> 复制自定义资源..."
        [ -f "${GITHUB_WORKSPACE}/argon/bg1.jpg" ] && {
            cp -f "${GITHUB_WORKSPACE}/argon/bg1.jpg" "${ARGON_IMG}/bg1.jpg"
            echo "  ✓ 背景图已替换"
        }
        [ -d "${GITHUB_WORKSPACE}/argon/fonts" ] && [ -d "${ARGON_FONTS}" ] && {
            rm -f "${ARGON_FONTS}/TypoGraphica"*
            cp -f "${GITHUB_WORKSPACE}/argon/fonts/"* "${ARGON_FONTS}/"
            echo "  ✓ 字体已替换"
        }
    else
        echo "  - 无自定义资源目录，跳过"
    fi

    # 4.2 CSS 修改
    if [ ! -f "${ARGON_CSS}" ]; then
        echo "  ⚠ cascade.css 未找到，跳过 CSS 修改"
    else
        echo ">>> 修改 Argon CSS..."

        # shine 动画关键帧（幂等）
        if ! grep -q "@keyframes shine" "${ARGON_CSS}"; then
            sed -i '/@keyframes anim-fade-in/i\
@keyframes shine {\
  0% { background-position: -200% center; }\
  100% { background-position: 200% center; }\
}\
' "${ARGON_CSS}"
            echo "  ✓ shine 关键帧已注入"
        fi

        # 侧边栏 Brand 渐变
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
        echo "  ✓ 侧边栏 Brand 渐变"

        # Brand margin 居中
        sed -i '/\.brand {/,/}/ s/margin: 50px auto 100px 50px;/margin: 50px auto 100px auto;/' \
            "${ARGON_CSS}"
        echo "  ✓ Brand margin 居中"

        # 删除登录页图标样式
        sed -i '/^\.login-page \.login-container \.login-form \.brand \.icon {/,/^}/d' \
            "${ARGON_CSS}"
        echo "  ✓ 登录页图标样式已删除"

        # 登录页 Brand 文字渐变
        sed -i '/\.login-page \.login-container \.login-form \.brand \.brand-text {/,/}/c\
.login-page .login-container .login-form .brand .brand-text {\
  margin-right: 0px; font-size: 2.6rem; font-weight: 400;\
  font-family: "TypoGraphica", sans-serif; word-break: break-word;\
  background: linear-gradient(120deg,#00fff7,#007cf0,#ff4ecd,#00fff7);\
  background-size: 300% 300%; -webkit-background-clip: text;\
  -webkit-text-fill-color: transparent;\
  animation: shine 5s linear infinite;\
}' "${ARGON_CSS}"
        echo "  ✓ 登录页 Brand 文字渐变"

        # 登录按钮样式
        sed -i '/\.login-page \.login-container \.login-form \.cbi-button-apply {/,/}/c\
.login-page .login-container .login-form .cbi-button-apply {\
  width: 100% !important; min-height: 45px; margin: 30px 0 100px;\
  padding: 10px 0; font-size: 15px; font-weight: 600;\
  text-align: center; letter-spacing: .35rem;\
  background: rgba(0,0,0,0); backdrop-filter: blur(8px);\
  border: none; border-radius: 9999px; outline: none;\
  cursor: pointer; transition: all 0.25s ease; position: relative;\
}' "${ARGON_CSS}"
        echo "  ✓ 登录按钮样式"

        # 登录按钮 Hover
        sed -i '/\.login-page \.login-container \.login-form \.cbi-button-apply:hover {/,/}/c\
.login-page .login-container .login-form .cbi-button-apply:hover {\
  box-shadow: 0 0 0 2px rgba(255,255,255,0.5);\
}' "${ARGON_CSS}"
        echo "  ✓ 登录按钮 Hover 样式"

        # 链接激活颜色
        sed -i '/a:active {/,/}/ s/var(--primary)/#dddddd/g' "${ARGON_CSS}"
        echo "  ✓ 链接激活颜色"

        echo "  ✓ CSS 修改全部完成"
    fi

    # 4.3 Footer 链接
    FOOTER_LOGIN="${ARGON_BASE}/ucode/template/themes/argon/footer_login.ut"
    [ -f "${FOOTER_LOGIN}" ] && {
        sed -i '/<footer/,/<\/footer>/ { /<a class="luci-link"/d }' "${FOOTER_LOGIN}"
        echo "  ✓ Footer 链接已删除"
    }

    # 4.4 SVG Logo
    SYSAUTH="${ARGON_BASE}/ucode/template/themes/argon/sysauth.ut"
    [ -f "${SYSAUTH}" ] && {
        sed -i 's#<img src="{{ media }}/img/argon.svg" class="icon">##g' "${SYSAUTH}"
        echo "  ✓ SVG 图标已删除"
    }
fi

echo ""
echo "✓ [Part3] 全部完成"
