# 移除 Argon 第三方主题

## 变更

- 从 `feeds.conf.default` 移除第三方 `luci-theme-argon` 仓库。
- 从 `config-temp` 移除对应的 feed 配置项。
- 继续使用 OpenWrt LuCI 官方 feed 提供的 `luci-theme-bootstrap`。

## 原因

Argon 是第三方 LuCI 美化主题，其仓库本身是单个根目录包，不能按普通 OpenWrt feed 正确生成索引。项目不再引入该第三方主题，避免 feed 更新失败，并保持管理界面使用官方主题。

## 更新与构建

拉取本次变更后重新更新和安装 feeds，再根据 `config-temp` 生成 `.config`。旧的 `feeds/argon` 目录只是构建缓存，不会再参与索引或固件构建。
