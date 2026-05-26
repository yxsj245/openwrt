# OpenWrt 控制台主菜单 - 实施计划

## 需求概述

在 OpenWrt 物理显示器（控制台/tty）上实现自定义交互式主菜单界面：
- 系统启动完毕后自动清屏，显示主菜单
- 显示 OpenWrt Logo + 版本号 + 物理网口状态和IP地址（英文）
- **交互式网络配置**：输入网口序号可修改该接口的 IP、DNS、网关、掩码，并持久保存
- 按 R 键刷新，按 Q 键退出进入终端

## 实现方案

采用**方案A（修改 /etc/profile）**：通过 `/etc/profile.d/` 机制注入入口脚本，主逻辑通过独立模块实现。

## 文件结构

```
package/base-files/files/
├── etc/
│   └── profile.d/
│       └── 30-console-menu.sh          # 入口：tty检测 + 调用主菜单
└── usr/
    └── lib/
        └── console-menu/
            ├── display.sh              # 主菜单显示与控制循环
            └── network-config.sh       # 交互式网络配置子菜单
```

## 实施步骤

### 步骤1：创建入口脚本

**文件**：`package/base-files/files/etc/profile.d/30-console-menu.sh`

**功能**：
- 检测当前是否为物理控制台（`/dev/tty*`、`/dev/console`），SSH 会话直接跳过
- 调用 `/usr/lib/console-menu/display.sh` 启动主菜单循环
- 菜单退出后执行 `clear` 清屏，返回正常终端

### 步骤2：创建主菜单显示模块

**文件**：`package/base-files/files/usr/lib/console-menu/display.sh`

**功能**：
1. `draw_header()` - 输出 OpenWrt Logo + 版本号分隔线
2. `draw_version()` - 从 `/etc/openwrt_release` 读取版本信息
3. `draw_network_list()` - 遍历物理网口，格式化显示状态表格
4. `main_menu_loop()` - 主循环，清屏→绘制→等待输入→路由

**主菜单界面布局**：

```
=====================================================
   _______                     ________        __
  |       |.-----.-----.-----.|  |  |  |.----.|  |_
  |   -   ||  _  |  -__|     ||  |  |  ||   _||   _|
  |_______||   __|_____|__|__||________||__|  |____|
           |__| W I R E L E S S   F R E E D O M
-----------------------------------------------------
  Version: OpenWrt 25.12.4 | r32933-4ccb782af7

  Network Interfaces:
 ----------------------------------------------------
  [1]  eth0    UP    1000Mbps   192.168.1.1/24     (LAN / static)
  [2]  eth1    UP    1000Mbps   10.0.0.100/24      (WAN / dhcp)
  [3]  eth2    DOWN  --                             (unconfigured)

 ----------------------------------------------------
  [1-3] Configure interface   [R] Refresh   [Q] Exit
  Enter choice >
```

**关键设计决策**：
- 网口序号从 `1` 开始，使用数组存储接口名映射
- 输入验证仅接受有效序号和 R/Q 键
- 每次操作后自动清屏重新绘制

### 步骤3：创建交互式网络配置模块

**文件**：`package/base-files/files/usr/lib/console-menu/network-config.sh`

**功能**：提供完整的交互式子菜单，支持修改网络参数并通过 OpenWrt UCI 持久保存。

#### 3.1 配置子菜单界面布局

```
=== Configure: eth0 (LAN) =================================

  Protocol:  static

  [1] IP Address:     192.168.1.1
  [2] Netmask:         255.255.255.0
  [3] Gateway:         192.168.1.254
  [4] DNS 1:           8.8.8.8
  [5] DNS 2:           114.114.114.114
  [+] Add DNS server

  [A] Apply & Save    [P] Change Protocol    [B] Back

  Select option >
```

#### 3.2 协议切换 （按 P）

```
Select protocol:
  [1] Static IP (manual configuration)
  [2] DHCP (auto config)
  [3] Unmanaged (no IP)

  Choice >
```

切换协议时：
- `static` → 显示所有 IP/掩码/网关/DNS 配置项
- `dhcp` → 隐藏手动配置项，保存后自动获取
- `none` → 不分配 IP

#### 3.3 UCI 持久保存逻辑

OpenWrt 使用 UCI（Unified Configuration Interface）管理网络配置，配置文件为 `/etc/config/network`。

**映射物理网口到 UCI section**：
1. 解析 `/etc/config/network`，查找 `option device 'ethX'` 对应的 section
2. 若找到，使用该 section 名（如 `lan`、`wan`）
3. 若未找到，自动创建新 section `config interface 'ethX_cfg'`

**写入操作**：
```bash
# 设置协议
uci set network.<section>.proto='static'

# 设置 IP
uci set network.<section>.ipaddr='192.168.1.100'

# 设置掩码
uci set network.<section>.netmask='255.255.255.0'

# 设置网关
uci set network.<section>.gateway='192.168.1.1'

# 设置 DNS（先清空再添加）
uci delete network.<section>.dns
uci add_list network.<section>.dns='8.8.8.8'
uci add_list network.<section>.dns='114.114.114.114'

# 持久保存
uci commit network

# 重启网络使配置生效
/etc/init.d/network reload
```

#### 3.4 输入验证

| 字段 | 验证规则 |
|------|----------|
| IP 地址 | 4段数字，每段 0-255，不允许 0.0.0.0 |
| 子网掩码 | 支持点分十进制（255.255.255.0）和 CIDR 前缀（24） |
| 网关 | 4段数字，每段 0-255 |
| DNS | 4段数字，每段 0-255，最多3个 |

#### 3.5 操作流程安全设计

1. **预览模式**：所有修改先在内存中暂存，不立即写入 UCI
2. **确认保存**：按 A 时才写入 UCI 并 `commit`
3. **放弃修改**：按 B 回主菜单，不写入任何修改
4. **保存后重启网络**：只 `reload`（热重载），不 `restart`（完全重启），减少影响

### 步骤4：实现主循环交互流程

```
启动
 │
 ├─ profile 加载
 │   └─ profile.d/30-console-menu.sh
 │       ├─ 检测 tty（非控制台则 return）
 │       └─ 调用 /usr/lib/console-menu/display.sh
 │
 └─ main_menu_loop()
     │
     ├─ clear_screen() + draw_header() + draw_network_list()
     │
     └─ while true:
         │
         ├─ read user_input
         │
         ├─ [1-N] → source network-config.sh → config_submenu(ethX)
         │   └─ 返回后刷新主菜单
         │
         ├─ [R/r] → 刷新主菜单（重新获取网络状态）
         │
         └─ [Q/q] → break（exit 循环，清屏，返回终端）
```

### 步骤5：编译验证

1. 在编译机上重新编译 base-files 包：`make package/base-files/compile -j$(nproc)`
2. 生成新固件
3. 在虚拟机中 sysupgrade 升级测试

### 步骤6：虚拟机测试

1. 通过 SSH 连接确认 SSH 不受影响
2. 通过 VNC 查看控制台显示效果
3. 测试网络配置修改和持久保存

---

## 技术细节

### busybox 兼容性

OpenWrt 使用 busybox，`read` 命令语法有限：
```sh
# busybox read 不支持 -p 提示，需使用 printf + read
printf "Enter choice > "
read choice
```

### ANSI 转义码

```sh
# 清屏
printf '\033[2J\033[H'
# 保存光标位置
printf '\033[s'
# 恢复光标位置
printf '\033[u'
```

### 物理网口枚举（兼容多命名）

```sh
for iface in /sys/class/net/eth*; do
    [ -d "$iface" ] || continue
    name=$(basename "$iface")
    ...
done
```

### 获取网口所属 UCI Section

```sh
# 从 /etc/config/network 中查找匹配 ethX 的 section
uci show network | grep "device='$iface_name'" | cut -d'.' -f2 | cut -d'=' -f1
```

---

## 风险评估

| 风险 | 等级 | 缓解措施 |
|------|------|----------|
| SSH登录也显示菜单 | 低 | tty检测，仅在 `/dev/tty*` `/dev/console` 显示 |
| 网口命名不匹配（em*/en*） | 中 | 可扩展 `for` 匹配模式 |
| busybox read 行为差异 | 中 | 使用 `printf + read` 替代 `read -p` |
| UCI 写入失败（权限） | 低 | 默认 root 登录，root 拥有 UCI 写权限 |
| 网络 reload 后断连 | 中 | 仅 `reload` 不禁用接口，若改网关不会立即生效 |
| 循环中阻塞或高 CPU | 低 | `read` 阻塞等待输入，不消耗 CPU |

---

## 补充：后续可扩展功能（本次不实现）

- 显示 CPU 温度/负载
- 显示内存使用
- 显示磁盘使用
- VLAN 配置
- WiFi SSID/密码配置（若有无线网卡）
