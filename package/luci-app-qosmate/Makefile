include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-qosmate
PKG_VERSION:=1.9.0
PKG_RELEASE:=3

PKG_MAINTAINER:=Markus Hütter <mh@hudra.net>
PKG_LICENSE:=GPL-3.0-or-later
PKG_LICENSE_FILES:=LICENSE

LUCI_TITLE:=LuCI support for QoSmate
LUCI_DESCRIPTION:=Web interface for QoSmate traffic shaping and per-device limits
LUCI_DEPENDS:=+qosmate +luci-base +luci-lib-jsonc +lua
LUCI_PKGARCH:=all
LUCI_MINIFY_JS:=0

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
