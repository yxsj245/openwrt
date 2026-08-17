# 移除 AdGuard Home

本项目的默认固件已不再预装 AdGuard Home 及其 LuCI 管理页面。

## 移除范围

- `config-temp` 不再选择 `adguardhome` 和 `luci-app-adguardhome`。
- 「系统 -> 服务」不再显示 AdGuard Home。
- 首次启动脚本不再尝试停止或禁用 AdGuard Home。

上游 feeds 中的包源码仍会保留，因此需要时可以在 `make menuconfig` 中重新选择以下软件包：

- `adguardhome`
- `luci-app-adguardhome`

选择后将生成的 `.config` 同步回 `config-temp`，再执行构建即可恢复预装。
