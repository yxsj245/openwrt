# LuCI 应用包开发规范

编写新的 `luci-app-*` 包时，必须遵循以下规范。违反任何一条都可能导致包不被编译系统识别、服务无法启动、或 LuCI 页面无法显示。

---

## 1. Makefile 必须包含 BuildPackage 签名

OpenWrt 构建系统通过 `grep 'call BuildPackage'` 扫描 `package/` 目录下的 Makefile 来发现包。**缺少此签名行的 Makefile 会被完全忽略，不会报任何错误，只是静默跳过。**

### 正确写法

```makefile
include $(TOPDIR)/rules.mk

LUCI_TITLE:=我的应用
LUCI_DEPENDS:=+luci-base

include ../../feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
```

### 错误写法

```makefile
include $(TOPDIR)/rules.mk

LUCI_TITLE:=我的应用
LUCI_DEPENDS:=+luci-base

include ../../feeds/luci/luci.mk
# ← 缺少签名行，包不会被发现
```

### 排查方法

```bash
# 检查包是否被构建系统索引
grep "your-package-name" tmp/.packagedeps
# 如果无输出，说明 Makefile 未被识别

# 手动验证签名行
grep 'call BuildPackage' package/your-package/Makefile
```

---

## 2. 所有关键文件必须使用 LF 换行符

Windows 编辑器默认保存为 CRLF，但 OpenWrt 构建系统的 shell 脚本和 make 工具无法正确解析 CRLF 文件。

### 受影响的关键文件类型

| 文件类型 | CRLF 导致的问题 |
|----------|----------------|
| `Makefile` / `*.mk` | 构建系统无法解析，包不被识别 |
| `*.sh` / `init.d/*` | shell 执行报错或行为异常 |
| `*.js` | LuCI 页面加载失败（jsmin 压缩器不兼容 CRLF） |

### 保障措施

项目已配置三重防护：

1. **`.editorconfig`** — VSCode 保存时自动使用 LF（编辑器层面）
2. **`.gitattributes`** — git checkout 时强制 LF（版本控制层面）
3. **编译前检查** — 如怀疑换行符问题，在编译机上执行：
   ```bash
   find package/your-package/ -type f -exec file {} \; | grep CRLF
   # 如有输出，批量修复：
   find package/your-package/ -type f -name 'Makefile' -exec sed -i 's/\r$//' {} \;
   find package/your-package/ -type f -name '*.sh' -exec sed -i 's/\r$//' {} \;
   ```

---

## 3. init.d 脚本必须始终向 procd 注册实例

使用 procd 的 init.d 脚本，`start_service()` 中**必须无条件调用 `procd_open_instance`**，否则服务在 LuCI 服务管理页面会始终显示"已停止"。

### 常见错误模式

将功能开关与 procd 注册耦合——当 UCI 配置中某开关为关闭时，跳过 `procd_open_instance`：

```sh
# ❌ 错误：enabled=0 时不注册 procd，服务显示"已停止"
start_service() {
    apply_rules || return   # enabled=0 时 return，不注册 procd
    procd_open_instance
    procd_set_param command /bin/busybox sleep 365d
    procd_close_instance
}
```

### 正确写法

始终注册 procd 实例，功能开关仅控制是否执行具体逻辑（如 nftables 规则）：

```sh
# ✅ 正确：始终注册 procd，功能开关只控制规则是否生效
start_service() {
    if [ "$(uci_get clientlimit.settings.enabled)" = "1" ]; then
        apply_rules
    fi

    procd_open_instance
    procd_set_param command /bin/busybox sleep 365d
    procd_set_param respawn
    procd_close_instance
}
```

### 设计原则

- **procd 注册** = 让 LuCI 和系统知道"这个服务存在且正在运行"
- **功能开关** = 控制"这个服务的具体功能是否生效"
- 两者必须解耦，服务应始终向 procd 报到

---

## 4. UCI section 命名必须与 LuCI JS 匹配

### 问题说明

LuCI 的 `form.NamedSection(name, type, ...)` 需要通过 section 名称查找 UCI section。匿名 section（`config settings`）没有名称，`NamedSection` 无法找到它。

### UCI 配置文件写法

```bash
# ❌ 错误：匿名 section，NamedSection('settings', ...) 找不到
config settings
    option enabled '0'

# ✅ 正确：显式命名，NamedSection('settings', 'settings') 可以找到
config settings 'settings'
    option enabled '0'
```

### JS 对应写法

```javascript
// NamedSection(名称, 类型)
// 名称 = UCI section 的名称标识
// 类型 = UCI section 的 config 类型（用于校验）
s = m.section(form.NamedSection, 'settings', 'settings');
```

### 类型参数说明

`NamedSection` 第二个参数是 UCI section 的**类型**（即 `config <type>` 中的 `<type>`），不是包名。类型不匹配会导致 section 不显示。

```javascript
// ❌ 错误：类型参数写成了包名
s = m.section(form.NamedSection, 'settings', 'clientlimit');

// ✅ 正确：类型参数与 UCI config 行一致
s = m.section(form.NamedSection, 'settings', 'settings');
```

### GridSection / TypedSection

`GridSection` 和 `TypedSection` 按**类型**匹配所有 section，不要求命名，适用于多个同类 section 的场景（如多条限速规则）：

```javascript
// GridSection 按 'client' 类型匹配所有 section，无需命名
s = m.section(form.GridSection, 'client', _('客户端限速规则'));
```

---

## 5. init.d 脚本文件权限

init.d 脚本需要可执行权限。由于 Windows 不支持 Unix 权限位，SFTP 同步的文件可能缺少执行权限。

### 验证与修复

```bash
# 在 VM 上检查
ls -la /etc/init.d/your-service
# 如果没有 x 权限：
chmod +x /etc/init.d/your-service
```

### 编译机上的预防措施

在编译机的源码目录中设置权限，构建系统会保留该权限到安装包：

```bash
chmod +x package/your-package/root/etc/init.d/your-service
```

---

## 自检清单

新建 `luci-app-*` 包后，逐一确认：

- [ ] Makefile 末尾有 `# call BuildPackage - OpenWrt buildroot signature`
- [ ] 所有 `.mk`、`Makefile`、`.sh`、`.js` 文件使用 LF 换行符
- [ ] `start_service()` 无条件调用 `procd_open_instance`
- [ ] UCI config 中被 `NamedSection` 引用的 section 有显式命名（`config type 'name'`）
- [ ] `NamedSection` 的类型参数与 UCI `config <type>` 一致
- [ ] init.d 脚本在编译机上有可执行权限
- [ ] `make defconfig` 后 `.config` 中包含 `CONFIG_PACKAGE_luci-app-*=y`
