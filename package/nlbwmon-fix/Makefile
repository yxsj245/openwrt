include $(TOPDIR)/rules.mk

PKG_NAME:=nlbwmon-fix
PKG_RELEASE:=1
PKG_MAINTAINER:=Custom

include $(INCLUDE_DIR)/package.mk

define Package/nlbwmon-fix
  SECTION:=net
  CATEGORY:=Network
  DEPENDS:=+nlbwmon
  TITLE:=Fix nlbwmon conntrack event conflict with nft_fullcone
  PKGARCH:=all
endef

define Package/nlbwmon-fix/description
  Replaces the nlbwmon init script with a version that reloads
  nf_conntrack_netlink before starting nlbwmon. This works around
  a conflict where nft_fullcone registers a conntrack event notifier
  callback that prevents nf_conntrack_netlink from delivering events,
  causing nlbwmon to receive no traffic data.
endef

define Build/Compile
endef

define Package/nlbwmon-fix/install
	$(INSTALL_DIR) $(1)/usr/share/nlbwmon-fix
	$(INSTALL_BIN) ./files/nlbwmon.init $(1)/usr/share/nlbwmon-fix/nlbwmon.init
endef

define Package/nlbwmon-fix/postinst
#!/bin/sh
[ -f "$${IPKG_INSTROOT}/usr/share/nlbwmon-fix/nlbwmon.init" ] && cp "$${IPKG_INSTROOT}/usr/share/nlbwmon-fix/nlbwmon.init" "$${IPKG_INSTROOT}/etc/init.d/nlbwmon" && chmod +x "$${IPKG_INSTROOT}/etc/init.d/nlbwmon"
endef

$(eval $(call BuildPackage,nlbwmon-fix))
