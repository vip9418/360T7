#!/bin/bash
# diy-part3.sh
# 执行时机：feeds install 之后

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
# 2. WiFi 默认参数（mtwifi.sh 方式）
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
# 3. Argon 主题美化
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
        echo "  ✓ 侧边栏 Brand 渐变"

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
