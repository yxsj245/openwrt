# SmartDNS 与 OpenClash 兼容服务

## 功能说明

固件预装 `smartdns-openclash-compat` 协调服务，并默认设置为开机自启。服务每 5 秒检查一次 OpenClash 与 SmartDNS 的 UCI 状态，仅在两者都启用时接管 DNS 兼容配置。

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

## 服务管理

进入 LuCI 的“系统 -> 服务”，找到“SmartDNS 与 OpenClash 兼容服务”，可以执行启动、停止、重启以及开机自启管理。

停止服务时会删除受管 NameServer 和覆写钩子，并恢复接管前保存的 UCI 配置。如果 OpenClash 正在运行，服务会重启 OpenClash，使恢复后的 DNS 设置立即生效。原 SmartDNS 配置启用了 `auto_set_dnsmasq` 时，也会重启 SmartDNS 恢复原始 dnsmasq 转发行为。

禁用 OpenClash 或 SmartDNS 时，协调服务也会自动恢复配置，但协调服务自身仍保持运行，以便两者再次启用时重新自动接管。

## 命令行检查

检查协调服务状态：

```sh
/etc/init.d/smartdns-openclash-compat status
/etc/init.d/smartdns-openclash-compat enabled
uci -q get smartdns_openclash_compat.state.active
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

检查解析：

```sh
nslookup openwrt.org 127.0.0.1
dig @127.0.0.1 -p "$(uci -q get smartdns.@smartdns[0].port)" openwrt.org
```

## 注意事项

- 协调服务运行期间会持续维护其接管的 DNS 选项；需要完全使用手工配置时，请先停止该服务。
- 服务只修改兼容所需选项，不修改 SmartDNS 上游服务器、OpenClash 代理规则或订阅地址。
- 如果自定义覆写脚本被用户或升级流程重建，协调服务会自动补回带有明确边界标记的托管钩子，不覆盖用户已有内容。
