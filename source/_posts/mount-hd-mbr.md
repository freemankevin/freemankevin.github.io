---
title: 数据盘挂载与 MBR 分区
date: 2025-01-01 09:37:20
tags:
    - Mount
    - MBR
    - Linux
category: Linux
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 本文详细讲解了如何在 Linux 系统中挂载数据盘并使用 MBR 分区表进行分区的完整流程，包括使用 `fdisk` 创建分区、格式化为 `ext4` 文件系统，以及配置永久挂载设置。文中提供了从创建挂载点到编辑 `/etc/fstab` 的具体命令，同时介绍了使用 `lsblk`、`blkid` 等工具确认磁盘挂载状态的方法。通过这篇指南，您可以轻松完成数据盘的挂载和管理，确保磁盘稳定性和数据安全性。

<!-- more -->

### 划分磁盘

使用 `fdisk` 工具对 `/dev/sdb` 磁盘进行分区：

```bash
fdisk /dev/sdb
```

在 `fdisk` 命令模式下，您可以使用以下命令进行分区：

- `n` 创建新分区
- `p` 选择主分区
- `1` 分区号
- 回车两次接受默认的起始和结束扇区
- `w` 保存并退出

### 格式化分区

格式化新创建的分区为 `ext4` 文件系统：

```bash
mkfs.ext4 /dev/sdb1
```

### 挂载分区

创建挂载点并挂载新分区：

```bash
mkdir /data
mount /dev/sdb1 /data
```

### 永久挂载设置

编辑 `/etc/fstab` 文件，添加以下行以实现开机自动挂载：

```bash
echo "/dev/sdb1 /data ext4 defaults 0 2" >> /etc/fstab
```

运行 `mount -a` 来挂载所有在 `/etc/fstab` 中定义的文件系统，确保没有错误：

```bash
mount -a
```

### 确认磁盘已成功挂载

使用 `df -Th` 查看所有文件系统及其类型：

```bash
df -Th
```

这将显示所有挂载的文件系统，您应该能看到 `/dev/sdb1` 在 `/data` 目录下。

### 查看块设备信息

使用 `lsblk` 查看所有块设备的挂载点和大小：

```bash
lsblk
```

确认 `/dev/sdb1` 是否正确挂载在 `/data`。

### 获取磁盘 UUID

使用 `blkid` 获取 `/dev/sdb1` 的 UUID：

```bash
blkid /dev/sdb1
```

这个 UUID 可用于 `/etc/fstab` 中，以代替设备名，使挂载更稳定：

```bash
UUID=[你的UUID] /data ext4 defaults 0 2
```

替换 `[你的UUID]` 为实际得到的 UUID，然后再次运行 `mount -a` 确认设置正确。

### 总结

以上步骤提供了完整的流程，从分区、格式化到挂载以及确认设置的正确性。务必在每次操作后使用检查命令确认配置的正确性，确保数据盘的稳定性和数据的安全。