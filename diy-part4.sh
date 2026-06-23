#!/bin/bash
sed -i 's/192.168.6.1/192.168.2.1/' ./package/base-files/files/bin/config_generate
sed -i 's/ImmortalWrt-2.4G/NW/' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i 's/ImmortalWrt-5G/NW/' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i 's/36/auto/' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i 's/encryption=none/encryption=sae-mixed/' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i '/encryption=sae-mixed/a \ \ \ \ set wireless.default_${dev}.key=12345678' ./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh

rm -rf ./feeds/packages/lang/golang && git clone --depth 1 https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang

# argon主题
### rm -rf ./feeds/luci/themes/luci-theme-argon && git clone --depth 1 https://github.com/immortalwrt/luci tmp_luci && \cp -rf tmp_luci/themes/luci-theme-argon/ feeds/luci/themes/luci-theme-argon/ && rm -rf tmp_luci
# 替换默认背景
\cp -f $GITHUB_WORKSPACE/argon/bg1.jpg ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg
# 替换字体
rm -f ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/fonts/TypoGraphica*
\cp -f $GITHUB_WORKSPACE/argon/fonts/* ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/fonts
# 修改界面
# 多彩效果
sed -i '/@keyframes anim-fade-in/i\
@keyframes shine {\
  0% { background-position: -200% center; }\
  100% { background-position: 200% center; }\
}\
' ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css
# 主页标识
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
}' ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css
# 登录页标识居中
sed -i '/\.brand {/,/}/ s/margin: 50px auto 100px 50px;/margin: 50px auto 100px auto;/' ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css
# 删除图标
sed -i '/^\.login-page \.login-container \.login-form \.brand \.icon {/,/^}/d' ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css
# 登录页标识
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
}' ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css
# 登录页按钮
sed -i '/\.cbi-button-apply {/,/}/c\
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
}' ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css

sed -i '/\.cbi-button-apply:hover/,/}/c\
.login-page .login-container .login-form .cbi-button-apply:hover {\
  box-shadow: 0 0 0 2px rgba(255, 255, 255, 0.5);\
}' ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css
# 登录页底部
sed -i '/a:active {/,/}/ s/var(--primary)/#dddddd/g' ./feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css
sed -i '/<footer/,/<\/footer>/ { /<a class="luci-link"/d }' ./feeds/luci/themes/luci-theme-argon/ucode/template/themes/argon/footer_login.ut
sed -i 's#<img src="{{ media }}/img/argon.svg" class="icon">##g' ./feeds/luci/themes/luci-theme-argon/ucode/template/themes/argon/sysauth.ut
