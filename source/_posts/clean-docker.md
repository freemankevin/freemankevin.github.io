---
title: Docker 环境清理
date: 2025-01-14 15:44:25
tags:
    - Development
    - Docker
    - Linux
category: Development
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 本文详细介绍了如何彻底清理Docker环境，分别针对RedHat/CentOS和Debian/Ubuntu系列系统提供了具体的操作步骤。包括环境检查、数据备份、服务停止、资源清理、软件包卸载等内容，帮助用户安全、完整地清理Docker环境。执行清理前请务必做好数据备份工作。

<!-- more -->

## 前置准备

### 环境检查

1. 检查Docker安装信息：
```bash
# 检查Docker版本和安装方式
docker version
docker info

# RedHat/CentOS系列
rpm -qa | grep docker

# Debian/Ubuntu系列
dpkg -l | grep docker
```

### 数据备份

1. 通用备份步骤：
```bash
# 创建备份目录
mkdir -p /backup/docker/$(date +%Y%m%d)
cd /backup/docker/$(date +%Y%m%d)

# 导出容器和镜像
docker ps -a --format "{{.Names}}" | while read container; do
  docker export "$container" > "${container}.tar"
done

docker images --format "{{.Repository}}:{{.Tag}}" | while read image; do
  docker save "$image" > "${image//\//_}.tar"
done

# 备份配置
tar -czf docker-config-$(date +%Y%m%d).tar.gz /etc/docker
tar -czf docker-data-$(date +%Y%m%d).tar.gz /var/lib/docker
```

## RedHat/CentOS系列清理

### 基础清理

1. 停止服务：
```bash
# 停止容器和服务
docker stop $(docker ps -aq)
systemctl stop docker
systemctl stop containerd
```

2. 清理资源：
```bash
# 清理容器资源
docker rm -f $(docker ps -aq)
docker rmi -f $(docker images -aq)
docker volume rm $(docker volume ls -q)
docker network rm $(docker network ls -q)
```

### 系统清理

1. 卸载软件包：
```bash
# 移除Docker包
yum remove -y docker \
    docker-client \
    docker-client-latest \
    docker-common \
    docker-latest \
    docker-latest-logrotate \
    docker-logrotate \
    docker-engine \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-compose-plugin

# 清理依赖
yum autoremove -y
yum clean all
```

2. 清理文件：
```bash
# 清理数据和配置
rm -rf /var/lib/docker
rm -rf /data/docker
rm -rf /etc/docker
rm -rf /etc/systemd/system/docker.service.d
rm -rf /var/run/docker
rm -rf /var/run/docker.sock
rm -rf /var/log/docker

# 清理yum仓库
rm -rf /etc/yum.repos.d/docker-ce.repo
```

## Debian/Ubuntu系列清理

### 基础清理

1. 停止服务：
```bash
# 停止容器和服务
docker stop $(docker ps -aq)
systemctl stop docker
systemctl stop containerd
```

2. 清理资源：
```bash
# 清理容器资源
docker rm -f $(docker ps -aq)
docker rmi -f $(docker images -aq)
docker volume rm $(docker volume ls -q)
docker network rm $(docker network ls -q)
```

### 系统清理

1. 卸载软件包：
```bash
# 移除Docker包
apt-get purge -y docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-compose-plugin \
    docker-ce-rootless-extras

# 清理依赖
apt-get autoremove -y
apt-get clean
```

2. 清理文件：
```bash
# 清理数据和配置
rm -rf /var/lib/docker
rm -rf /data/docker
rm -rf /etc/docker
rm -rf /etc/systemd/system/docker.service.d
rm -rf /var/run/docker
rm -rf /var/run/docker.sock
rm -rf /var/log/docker

# 清理apt仓库
rm -rf /etc/apt/sources.list.d/docker.list
rm -rf /etc/apt/sources.list.d/docker.list.save
```

## 环境验证

### 清理验证

1. 进程检查：
```bash
# 检查进程
ps aux | grep -i docker
ps aux | grep -i containerd

# 检查端口
netstat -tulpn | grep -E "docker|containerd"

# 检查文件
find / -name "*docker*"
find / -name "*containerd*"
```

## 总结

本文档提供了针对RedHat/CentOS和Debian/Ubuntu系列系统的Docker环境清理指南，包括完整的清理流程和验证步骤。建议在执行清理操作前做好充分的备份工作。