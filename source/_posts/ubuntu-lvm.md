---
title: 如何给 Ubuntu 系统做 LVM 拓展
date: 2024-12-27 12:57:25
tags:
    - Linux
    - Ubuntu
    - LVM
category: Ubuntu
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在本篇文章中，我们将详细介绍如何在 Ubuntu 系统中扩展 LVM 分区。通过具体演示 Ubuntu 22.04 LTS 环境下的磁盘配置，我们将展示如何检查现有的逻辑卷和卷组状态，并为逻辑卷分配剩余空间。在完成这些步骤后，我们还将调整文件系统大小，以确保能够充分利用新分配的空间。

<!-- more -->

> 这里以`Ubuntu 22.04 LTS` 环境举例。

### 问题场景

这里是磁盘情况：
```shell
root@ubuntu:~# lsblk
NAME                      MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
loop0                       7:0    0  63.9M  1 loop /snap/core20/2318
loop1                       7:1    0  63.7M  1 loop /snap/core20/2434
loop2                       7:2    0    87M  1 loop /snap/lxd/29351
loop3                       7:3    0  89.4M  1 loop /snap/lxd/31333
loop4                       7:4    0  38.8M  1 loop /snap/snapd/21759
loop5                       7:5    0  44.3M  1 loop /snap/snapd/23258
nvme0n1                   259:0    0 931.5G  0 disk
├─nvme0n1p1               259:1    0     1G  0 part /boot/efi
├─nvme0n1p2               259:2    0     2G  0 part /boot
└─nvme0n1p3               259:3    0 928.5G  0 part
  └─ubuntu-vg-ubuntu-lv   253:0    0   100G  0 lvm  /
```
可以看到，当前有一个分区 `nvme0n1p3`，大小为 `928.5G`，但只使用了 `100G`，所以需要将现在 lv 空间拓展到100%。

### 检查分区和逻辑卷

运行以下命令检查现有的逻辑卷和卷组状态：

```shell
lsblk
df -Th
sudo vgdisplay
sudo lvdisplay
```
确认 `ubuntu-vg` 是卷组名称，`ubuntu-lv` 是逻辑卷名称。

---

### 扩展逻辑卷

为逻辑卷 `ubuntu-vg/ubuntu-lv` 分配全部剩余空间：

```shell
sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
```

---

### 查看文件系统
运行以下命令查看文件系统类型：

```shell
lsblk -f
df -Th
```

输出中会显示 `FSTYPE` 列，指示逻辑卷（如 `/dev/mapper/ubuntu-vg-ubuntu-lv`）的文件系统类型。 通常，是`ext4`。

---

### 5. 调整文件系统大小

扩展逻辑卷后，需要调整文件系统大小以使用新分配的空间。

#### 如果是 Ext4 文件系统：

```shell
sudo resize2fs /dev/ubuntu-vg/ubuntu-lv
```

#### 如果是 XFS 文件系统：

```shell
sudo xfs_growfs /dev/ubuntu-vg/ubuntu-lv
```

---

### 6. 验证扩展结果

运行以下命令确认 `/` 的大小已扩展：

```shell
df -Th 
lsblk
```

---

### 注意事项

- **备份数据**：执行分区操作前请备份重要数据。
- **运行环境**：确保没有其他服务占用相关的磁盘或逻辑卷，以免影响操作。