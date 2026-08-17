# J6412 专用硬件调优与验证

本文记录 `x86_j6412-Specialized` 分支对 Intel Elkhart Lake J6412/J6413/J6426、4×Intel i226-V 和 NVMe 平台的实际核验结果与使用方式。

## 实体机核验结论

2026-08-17 通过实体设备只读核验：

- CPU 为 J6412，四核，Intel P-State 正常工作，空闲频率约 800 MHz；
- 四张网卡均为 `8086:125c`，由内核 `igc` 驱动，每端口支持四个 combined 队列；
- NVMe 通过 PCIe 3.0 x1 连接，符合主板规格，SMART 健康检查通过；
- i915 正常识别 Elkhart Lake Gen11 GPU，并加载 `icl_dmc_ver1_09.bin`；
- CPU 核心温度约 36-41 摄氏度，NVMe 温度约 30 摄氏度；
- 当前 BIOS 为 2023 年 AMI 固件，DMI 信息为通用占位值，无法仅凭软件确认厂商最新 BIOS；
- 网卡 NVM 和 NVMe 固件必须向实际整机或硬盘厂商核对，禁止使用其他 OEM 型号的固件强刷。

实体机当前仍运行 OpenWrt 25.12.4 和 Linux 6.12.87，以下目标版本要在新固件完成构建、升级并重启后才会生效。

## 驱动与固件版本核验

2026-08-17 再次对照官方来源：

| 组件 | 当前实体机 | 本分支目标 | 核验结论 |
|------|------------|------------|----------|
| Linux 内核 | 6.12.87 | 6.12.103 | 6.12.103 是 kernel.org 于 2026-08-09 发布的最新 6.12 LTS |
| i226-V `igc` | 6.12.87 | 6.12.103 | 内核内置驱动，随 6.12 LTS 一并更新 |
| NVMe、i915、xHCI、AHCI、SDHCI | 6.12.87 | 6.12.103 | 均为内核内置驱动，随 6.12 LTS 一并更新 |
| Intel 微码 | 已安装 20251111，实际仍为 `0x17` | 20251111，早期加载后为 `0x1a` | Intel 最新集合为 20260812，但 J6412 对应 `06-96-01` 自 20240813 起未再变化，仍为 `0x1a` |
| i915 DMC | `icl_dmc_ver1_09.bin` v1.9 | 保持 | 已正确加载，无需为此平台增加 GuC/HuC |
| `ethtool` | 6.15 | 6.15 | 与 OpenWrt 25.12 当前维护分支一致 |
| `irqbalance` | 1.9.5 | 1.9.5 | 与 OpenWrt packages 25.12 当前维护分支一致 |

四张 i226-V 报告相同 NVM 标识 `2013:8877`，NVMe 固件为厂商专用版本。由于主板 DMI 和硬盘型号均为通用标识，无法可靠映射到厂商下载页，不能宣称其为最新版，也不能跨 OEM 强刷。BIOS 同样必须向销售方索取对应主板批次的固件及更新说明。

实体机连续运行约十五天后，`eth2` 累计出现 3814 次 RX FIFO 错误，其中多数集中在队列 3；这支持把旧配置的 256 Ring 提高到默认 1024。升级后应清零或记录基线，再按相同负载观察计数增量，不能仅凭历史累计值判断驱动故障。启动时的一条 `exceed max 2 second` 来自 `igc` 等待 1000Base-T 对端接收状态，不是 NETDEV watchdog 或发送队列卡死。

启动日志还记录了 EFI FAT 分区未正常卸载，以及根分区完成日志回放。安排维护窗口正常重启后应再次检查；若提示持续出现，再离线执行文件系统检查，不要在已挂载文件系统上强制修复。

## 内核与微码

本分支保持 Linux 6.12 LTS，并跟进 OpenWrt 25.12 维护分支的 6.12.103，不跨版本迁移到主线内核。

实体机原有 GRUB 使用 `noinitrd`，导致 Intel 微码只能在根文件系统启动后加载。Linux 6.12 拒绝缺少最低安全版本声明的晚期更新，最终仍运行 BIOS 提供的 `0x17`，并报告 RFDS 和 SRBDS 微码缺失风险。

新镜像会把 J6412/J6413/J6426 对应的 `06-96-01` 文件打包为：

```text
/boot/intel-ucode.img
└── kernel/x86/microcode/GenuineIntel.bin
```

GRUB 在内核启动前加载该镜像。不要通过关闭 `CONFIG_MICROCODE_LATE_FORCE_MINREV` 绕过安全检查。

升级后验证：

```sh
grep -m1 '^microcode' /proc/cpuinfo
dmesg | grep -i microcode
grep -H . /sys/devices/system/cpu/vulnerabilities/* | grep -E 'register_file_data_sampling|srbds'
```

预期微码版本为 `0x1a`，启动日志不再出现晚期加载被拒绝的信息。

## i226-V 调优模式

配置文件为 `/etc/config/nic-tuning`：

```uci
config settings 'settings'
	option enabled '1'
	option profile 'balanced'
	option irq_mode 'irqbalance'
```

可用模式：

| 模式 | Ring | 硬件分载 | 适用场景 |
|------|------|----------|----------|
| `balanced` | 1024 | 开启 TSO/GSO/GRO | 默认，适合 PPPoE、CAKE 和日常 2.5G 转发 |
| `low-latency` | 512 | 关闭 TSO/GSO/GRO | 仅在 A/B 延迟测试确认有效后使用 |
| `throughput` | 4096 | 开启 TSO/GSO/GRO | 内网大文件和吞吐优先 |

每种模式都会自动将队列数限制在在线 CPU 数和网卡最大 combined 队列数之间。需要覆盖时，可增加 `queue_count` 或 `ring_size`，脚本不会写死接口名称。

在线 CPU 数会优先通过 `nproc` 获取；精简固件未安装该命令时，脚本会从 sysfs 自动统计，不会错误回退成单队列。重复应用相同的队列数和 Ring 大小时会直接跳过，避免把“参数未变化”误报为调优失败。

应用和检查：

```sh
/etc/init.d/nic-tuning apply
logread | grep nic-tuning
ethtool -l eth0
ethtool -g eth0
ethtool -k eth0 | grep -E 'segmentation|generic-receive'
```

## IRQ 策略

默认使用 `irqbalance`，不再同时执行静态 IRQ 绑定。手工模式只用于明确的 CPU 隔离测试：

```sh
uci set irqbalance.irqbalance.enabled='0'
uci commit irqbalance
/etc/init.d/irqbalance stop
uci set nic-tuning.settings.irq_mode='manual'
uci commit nic-tuning
/etc/init.d/irq-affinity apply
```

手工脚本检测到 `irqbalance` 仍在运行时会拒绝执行。恢复默认策略：

```sh
uci set nic-tuning.settings.irq_mode='irqbalance'
uci set irqbalance.irqbalance.enabled='1'
uci commit nic-tuning
uci commit irqbalance
/etc/init.d/irqbalance restart
```

## 保留的上游默认项

实体测试中 CAKE 峰值排队延迟低于 0.2 ms，CPU 和 NVMe 温度正常，因此继续保留：

- `HZ=100` 和 `PREEMPT_NONE`；
- Intel P-State `powersave` governor；
- PCIe ASPM `default`；
- i915 仅安装 DMC 固件，不预装无实际需求的 GuC/HuC 和 HDMI 音频组件。

这些设置不应仅为了参数看起来更激进而调整，应以实体机吞吐、丢包、温度和延迟对比结果为依据。
