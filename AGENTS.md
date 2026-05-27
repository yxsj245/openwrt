这是一个openwrt系统源码文件，请你根据我的需求进行修改和提出解决方案。我给你准备了一台编译机，接下来以及后续所有操作务必只能使用这一台编译机。
MCP名称：SSH-MCP_System_compilation 项目目录：/opt/project/openwrt
默认是非root用户，root用户密码为Qw133133 一般情况编译时不需要使用root用户。下面是项目规则
1. 由于我不懂内核，所以当我提出需求的时候你需要充分阅读把所有涉及相关决策的地方使用IDE选择弹窗让我选择并详细描述每个选择的作用，不要擅自做主。
2. 涉及编译相关的操作，请你告诉我命令一般情况由我自己去执行。如果编译机没有虚拟机的话旧执行完毕后请务必在机器上启动一个虚拟机并开启VNC方便我进行测试，如果编译机已经存在已有的虚拟机时请编译后连接进去使用sysupgrade升级，当前openwrt虚拟机IP是192.168.122.3，参考[UPGRADE](docs\UPGRADE.md)。由于你没有视觉所以你不能通关VNC截图进行查看，只能通过命令行进行操作。比
3. 代码会自动实时同步到编译机，所有代码编写修改操作必须在当前IDE中进行，一般情况除调试外不能再其他地方进行修改。您也不需要使用MCP的上传工具手动同步代码。当然你需要编写后去机器上验证文件是否同步 如果没有同步可以使用MCP手动上传文件。
4. OpenWrt 的 make 实际读取的是 .config为了方便读取我在IDE上加他重命名了为config-temp，所以修改config-temp这个文件之后需要去编译机上进行替换操作，这一步由你来直接帮我操作了。

---

## 虚拟机参考规格

以下为当前编译机上运行的 OpenWrt 测试虚拟机 `openwrt-vm` 的完整配置，后续创建新虚拟机时必须参照此规格：

| 参数 | 值 |
|------|-----|
| **VM名称** | openwrt-vm |
| **UUID** | cc74c82d-4dfd-43bf-98c0-bd25c15d3b02 |
| **架构/虚拟机类型** | x86_64 / qemu (KVM) |
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
| **网络类型** | NAT 网络（libvirt default 网络），bridge: `virbr0` |
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
| **VM IP** | 192.168.122.3 |

### 创建新虚拟机参考命令

```bash
# 基于此规格创建新虚拟机的 virt-install 或 qemu 命令参数应与此规格一致
# 最小化参数示例：
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
