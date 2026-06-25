#!/bin/bash
# diy-part3.sh

set -e

echo "========================================="
echo "[Part3] 自定义系统配置 & 主题美化"
echo "========================================="

# =============================================
# 1. 修改默认 LAN IP
#    config_generate 是 immortalwrt/openwrt 通用路径
#    VIKINGYFY owrt 完全适用
# =============================================
echo ""
echo ">>> 修改默认 LAN IP ..."

CONFIG_GEN="./package/base-files/files/bin/config_generate"

if [ ! -f "${CONFIG_GEN}" ]; then
    echo "  ⚠ WARNING: config_generate 未找到"
    echo "    预期路径: ${CONFIG_GEN}"
else
    sed -i 's/192\.168\.6\.1/192.168.2.1/' "${CONFIG_GEN}"
    echo "  ✓ LAN IP → 192.168.2.1"
fi

# =============================================
# 2. WiFi 默认参数（uci-defaults 方式）
#
#    VIKINGYFY owrt 分支适配说明：
#    ─────────────────────────────
#    此分支基于 immortalwrt upstream，使用 mt76（mac80211）
#    驱动。360T7 硬件：
#      radio0 = MT7976C 2.4GHz（band=2g）
#      radio1 = MT7976C 5GHz  （band=5g）
#
#    uci-defaults 脚本在首次开机时由 /etc/init.d/boot
#    自动调用，执行成功（exit 0）后脚本自动删除。
#    此方式对标准 immortalwrt 100% 兼容。
# =============================================
echo ""
echo ">>> 写入 WiFi 默认配置（uci-defaults）..."

UCI_DIR="./package/base-files/files/etc/uci-defaults"
mkdir -p "${UCI_DIR}"

# 使用 UCI batch 模式写入，更稳定可靠
cat > "${UCI_DIR}/99-wireless-defaults" << 'WIFI_EOF'
#!/bin/sh
# 99-wireless-defaults
# 适配：VIKINGYFY/immortalwrt owrt 分支（标准 mac80211 / mt76）
# 设备：360T7（MT7981B + MT7976C）
# 执行：首次开机自动运行，exit 0 后自动删除

# ── 等待 wireless UCI 初始化完成 ──────────────────
# 某些平台首次启动时 wireless config 生成较慢
local retries=0
while [ ! -f /etc/config/wireless ] && [ $retries -lt 10 ]; do
    sleep 1
    retries=$((retries + 1))
done

[ -f /etc/config/wireless ] || {
    echo "99-wireless-defaults: /etc/config/wireless not found, skip"
    exit 1
}

# ── 2.4GHz（radio0）────────────────────────────────
uci -q batch << 'UCI'
set wireless.radio0.disabled=0
set wireless.default_radio0.ssid=cmcc
set wireless.default_radio0.encryption=sae-mixed
set wireless.default_radio0.key=12345678
UCI

# ── 5GHz（radio1）──────────────────────────────────
uci -q batch << 'UCI'
set wireless.radio1.disabled=0
set wireless.default_radio1.ssid=cmcc_5G
set wireless.default_radio1.encryption=sae-mixed
set wireless.default_radio1.key=12345678
UCI

uci commit wireless

echo "99-wireless-defaults: WiFi 默认配置已写入"
exit 0
WIFI_EOF

chmod +x "${UCI_DIR}/99-wireless-defaults"

echo "  ✓ WiFi uci-defaults 脚本已写入"
echo "    路径 : ${UCI_DIR}/99-wireless-defaults"
echo "    2.4G : SSID=cmcc  加密=sae-mixed  密码=12345678"
echo "    5G   : SSID=cmcc_5G  加密=sae-mixed  密码=12345678"
echo "    时机 : 路由器首次开机自动执行，执行后自动删除"

# =============================================
# 3. Argon 主题美化
#    VIKINGYFY owrt 使用 immortalwrt/luci，
#    luci-theme-argon 路径与标准 immortalwrt 完全一致
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
    echo "    请确认 .config 中已启用 luci-theme-argon"
else
    echo "  ✓ Argon 主题目录已找到"

    # --- 3.1 替换背景图 & 字体 ---
    if [ -d "${GITHUB_WORKSPACE}/argon" ]; then
        echo ""
        echo ">>> 复制自定义资源..."

        if [ -f "${GITHUB_WORKSPACE}/argon/bg1.jpg" ]; then
            cp -f "${GITHUB_WORKSPACE}/argon/bg1.jpg" \
                "${ARGON_IMG}/bg1.jpg"
            echo "  ✓ 背景图 bg1.jpg 已替换"
        else
            echo "  - argon/bg1.jpg 不存在，跳过"
        fi

        if [ -d "${GITHUB_WORKSPACE}/argon/fonts" ] && \
           [ -d "${ARGON_FONTS}" ]; then
            rm -f "${ARGON_FONTS}/TypoGraphica"*
            cp -f "${GITHUB_WORKSPACE}/argon/fonts/"* \
                "${ARGON_FONTS}/"
            echo "  ✓ 自定义字体已替换"
        else
            echo "  - argon/fonts 目录不存在或字体目录缺失，跳过"
        fi
    else
        echo "  - 无自定义资源目录 (argon/)，跳过资源替换"
    fi

    # --- CSS 修改前验证文件存在 ---
    if [ ! -f "${ARGON_CSS}" ]; then
        echo "  ⚠ WARNING: cascade.css 未找到，跳过 CSS 修改"
        echo "    预期路径: ${ARGON_CSS}"
    else
        echo ""
        echo ">>> 修改 Argon CSS..."

        # --- 3.2 注入 shine 动画关键帧（幂等）---
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

        # --- 3.5 删除登录页图标样式块 ---
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
        sed -i '/a:active {/,/}/ s/var(--primary)/#dddddd/g' \
            "${ARGON_CSS}"
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

    # --- 3.11 删除登录页 SVG Logo ---
    SYSAUTH="${ARGON_BASE}/ucode/template/themes/argon/sysauth.ut"
    if [ -f "${SYSAUTH}" ]; then
        sed -i 's#<img src="{{ media }}/img/argon.svg" class="icon">##g' \
            "${SYSAUTH}"
        echo "  ✓ 登录页 SVG 图标已删除"
    else
        echo "  - sysauth.ut 未找到，跳过"
    fi

fi

echo ""
echo "✓ [Part3] 所有自定义配置已完成"
