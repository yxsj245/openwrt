# 定制开发通用性
当前分支是基于main分支tag `v25.12.4` 的定制开发通用性分支。下面是各分支的说明：


# 开发说明
## 编译
```bash
# 安装依赖
./scripts/feeds update -a
./scripts/feeds install -a
# 编译选择菜单
make menuconfig
# 开始编译
make download -j$(nproc)
make V=s -j$(nproc) 2>&1 | grep -i error
```

## 清理缓存
```bash
make clean
```