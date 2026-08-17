# QoSmate 使用与迁移说明

## 1. 集成信息

固件已用 QoSmate 完整替换原有的 `luci-app-clientlimit` 和 SQM：

| 组件 | 版本 | 上游提交 |
|------|------|----------|
| `qosmate` | v1.9.0 | `ad5ef37a6b38b651849eccb33670a5398e06c876` |
| `luci-app-qosmate` | v1.9.0 | `f37bc15498f7cbe3cd2cb912d1133551c9a5a738` |

源码已放入仓库的 `package/qosmate` 和 `package/luci-app-qosmate`，干净克隆后无需在编译阶段联网下载第三方文件。

QoSmate 不加入项目的 LuCI 统一服务管理页，使用其自带页面管理。固件首次启动时会自动启用该服务。

## 2. 默认配置

默认配置沿用当前路由器原 SQM 的链路参数，并将调度算法设为 CAKE：

| 配置项 | 默认值 |
|--------|--------|
| WAN 设备 | `auto`，启动时解析逻辑 WAN 或默认路由设备 |
| 下载带宽 | `85000` Kbit/s |
| 上传带宽 | `10000` Kbit/s |
| 根队列 | `cake` |
| 服务状态 | 启用 |

进入 **网络 → QoSmate → Settings** 可修改 WAN 设备与上下行带宽。建议把上下行值设置为稳定测速结果的 85%～90%，设置完成后保存并应用。

## 3. 自动迁移行为

首次启动执行 `/etc/uci-defaults/99-qosmate-migrate`：

1. 读取旧 SQM 第一条队列的接口、下载和上传速率，写入 QoSmate。
2. 旧客户端限速总开关开启时，将每条启用规则转换成 QoSmate `ratelimit`：
   - IP 地址写入 `target`；
   - 旧配置的 KB/s 自动乘以 8，转换成 QoSmate 使用的 Kbit/s；
   - 下载和上传方向保持不变。
3. 停止并禁用旧 `clientlimit`、`sqm` 服务。
4. 删除旧配置、旧客户端限速 LuCI 文件及 `inet clientlimit` nftables 表。
5. 启用 QoSmate，并用 CAKE 作为根队列。

迁移完成标记保存在 `qosmate.global.migration_done`，避免重复生成限速规则。

## 4. 客户端限速

进入 **网络 → QoSmate → Rate Limits**，每条规则可配置名称、目标、上下行上限、突发系数和启用状态。目标支持 IPv4、IPv6、CIDR 及 IP Set。

固定客户端建议先在 DHCP 中配置静态租约，再以固定 IP 建立限速规则。

## 5. CAKE 建议

进入 **网络 → QoSmate → CAKE**：

- 普通家庭网络优先保留 `diffserv4`；
- 保持 Host Isolation 开启，以便在多客户端之间公平分配带宽；
- NAT 场景保持入口和出口 NAT 识别开启；
- 上传带宽明显小于下载带宽时，可使用自动 ACK Filter；
- 光纤或普通以太网可先使用 `ethernet` 链路预设，PPPoE 应按实际封装设置开销。

QoSmate 与 SQM 都会控制 WAN 的 tc 队列，不能同时运行。当前固件已移除 SQM，后续也不要重新启用 `sqm-scripts`。

## 6. 验证命令

```sh
# 服务与开机启动状态
/etc/init.d/qosmate status
/etc/init.d/qosmate enabled && echo enabled

# 配置
uci show qosmate

# CAKE/IFB 队列
WAN="$(uci -q get qosmate.settings.WAN)"
tc -s qdisc show dev "$WAN"
tc -s qdisc show dev "ifb-$WAN"

# QoSmate nftables 表和限速规则
nft list table inet dscptag

# 确认旧组件已经清理
apk list --installed | grep -E 'clientlimit|sqm' || true
nft list tables | grep clientlimit || true
```

QoSmate 会在配置设备缺失时依次探测逻辑 WAN、`network.wan.device` 和默认路由设备，并将最终设备写回配置。

## 7. 配置备份与恢复

主要配置文件：

```text
/etc/config/qosmate
/etc/qosmate.d/custom_rules.nft
/etc/qosmate.d/inline_dscptag.nft
```

恢复默认配置后重新启动：

```sh
cp /etc/qosmate.d/qosmate-defaults /etc/config/qosmate
/etc/init.d/qosmate restart
```

暂时停用并清理运行规则：

```sh
/etc/init.d/qosmate stop
```

再次启用：

```sh
/etc/init.d/qosmate enable
/etc/init.d/qosmate start
```
