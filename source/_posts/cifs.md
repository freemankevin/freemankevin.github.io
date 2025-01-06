---
title: 创建 CIFS (SMB) 共享并挂载给 Linux 和 Windows 使用
date: 2025-01-06 13:57:25
tags:
    - Linux
    - Windows
    - CIFS
category: Linux
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;本文将指导您如何在 Windows 系统上创建 SMB/CIFS 共享，并展示如何在 Linux 和 Windows 客户端上挂载这些共享。我们还将介绍如何配置防火墙，以确保 SMB/CIFS 通信的安全性，帮助您顺利实现跨平台的文件共享。

<!-- more -->

## 创建 SMB/CIFS 共享

### 在 Windows 上设置共享文件夹

1. **选择并创建文件夹**：如果尚未创建共享文件夹，请右键点击并选择“新建文件夹”。
2. **设置文件夹共享**：右键点击文件夹，选择“属性” > “共享”标签页，点击“高级共享”，勾选“共享此文件夹”并为共享文件夹命名。
3. **配置共享权限**：点击“权限”，为需要访问的用户或用户组配置权限，如“读取”或“完全控制”。

### 记录共享路径

记录下文件夹的共享路径，格式为 `\\ComputerName\SharedFolder`，以便在客户端挂载时使用。

## 在客户端上挂载 SMB/CIFS 共享

### Windows 客户端

1. 打开文件资源管理器，输入共享路径，例如 `\\ComputerName\SharedFolder`。
2. （可选）映射网络驱动器：点击“计算机”选项卡，选择“映射网络驱动器”，指定驱动器字母并输入共享路径。

### Linux 客户端

1. **安装 CIFS 工具包**：确保安装 `cifs-utils`，以支持 SMB 协议：

   对于基于 Debian 的系统（如 Ubuntu）：

   ```bash
   sudo apt update
   sudo apt install cifs-utils
   ```

   对于基于 RHEL 的系统（如 CentOS 或 Fedora）：

   ```bash
   sudo yum install cifs-utils   # CentOS 7 及之前版本
   sudo dnf install cifs-utils   # CentOS 8 及以后版本，Fedora
   ```

2. **创建挂载点**：例如：

   ```bash
   sudo mkdir /mnt/sharedfolder
   ```

3. **手动挂载共享目录**：

   ```bash
   sudo mount -t cifs //ComputerName/SharedFolder /mnt/sharedfolder -o username=yourUsername,password=yourPassword
   ```

4. **自动挂载**：编辑 `/etc/fstab`，添加以下内容：

   ```bash
   //ComputerName/SharedFolder /mnt/sharedfolder cifs username=yourUsername,password=yourPassword,iocharset=utf8 0 0
   ```

## 配置防火墙

确保防火墙允许 SMB/CIFS 通信，开放必要端口：

- **TCP 445**：用于直接通过 TCP/IP 协议的 SMB。
- **TCP 139**：通过 NetBIOS 的 SMB。

### Windows 防火墙配置

1. 打开“防火墙设置” > “高级设置”。
2. 创建新规则，允许 TCP 端口 445 和 139。

### Linux 防火墙配置

使用 `firewalld`：

```bash
sudo firewall-cmd --permanent --add-port=445/tcp
sudo firewall-cmd --permanent --add-port=139/tcp
sudo firewall-cmd --reload
```

## 结语

按照本文步骤，您能够在 Windows 上创建 SMB 共享，并成功在 Linux 和 Windows 客户端挂载这些共享。同时，确保防火墙配置得当，保障数据安全。