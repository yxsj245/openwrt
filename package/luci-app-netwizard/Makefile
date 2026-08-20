include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-netwizard
PKG_VERSION:=2.1.5
PKG_RELEASE:=20260313
PKG_LICENSE:=GPLv3
PKG_MAINTAINER:=sirpdboy <herboy2008@gmail.com>

LUCI_TITLE:=LuCI Support for Netwizard
LUCI_DEPENDS:=+luci-base +rpcd +jsonfilter +ip-full
LUCI_PKGARCH:=all

define Build/Prepare/luci-app-netwizard
	chmod 0755 $(PKG_BUILD_DIR)/root/etc/init.d/netwizard
	chmod 0755 $(PKG_BUILD_DIR)/root/usr/libexec/rpcd/luci.netwizard
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
