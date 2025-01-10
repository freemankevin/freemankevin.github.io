---
title: Nginx 日志切割方案配置
date: 2025-01-10 10:57:25
tags:
    - Nginx
    - Linux
    - Logrotate
category: Linux
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; Nginx 生成的访问日志和错误日志，随着时间的推移，会不断增大，可能会占用大量磁盘空间。为了确保系统性能和磁盘空间的有效利用，配置日志切割是一个非常重要的步骤。 本文将介绍如何在 CentOS 和 Debian 系统上配置 Nginx 日志切割，并且提供适用于 Docker 环境的解决方案。

<!-- more -->

## Linux环境

### 安装 `logrotate`

`logrotate` 是一种日志文件管理工具，它会定期轮换、压缩、删除和邮件发送日志文件。大多数 Linux 系统默认已安装 `logrotate`，但如果您的系统中没有安装，可以按照以下步骤进行安装：

#### 在 CentOS 上安装
```shell
$ sudo yum -y install logrotate
```

#### 在 Debian 上安装
```shell
$ sudo apt-get install logrotate
```

### 配置日志切割

日志切割配置文件位于 `/etc/logrotate.d/` 目录下。我们可以在该目录中为 Nginx 创建一个自定义的日志切割配置文件。

#### 进入配置目录
```shell
$ cd /etc/logrotate.d/
```

#### 备份并重命名原有的 Nginx 配置文件
默认情况下，Nginx 可能已经有了一个日志切割配置文件。我们可以先将其备份并重命名：
```shell
$ sudo mv nginx{,.bak}
```

#### 创建 Nginx 的日志切割配置文件
创建一个新的配置文件 `nginx`，并编辑其中的日志切割规则：
```shell
$ sudo vim nginx
```

#### 配置内容
以下是一个日志切割的基本配置，按照天进行切割，保留30天的日志，进行压缩处理，并防止日志文件占用过多磁盘空间。

```shell
# Nginx 日志切割配置

/alldev/log/nginx/*.log {
    daily              # 按天切割
    rotate 30          # 保留 30 天的日志
    missingok          # 如果日志文件丢失，不报错
    notifempty         # 如果日志文件为空，则不切割
    compress           # 切割后的日志文件进行压缩
    nodelaycompress    # 立即压缩，不延迟
    copytruncate       # 在复制日志内容后，截断日志文件
    dateext            # 使用日期后缀命名切割的日志文件
    dateformat -%Y-%m-%d   # 设置日期格式为 -YYYY-MM-DD
    dateyesterday      # 如果是昨天的日志，使用昨天日期
}
```

#### 修改日志路径（可选）
根据您的需求，您可以将日志存储路径配置为其他位置，例如，将日志存储到 `/data` 目录而非 `/var/log`，以避免占用系统盘空间。

如果您修改了日志路径，记得修改 Nginx 配置文件中的日志路径，并重启 Nginx 服务来应用更改。

### 验证配置

完成配置后，可以通过以下命令手动执行 `logrotate` 来验证配置是否正确：

```shell
$ sudo logrotate -d /etc/logrotate.d/nginx
```

该命令会模拟日志切割，并打印出详细的调试信息。如果没有错误信息，说明配置成功。

如果您希望立即切割日志，可以使用以下命令：

```shell
$ sudo logrotate -f /etc/logrotate.d/nginx
```

## Docker环境

如果您在 Docker 环境中运行 Nginx，日志切割的配置会稍有不同，因为 Docker 的日志存储通常是通过容器内部的文件系统进行管理的。

### 配置 Docker 日志驱动

首先，确保 Docker 配置了正确的日志驱动。我们可以通过以下命令查看当前的日志驱动设置：

```shell
$ docker info | grep "Logging Driver"
```

通常推荐使用 `json-file` 日志驱动。确保 Docker 配置文件 `/etc/docker/daemon.json` 中配置了正确的日志驱动：

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

这将设置 Docker 容器的日志文件大小限制为 10MB，并且最多保留 3 个日志文件。

### 配置日志切割

可以使用主机上的 `logrotate` 来管理 Docker 容器日志。日志文件通常位于 `/var/lib/docker/containers/<container_id>/` 目录下。

您可以通过创建一个 `docker-nginx` 配置文件来管理这些日志文件。创建并编辑该文件：

```shell
$ sudo vim /etc/logrotate.d/docker-nginx
```

然后添加以下内容：

```shell
# Docker Nginx 容器日志切割配置

/var/lib/docker/containers/*/*.log {
    daily              # 按天切割
    rotate 30          # 保留 30 天的日志
    missingok          # 如果日志文件丢失，不报错
    notifempty         # 如果日志文件为空，则不切割
    compress           # 切割后的日志文件进行压缩
    nodelaycompress    # 立即压缩，不延迟
    copytruncate       # 在复制日志内容后，截断日志文件
    dateext            # 使用日期后缀命名切割的日志文件
    dateformat -%Y-%m-%d   # 设置日期格式为 -YYYY-MM-DD
}
```

### 重启 Docker 服务

完成配置后，记得重启 Docker 服务以应用更改：

```shell
$ sudo systemctl restart docker
```

### 验证 Docker 日志切割

通过以下命令查看 Docker 容器的日志是否在按预期切割：

```shell
$ sudo logrotate -f /etc/logrotate.d/docker-nginx
```

## 总结

通过上述步骤，您可以在 CentOS、Debian 系统以及 Docker 环境中配置 Nginx 日志切割。这将帮助您有效地管理 Nginx 日志文件，避免占用过多磁盘空间，并确保系统运行的稳定性。

如果您的 Nginx 日志路径不同，或者有特殊的需求，可以根据实际情况调整配置。