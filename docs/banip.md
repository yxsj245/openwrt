# banIP 使用说明

## 已启用的软件包

固件配置已选择以下软件包：

- `banip`：基于 nftables 集合下载并应用 IP 封禁列表的服务。
- `luci-app-banip`：banIP 的 LuCI 配置页面。

`luci-app-banip` 依赖 `banip`，两者均在 `config-temp` 中显式启用，避免依赖解析结果受构建缓存影响。

## 构建前配置同步

编译机上的 OpenWrt 构建系统读取 `.config`，因此需要先将 IDE 中的 `config-temp` 同步为编译机项目目录的 `.config`，然后执行：

```sh
make defconfig
```

此命令会解析并补齐 banIP 所需的运行依赖，例如 `gawk`、`firewall4`、`ca-bundle`、`rpcd` 和 `rpcd-mod-rpcsys`。

可使用以下命令确认配置已生效：

```sh
grep -E '^CONFIG_PACKAGE_(banip|luci-app-banip)=' .config
```

预期结果为：

```text
CONFIG_PACKAGE_luci-app-banip=y
CONFIG_PACKAGE_banip=y
```

## LuCI 配置

刷入包含该软件包的固件后，在 LuCI 的“服务 → banIP”打开配置页面。

banIP 初始状态为关闭。先按实际网络环境选择订阅源和阻断方向，确认不会影响必要的访问地址后，再启用服务。建议先保留少量订阅源验证日志和 nftables 集合状态，确认正常后再逐步增加。

## 运行状态检查

```sh
/etc/init.d/banip status
logread -e banIP
nft list sets | grep -i banip
```

禁用或排障时可执行：

```sh
/etc/init.d/banip stop
/etc/init.d/banip disable
```
