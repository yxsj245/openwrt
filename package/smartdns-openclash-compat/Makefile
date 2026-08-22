include $(TOPDIR)/rules.mk

PKG_NAME:=smartdns-openclash-compat
PKG_VERSION:=1.1.0
PKG_RELEASE:=2
PKG_LICENSE:=MIT
PKG_MAINTAINER:=OpenWrt Developer

include $(INCLUDE_DIR)/package.mk

define Package/smartdns-openclash-compat
	SECTION:=net
	CATEGORY:=Network
	TITLE:=SmartDNS and OpenClash compatibility coordinator
	DEPENDS:=+smartdns +luci-app-openclash
endef

define Package/smartdns-openclash-compat/description
 Coordinates the DNS chain between SmartDNS, OpenClash and dnsmasq,
 and restores the original settings when the service is stopped.
endef

define Package/smartdns-openclash-compat/conffiles
/etc/config/smartdns_openclash_compat
endef

define Build/Compile
endef

define Package/smartdns-openclash-compat/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/smartdns-openclash-compat.config $(1)/etc/config/smartdns_openclash_compat
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/smartdns-openclash-compat.init $(1)/etc/init.d/smartdns-openclash-compat
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/smartdns-openclash-compat.sh $(1)/usr/sbin/smartdns-openclash-compat
	$(INSTALL_DIR) $(1)/usr/libexec
	$(INSTALL_BIN) ./files/smartdns-openclash-compat-overwrite.sh $(1)/usr/libexec/smartdns-openclash-compat-overwrite
endef

define Package/smartdns-openclash-compat/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
for file in \
	/etc/config/smartdns_openclash_compat \
	/etc/init.d/smartdns-openclash-compat \
	/usr/sbin/smartdns-openclash-compat \
	/usr/libexec/smartdns-openclash-compat-overwrite; do
	[ -e "$$file" ] || continue
	chown 0:0 "$$file" || exit 1
done
exit 0
endef

$(eval $(call BuildPackage,smartdns-openclash-compat))
