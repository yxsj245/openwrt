define Device/generic
  DEVICE_VENDOR := Generic
  DEVICE_MODEL := x86/64
  DEVICE_PACKAGES += \
	kmod-igc kmod-fs-vfat kmod-drm-i915 \
	kmod-nvme \
	kmod-usb-core kmod-usb2 kmod-usb2-pci kmod-usb3 \
	kmod-usb-storage kmod-usb-hid \
	kmod-hwmon-core kmod-hwmon-coretemp kmod-hwmon-drivetemp
  GRUB2_VARIANT := generic
endef
TARGET_DEVICES += generic
