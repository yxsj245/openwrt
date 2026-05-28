include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-uugamebooster
PKG_VERSION:=1.0.0
PKG_RELEASE:=3
PKG_LICENSE:=Apache-2.0
PKG_MAINTAINER:=OpenWrt Developer

PKG_BUILD_DIR:=$(BUILD_DIR)/luci-app-uugamebooster

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-uugamebooster
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=UU Game Booster
  DEPENDS:=+luci-base +kmod-tun +iptables-nft
  PKGARCH:=all
endef

define Package/luci-app-uugamebooster/description
  NetEase UU Game Booster router plugin with LuCI web interface.
  Provides game acceleration for PS5, Xbox, Switch, PC and other devices.
  Bind the router via UU Host Accelerator mobile App.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	chmod +x ./download.sh
	./download.sh $(PKG_BUILD_DIR)
endef

define Build/Compile
	true
endef

define Package/luci-app-uugamebooster/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/uuplugin $(1)/usr/bin/uuplugin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/xtables-nft-multi $(1)/usr/bin/xtables-nft-multi

	$(INSTALL_DIR) $(1)/usr/share/uugamebooster
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/uu.conf $(1)/usr/share/uugamebooster/uu.conf

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./root/etc/config/uuplugin $(1)/etc/config/uuplugin

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./root/etc/init.d/uuplugin $(1)/etc/init.d/uuplugin

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./root/etc/uci-defaults/90-uuplugin-firewall $(1)/etc/uci-defaults/90-uuplugin-firewall

	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./root/usr/share/luci/menu.d/luci-app-uugamebooster.json $(1)/usr/share/luci/menu.d/luci-app-uugamebooster.json

	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/luci-app-uugamebooster.json $(1)/usr/share/rpcd/acl.d/luci-app-uugamebooster.json

	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/services
	$(INSTALL_DATA) ./htdocs/luci-static/resources/view/services/uugamebooster.js $(1)/www/luci-static/resources/view/services/uugamebooster.js
endef

$(eval $(call BuildPackage,luci-app-uugamebooster))
