include $(TOPDIR)/rules.mk

PKG_NAME:=qosmate
PKG_VERSION:=1.9.0
PKG_RELEASE:=3

PKG_MAINTAINER:=Markus Hütter <mh@hudra.net>
PKG_LICENSE:=GPL-3.0-or-later
PKG_LICENSE_FILES:=LICENSE

include $(INCLUDE_DIR)/package.mk

define Package/qosmate
  SECTION:=net
  CATEGORY:=Network
  TITLE:=QoSmate - Quality of Service management tool
  URL:=https://github.com/hudra0/qosmate
  DEPENDS:=+coreutils-sleep +ip-full +jq +kmod-ifb +kmod-netem +kmod-sched \
	+kmod-sched-cake +kmod-sched-ctinfo +kmod-sched-red +kmod-veth \
	+luci-lib-jsonc +lua +nftables-json +tc-full
  CONFLICTS:=sqm-scripts
endef

define Package/qosmate/description
 QoSmate provides CAKE/HFSC traffic shaping, DSCP classification and
 per-device bandwidth limits for OpenWrt.
endef

define Build/Compile
endef

define Package/qosmate/conffiles
/etc/config/qosmate
/etc/qosmate.d/custom_rules.nft
/etc/qosmate.d/inline_dscptag.nft
endef

define Package/qosmate/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./etc/config/qosmate $(1)/etc/config/qosmate

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./etc/init.d/qosmate $(1)/etc/init.d/qosmate
	$(INSTALL_BIN) ./etc/init.d/qosmate-autorate $(1)/etc/init.d/qosmate-autorate

	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_BIN) ./etc/hotplug.d/iface/13-qosmateHotplug $(1)/etc/hotplug.d/iface/13-qosmateHotplug

	$(INSTALL_DIR) $(1)/etc/qosmate.d
	$(INSTALL_CONF) ./etc/config/qosmate $(1)/etc/qosmate.d/qosmate-defaults
	$(INSTALL_CONF) /dev/null $(1)/etc/qosmate.d/custom_rules.nft
	$(INSTALL_CONF) /dev/null $(1)/etc/qosmate.d/inline_dscptag.nft

	$(INSTALL_BIN) ./etc/qosmate.sh $(1)/etc/qosmate.sh
	$(INSTALL_BIN) ./etc/qosmate-autorate.sh $(1)/etc/qosmate-autorate.sh
	$(INSTALL_DATA) ./etc/qosmate-autorate-tc.sh $(1)/etc/qosmate-autorate-tc.sh

	$(INSTALL_DIR) $(1)/usr/lib/tc
	$(INSTALL_DATA) ./usr/lib/tc/*.dist $(1)/usr/lib/tc/

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/99-qosmate-migrate $(1)/etc/uci-defaults/99-qosmate-migrate

	(cd $(1) && md5sum \
		etc/init.d/qosmate \
		etc/qosmate.sh \
		etc/qosmate.d/qosmate-defaults \
		etc/qosmate-autorate.sh \
		etc/qosmate-autorate-tc.sh \
		etc/init.d/qosmate-autorate \
		usr/lib/tc/experimental.dist \
		usr/lib/tc/normal.dist \
		usr/lib/tc/normmix20-64.dist \
		usr/lib/tc/pareto.dist \
		usr/lib/tc/paretonormal.dist) | \
		sed 's#  #  /#' > $(1)/etc/qosmate.d/backend_reg.md5
endef

$(eval $(call BuildPackage,qosmate))
