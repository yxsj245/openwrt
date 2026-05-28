# LuCI 服务管理页面（luci-app-services）

在 LuCI 后台「系统 → 服务」下提供统一的系统服务启停管理界面。支持查看服务运行状态、启动/停止/重启服务、设置开机自启。

---

## 目录结构

```
package/luci-app-services/
├── Makefile                                              # 包定义，版本号
├── htdocs/luci-static/resources/view/system/
│   └── services.js                                       # 前端 JS（核心逻辑）
├── po/templates/services.pot                             # 翻译模板
├── po/zh_Hans/services.po                                # 简体中文翻译
└── root/
    ├── etc/uci-defaults/99-disable-services              # 首次安装禁用服务脚本
    └── usr/share/
        ├── luci/menu.d/luci-app-services.json            # 菜单注册
        └── rpcd/acl.d/luci-app-services.json             # ACL 权限
```

---

## 技术实现

### 状态检测

使用 `rc.list` ubus 方法查询 procd 服务注册表，返回 `{ running: bool, enabled: bool }`：

```javascript
var callServiceList = rpc.declare({
    object: 'rc',
    method: 'list',
    params: ['name']
});
```

ubus 返回示例：
```json
{
    "dockerd": {
        "start": 99,
        "enabled": false,
        "running": true
    }
}
```

### 服务操作

使用 `rc.init` ubus 方法，支持 `start` / `stop` / `restart` / `enable` / `disable`：

```javascript
var callServiceAction = rpc.declare({
    object: 'rc',
    method: 'init',
    params: ['name', 'action']
});
```

### 自动轮询

页面通过 LuCI `poll` 模块每 5 秒自动刷新所有服务状态，服务被外部停止后页面也会自动更新：

```javascript
poll.add(function() {
    SERVICE_DEFINITIONS.forEach(function(service) {
        refreshServiceStatus(service);
    });
}, 5);
```

### ACL 权限

`rpcd` ACL 需同时授权 `rc.init`（读写）和 `rc.list`（只读）：

```json
{
    "luci-app-services": {
        "description": "Grant access to service management",
        "read": {
            "ubus": {
                "rc": [ "init", "list" ]
            }
        },
        "write": {
            "ubus": {
                "rc": [ "init" ]
            }
        }
    }
}
```

---

## 添加新服务

在 `services.js` 的 `SERVICE_DEFINITIONS` 数组中添加一条记录即可。

### 字段说明

| 字段 | 必填 | 说明 |
|------|------|------|
| `id` | ✅ | OpenWrt init.d 服务名，对应 `/etc/init.d/<id>` |
| `name` | ✅ | 在页面上显示的中文名称 |
| `desc` | ✅ | 服务功能描述 |
| `management_link` | ❌ | 指向管理页面的链接，无则填 `null` |

### 示例

```javascript
var SERVICE_DEFINITIONS = [
    {
        id: 'dockerd',
        name: 'Docker',
        desc: 'Docker容器引擎，用于运行和管理容器化应用',
        management_link: null
    },
    {
        id: 'nginx',
        name: 'Nginx',
        desc: '高性能Web服务器和反向代理',
        management_link: null
    }
];
```

### 完整修改步骤

1. 在 `services.js` 的 `SERVICE_DEFINITIONS` 数组中添加服务条目
2. 在 `root/etc/uci-defaults/99-disable-services` 中添加对应的 stop + disable 命令
3. 更新 Makefile 中的 `PKG_VERSION`
4. 更新 `po/` 目录下的翻译文件（如需要新翻译字符串）

---

## 首次安装禁用规则

**核心原则：** 所有通过此页面管理的服务，首次安装后必须处于停止状态（`running: false` + `enabled: false`）。

如果某个服务的安装包（如 dockerd）自带开机自启链接（`/etc/rc.d/S*`），必须在 `root/etc/uci-defaults/99-disable-services` 中先 stop 再 disable。该脚本由 OpenWrt 在首次启动时自动执行一次后删除。

```sh
#!/bin/sh
[ -x /etc/init.d/dockerd ] && {
    /etc/init.d/dockerd stop 2>/dev/null
    /etc/init.d/dockerd disable 2>/dev/null
}
[ -x /etc/init.d/nginx ] && {
    /etc/init.d/nginx stop 2>/dev/null
    /etc/init.d/nginx disable 2>/dev/null
}
[ -x /etc/init.d/uuplugin ] && {
    /etc/init.d/uuplugin stop 2>/dev/null
    /etc/init.d/uuplugin disable 2>/dev/null
}
exit 0
```

---

## 故障排查

### 服务状态不更新

- 确认 `rpcd` 已重启使 ACL 生效：`/etc/init.d/rpcd restart`
- 确认 `rc.list` 返回值正确：`ubus call rc list '{"name":"dockerd"}'`
- 浏览器强制刷新（Ctrl+F5）清除 JS 缓存

### 服务操作无响应

- 确认 ACL 授权了 `rc.init` 写权限
- 确认 init.d 脚本存在且可执行：`ls -la /etc/init.d/<id>`

### 启动后仍显示"已停止"

这个问题已通过技术架构修复。旧版使用 `file.exec` + `/etc/init.d/<id> running` 存在 rpc.declare 的 `expect` 解包问题及 procd 清理延迟假阳性，现已统一改用 `rc.list` 直接查询 procd 状态。
