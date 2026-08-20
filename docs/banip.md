# banIP 最高优先级封禁说明

## 已启用的软件包

固件配置已选择以下软件包：

- `banip`：基于 nftables 集合下载并应用 IP 封禁列表的服务。
- `luci-app-banip`：banIP 的 LuCI 配置页面。
- `banip-authority`：让 banIP 同时约束转发流量、路由器自身流量和 OpenClash 代理内部目标的协调服务。

三个软件包均在 `config-temp` 中显式启用，避免依赖解析结果受构建缓存影响。

## 默认策略

新安装固件首次启动时会启用 banIP，并选择官方文档建议的小规模订阅组合：

- `cinsscore`
- `debl`
- `turris`
- `doh`

这四个订阅被配置为双向封禁。默认保留自动允许上联子网，未启用仅白名单模式，也没有选择 `bogon`。用户后续在 LuCI 调整的配置不会在每次启动时被覆盖。

`banip-authority` 使用优先级 `-300` 的 nftables `prerouting` 和 `output` 钩子，早于 banIP 原生 `-175` 钩子与 OpenClash 的透明代理钩子。它直接调用 banIP 已生成的 `_inbound` 和 `_outbound` 链，因此新增封禁对已有连接同样生效。

OpenClash 使用远端代理时，内核只能看到代理服务器地址。协调服务会从 banIP 的出站集合生成 `/etc/openclash/rule_provider/banip-authority.yaml`，并通过 OpenClash 官方自定义覆写入口把 `RULE-SET,banip-authority,REJECT` 放到规则首位。这样代理和直连模式使用同一份 banIP 结果。

OpenClash Fake-IP 地址属于内部映射，不是真实目的地址。强制 nftables 链会跳过保留测试网段 `198.18.0.0/15`，再由 OpenClash 内部的最高优先级规则按真实域名或 IP 判定，避免 `bogon` 误伤整个 Fake-IP 模式。

## 域名封禁

在 banIP 本地封禁列表中每行填写一个域名，例如：

```text
example.org
```

协调服务会动态读取 SmartDNS 实际监听端口，并把 banIP 域名解析器设置为 `127.0.0.1:<SmartDNS端口>`，避免得到 OpenClash Fake-IP。banIP 会将解析到的真实 IPv4/IPv6 地址加入本地集合；协调服务还会生成 `DOMAIN-SUFFIX` 规则，使域名及其子域名在 OpenClash 内部直接拒绝。

修改本地列表后执行：

```sh
/etc/init.d/banip reload
```

协调服务会检测集合变化、原子更新规则提供者，并在确有变化时重启 OpenClash 使规则生效。

## 能力边界

该方案可封禁路由器能够识别的 IPv4、IPv6、域名，以及 OpenClash 代理隧道中的逻辑目标。客户端自己建立的端到端 VPN、Tor 或其他加密隧道只向路由器暴露隧道服务器地址，任何路由器侧 IP/DNS 工具都无法识别隧道内部目标；此时可以封禁隧道服务器，或另行禁止该隧道协议。

## 构建前配置同步

编译机上的 OpenWrt 构建系统读取 `.config`，因此需要先将 IDE 中的 `config-temp` 同步为编译机项目目录的 `.config`，然后执行：

```sh
make defconfig
```

此命令会解析并补齐 banIP 所需的运行依赖，例如 `gawk`、`firewall4`、`ca-bundle`、`rpcd` 和 `rpcd-mod-rpcsys`。

可使用以下命令确认配置已生效：

```sh
grep -E '^CONFIG_PACKAGE_(banip|banip-authority|luci-app-banip)=' .config
```

预期结果为：

```text
CONFIG_PACKAGE_luci-app-banip=y
CONFIG_PACKAGE_banip=y
CONFIG_PACKAGE_banip-authority=y
```

## LuCI 配置

刷入包含该软件包的固件后，在 LuCI 的“服务 → banIP”打开配置页面。

banIP 初始策略由固件的一次性初始化脚本配置。进入 LuCI 的“服务 → banIP”可以调整订阅源、方向以及本地允许/封禁列表。进入“系统 → 服务”可以单独停止“banIP 强制封禁协调服务”；停止后会撤销透明代理前置链和 OpenClash 托管规则，并恢复原域名解析器。

## 运行状态检查

```sh
/etc/init.d/banip status
/etc/init.d/banip-authority status
nft list table inet banIP
nft list chain inet banIP authority-prerouting
nft list chain inet banIP authority-output
```

只检查 OpenClash 集成状态时，不要输出完整运行配置，以免暴露代理信息：

```sh
grep -F 'BEGIN BANIP-AUTHORITY' /etc/openclash/custom/openclash_custom_overwrite.sh
ruby -ryaml -e 'v=YAML.load_file(ARGV[0]); puts(v.dig("rule-providers", "banip-authority") ? "provider=ok" : "provider=missing"); puts(v.fetch("rules", []).first)' /etc/openclash/*.yaml
```

禁用或排障时可执行：

```sh
/etc/init.d/banip stop
/etc/init.d/banip disable
/etc/init.d/banip-authority stop
/etc/init.d/banip-authority disable
```
