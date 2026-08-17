include $(TOPDIR)/rules.mk

PKG_NAME:=docker-persistence-migrate
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKG_LICENSE:=MIT
PKG_MAINTAINER:=OpenWrt Developer
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/docker-persistence-migrate
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Docker data partition migration helper
  DEPENDS:=+docker-persistence +rsync +tune2fs
endef

define Package/docker-persistence-migrate/description
  Provide the one-time guarded migration utility for moving existing Docker
  data to a labeled ext4 partition.
endef

define Build/Compile
	true
endef

define Package/docker-persistence-migrate/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/usr/sbin/migrate-docker-data $(1)/usr/sbin/migrate-docker-data
endef

$(eval $(call BuildPackage,docker-persistence-migrate))
