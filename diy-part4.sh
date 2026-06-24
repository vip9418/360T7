#!/bin/bash
#
# File name: diy-part4.sh
# Description: OpenWrt DIY script part 4 (After feeds install)
# Executed after: ./scripts/feeds install -a
#

set -e

echo "=========================================="
echo "  DIY Part 4: Post-feeds customization"
echo "=========================================="

# -----------------------------------------------
# 【Step 1】网络基础 & WiFi 配置 (保持原始逻辑)
# -----------------------------------------------
echo ""
echo "=== Step 1: Network & WiFi configuration ==="

sed -i 's/192.168.6.1/192.168.2.1/' \
    ./package/base-files/files/bin/config_generate

sed -i 's/ImmortalWrt-2.4G/cmcc/' \
    ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i 's/ImmortalWrt-5G/cmcc_5G/' \
    ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i 's/36/auto/' \
    ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i 's/encryption=none/encryption=sae-mixed/' \
    ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i '/encryption=sae-mixed/a \ \ \ \ set wireless.default_${dev}.key=12345678' \
    ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh

echo "✓ Network & WiFi configured"

# -----------------------------------------------
# 【Step 2】Argon 主题定制
# 主题本体已在 diy-part1.sh 通过 sbwml 版本集成
# -----------------------------------------------
echo ""
echo "=== Step 2: Argon theme customization ==="

ARGON_BASE="./feeds/luci/themes/luci-theme-argon"
ARGON_CSS="${ARGON_BASE}/htdocs/luci-static/argon/css/cascade.css"
ARGON_FONTS="${ARGON_BASE}/htdocs/luci-static/argon/fonts"

# 检查 argon 主题是否存在
if [ ! -d "${ARGON_BASE}" ]; then
    echo "❌ ERROR: luci-theme-argon not found at ${ARGON_BASE}"
    exit 1
fi

# 检查自定义资源目录
if [ ! -d "${GITHUB_WORKSPACE}/argon" ]; then
    echo "⚠ WARNING: argon resource directory not found, skip asset replacement"
else
    # 替换背景图
    if [ -f "${GITHUB_WORKSPACE}/argon/bg1.jpg" ]; then
        cp -f "${GITHUB_WORKSPACE}/argon/bg1.jpg" \
            "${ARGON_BASE}/htdocs/luci-static/argon/img/bg1.jpg"
        echo "✓ Background image replaced"
    fi

    # 替换字体
    if [ -d "${GITHUB_WORKSPACE}/argon/fonts" ]; then
        rm -f "${ARGON_FONTS}/TypoGraphica"*
        cp -f "${GITHUB_WORKSPACE}/argon/fonts/"* "${ARGON_FONTS}/"
        echo "✓ Fonts replaced"
    fi
fi

# -----------------------------------------------
# CSS 深度定制
# -----------------------------------------------
echo "  Applying CSS customizations..."

# 1. 注入 shine 渐变动画 keyframes
sed -i '/@keyframes anim-fade-in/i\
@keyframes shine {\
  0% { background-position: -200% center; }\
  100% { background-position: 200% center; }\
}\
' "${ARGON_CSS}"

# 2. 主页导航品牌文字流光渐变
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

# 3. 登录页品牌标识居中
sed -i '/\.brand {/,/}/ s/margin: 50px auto 100px 50px;/margin: 50px auto 100px auto;/' \
    "${ARGON_CSS}"

# 4. 删除登录页品牌 icon
sed -i '/^\.login-page \.login-container \.login-form \.brand \.icon {/,/^}/d' \
    "${ARGON_CSS}"

# 5. 登录页品牌文字流光渐变
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

# 6. 登录页按钮毛玻璃效果 (精确限定登录页范围)
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

# 7. 登录页按钮 hover 效果
sed -i '/\.login-page \.login-container \.login-form \.cbi-button-apply:hover {/,/}/c\
.login-page .login-container .login-form .cbi-button-apply:hover {\
  box-shadow: 0 0 0 2px rgba(255, 255, 255, 0.5);\
}' "${ARGON_CSS}"

# 8. 底部链接颜色
sed -i '/a:active {/,/}/ s/var(--primary)/#dddddd/g' "${ARGON_CSS}"

# 9. 移除页脚 LuCI 链接
FOOTER_LOGIN="${ARGON_BASE}/ucode/template/themes/argon/footer_login.ut"
if [ -f "${FOOTER_LOGIN}" ]; then
    sed -i '/<footer/,/<\/footer>/ { /<a class="luci-link"/d }' "${FOOTER_LOGIN}"
    echo "✓ Footer LuCI link removed"
fi

# 10. 移除 argon SVG 图标
SYSAUTH="${ARGON_BASE}/ucode/template/themes/argon/sysauth.ut"
if [ -f "${SYSAUTH}" ]; then
    sed -i 's#<img src="{{ media }}/img/argon.svg" class="icon">##g' "${SYSAUTH}"
    echo "✓ Argon SVG icon removed"
fi

echo "✓ Argon theme customization complete"

echo ""
echo "=========================================="
echo "  DIY Part 4 Complete"
echo "=========================================="
