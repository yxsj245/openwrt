include $(TOPDIR)/rules.mk

PKG_NAME:=docker-persistence
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKG_LICENSE:=MIT
PKG_MAINTAINER:=OpenWrt Developer
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/docker-persistence
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Docker data partition persistence helper
  DEPENDS:=+block-mount
endef

define Package/docker-persistence/description
  Configure a labeled ext4 partition as the Docker data root during boot.
endef

define Build/Compile
	true
endef

define Package/docker-persistence/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/90-docker-persistence $(1)/etc/uci-defaults/90-docker-persistence
endef

$(eval $(call BuildPackage,docker-persistence))
