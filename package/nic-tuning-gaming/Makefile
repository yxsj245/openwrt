include $(TOPDIR)/rules.mk

PKG_NAME:=nic-tuning-gaming
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=OpenWrt Developer
PKG_LICENSE:=Apache-2.0

include $(INCLUDE_DIR)/package.mk

define Package/nic-tuning-gaming
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Gaming NIC Tuning for Intel i226-V
  DEPENDS:=+ethtool
endef

define Package/nic-tuning-gaming/description
  Automatic NIC tuning for Intel i226-V 2.5G adapters.
  Applies low-latency ethtool parameters and IRQ affinity
  optimizations for gaming scenarios.
endef

define Build/Compile
endef

define Package/nic-tuning-gaming/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./root/etc/init.d/nic-tuning $(1)/etc/init.d/nic-tuning
	$(INSTALL_BIN) ./root/etc/init.d/irq-affinity $(1)/etc/init.d/irq-affinity
endef

$(eval $(call BuildPackage,nic-tuning-gaming))
