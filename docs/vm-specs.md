# OpenWrt 测试虚拟机规格

## 当前虚拟机

| 参数 | 值 |
|------|-----|
| **VM名称** | openwrt-vm |
| **IP** | 192.168.123.3 |
| **UUID** | cc74c82d-4dfd-43bf-98c0-bd25c15d3b02 |
| **架构/虚拟机类型** | x86_64 / qemu (KVM)，无硬件虚拟化 |
| **机器型号** | pc-q35-10.2 |
| **固件** | UEFI (OVMF)，`/usr/share/OVMF/OVMF_CODE_4M.fd` |
| **NVRAM模板** | `/usr/share/OVMF/OVMF_VARS_4M.fd` |
| **Secure Boot** | 禁用 |
| **vCPU** | 1 (static placement) |
| **内存** | 1 GiB (1048576 KiB) |
| **CPU型号** | qemu64 (custom, match=exact, check=full) |
| **CPU特性** | hypervisor (require), lahf_lm (require) |
| **磁盘格式** | qcow2 (driver: qemu) |
| **磁盘虚拟大小** | 1 GiB |
| **磁盘总线** | virtio (vda) |
| **磁盘存放目录** | `/home/xiaozhu/vms/` |
| **网络类型** | NAT 网络（libvirt `net-openwrt` 网络），bridge: `virbr1` |
| **网卡型号** | virtio |
| **MAC地址** | 52:54:00:4c:f3:d5 |
| **VNC** | 端口 5900（display `:0`），监听 `0.0.0.0`，autoport=yes |
| **显示** | virtio (heads=1) |
| **输入** | PS/2 鼠标 + 键盘 |
| **音频** | 无 (type='none') |
| **串口** | pty (`/dev/pts/4`) |
| **Watchdog** | itco, action=reset |
| **RNG** | virtio, `/dev/urandom` |
| **Memballoon** | virtio |
| **ACPI/APIC** | 启用 |
| **时钟** | UTC (rtc track=guest, pit delay, hpet=no) |
| **电源动作** | on_poweroff=destroy, on_reboot=restart, on_crash=destroy |
| **模拟器** | `/usr/bin/qemu-system-x86_64` |

## 创建新虚拟机参考命令

```bash
virt-install \
  --name openwrt-vm \
  --ram 1024 \
  --vcpus 1 \
  --cpu qemu64 \
  --os-variant generic \
  --boot uefi \
  --disk path=/home/xiaozhu/vms/openwrt-vm.qcow2,format=qcow2,bus=virtio,size=1 \
  --network network=default,model=virtio \
  --graphics vnc,listen=0.0.0.0 \
  --video virtio \
  --rng /dev/urandom \
  --import
```
