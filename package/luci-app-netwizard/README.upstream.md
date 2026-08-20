# 上游来源

- 仓库：`https://github.com/sirpdboy/luci-app-netwizard.git`
- 固定提交：`7867a28e711269889ca1c999a0ce844c3adb45a0`
- 上游版本：`2.1.5-r20260312`；本地包发行号为 `20260313`。

## 本地调整

本包保留上游功能文件，并作以下构建兼容调整：

- 在包依赖中显式声明 `luci-base`、`rpcd`、`jsonfilter` 和 `ip-full`；
- 在构建目录中将 `/etc/init.d/netwizard` 与 `/usr/libexec/rpcd/luci.netwizard` 设置为 `0755`，避免 Windows 工作区缺少 Unix 可执行位导致服务与 RPC 无法运行。
