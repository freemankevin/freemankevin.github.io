---
title: Linux 传统 MBR 分区与小容量磁盘挂载指南
date: 2025-01-01 09:37:20
keywords:
  - MBR
  - DiskPartition
  - Mount
  - Storage
categories:
  - Linux
  - Storage
tags:
  - MBR
  - Partition
  - Mount
  - fdisk
---

MBR（Master Boot Record）分区表是小容量磁盘（≤2TB）的传统管理方案，适用于传统BIOS系统和兼容性要求场景。本指南涵盖 MBR 分区创建、文件系统格式化、自动化挂载和注意事项，适用于传统系统环境和小容量存储部署。

<!-- more -->

## MBR 分区架构概述

### MBR 分区类型限制

```
MBR 分区结构（最大4个主分区）：
┌──────────────────────────────────┐
│  Primary Partition 1             │  主分区1
│  Primary Partition 2             │  主分区2
│  Primary Partition 3             │  主分区3
│  ┌──────────────────────────┐   │
│  │ Extended Partition        │   │  扩展分区（容器）
│  │  ┌──────────────────────┐ │   │
│  │  │ Logical Partition 1  │ │   │  逻辑分区1
│  │  │ Logical Partition 2  │ │   │  逻辑分区2
│  │  │ Logical Partition N  │ │   │  逻辑分区N
│  │  └──────────────────────┘ │   │
│  └──────────────────────────┘   │
└──────────────────────────────────┘

容量限制：单个分区最大2TB
```

### MBR 适用场景判断

| 场景特征 | 推荐方案 | 说明 |
|---------|---------|------|
| 磁盘容量 ≤2TB | MBR | 传统方案足够 |
| 传统BIOS系统 | MBR | 系统兼容性 |
| 4个以下分区 | MBR | 主分区足够 |
| 磁盘容量 >2TB | GPT | 必须升级 |
| UEFI系统 | GPT | 系统要求 |
| 数据安全优先 | GPT | CRC校验 |

### 分区工具对比

| 工具 | 功能 | 适用性 | 生产场景 |
|------|------|--------|----------|
| fdisk | MBR专用 | 传统系统 | 小容量磁盘 |
| parted | MBR/GPT | 全功能 | 灵活选择 |
| cfdisk | 图形界面 | 简单操作 | 快速分区 |

### 生产注意事项

| 注意点 | 说明 | 影响 |
|---------|------|------|
| 容量限制 | 单分区≤2TB | 超过需GPT |
| 分区数量 | 主分区最多4个 | 需扩展分区 |
| 数据安全 | 无校验机制 | 损坏风险高 |
| 系统兼容 | 传统BIOS系统 | 启动兼容性 |
| 扩展分区 | 配置复杂 | 管理难度增加 |

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