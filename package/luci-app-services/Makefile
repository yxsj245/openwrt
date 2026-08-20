include $(TOPDIR)/rules.mk

LUCI_TITLE:=服务管理
LUCI_DEPENDS:=+luci-base

PKG_LICENSE:=Apache-2.0
PKG_VERSION:=1.2.0
PKG_RELEASE:=3
PKG_MAINTAINER:=OpenWrt Developer

define Package/luci-app-services/postinst
#!/bin/sh
for file in \
	/www/luci-static/resources/view/system/services.js \
	/usr/share/luci/menu.d/luci-app-services.json \
	/usr/share/rpcd/acl.d/luci-app-services.json; do
	[ -e "$${IPKG_INSTROOT}$$file" ] || continue
	chown 0:0 "$${IPKG_INSTROOT}$$file" || exit 1
done
[ -n "$${IPKG_INSTROOT}" ] || /etc/init.d/rpcd restart >/dev/null 2>&1
exit 0
endef

include ../../feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
