---
title: 数据盘挂载与 LVM 创建
date: 2024-12-11 12:17:25
tags:
  - Mount
  - Linux
  - LVM
category: Linux
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在服务器环境中，使用逻辑卷管理器（LVM）配置和挂载数据盘是一种灵活高效的方式。本文介绍了在 CentOS 和其他常见 Linux 系统中，如何使用 LVM 将新数据盘挂载到 /data 目录。我们详细讲解了从安装 LVM 工具、初始化物理卷、创建卷组和逻辑卷，到创建文件系统、挂载逻辑卷以及设置开机自动挂载的步骤。此外，还提供了适用于不同 Linux 系统的注意事项和扩展管理技巧。通过这些步骤，你可以实现数据盘的灵活管理和高效利用。

<!-- more -->

### **前置检查**
1. 确保目标硬盘（`vdb`）是新磁盘或非关键数据盘。
2. 验证系统是否检测到硬盘：
   ```bash
   lsblk
   ```
   找到 `vdb`，确认其未分区或挂载。

---

### **安装 LVM 工具**

- **CentOS/Red Hat 系统**:
  ```bash
  sudo yum install -y lvm2
  ```

- **Debian/Ubuntu 系统**:
  ```bash
  sudo apt update
  sudo apt install -y lvm2
  ```

- **OpenSUSE 系统**:
  ```bash
  sudo zypper install -y lvm2
  ```

---

### **LVM 配置步骤**

#### 初始化物理卷 (PV)
将 `vdb` 初始化为 LVM 的物理卷：
```bash
sudo pvcreate /dev/vdb
```

验证创建是否成功：
```bash
sudo pvdisplay
```

---

#### 创建卷组 (VG)
创建一个新的卷组 `vg_data`，并将 `vdb` 添加到该卷组：
```bash
sudo vgcreate vg_data /dev/vdb
```

检查卷组信息：
```bash
sudo vgdisplay
```

---

#### 创建逻辑卷 (LV)
在卷组 `vg_data` 中创建逻辑卷 `lv_data`：
- 使用所有剩余空间：
  ```bash
  sudo lvcreate -l +100%FREE -n lv_data vg_data
  ```
- 或者指定大小（如 100GB）：
  ```bash
  sudo lvcreate -L 100G -n lv_data vg_data
  ```

验证逻辑卷：
```bash
sudo lvdisplay
```

---

#### 创建文件系统
为逻辑卷 `lv_data` 创建 EXT4 文件系统：
```bash
sudo mkfs.ext4 /dev/vg_data/lv_data
```

---

#### 挂载逻辑卷
1. 创建挂载点：
   ```bash
   sudo mkdir -p /data
   ```

2. 挂载逻辑卷到 `/data`：
   ```bash
   sudo mount /dev/vg_data/lv_data /data
   ```

3. 确认挂载成功：
   ```bash
   df -h | grep /data
   ```

---

#### 设置开机自动挂载
编辑 `/etc/fstab` 文件，使逻辑卷在开机时自动挂载：
```bash
sudo vim /etc/fstab
```

在文件末尾添加以下内容：
```
/dev/vg_data/lv_data /data ext4 defaults 0 0
```

测试 `fstab` 配置是否正确：
```bash
sudo umount /data
sudo mount -a
```
如果没有错误，挂载设置无误。

---

### **其他 Linux 系统的注意事项**
1. **文件系统支持**:  
   不同发行版可能默认支持不同文件系统（如 `XFS` 或 `Btrfs`）。可以根据需求替换 `mkfs.ext4` 为适合的文件系统命令，例如：
   ```bash
   sudo mkfs.xfs /dev/vg_data/lv_data
   ```

2. **卷组管理**:  
   如果有多个硬盘，可将多个物理卷（如 `/dev/vdb` 和 `/dev/vdc`）加入同一卷组：
   ```bash
   sudo vgextend vg_data /dev/vdc
   ```

3. **调整逻辑卷大小**:  
   如果需要扩展逻辑卷：
   ```bash
   sudo lvextend -L +50G /dev/vg_data/lv_data
   sudo resize2fs /dev/vg_data/lv_data
   ```

---

### **总结**
通过以上步骤，我们成功配置了数据盘并挂载到 `/data`。这种使用 LVM 的方式不仅提供了灵活的卷管理能力，还能在未来需要时动态扩展存储，避免繁琐的重新分区操作。

确保在生产环境操作前备份重要数据，执行步骤时严格按照实际需求调整命令。
