# SmartDNS 使用说明

## 默认架构

固件预装 `smartdns` 和 `luci-app-smartdns`，首次启动时自动启用 SmartDNS：

- dnsmasq-full 继续监听 53 端口，负责 DHCP、本地域名解析和 nftset。
- SmartDNS 监听 6053 端口，负责并发查询上游 DNS 并优选返回结果。
- SmartDNS 使用 WAN 动态获得的 DNS 作为默认上游，不写死公共 DNS 地址。
- SmartDNS 自带的 LuCI 页面负责配置管理，不加入自定义统一服务页。

SmartDNS 的 `auto_set_dnsmasq` 默认开启。服务启动时会把 dnsmasq 的上游设置为 `127.0.0.1#6053`，并启用 dnsmasq 的 `noresolv`，避免 dnsmasq 绕过 SmartDNS 直接查询 WAN DNS。

## LuCI 管理

进入“服务 > SmartDNS”管理启停、监听端口、上游服务器及高级规则。首次启动生成默认配置后，固件升级不会覆盖用户在 LuCI 中保存的设置。

如果修改 SmartDNS 监听端口，请保持“自动设置 Dnsmasq”开启，SmartDNS 会同步更新 dnsmasq 的转发地址。

## 命令行检查

检查服务和端口：

```sh
/etc/init.d/smartdns status
netstat -lnptu | grep -E '(:53|:6053)'
```

检查转发链路：

```sh
uci -q get smartdns.@smartdns[0].enabled
uci -q get smartdns.@smartdns[0].port
uci -q get dhcp.@dnsmasq[0].server
uci -q get dhcp.@dnsmasq[0].noresolv
```

预期结果分别包含 `1`、`6053`、`127.0.0.1#6053` 和 `1`。

检查 DNS 查询：

```sh
nslookup openwrt.org 127.0.0.1
nslookup openwrt.org 127.0.0.1#6053
```

BusyBox `nslookup` 若不支持 `地址#端口` 语法，可安装或使用 `dig` 执行：

```sh
dig @127.0.0.1 -p 6053 openwrt.org
```
