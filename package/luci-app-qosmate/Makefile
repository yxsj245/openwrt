include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-qosmate
PKG_VERSION:=1.9.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Markus Hütter <mh@hudra.net>
PKG_LICENSE:=GPL-3.0-or-later
PKG_LICENSE_FILES:=LICENSE

LUCI_TITLE:=LuCI support for QoSmate
LUCI_DESCRIPTION:=Web interface for QoSmate traffic shaping and per-device limits
LUCI_DEPENDS:=+qosmate +luci-base +luci-lib-jsonc +lua
LUCI_PKGARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/qosmate
	$(INSTALL_DATA) ./htdocs/luci-static/resources/view/*.js \
		$(1)/www/luci-static/resources/view/qosmate/

	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./root/usr/share/luci/menu.d/luci-app-qosmate.json \
		$(1)/usr/share/luci/menu.d/luci-app-qosmate.json

	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/luci-app-qosmate.json \
		$(1)/usr/share/rpcd/acl.d/luci-app-qosmate.json

	$(INSTALL_DIR) $(1)/usr/libexec/rpcd
	$(INSTALL_BIN) ./root/usr/libexec/rpcd/luci.qosmate \
		$(1)/usr/libexec/rpcd/luci.qosmate
	$(INSTALL_BIN) ./root/usr/libexec/rpcd/luci.qosmate_stats \
		$(1)/usr/libexec/rpcd/luci.qosmate_stats

	$(INSTALL_DIR) $(1)/etc/qosmate.d
	(cd $(1) && md5sum \
		usr/share/luci/menu.d/luci-app-qosmate.json \
		usr/share/rpcd/acl.d/luci-app-qosmate.json \
		usr/libexec/rpcd/luci.qosmate \
		usr/libexec/rpcd/luci.qosmate_stats \
		www/luci-static/resources/view/qosmate/settings.js \
		www/luci-static/resources/view/qosmate/hfsc.js \
		www/luci-static/resources/view/qosmate/cake.js \
		www/luci-static/resources/view/qosmate/advanced.js \
		www/luci-static/resources/view/qosmate/rules.js \
		www/luci-static/resources/view/qosmate/ratelimits.js \
		www/luci-static/resources/view/qosmate/connections.js \
		www/luci-static/resources/view/qosmate/custom_rules.js \
		www/luci-static/resources/view/qosmate/ipsets.js \
		www/luci-static/resources/view/qosmate/statistics.js) | \
		sed 's#  #  /#' > $(1)/etc/qosmate.d/frontend_reg.md5
endef

# call BuildPackage - OpenWrt buildroot signature
