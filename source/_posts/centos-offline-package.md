---
title: CentOS 系统下制作离线安装包
date: 2024-12-20 12:17:25
tags:
    - Yum
    - Offline
    - CentOS
category: Linux
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在无法联网的环境中安装软件需要提前准备好所有必要的安装包及其依赖项。本文将指导你如何在 CentOS 7.9 系统上创建一个离线软件安装包。首先，我们会使用 yum 命令下载所需软件及其依赖项，然后创建一个本地仓库。接着，我们会将下载的目录打包并传输到目标离线机器。最后，我们会在离线机器上解压并配置本地仓库，以便顺利安装软件。通过这些步骤，你可以在没有网络连接的情况下方便地安装所需的软件。

<!-- more -->

## 准备工作

在开始之前，请确保您有一台可以联网的 CentOS 7.9 系统，用于下载软件及其依赖。

## 下载软件及其依赖

您可以使用 `yum` 的 `--downloadonly` 和 `--downloaddir` 选项来下载软件包和它们的所有依赖。

例如，如果您想下载 `httpd`（Apache Web 服务器）及其所有依赖，可以执行以下命令：

```bash
yum install --downloadonly --downloaddir=/path/to/download/directory httpd
```

将 `/path/to/download/directory` 替换为您想要保存下载文件的目录路径。

## 创建本地仓库

下载所有包后，您需要在下载目录中创建一个本地仓库，这样在离线安装时 `yum` 能够识别并正确处理依赖关系。

```bash
cd /path/to/download/directory
# sudo rpm --import /path/to/RPM-GPG-KEY-PGDG # 如果有的话
createrepo .
```

如果 `createrepo` 命令不可用，您需要先在线安装 `createrepo` 包：

```bash
yum install createrepo
```

并在同样的联网环境中运行 `createrepo` 命令。


## 打包下载目录

将带有软件包和本地仓库元数据的下载目录打包，以便于传输。

```bash
tar -czvf offline-packages.tar.gz -C /path/to/download/directory .
```

## 传输到离线机器

使用 USB 驱动器、光盘或其他媒体将 `offline-packages.tar.gz` 文件传输到离线 CentOS 7.9 机器上。

## 离线安装软件

在离线机器上，执行以下步骤来安装软件：

### 解压软件包

```bash
tar -xzvf /path/to/offline-packages.tar.gz -C /path/to/local/repo
```

### 配置本地仓库

创建一个新的 YUM 仓库配置文件：

```bash
vi /etc/yum.repos.d/local.repo
```

添加以下内容：

```ini
[local-repo]
name=Local Repository
baseurl=file:///path/to/local/repo
enabled=1
gpgcheck=0
```

确保替换 `/path/to/local/repo` 为您解压缩软件包的实际目录。

### 安装软件

现在您可以使用 `yum` 从本地仓库安装软件，`yum` 会自动处理所有依赖关系。

```bash
# 可能需要清理其他旧仓库，然后执行清理缓存，yum clean all && yum makecache fast
yum install --disablerepo='*' --enablerepo='local-repo' httpd
```

用您实际下载的软件包名替换 `httpd`。

## 注意事项

- 请确保在可联网的机器上下载软件包时的 CentOS 版本和离线机器上的版本一致，以免因版本不匹配导致依赖问题。
- 如果您下载了大量的包，并且依赖很复杂，建议直接下载整个 CentOS 仓库，并在离线环境中设置本地镜像。

按照这些步骤，您应该能够在没有网络连接的情况下在 CentOS 7.9 系统上安装软件。

