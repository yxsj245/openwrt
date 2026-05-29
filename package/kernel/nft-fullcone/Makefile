# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2018 Chion Tang <tech@chionlab.moe>
# Copyright (c) 2019-2022 GitHub/llccd
# Copyright (c) 2022 Syrone Wong <wong.syrone@gmail.com>

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=nft-fullcone
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define KernelPackage/nft-fullcone
  SUBMENU:=Netfilter Extensions
  DEPENDS:=@IPV6 +kmod-nft-core +kmod-nf-conntrack +kmod-nf-conntrack6
  TITLE:=nftables fullcone expression support
  FILES:= $(PKG_BUILD_DIR)/nft_fullcone.ko
  KCONFIG:= \
	CONFIG_NFT_FULLCONE=y \
	CONFIG_NF_NAT=y \
	CONFIG_NF_CONNTRACK_EVENTS=y \
	CONFIG_NF_CONNTRACK_CHAIN_EVENTS=y
  AUTOLOAD:=$(call AutoProbe,nft_fullcone)
endef

define KernelPackage/nft-fullcone/Description
 Kernel module adds the "fullcone" expression that you can use
 to perform NAT in the RFC3489-compatible full cone SNAT flavour.
 Currently only UDP traffic is supported for full-cone NAT.
 For other protos FULLCONENAT is equivalent to MASQUERADE.
endef

define Build/Compile
	+$(MAKE) $(PKG_JOBS) $(KERNEL_MAKEOPTS) \
		M="$(PKG_BUILD_DIR)" \
		EXTRA_CFLAGS="$(BUILDFLAGS)" \
		modules
endef

$(eval $(call KernelPackage,nft-fullcone))
