---
title: 数据盘挂载与 GPT 分区
date: 2024-12-26 12:00:00
tags:
  - Linux
  - GPT
  - Mount
categories:
  - Linux
---



&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在 Linux 系统中，磁盘分区和挂载是常见的管理任务，尤其在添加新的数据盘时。对于大于 2TB 的磁盘，通常需要使用 GPT（GUID Partition Table）分区模式，因为传统的 MBR（Master Boot Record）分区表不支持超过 2TB 的磁盘容量。在本文中，我们将展示如何使用 GPT 分区表创建分区，格式化为 `ext4` 文件系统，并挂载到指定目录。此外，还会介绍如何配置系统，以确保在系统重启后能够自动挂载磁盘。最终，您将学会如何有效地管理 Linux 系统中的大容量磁盘，确保数据安全与系统稳定。

<!-- more -->

### 创建 GPT 分区表

使用 `parted` 工具在 `/dev/sdb` 磁盘上创建一个新的 GPT 分区表：

```shell
parted /dev/sdb mklabel gpt
```



### 创建分区

创建一个占用整个磁盘的主分区，并格式化为 `ext4` 文件系统：

```shell
parted /dev/sdb mkpart primary ext4 0% 100%
```

等待分区操作完成。

### 格式化分区

格式化新创建的分区 `/dev/sdb1`：

```shell
mkfs.ext4 /dev/sdb1
```

### 挂载分区

创建一个挂载点 `/data` 并挂载新分区：

```shell
mkdir /data
mount /dev/sdb1 /data
```

### 永久挂载设置

为了使挂载在启动时自动进行，需要编辑 `/etc/fstab` 文件：

```shell
echo "/dev/sdb1 /data ext4 defaults 0 2" >> /etc/fstab
```

运行以下命令以验证配置是否正确：

```shell
mount -a
```

### 确认磁盘已成功挂载

使用 `df -Th` 命令查看所有文件系统及其类型，确认 `/dev/sdb1` 是否正确挂载在 `/data` 下：

```shell
df -Th
```

### 查看块设备信息

使用 `lsblk` 命令查看所有块设备的挂载点和大小，确认挂载情况：

```shell
lsblk
```

### 获取磁盘 UUID

使用 `blkid` 命令获取 `/dev/sdb1` 的 UUID，这有助于 `/etc/fstab` 中的稳定性配置：

```shell
blkid /dev/sdb1
```

可以使用这个 UUID 替换 `/etc/fstab` 中的设备名，以确保即使设备名变化，挂载依然稳定：

```shell
echo "UUID=$(blkid -s UUID -o value /dev/sdb1) /data ext4 defaults 0 2" >> /etc/fstab
```

------



### 总结

此文档提供了从创建 GPT 分区表到挂载和确认分区的完整步骤。在每一步操作后，建议使用校验命令（如 `lsblk` 和 `df -Th`）确保配置的正确性。这种分区和挂载方式可以适应多种场景，并确保数据存储的安全与稳定。