---
title: 从传统分区到LVM统一存储的完整迁移实践
date: 2025-09-16 10:10:00
tags:
  - Linux
  - LVM
  - 数据迁移
# comments: true
category: Linux
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在企业级Linux服务器管理中，存储扩展和数据迁移是运维工程师经常面临的挑战。本文将详细记录一次真实的生产环境存储重构项目：将分散在多个传统分区的数据统一迁移到LVM（Logical Volume Manager）管理的大容量存储中，实现存储的统一管理和动态扩展。

<!-- more -->

## 项目背景与需求分析

### 原始环境状况

我们的服务器配置如下：
- 系统盘：SDA 446.6GB（根分区、EFI分区）
- 数据盘1：NVMe0n1 3.5TB（已分区，挂载到 `/data`）
- 数据盘2：NVMe1n1 3.5TB（未使用）

```bash
NAME               MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
sda                  8:0    0 446.6G  0 disk
├─sda1               8:1    0     1G  0 part /boot/efi
├─sda2               8:2    0 445.6G  0 part /
└─sda3               8:3    0    65M  0 part
nvme0n1            259:0    0   3.5T  0 disk
└─nvme0n1p1        259:3    0 931.3G  0 part /data
nvme1n1            259:1    0   3.5T  0 disk
```

### 面临的问题

1. **存储分散**：数据分散在 `/data` 和 `/home` 等多个挂载点
2. **扩展困难**：传统分区无法动态调整大小
3. **资源浪费**：NVMe1n1 完全未使用
4. **管理复杂**：多个独立分区增加了管理复杂度

### 目标架构设计

设计一个统一的LVM存储架构：
- 将两块NVMe盘整合为单一卷组（Volume Group）
- 创建大容量逻辑卷，提供约7TB可用空间
- 通过软链接保持应用程序路径兼容性
- 实现存储的统一管理和动态扩展能力

## LVM技术原理深度解析

### LVM架构层次

LVM采用三层架构设计，从底层到上层分别是：

```
应用层          文件系统 (ext4/xfs)
逻辑层    ←     逻辑卷 (Logical Volume)
组管理层  ←     卷组 (Volume Group)  
物理层    ←     物理卷 (Physical Volume)
硬件层          物理磁盘 (/dev/nvme0n1, /dev/nvme1n1)
```

#### Physical Volume (PV)
物理卷是LVM的基础构建块，将物理存储设备（硬盘、分区）转换为LVM可管理的格式：

```bash
# PV创建过程中的关键操作
pvcreate /dev/nvme1n1
# 在磁盘开头写入LVM标签和元数据
# 划分PE (Physical Extent) 单位，默认4MB
```

#### Volume Group (VG)
卷组将多个物理卷聚合为统一的存储池：

```bash
vgcreate data_vg /dev/nvme1n1
# 创建卷组元数据
# 建立PE到VG的映射关系
# 提供统一的存储地址空间
```

#### Logical Volume (LV)
逻辑卷是用户实际使用的存储单元，具有以下特性：
- **动态扩展**：可在线扩展容量
- **快照支持**：支持一致性备份
- **条带化**：支持多磁盘并行I/O

### LVM vs 传统分区对比

| 特性 | 传统分区 | LVM |
|------|---------|-----|
| 大小调整 | 困难，通常需要重建 | 在线动态调整 |
| 跨磁盘 | 不支持 | 支持跨多个物理磁盘 |
| 快照 | 不支持 | 支持CoW快照 |
| 性能 | 单磁盘性能 | 支持条带化提升性能 |
| 管理复杂度 | 简单 | 中等，但功能强大 |

## 实施方案详细步骤

### 阶段一：LVM基础设施构建

#### 1.1 创建物理卷

首先将NVMe1n1磁盘转换为LVM物理卷：

```bash
# 创建物理卷，写入LVM元数据
pvcreate /dev/nvme1n1

# 验证PV创建结果
pvdisplay /dev/nvme1n1
```

物理卷创建过程中，LVM会在磁盘开头写入以下信息：
- LVM标签（LVM2_member）
- 物理卷UUID
- 卷组名称
- PE大小和数量

#### 1.2 创建卷组

```bash
# 创建卷组，将PV加入存储池
vgcreate data_vg /dev/nvme1n1

# 查看卷组信息
vgdisplay data_vg
```

卷组创建后的关键参数：
- **PE Size**: 4.00 MiB（默认）
- **Total PE**: 约915,707个PE
- **Allocatable**: 是否可分配空间

#### 1.3 创建逻辑卷

```bash
# 创建逻辑卷，使用所有可用空间
lvcreate -l 100%FREE -n data1_lv data_vg

# 验证逻辑卷状态
lvdisplay /dev/data_vg/data1_lv
```

关键参数说明：
- `-l 100%FREE`: 使用所有可用的逻辑分区单元
- `-n data1_lv`: 指定逻辑卷名称
- `data_vg`: 目标卷组名称

#### 1.4 文件系统创建

```bash
# 创建ext4文件系统
mkfs.ext4 /dev/data_vg/data1_lv

# 优化参数（可选）
mkfs.ext4 -b 4096 -E stride=32,stripe-width=64 /dev/data_vg/data1_lv
```

### 阶段二：数据迁移策略与实施

#### 2.1 迁移准备工作

```bash
# 创建挂载点
mkdir /data1
mount /dev/data_vg/data1_lv /data1

# 创建目标目录结构
mkdir /data1/data_backup
mkdir /data1/home_backup
```

#### 2.2 数据完整性迁移

使用rsync进行增量同步，保证数据一致性：

```bash
# 迁移/data数据，保持所有属性
nohup rsync -avxHAX --progress \
    --exclude='lost+found' \
    /data/ /data1/data_backup/ \
    > /data1/data_backup.log 2>&1 &

# 迁移/home数据（确保没有用户登陆，已登陆用户请踢出）
nohup rsync -avxHAX --progress \
    --exclude='lost+found' \
    /home/ /data1/home_backup/ \
    > /data1/home_backup.log 2>&1 &
```

rsync参数详解：
- `-a`: 归档模式，保持权限、时间戳等
- `-v`: 详细输出
- `-x`: 不跨文件系统
- `-H`: 保持硬链接
- `-A`: 保持ACL
- `-X`: 保持扩展属性
- `--progress`: 显示进度

#### 2.3 数据完整性验证

```bash
# 比较文件数量
find /data -type f | wc -l
find /data1/data_backup -type f | wc -l

# 比较总大小
du -sh /data
du -sh /data1/data_backup

# 使用校验和验证（可选，耗时较长）
find /data -type f -exec md5sum {} \; | sort > /tmp/original.md5
cd /data1/data_backup
find . -type f -exec md5sum {} \; | sort > /tmp/backup.md5
diff /tmp/original.md5 /tmp/backup.md5
```

### 阶段三：系统切换与进程处理

#### 3.1 进程排查与处理

在卸载原分区前，必须确保没有进程占用：

```bash
# 查找占用/data的进程
lsof +D /data

# 示例输出分析
COMMAND       PID USER   FD   TYPE DEVICE   SIZE/OFF     NODE NAME
sftp-serv 1528862 root    3r   REG  259,3 8776906927 11273975 /data/opt/...
```

发现SFTP进程正在传输大文件，这解释了为什么"静态文件"会有进程占用。

#### 3.2 优雅停止服务

```bash
# 停止相关服务
systemctl stop docker

# 强制终止占用进程（谨慎使用）
fuser -km /data

# 或者单独终止特定进程
kill -15 1528862  # 温和终止
kill -9 1528862   # 强制终止
```

#### 3.3 安全卸载与切换

```bash
# 备份fstab
cp /etc/fstab /etc/fstab.backup

# 卸载原分区
umount /data
# 如果busy，使用懒卸载
umount -l /data

# 重命名原目录（保留备份）
mv /data /data.old
mv /home /home.old

# 创建软链接
ln -s /data1/data_backup /data
ln -s /data1/home_backup /home
```

### 阶段四：存储池扩展

#### 4.1 第二块磁盘处理

NVMe0n1已有分区表，需要清理：

```bash
# 清除分区表和文件系统签名
wipefs -a /dev/nvme0n1

# 输出示例
/dev/nvme0n1: 8 bytes were erased at offset 0x00000200 (gpt): 45 46 49 20 50 41 52 54
/dev/nvme0n1: 8 bytes were erased at offset 0x37e3ee55e00 (gpt): 45 46 49 20 50 41 52 54
/dev/nvme0n1: 2 bytes were erased at offset 0x000001fe (PMBR): 55 aa
```

#### 4.2 扩展LVM存储池

```bash
# 将新磁盘加入物理卷
pvcreate /dev/nvme0n1

# 扩展卷组
vgextend data_vg /dev/nvme0n1

# 扩展逻辑卷
lvextend -l +100%FREE /dev/data_vg/data1_lv

# 扩展文件系统
resize2fs /dev/data_vg/data1_lv
```

#### 4.3 验证扩展结果

```bash
# 查看存储状态
pvdisplay
vgdisplay data_vg
lvdisplay /dev/data_vg/data1_lv
df -Th
```

### 阶段五：系统配置与验证

#### 5.1 更新系统配置

```bash
# 更新fstab，添加新挂载项
echo "/dev/data_vg/data1_lv /data1 ext4 defaults 0 2" >> /etc/fstab

# 验证fstab语法
mount -a
```







