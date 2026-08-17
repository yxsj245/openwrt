# Docker 数据跨固件升级持久化

## 设计目标

Docker 的默认数据目录为 `/opt/docker`。如果该目录位于 OpenWrt 根分区，x86 固件升级重写根分区后，容器、镜像和卷会一起丢失。

本项目使用同一系统盘上的独立 ext4 分区保存 Docker 数据：

- 文件系统标签固定为 `docker_data`，避免依赖可能变化的 `/dev/nvme*` 或 `/dev/sd*` 设备名。
- 挂载点沿用 `/opt/docker`，无需修改 dockerd 的数据目录。
- `docker-persistence` 包会在首次启动时按标签写入 `/etc/config/fstab`。
- 一次性迁移命令位于独立的 `docker-persistence-migrate` 包，不会让日常持久化包引入 rsync、tune2fs 及其构建依赖。
- `sysupgrade` 必须保留现有分区表，升级镜像只写入固件包含的启动分区和根分区。

## 首次迁移

目标分区必须是已经创建且未挂载的 ext4 分区。首次迁移时安装可选的 `docker-persistence-migrate` 包，迁移会短暂停止 Docker：

```sh
migrate-docker-data /dev/nvme0n1p3
```

迁移工具会依次执行：

1. 验证目标设备、文件系统类型和挂载状态。
2. 备份 fstab、dockerd 配置和容器清单到 `/root/docker-persistence-backup-*`。
3. 停止 Docker。
4. 将目标文件系统标记为 `docker_data`。
5. 使用 `rsync -aHAX` 复制并校验 Docker 数据。
6. 按文件系统标签配置 fstab。
7. 挂载持久化分区、启动 Docker 并验证 daemon。

迁移成功后，原数据仍留在根分区挂载点下方，直到下一次固件升级，便于迁移后立即回滚。

## 验证

```sh
block info | grep 'LABEL="docker_data"'
mount | grep ' on /opt/docker '
df -hT /opt/docker
docker info --format 'Root={{.DockerRootDir}} Containers={{.Containers}} Images={{.Images}}'
docker ps -a
sysupgrade -l | grep -E 'dockerd|fstab'
```

`/opt/docker` 的挂载源应是独立数据分区，而不是 `/dev/root`。

## 固件升级要求

使用项目 `docs/UPGRADE.md` 中的普通 sysupgrade 流程。不要添加 `-p` 参数；该参数会关闭 x86 平台的现有分区表保留逻辑。

升级前建议检查：

```sh
mount | grep ' on /opt/docker '
docker ps -a
```

升级后再次执行“验证”一节中的命令，确认数据分区先于 Docker 挂载。

## 回滚

迁移脚本执行失败时会自动恢复 fstab 并重新启动原 Docker 数据目录。迁移成功后如需人工回滚：

```sh
/etc/init.d/dockerd stop
umount /opt/docker
cp /root/docker-persistence-backup-*/fstab /etc/config/fstab
/etc/init.d/dockerd start
```

确认原容器恢复后，再决定是否清理数据分区。
