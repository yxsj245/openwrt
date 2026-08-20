include $(TOPDIR)/rules.mk

PKG_NAME:=banip-authority
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKG_LICENSE:=MIT
PKG_MAINTAINER:=OpenWrt Developer

include $(INCLUDE_DIR)/package.mk

define Package/banip-authority
	SECTION:=net
	CATEGORY:=Network
	TITLE:=Authoritative banIP enforcement for routed and proxied traffic
	DEPENDS:=+banip +nftables +ruby +ruby-ipaddr +ruby-json +ruby-yaml
endef

define Package/banip-authority/description
 Enforces banIP before transparent proxy routing, on router-originated traffic,
 and inside OpenClash through a generated highest-priority rule provider.
endef

define Package/banip-authority/conffiles
/etc/config/banip_authority
endef

define Build/Compile
endef

define Package/banip-authority/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/banip-authority.config $(1)/etc/config/banip_authority
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/banip-authority.init $(1)/etc/init.d/banip-authority
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/98-banip-authority $(1)/etc/uci-defaults/98-banip-authority
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/banip-authority.sh $(1)/usr/sbin/banip-authority
	$(INSTALL_DIR) $(1)/usr/libexec
	$(INSTALL_BIN) ./files/banip-authority-provider.rb $(1)/usr/libexec/banip-authority-provider
	$(INSTALL_BIN) ./files/banip-authority-openclash-overwrite.sh $(1)/usr/libexec/banip-authority-openclash-overwrite
endef

$(eval $(call BuildPackage,banip-authority))
