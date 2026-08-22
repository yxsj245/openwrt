# SmartDNS 与 OpenClash 兼容服务

## 功能说明

固件预装 `smartdns-openclash-compat` 协调服务，并默认设置为开机自启。服务默认每 5 秒检查一次 OpenClash 与 SmartDNS 的 UCI 状态，仅在两者都启用时接管 DNS 兼容配置。

服务首次运行还会为 OpenClash 写入一次 Real-IP 默认值：

```text
en_mode=redir-host
operation_mode=redir-host
enable_meta_sniffer=1
```

这组默认值让浏览器获得真实公网地址，避免 Fake-IP 测试网段触发浏览器的本地地址空间检查。完成后会写入 `real_ip_default_applied=1` 标记；用户此后在 OpenClash 中主动切换模式时，协调服务不会反复覆盖。

启用后的 DNS 链路如下：

```text
客户端 -> dnsmasq:53 -> OpenClash:实际 DNS 端口 -> SmartDNS:实际监听端口
```

服务会执行以下操作：

- 保存 SmartDNS、OpenClash 相关选项和 DNS 服务器启用状态。
- 关闭 SmartDNS 的 `auto_set_dnsmasq`，防止重启 SmartDNS 后绕过 OpenClash。
- 启用 OpenClash 自定义 DNS，并关闭 WAN DNS 和默认 DNS 追加。
- 动态读取 SmartDNS 监听端口，创建一个受管的 OpenClash NameServer。
- 临时禁用其他 NameServer 和 Fallback，但保留其原始启用状态。
- 通过 OpenClash 官方自定义覆写接口删除订阅文件残留的 `dns.fallback`。
- 检测 OpenClash 核心已经运行、但 `openclash` 透明代理链连续缺失的启动竞态；默认连续检查 6 次后调用 OpenClash 自带的同步防火墙恢复入口，并设置 300 秒冷却时间防止重复重载。

## 服务管理

进入 LuCI 的“系统 -> 服务”，找到“SmartDNS 与 OpenClash 兼容服务”，可以执行启动、停止、重启以及开机自启管理。

停止服务时会删除受管 NameServer 和覆写钩子，并恢复接管前保存的 DNS UCI 配置。如果 OpenClash 正在运行，服务会重启 OpenClash，使恢复后的 DNS 设置立即生效。原 SmartDNS 配置启用了 `auto_set_dnsmasq` 时，也会重启 SmartDNS 恢复原始 dnsmasq 转发行为。

Real-IP 设置属于固件的一次性默认值，不在停止服务时回滚。如果需要重新使用 Fake-IP，可在 OpenClash 页面手工切换；一次性标记存在时，后续巡检会保留该选择。

禁用 OpenClash 或 SmartDNS 时，协调服务也会自动恢复配置，但协调服务自身仍保持运行，以便两者再次启用时重新自动接管。

## 命令行检查

检查协调服务状态：

```sh
/etc/init.d/smartdns-openclash-compat status
/etc/init.d/smartdns-openclash-compat enabled
uci -q get smartdns_openclash_compat.state.active
uci -q get smartdns_openclash_compat.settings.real_ip_default_applied
```

兼容状态下检查关键配置：

```sh
uci -q get smartdns.@smartdns[0].auto_set_dnsmasq
uci -q get openclash.config.enable_custom_dns
uci -q get openclash.config.append_wan_dns
uci -q show openclash | grep -E 'compat_managed|group|ip|port|enabled'
uci -q get dhcp.@dnsmasq[0].server
```

预期 `auto_set_dnsmasq` 为 `0`，OpenClash 自定义 DNS 为 `1`，WAN DNS 追加为 `0`，受管服务器指向 SmartDNS 当前端口，dnsmasq 上游指向 OpenClash 当前 DNS 端口。

检查 Real-IP 与防火墙状态：

```sh
uci -q get openclash.config.en_mode
uci -q get openclash.config.operation_mode
uci -q get openclash.config.enable_meta_sniffer
nft list chain inet fw4 openclash
logread -e smartdns-openclash-compat
```

前三项预期分别为 `redir-host`、`redir-host` 和 `1`。使用 fw4 时应能读取 `inet fw4 openclash` 链；如首轮启动时链持续缺失，日志会记录同步重建结果。

检查解析：

```sh
nslookup openwrt.org 127.0.0.1
dig @127.0.0.1 -p "$(uci -q get smartdns.@smartdns[0].port)" openwrt.org
```

## 注意事项

- 协调服务运行期间会持续维护其接管的 DNS 选项；需要完全使用手工配置时，请先停止该服务。
- 服务只修改兼容所需选项，不修改 SmartDNS 上游服务器、OpenClash 代理规则或订阅地址。
- 如果自定义覆写脚本被用户或升级流程重建，协调服务会自动补回带有明确边界标记的托管钩子，不覆盖用户已有内容。

## 高级设置

默认参数位于 `/etc/config/smartdns_openclash_compat`：

```sh
uci set smartdns_openclash_compat.settings.apply_real_ip_default='1'
uci set smartdns_openclash_compat.settings.repair_firewall='1'
uci set smartdns_openclash_compat.settings.check_interval='5'
uci set smartdns_openclash_compat.settings.firewall_missing_checks='6'
uci set smartdns_openclash_compat.settings.firewall_repair_cooldown='300'
uci commit smartdns_openclash_compat
/etc/init.d/smartdns-openclash-compat restart
```

- `apply_real_ip_default`：是否允许首次应用 Real-IP 默认值；设为 `0` 可在尚未应用前跳过。
- `real_ip_default_applied`：一次性完成标记。通常不需要手工修改。
- `repair_firewall`：是否检测并修复 OpenClash 首轮启动防火墙竞态。
- `check_interval`：协调巡检间隔，单位为秒。
- `firewall_missing_checks`：透明代理链连续缺失多少轮后触发恢复。
- `firewall_repair_cooldown`：两次防火墙恢复尝试之间的最短间隔，单位为秒。

恢复 OpenClash 上游 Fake-IP 默认值：

```sh
uci set smartdns_openclash_compat.settings.real_ip_default_applied='1'
uci set openclash.config.en_mode='fake-ip'
uci set openclash.config.operation_mode='fake-ip'
uci delete openclash.config.enable_meta_sniffer
uci commit smartdns_openclash_compat
uci commit openclash
/etc/init.d/openclash restart
```
