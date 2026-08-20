include $(TOPDIR)/rules.mk

LUCI_TITLE:=服务管理
LUCI_DEPENDS:=+luci-base

PKG_LICENSE:=Apache-2.0
PKG_VERSION:=1.2.0
PKG_RELEASE:=4
PKG_MAINTAINER:=OpenWrt Developer

define Package/luci-app-services/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
for file in \
	/www/luci-static/resources/view/system/services.js \
	/usr/share/luci/menu.d/luci-app-services.json \
	/usr/share/rpcd/acl.d/luci-app-services.json; do
	[ -e "$$file" ] || continue
	chown 0:0 "$$file" || exit 1
done
/etc/init.d/rpcd restart >/dev/null 2>&1
exit 0
endef

include ../../feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
