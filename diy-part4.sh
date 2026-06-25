#!/bin/bash

set -e

sed -i 's/192.168.6.1/192.168.2.1/' ./package/base-files/files/bin/config_generate
sed -i 's/ImmortalWrt-2.4G/cmcc/' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i 's/ImmortalWrt-5G/cmcc_5G/' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i 's/36/auto/' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i 's/encryption=none/encryption=sae-mixed/' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i '/encryption=sae-mixed/a \ \ \ \ set wireless.default_${dev}.key=12345678' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh

ARGON_BASE="./feeds/luci/themes/luci-theme-argon"
ARGON_CSS="${ARGON_BASE}/htdocs/luci-static/argon/css/cascade.css"
ARGON_FONTS="${ARGON_BASE}/htdocs/luci-static/argon/fonts"

if [ ! -d "${ARGON_BASE}" ]; then
    echo "ERROR: luci-theme-argon not found at ${ARGON_BASE}"
    exit 1
fi

if [ -d "${GITHUB_WORKSPACE}/argon" ]; then
    if [ -f "${GITHUB_WORKSPACE}/argon/bg1.jpg" ]; then
        cp -f "${GITHUB_WORKSPACE}/argon/bg1.jpg" \
            "${ARGON_BASE}/htdocs/luci-static/argon/img/bg1.jpg"
    fi
    if [ -d "${GITHUB_WORKSPACE}/argon/fonts" ]; then
        rm -f "${ARGON_FONTS}/TypoGraphica"*
        cp -f "${GITHUB_WORKSPACE}/argon/fonts/"* "${ARGON_FONTS}/"
    fi
fi

sed -i '/@keyframes anim-fade-in/i\
@keyframes shine {\
  0% { background-position: -200% center; }\
  100% { background-position: 200% center; }\
}\
' "${ARGON_CSS}"

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

sed -i '/\.brand {/,/}/ s/margin: 50px auto 100px 50px;/margin: 50px auto 100px auto;/' \
    "${ARGON_CSS}"

sed -i '/^\.login-page \.login-container \.login-form \.brand \.icon {/,/^}/d' \
    "${ARGON_CSS}"

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

sed -i '/\.login-page \.login-container \.login-form \.cbi-button-apply:hover {/,/}/c\
.login-page .login-container .login-form .cbi-button-apply:hover {\
  box-shadow: 0 0 0 2px rgba(255, 255, 255, 0.5);\
}' "${ARGON_CSS}"

sed -i '/a:active {/,/}/ s/var(--primary)/#dddddd/g' "${ARGON_CSS}"

FOOTER_LOGIN="${ARGON_BASE}/ucode/template/themes/argon/footer_login.ut"
if [ -f "${FOOTER_LOGIN}" ]; then
    sed -i '/<footer/,/<\/footer>/ { /<a class="luci-link"/d }' "${FOOTER_LOGIN}"
fi

SYSAUTH="${ARGON_BASE}/ucode/template/themes/argon/sysauth.ut"
if [ -f "${SYSAUTH}" ]; then
    sed -i 's#<img src="{{ media }}/img/argon.svg" class="icon">##g' "${SYSAUTH}"
fi

# 禁用 HNAT 以兼容 DAE（eBPF 透明代理）
mkdir -p ./package/base-files/files/etc/uci-defaults
cat > ./package/base-files/files/etc/uci-defaults/99-disable-hnat << 'EOF'
#!/bin/sh
# DAE 使用 eBPF 接管流量，与 HNAT 硬件加速路径冲突，禁用 HNAT
if [ -f /etc/config/hnat ]; then
    uci set hnat.global.enable='0'
    uci commit hnat
fi
# 阻止 kmod-mtkhnat 自动加载
echo "blacklist mtkhnat" > /etc/modprobe.d/99-no-hnat.conf
exit 0
EOF
chmod +x ./package/base-files/files/etc/uci-defaults/99-disable-hnat
