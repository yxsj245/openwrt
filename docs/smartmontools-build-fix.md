# smartmontools 构建依赖修复

## 问题现象

在仅选择 `smartmontools`、未选择 `smartd-mail` 时，全量构建可能错误进入以下依赖链：

```text
smartmontools -> msmtp -> gnutls
```

随后由于 `libgnutls` 未被配置选中，构建在 `feeds/packages/libs/gnutls` 中以
`No rule to make target 'compile'` 结束。日志末尾出现的 Rust 成功信息只是并行任务收尾，
不是故障原因。

## 修复方式

仓库内的 `package/smartmontools` 是 OpenWrt packages feed 对应版本的本地覆盖包。
它只将 `smartd-mail` 的外部邮件依赖改为条件依赖：

```make
DEPENDS+= +smartd +PACKAGE_smartd-mail:nail +PACKAGE_smartd-mail:msmtp-mta
```

因此：

- 只选择 `smartmontools` 时，不再构建 `nail`、`msmtp` 和 `gnutls`；
- 选择 `smartd-mail` 时，邮件依赖仍会正常加入；
- `luci-app-diskman` 使用的 `smartctl` 功能保持不变。

## 全新克隆后的准备

先更新并安装 feeds：

```sh
./scripts/feeds update -a
./scripts/feeds install -a
```

安装脚本检测到核心源码树中的同名本地包后，不会用 feed 包覆盖它。随后按项目约定将
`config-temp` 复制为 `.config` 并执行 `make defconfig`。

对于已经安装过 feeds 的旧工作树，应先删除生成的同名 feed 软链接，再重新生成包索引。
该软链接属于生成文件，不应提交到仓库。
