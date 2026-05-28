# OP 虚拟机调试指南

当 OpenWrt 虚拟机（192.168.122.3）上的 Web 页面或服务表现不符合预期时，按本文档流程进行调试。

---

## 1. 浏览器缓存优先排查

OpenWrt LuCI 的 JS/CSS 资源文件容易被浏览器缓存。当页面行为异常时，**第一优先级**确认是否为缓存问题。

### 验证方法

在目标 JS 文件的页面标题或关键文案后面追加临时标记：

```bash
ssh root@192.168.122.3 "sed -i \"s/_('原文本')/_('原文本V2')/\" /www/luci-static/resources/view/xxx/xxx.js"
```

让用户强制刷新（Ctrl+Shift+R 或 Ctrl+F5），确认是否加载了新文件。确认后还原标记。

---

## 2. 文件部署管线（VM 调试专用）

**禁止**直接在 VM 上用 `sed`/`python`/`cat` 等方式修改文件 —— ash shell 转义问题极易导致文件损坏。必须遵循以下管线：

```
IDE 修改代码 → 自动同步编译机 → scp 上传到 OP 虚拟机 → 重启相关服务
```

### 步骤

| 步骤 | 操作 | 示例 |
|------|------|------|
| ① | IDE 中修改源码文件 | 修改 `package/luci-app-services/.../services.js` |
| ② | 验证编译机同步 | `grep "关键词" /opt/project/openwrt/package/.../目标文件` |
| ③ | scp 上传到 OP | `scp /opt/project/openwrt/.../源文件 root@192.168.122.3:<目标路径>` |
| ④ | 重启相关服务 | `/etc/init.d/rpcd restart` 或 `/etc/init.d/uhttpd restart` |

---

## 3. 服务状态调试

当服务管理页面状态显示异常时，使用以下命令链诊断：

### 诊断命令链

```bash
# ① 检查 rc.list（procd 注册状态，jail 服务可能无 running 字段）
ubus call rc list '{"name":"<服务名>"}'

# ② 检查 service.list（procd 实例状态，始终有 running 字段）
ubus call service list '{"name":"<服务名>"}'

# ③ 检查进程是否在运行
ps | grep <服务名>

# ④ 检查服务 init.d 状态
/etc/init.d/<服务名> status
```

### 已知问题

使用 `procd_add_jail` 的服务（如 adguardhome），`rc.list` **不会**返回 `running` 字段（只返回 `start`、`stop`、`enabled`），但 `service.list` 会正确返回 `running: true`。

| 服务类型 | `rc.list` 返回 `running` | `service.list` 返回 `running` |
|---------|--------------------------|------------------------------|
| 普通 procd 服务（如 dockerd） | ✅ | ✅ |
| jail 服务（如 adguardhome） | ❌ | ✅ |

### 解决方案

在 `services.js` 的 `getServiceStatus` 中增加回退逻辑：当 `rc.list` 不包含 `running` 字段时，自动调用 `service.list` 检测运行状态。

---

## 4. rpcd ACL 权限调试

当 Web 页面的 RPC 调用失败时，检查 ACL 权限链：

### 诊断命令链

```bash
# ① 检查 ACL 配置文件
cat /usr/share/rpcd/acl.d/<app名>.json

# ② 获取当前登录会话 ID
ubus call session list | grep ubus_rpc_session | grep -v 00000000

# ③ 检查会话的 ubus 权限（替换 <session_id>）
ubus call session list | sed -n '/<session_id>/,/"data"/p' | grep -E '"rc"|"service"' -A 3

# ④ 重启 rpcd 使 ACL 生效
/etc/init.d/rpcd restart
```

### ACL 文件示例

```json
{
    "luci-app-services": {
        "description": "Grant access to service management",
        "read": {
            "ubus": {
                "rc": [ "init", "list" ],
                "service": [ "list" ]
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

## 5. 常见陷阱速查

| 现象 | 可能原因 | 排查动作 |
|------|---------|---------|
| 页面 JS 修改不生效 | 浏览器缓存 | 添加视觉标记验证 + 强制刷新 |
| 服务状态始终「已停止」 | jail 服务 + `rc.list` 无 `running` 字段 | 检查 `ubus call service list` |
| RPC 调用无响应 | rpcd ACL 未授权或未重启 | 检查 ACL 文件 + 重启 rpcd |
| scp 上传后文件不生效 | uhttpd 缓存 / 未重启相关服务 | 重启 uhttpd 或 rpcd |
| 服务操作报权限错误 | 会话缺少对应 ubus 权限 | `ubus call session list` 检查会话 ACL |
