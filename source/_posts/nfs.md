---
title: NFS 网络文件系统跨平台共享与部署完整指南
date: 2025-01-06 12:57:25
keywords:
  - NFS
  - NetworkStorage
  - FileShare
  - CrossPlatform
categories:
  - Linux
  - Storage
tags:
  - NFS
  - Storage
  - Network
  - FileShare
---

NFS（Network File System）是跨平台网络文件共享的标准解决方案，提供高效的数据共享能力。本指南涵盖 NFS 服务器搭建、Linux/Windows客户端配置、安全权限管理、性能优化和故障排查，适用于生产环境的跨平台文件共享架构。

<!-- more -->

## NFS 架构设计

### NFS 工作原理

```
┌─────────────────┐
│  NFS Server     │
│  (Linux Host)   │
│                 │
│  ┌───────────┐  │
│  │ NFS Daemon│  │  nfsd (2049/tcp)
│  │ rpc.mountd│  │  mountd (20048/tcp)
│  │ rpcbind   │  │  rpcbind (111/tcp/udp)
│  └───────────┘  │
│                 │
│  ┌───────────┐  │
│  │ Export Dir│  │  /etc/exports配置
│  │  共享目录  │  │
│  └───────────┘  │
└─────────────────┘
        │
        │ NFS Protocol (TCP/UDP 2049)
        │
        ▼
┌─────────────────┐
│  NFS Client     │
│  (Linux/Win)    │
│                 │
│  ┌───────────┐  │
│  │  Mount    │  │  mount / showmount
│  │  Point    │  │
│  └───────────┘  │
└─────────────────┘
```

### NFS 版本特性

| NFS版本 | 性能 | 安全性 | 兼容性 | 生产推荐 |
|---------|------|--------|--------|----------|
| NFSv3 | 良好 | 基础 | 广泛 | 传统系统 |
| NFSv4 | 优秀 | Kerberos | Linux优先 | 生产首选 |
| NFSv4.1 | 最优 | 完整安全 | 新系统 | 大规模应用 |

### NFS 生产配置要点

| 配置项 | 推荐值 | 说明 |
|-------|--------|------|
| sync/async | sync | 数据一致性保障 |
| rw/ro | 按需求 | 读写权限控制 |
| no_root_squash | 慎用 | root权限映射 |
| secure | 推荐 | 端口安全限制 |
| no_subtree_check | 推荐 | 性能优化 |





## 在 Linux 上搭建 NFS 服务器

### 安装 NFS 服务器

首先，根据您的 Linux 发行版安装 NFS 服务。

> 对于基于 Debian 的系统（如 Ubuntu）：

```bash
sudo apt update
sudo apt install nfs-kernel-server
```

> 对于基于 RPM 的系统（如 CentOS 或 Fedora）：

```bash
sudo yum install nfs-utils
```

### 配置 NFS 共享

创建一个共享目录并配置 NFS 来共享此目录。以下以 `/var/nfs_share` 目录为例：

```bash
sudo mkdir /var/nfs_share
sudo chown nobody:nogroup /var/nfs_share
```

接下来，编辑 `/etc/exports` 文件，添加共享目录的配置项：

```bash
sudo vim /etc/exports
```

在文件中添加如下行，允许特定客户端（例如，IP 地址为 `<client_ip>` 的机器）访问共享目录：

```
/var/nfs_share <client_ip>(rw,sync,no_subtree_check)
```

例如，允许整个子网 `192.168.1.0/24` 访问：

```
/var/nfs_share 192.168.1.0/24(rw,sync,no_subtree_check)
```

保存并关闭文件。

### 启动并配置 NFS 服务

启动 NFS 服务，并确保它在系统启动时自动启动：

```bash
sudo systemctl start nfs-kernel-server
sudo systemctl enable nfs-kernel-server
```

验证 NFS 服务是否正在运行：

```bash
sudo systemctl status nfs-kernel-server
```

## 在客户端挂载 NFS 共享

### Linux 客户端

#### 安装 NFS 客户端工具

根据客户端系统类型安装 NFS 客户端工具：

> 对于 Debian/Ubuntu：

```bash
sudo apt install nfs-common
```

> 对于 CentOS/Fedora：

```bash
sudo yum install nfs-utils
```

#### 挂载 NFS 共享

使用 `mount` 命令挂载共享目录：

```bash
sudo mount -t nfs <nfs_server_ip>:/var/nfs_share /mnt
```

将 `<nfs_server_ip>` 替换为您的 NFS 服务器的 IP 地址，`/mnt` 为本地挂载点。

#### 配置开机自动挂载（可选）

如果您希望在每次启动时自动挂载 NFS 共享，可以编辑 `/etc/fstab` 文件：

```bash
sudo nano /etc/fstab
```

添加如下行：

```
<nfs_server_ip>:/var/nfs_share /mnt nfs defaults 0 0
```

### Windows 客户端

#### 启用 NFS 客户端功能

在 Windows 10 或 Windows Server 上，首先需要启用 NFS 客户端功能。打开“控制面板”，依次点击“程序和功能” > “启用或关闭 Windows 功能”，勾选“服务于 NFS 的子系统”。

#### 挂载 NFS 共享

打开命令提示符（以管理员身份），并使用如下命令：

```cmd
mount <nfs_server_ip>:/var/nfs_share Z:
```

将 `<nfs_server_ip>` 替换为 NFS 服务器的 IP 地址，`Z:` 为您希望挂载的驱动器字母。

## 验证挂载

> 在 Linux 上验证挂载

可以使用 `ls` 命令查看挂载点内容，确认共享目录是否成功挂载：

```bash
ls /mnt
```

> 在 Windows 上验证挂载

可以在命令提示符中使用 `dir` 命令来验证挂载是否成功：

```cmd
dir Z:
```

## 配置防火墙以支持 NFS 服务

### NFS 服务所需的主要端口

NFS 服务依赖于多个网络端口，确保防火墙正确配置是至关重要的。以下是主要端口：

- **TCP/UDP 2049**：NFS 主端口，用于文件系统操作。
- **TCP/UDP 111**：RPC（远程过程调用）端口，用于客户端与 NFS 服务器之间的通信。
  
此外，NFS 还可能使用一些额外的端口：

- **TCP/UDP 3270-3280**：这些端口用于 NFS 的附加服务，如 `mountd`、`statd` 和 `lockd`。

### 配置 UFW 防火墙（Debian 系列）

在基于 Debian 的 Linux 系统（如 Ubuntu）中，可以使用 UFW 来配置防火墙规则：

```bash
sudo ufw allow 2049/tcp
sudo ufw allow 2049/udp
sudo ufw allow 111/tcp
sudo ufw allow 111/udp
sudo ufw allow 3270:3280/tcp
sudo ufw allow 3270:3280/udp
```

### 配置 firewalld 防火墙（RHEL 系列）

对于基于 RHEL 的 Linux 系统（如 CentOS 或 Fedora），可以使用 `firewalld` 配置防火墙规则：

1. **启用 `firewalld` 服务**

   ```bash
   sudo systemctl start firewalld
   sudo systemctl enable firewalld
   ```

2. **添加防火墙规则**

   开放 NFS 所需的端口：

   ```bash
   sudo firewall-cmd --permanent --add-port=2049/tcp
   sudo firewall-cmd --permanent --add-port=2049/udp
   sudo firewall-cmd --permanent --add-port=111/tcp
   sudo firewall-cmd --permanent --add-port=111/udp
   sudo firewall-cmd --permanent --add-port=3270-3280/tcp
   sudo firewall-cmd --permanent --add-port=3270-3280/udp
   ```

3. **重新加载防火墙规则**

   ```bash
   sudo firewall-cmd --reload
   ```

4. **验证防火墙规则**

   使用以下命令检查防火墙规则是否已正确配置：

   ```bash
   sudo firewall-cmd --list-all
   ```

确保防火墙规则正确无误，避免由于端口未开放而导致客户端无法访问 NFS 服务。

## 总结

通过本文提供的步骤，您已经学会如何在 Linux 系统上搭建并配置 NFS 服务器，以及如何在 Linux 和 Windows 客户端上挂载 NFS 共享。确保在生产环境中使用适当的安全配置和网络策略，以防止未经授权的访问。
