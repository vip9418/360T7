#!/bin/bash
# diy-part3.sh
# ⚠️ 执行时机：feeds install 之后
# ✅ 职责：系统配置修改、WiFi 默认参数、Argon 主题美化

set -e

echo "========================================="
echo "[Part3] 自定义系统配置 & 主题美化"
echo "========================================="

# =============================================
# 1. 系统基础配置
# =============================================
echo ""
echo ">>> 修改默认 LAN IP ..."
sed -i 's/192\.168\.6\.1/192.168.2.1/' \
    ./package/base-files/files/bin/config_generate
echo "  ✓ LAN IP → 192.168.2.1"

# =============================================
# 2. WiFi 默认参数（针对 MTK mtwifi-cfg）
# =============================================
MTWIFI_SH="./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh"

if [ ! -f "$MTWIFI_SH" ]; then
    echo "  ⚠ WARNING: mtwifi.sh 未找到，跳过 WiFi 配置"
else
    echo ""
    echo ">>> 修改 WiFi 默认参数..."

    # SSID
    sed -i 's/ImmortalWrt-2\.4G/cmcc/' "$MTWIFI_SH"
    sed -i 's/ImmortalWrt-5G/cmcc_5G/' "$MTWIFI_SH"
    echo "  ✓ SSID: cmcc / cmcc_5G"

    # ✅ Bug修复：原 s/36/auto/ 过于宽泛，会误替换文件中所有数字36
    #    改为精确匹配 channel=36 格式，避免误伤其他配置项
    sed -i 's/\bchannel\b\s*=\s*36\b/channel=auto/g' "$MTWIFI_SH"
    sed -i 's/\bChannel\b\s*=\s*36\b/Channel=auto/g' "$MTWIFI_SH"
    echo "  ✓ 信道 → auto"

    # 加密方式
    sed -i 's/encryption=none/encryption=sae-mixed/' "$MTWIFI_SH"
    echo "  ✓ 加密 → sae-mixed"

    # 密码（仅在 encryption=sae-mixed 行后插入，避免重复插入）
    if ! grep -q 'key=12345678' "$MTWIFI_SH"; then
        sed -i '/encryption=sae-mixed/a \    set wireless.default_${dev}.key=12345678' \
            "$MTWIFI_SH"
        echo "  ✓ WiFi 密码 → 12345678"
    else
        echo "  - WiFi 密码已存在，跳过"
    fi
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
    echo "  ⚠ WARNING: luci-theme-argon 未找到，跳过主题美化"
    echo "    预期路径: ${ARGON_BASE}"
else
    echo "  ✓ Argon 主题目录已找到"

    # --- 3.1 自定义背景图 & 字体（来自仓库 argon/ 目录）---
    if [ -d "${GITHUB_WORKSPACE}/argon" ]; then
        echo ""
        echo ">>> 复制自定义资源..."

        if [ -f "${GITHUB_WORKSPACE}/argon/bg1.jpg" ]; then
            cp -f "${GITHUB_WORKSPACE}/argon/bg1.jpg" "${ARGON_IMG}/bg1.jpg"
            echo "  ✓ 背景图 bg1.jpg 已替换"
        fi

        if [ -d "${GITHUB_WORKSPACE}/argon/fonts" ] && \
           [ -d "${ARGON_FONTS}" ]; then
            rm -f "${ARGON_FONTS}/TypoGraphica"*
            cp -f "${GITHUB_WORKSPACE}/argon/fonts/"* "${ARGON_FONTS}/"
            echo "  ✓ 自定义字体已替换"
        fi
    else
        echo "  - 无自定义资源目录 (argon/)，跳过资源替换"
    fi

    # ✅ 所有 CSS 修改前先检查文件是否存在
    if [ ! -f "${ARGON_CSS}" ]; then
        echo "  ⚠ WARNING: cascade.css 未找到，跳过 CSS 修改"
        echo "    预期路径: ${ARGON_CSS}"
    else
        echo ""
        echo ">>> 修改 Argon CSS..."

        # --- 3.2 注入 shine 动画关键帧（幂等：先检查是否已存在）---
        if ! grep -q "@keyframes shine" "${ARGON_CSS}"; then
            sed -i '/@keyframes anim-fade-in/i\
@keyframes shine {\
  0% { background-position: -200% center; }\
  100% { background-position: 200% center; }\
}\
' "${ARGON_CSS}"
            echo "  ✓ shine 动画关键帧已注入"
        else
            echo "  - shine 动画已存在，跳过"
        fi

        # --- 3.3 侧边栏 Brand 渐变文字样式 ---
        sed -i '/\.main-left \.sidenav-header \.brand {/,/}/c\
.main-left .sidenav-header .brand {\
  display: block;\
  margin: 0;\
  font-size: 1.8rem;\
  font-family: "TypoGraphica";\
  text-decoration: none;\
  text-align: center;\
  cursor: default;\
  background: linear-gradient(\
    120deg,\
    #00fff7,\
    #007cf0,\
    #ff4ecd,\
    #00fff7\
    );\
  background-size: 300% 300%;\
  -webkit-background-clip: text;\
  -webkit-text-fill-color: transparent;\
  animation: shine 5s linear infinite;\
}' "${ARGON_CSS}"
        echo "  ✓ 侧边栏 Brand 渐变样式已应用"

        # --- 3.4 Brand margin 居中 ---
        sed -i '/\.brand {/,/}/ s/margin: 50px auto 100px 50px;/margin: 50px auto 100px auto;/' \
            "${ARGON_CSS}"
        echo "  ✓ Brand margin 居中"

        # --- 3.5 删除登录页图标 ---
        sed -i '/^\.login-page \.login-container \.login-form \.brand \.icon {/,/^}/d' \
            "${ARGON_CSS}"
        echo "  ✓ 登录页图标样式已删除"

        # --- 3.6 登录页 Brand 文字渐变样式 ---
        sed -i '/\.login-page \.login-container \.login-form \.brand \.brand-text {/,/}/c\
.login-page .login-container .login-form .brand .brand-text {\
  margin-right: 0px;\
  font-size: 2.6rem;\
  font-weight: 400;\
  font-family: "TypoGraphica", sans-serif;\
  word-break: break-word;\
  background: linear-gradient(\
    120deg,\
    #00fff7,\
    #007cf0,\
    #ff4ecd,\
    #00fff7\
  );\
  background-size: 300% 300%;\
  -webkit-background-clip: text;\
  -webkit-text-fill-color: transparent;\
  animation: shine 5s linear infinite;\
}' "${ARGON_CSS}"
        echo "  ✓ 登录页 Brand 文字渐变样式已应用"

        # --- 3.7 登录按钮样式 ---
        sed -i '/\.login-page \.login-container \.login-form \.cbi-button-apply {/,/}/c\
.login-page .login-container .login-form .cbi-button-apply {\
  width: 100% !important;\
  min-height: 45px;\
  margin: 30px 0 100px;\
  padding: 10px 0;\
  font-size: 15px;\
  font-weight: 600;\
  text-align: center;\
  letter-spacing: .35rem;\
  background: rgba(0, 0, 0, 0);\
  backdrop-filter: blur(8px);\
  border: none;\
  border-radius: 9999px;\
  outline: none;\
  cursor: pointer;\
  transition: all 0.25s ease;\
  position: relative;\
}' "${ARGON_CSS}"
        echo "  ✓ 登录按钮样式已应用"

        # --- 3.8 登录按钮 Hover 样式 ---
        sed -i '/\.login-page \.login-container \.login-form \.cbi-button-apply:hover {/,/}/c\
.login-page .login-container .login-form .cbi-button-apply:hover {\
  box-shadow: 0 0 0 2px rgba(255, 255, 255, 0.5);\
}' "${ARGON_CSS}"
        echo "  ✓ 登录按钮 Hover 样式已应用"

        # --- 3.9 链接激活颜色 ---
        sed -i '/a:active {/,/}/ s/var(--primary)/#dddddd/g' "${ARGON_CSS}"
        echo "  ✓ 链接激活颜色已修改"

        echo "  ✓ CSS 修改全部完成"
    fi

    # --- 3.10 删除登录页 Footer 链接 ---
    FOOTER_LOGIN="${ARGON_BASE}/ucode/template/themes/argon/footer_login.ut"
    if [ -f "${FOOTER_LOGIN}" ]; then
        sed -i '/<footer/,/<\/footer>/ { /<a class="luci-link"/d }' \
            "${FOOTER_LOGIN}"
        echo "  ✓ 登录页 Footer 链接已删除"
    else
        echo "  - footer_login.ut 未找到，跳过"
    fi

    # --- 3.11 删除登录页 Logo 图标 ---
    SYSAUTH="${ARGON_BASE}/ucode/template/themes/argon/sysauth.ut"
    if [ -f "${SYSAUTH}" ]; then
        sed -i 's#<img src="{{ media }}/img/argon.svg" class="icon">##g' \
            "${SYSAUTH}"
        echo "  ✓ 登录页 SVG 图标已删除"
    else
        echo "  - sysauth.ut 未找到，跳过"
    fi

fi  # end ARGON_BASE check

echo ""
echo "✓ [Part3] 所有自定义配置已完成"
