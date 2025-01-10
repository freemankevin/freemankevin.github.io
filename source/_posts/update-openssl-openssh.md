---
title: 如何在 CentOS 和 Debian 上升级 OpenSSL 和 OpenSSH
date: 2025-01-10 11:57:25
tags:
    - OpenSSL
    - OpenSSH
    - Linux
category: Linux
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;OpenSSL 和 OpenSSH 是现代 Linux 系统中不可或缺的安全工具，广泛用于加密通讯、身份验证和保障网络安全。定期升级这两个组件是确保系统安全性和稳定性的必要操作。本文将介绍如何在 CentOS 和 Debian 系统上手动升级 OpenSSL 和 OpenSSH。

<!-- more -->

## 升级 OpenSSL

OpenSSL 是一种广泛使用的开源工具包，用于实现加密协议。升级 OpenSSL 主要是为了确保系统使用最新的加密算法和安全修复。下面是升级 OpenSSL 的步骤：

### 检查当前 OpenSSL 版本

首先，查看当前系统上安装的 OpenSSL 版本，确保是否需要升级：

```shell
openssl version
```

输出类似于：

```shell
OpenSSL 1.0.2k-fips  26 Jan 2017
```

如果版本较旧，可以按照以下步骤进行升级。

### 安装依赖包

在开始安装之前，您需要安装一些开发工具和依赖库，这些工具将帮助您编译 OpenSSL 的源代码。根据您的系统类型，执行以下命令：

#### 对于 CentOS

```shell
sudo yum groupinstall "Development Tools"
sudo yum install zlib-devel gcc-c++ make
```

#### 对于 Debian

```shell
sudo apt-get update
sudo apt-get install build-essential zlib1g-dev
```

### 下载最新版本的 OpenSSL

访问 [OpenSSL 官方网站](https://www.openssl.org/source/) 下载最新版本的 OpenSSL 源码包。可以使用 `wget` 或浏览器下载并传输到服务器：

```shell
wget https://www.openssl.org/source/openssl-1.1.1l.tar.gz
```

解压下载的文件：

```shell
tar -xvzf openssl-1.1.1l.tar.gz
cd openssl-1.1.1l
```

### 编译和安装 OpenSSL

在解压后的目录中，运行以下命令来编译和安装 OpenSSL：

```shell
./config
make
sudo make install
```

编译过程可能需要一些时间。安装完成后，您可以通过执行 `openssl version` 来确认安装是否成功。

### 更新系统链接

为了让系统识别新安装的 OpenSSL，您可能需要更新系统中的链接：

```shell
sudo ldconfig
```

### 验证安装

再次执行 `openssl version` 来确认版本是否更新：

```shell
openssl version
```

输出应该类似于：

```shell
OpenSSL 1.1.1l  24 Aug 2021
```

至此，您已经成功升级了 OpenSSL。


## 升级 OpenSSH

OpenSSH 是一种常用的远程登录协议，广泛用于在不安全的网络中安全地管理和访问服务器。升级 OpenSSH 可以提供更强的安全性和修复潜在的漏洞。以下是升级 OpenSSH 的步骤：

### 检查当前 OpenSSH 版本

与 OpenSSL 类似，首先检查当前系统上的 OpenSSH 版本：

```shell
ssh -V
```

输出类似于：

```shell
OpenSSH_7.4p1, OpenSSL 1.0.2k-fips  26 Jan 2017
```

如果版本较低，可以继续进行升级。

### 安装依赖包

升级 OpenSSH 也需要安装一些依赖包，具体依赖项如下：

#### 对于 CentOS

```shell
sudo yum install gcc make pam-devel pcre-devel
```

#### 对于 Debian

```shell
sudo apt-get install build-essential libssl-dev libpam-dev libpcre3-dev
```

### 下载 OpenSSH 源码包

访问 [OpenSSH 官方网站](https://www.openssh.com/) 下载最新的 OpenSSH 源码包，或使用 `wget` 直接下载：

```shell
wget https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-8.8p1.tar.gz
```

解压文件并进入目录：

```shell
tar -xvzf openssh-8.8p1.tar.gz
cd openssh-8.8p1
```

### 编译和安装 OpenSSH

在解压后的目录中，执行以下命令来编译和安装 OpenSSH：

```shell
./configure
make
sudo make install
```

此过程将安装新版本的 OpenSSH。

### 更新 SSH 配置

安装完成后，您可能需要更新 `/etc/ssh/sshd_config` 配置文件以启用新版本的特性（如启用新的加密算法、更新配置项等）。在修改配置后，重启 SSH 服务以使更改生效：

```shell
sudo systemctl restart sshd
```

### 验证安装

检查新安装的 OpenSSH 版本：

```shell
ssh -V
```

输出应该类似于：

```shell
OpenSSH_8.8p1, OpenSSL 1.1.1l  24 Aug 2021
```

至此，OpenSSH 也已成功升级。