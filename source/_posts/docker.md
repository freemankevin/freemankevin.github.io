---
title: Docker 生产环境部署完整指南
date: 2024-12-19 09:00:00
tags:
  - Docker
  - Container
  - Linux
  - DevOps
keywords:
  - Docker安装
  - 容器化
  - 生产环境配置
  - 镜像加速
categories:
  - DevOps
  - Container
---

Docker 是现代 DevOps 流程的核心组件，提供轻量级的操作系统级虚拟化。本文档详细阐述 Docker 在主流 Linux 发行版上的生产级部署方法，包括架构解析、安装配置、性能调优、安全加固和故障排查等关键环节。

<!-- more -->

**适用版本与环境说明：**
- Docker Engine: 27.5.x（本文示例版本）
- Docker Compose: 2.x 及以上版本
- Containerd: 1.7.x 及以上版本
- 操作系统: Ubuntu 20.04+/Debian 11+/CentOS 7.9+/Rocky Linux 8+
- 内核版本: 建议 4.18+ 以支持 overlay2 存储驱动和完整网络特性
- 更新日期: 2024-12-19（建议每月检查 Docker 安全公告）

{% note info %}
本文配置示例基于 Docker 27.5.1 LTS 版本。不同版本配置参数可能略有差异，请参考 [Docker 官方文档](https://docs.docker.com/engine/release-notes/) 查看具体版本说明。
{% endnote %}

## Docker 架构概述

## Docker 架构概述

### 核心组件

- **Docker Daemon (dockerd)**：守护进程，负责构建、运行和分发容器
- **Docker Client (docker)**：CLI 客户端，与 Daemon 通信
- **containerd**：行业标准的容器运行时，管理容器生命周期
- **runc**：OCI 运行时规范实现，负责创建和运行容器
- **Docker Registry**：镜像仓库服务（如 Docker Hub、Harbor）

### 存储驱动选择

| 存储驱动 | 适用场景 | 性能 | 稳定性 |
|---------|---------|------|--------|
| overlay2 | 推荐首选（内核 4.0+） | 优秀 | 生产就绪 |
| devicemapper | RHEL/CentOS 旧版本 | 中等 | 稳定 |
| btrfs | 需要快照功能 | 优秀 | 较新 |
| zfs | 企业级存储管理 | 优秀 | 生产就绪 |

## Ubuntu/Debian 系统安装

### 1. 更新系统并安装依赖
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https \
    software-properties-common
```

### 2. 添加 Docker 官方 GPG 密钥
```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

### 3. 配置 Docker 软件源
```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### 4. 安装 Docker Engine（生产环境推荐版本）
```bash
sudo apt update
sudo apt install -y \
    docker-ce=5:27.5.1-1~ubuntu.* \
    docker-ce-cli=5:27.5.1-1~ubuntu.* \
    containerd.io=1.7.27-1 \
    docker-buildx-plugin \
    docker-compose-plugin
```

### 5. 启动并启用服务
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now docker
sudo systemctl status docker
```

### 6. 验证安装
```bash
docker version
docker info
docker run --rm hello-world
```

---

## CentOS/RHEL/Rocky Linux 系统安装

### 1. 更新系统
```bash
sudo yum update -y
sudo yum install -y yum-utils device-mapper-persistent-data lvm2
```

### 2. 配置 Docker 仓库
```bash
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
```

### 3. 安装 Docker（指定版本）
```bash
yum list docker-ce --showduplicates | sort -r
sudo yum install -y \
    docker-ce-27.5.1 \
    docker-ce-cli-27.5.1 \
    containerd.io-1.7.27 \
    docker-buildx-plugin \
    docker-compose-plugin
```

### 4. 启动服务
```bash
sudo systemctl enable --now docker
docker version
```

---

## 生产环境关键配置

### daemon.json 配置详解

创建或编辑 `/etc/docker/daemon.json`：

```json
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "5"
  },
  "live-restore": true,
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 5,
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65535,
      "Soft": 65535
    }
  },
  "registry-mirrors": [
    "https://registry.docker-cn.com",
    "https://docker.mirrors.ustc.edu.cn"
  ],
  "insecure-registries": ["harbor.local.com"],
  "exec-opts": ["native.cgroupdriver=systemd"],
  "bip": "172.17.0.1/16",
  "fixed-cidr": "172.17.0.0/16",
  "mtu": 1500
}
```

**配置说明：**

| 配置项 | 说明 | 推荐值 | 原理 |
|-------|------|-------|------|
| `storage-driver` | 存储驱动 | overlay2（首选） | overlay2 是现代 Linux 内核推荐的存储驱动，性能优异，支持多层镜像 |
| `log-driver` | 日志驱动 | json-file / journald | json-file 便于调试，journald 节省磁盘但查询困难 |
| `log-opts.max-size` | 单个日志文件最大值 | 100m | 避免单个容器日志占用过多磁盘 |
| `log-opts.max-file` | 日志文件保留数量 | 5 | 保留最近 5 个日志文件，自动轮转 |
| `live-restore` | 守护进程重启时保持容器运行 | true | Docker Daemon 重启不影响运行中的容器（生产必需） |
| `registry-mirrors` | 镜像加速地址 | 根据地区选择 | 减少镜像拉取时间，国内推荐阿里云、USTC 镜像 |
| `exec-opts` | Cgroup 驱动 | systemd（K8s 必需） | Kubernetes 要求 systemd cgroup 驱动，避免 cgroupfs 冲突 |
| `bip` | Docker 网桥 IP | 172.17.0.1/16 | 默认网桥 IP，可自定义避免与宿主机网络冲突 |
| `max-concurrent-downloads` | 最大并发下载数 | 10 | 加速镜像拉取，但会增加网络带宽占用 |
| `max-concurrent-uploads` | 最大并发上传数 | 5 | 限制镜像上传并发，避免带宽饱和 |

**关键参数深度解析：**

**1. storage-driver: overlay2**
- **原理**：overlay2 使用 Linux 内核的 OverlayFS，将多个目录层叠加为单一视图
- **优势**：
  - 镜像层共享，节省磁盘空间
  - 写时复制（CoW）机制，容器写入性能高
  - 支持内核 4.0+，生产就绪
- **验证方法**：
```bash
# 查看当前存储驱动
docker info | grep "Storage Driver"

# 检查 overlay2 是否可用
cat /proc/filesystems | grep overlay
```

**2. live-restore: true**
- **原理**：容器运行时与 Docker Daemon 进程解耦
- **作用**：Daemon 重启或升级时，容器继续运行，不丢失业务
- **适用场景**：生产环境必需，避免 Docker 升级导致服务中断
- **验证方法**：
```bash
# 重启 Docker 服务后检查容器状态
docker ps
# 应显示容器仍在运行
```

**3. exec-opts: native.cgroupdriver=systemd**
- **原理**：systemd 是现代 Linux 的初始化系统，统一管理 cgroup
- **Kubernetes 要求**：K8s 使用 systemd 管理 cgroup，Docker 必须匹配
- **冲突后果**：如果使用 cgroupfs，可能导致 K8s 资源限制失效
- **验证方法**：
```bash
# 查看 cgroup 驱动
docker info | grep "Cgroup Driver"
# 应输出: Cgroup Driver: systemd
```

**4. registry-mirrors（镜像加速）**
- **国内推荐镜像源**：
  - 阿里云：`https://<your-id>.mirror.aliyuncs.com`（需登录获取专属地址）
  - USTC：`https://docker.mirrors.ustc.edu.cn`
  - 腾讯云：`https://mirror.ccs.tencentyun.com`
- **验证方法**：
```bash
# 测试镜像拉取速度
time docker pull nginx:alpine
# 配置后通常 5-30 秒，未配置可能 60-300 秒
```

### 应用配置
```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl status docker

# 验证配置生效
docker info | grep -E "Storage Driver|Cgroup Driver|Logging Driver"
```

---

## 安全加固配置

### 1. 用户权限管理
```bash
sudo groupadd docker 2>/dev/null || true
sudo usermod -aG docker $USER
newgrp docker
```

### 2. 配置防火墙规则（UFW）
```bash
sudo ufw allow 2375/tcp
sudo ufw allow 2376/tcp
sudo ufw reload
```

### 3. 启用 TLS 加密通信（生产必需）

生成 TLS 证书：
```bash
# 创建证书目录
sudo mkdir -p /etc/docker/tls

# 生成 CA 私钥
openssl genrsa -out /etc/docker/tls/ca-key.pem 4096

# 生成 CA 证书
openssl req -new -x509 -days 365 -key /etc/docker/tls/ca-key.pem \
  -sha256 -out /etc/docker/tls/ca.pem \
  -subj "/C=CN/ST=Shanghai/L=Shanghai/O=DevOps/CN=Docker CA"

# 生成服务器私钥
openssl genrsa -out /etc/docker/tls/server-key.pem 4096

# 生成服务器证书签名请求
openssl req -new -key /etc/docker/tls/server-key.pem \
  -out /etc/docker/tls/server.csr \
  -subj "/CN=$(hostname)"

# 签发服务器证书
openssl x509 -req -days 365 -sha256 \
  -in /etc/docker/tls/server.csr \
  -CA /etc/docker/tls/ca.pem \
  -CAkey /etc/docker/tls/ca-key.pem \
  -CAcreateserial \
  -out /etc/docker/tls/server-cert.pem

# 设置权限
sudo chmod 600 /etc/docker/tls/*.pem
sudo chown root:root /etc/docker/tls/*.pem
```

### 4. systemd 服务加固

编辑 `/etc/systemd/system/docker.service.d/override.conf`：
```ini
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --tlsverify --tlscacert=/etc/docker/tls/ca.pem \
  --tlscert=/etc/docker/tls/server-cert.pem \
  --tlskey=/etc/docker/tls/server-key.pem \
  -H fd:// -H tcp://0.0.0.0:2376
LimitNOFILE=65535
LimitNPROC=65535
TimeoutStartSec=0
Delegate=yes
KillMode=process
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s
```

应用配置：
```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

---

## 性能调优

### 1. 内核参数优化

编辑 `/etc/sysctl.conf` 或创建 `/etc/sysctl.d/99-docker.conf`：
```bash
# 网络优化
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1

# 内存优化
vm.swappiness = 10
vm.max_map_count = 262144

# 文件描述符
fs.file-max = 655350
fs.nr_open = 655350

# 网络连接数
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 8192
net.core.netdev_max_backlog = 5000
```

应用配置：
```bash
sudo sysctl --system
```

### 2. 磁盘清理策略

设置定时清理任务：
```bash
cat << 'EOF' | sudo tee /etc/cron.daily/docker-cleanup
#!/bin/bash
docker system prune -af --volumes --filter "until=168h"
docker image prune -af --filter "dangling=true"
docker container prune -f --filter "until=72h"
EOF
sudo chmod +x /etc/cron.daily/docker-cleanup
```

### 3. 监控配置

部署 cAdvisor + Prometheus：
```bash
docker run -d \
  --name=cadvisor \
  --volume=/:/rootfs:ro \
  --volume=/var/run:/var/run:ro \
  --volume=/sys:/sys:ro \
  --volume=/var/lib/docker/:/var/lib/docker:ro \
  --publish=8080:8080 \
  --restart=unless-stopped \
  gcr.io/cadvisor/cadvisor:latest
```

---

## 故障排查指南

### 常见问题与解决方案

#### 1. Docker 服务无法启动
```bash
# 检查服务状态
sudo systemctl status docker -l

# 查看详细日志
sudo journalctl -u docker.service -f

# 检查配置文件语法
dockerd --validate

# 检查存储驱动
docker info | grep "Storage Driver"

# 重置 Docker（慎用）
sudo systemctl stop docker
sudo rm -rf /var/lib/docker/*
sudo systemctl start docker
```

#### 2. 容器网络问题
```bash
# 查看网络配置
docker network ls
docker network inspect bridge

# 重建网络
sudo systemctl stop docker
sudo ip link delete docker0
sudo systemctl start docker

# 检查 iptables
sudo iptables -t nat -L -n -v
sudo iptables -t filter -L -n -v
```

#### 3. 存储空间不足
```bash
# 查看磁盘使用
docker system df -v

# 清理未使用资源
docker system prune -a --volumes

# 清理悬空镜像
docker image prune -a

# 清理停止的容器
docker container prune
```

#### 4. 权限问题
```bash
# 检查 Docker socket 权限
ls -la /var/run/docker.sock

# 临时修复权限
sudo chmod 666 /var/run/docker.sock

# 永久修复：添加用户到 docker 组
sudo usermod -aG docker $USER
newgrp docker
```

#### 5. 镜像拉取失败
```bash
# 检查网络连接
ping hub.docker.com

# 配置镜像加速
# 编辑 /etc/docker/daemon.json 添加 registry-mirrors

# 使用代理
export HTTP_PROXY=http://proxy-server:port
export HTTPS_PROXY=http://proxy-server:port

# 或配置 systemd
sudo mkdir -p /etc/systemd/system/docker.service.d
cat <<EOF | sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=http://proxy-server:port"
Environment="HTTPS_PROXY=http://proxy-server:port"
Environment="NO_PROXY=localhost,127.0.0.1"
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
```

---

## 生产环境最佳实践

### 1. 容器资源限制
```bash
# CPU 限制（1.5 核）
docker run -d --cpus="1.5" nginx:alpine

# 内存限制（512MB）
docker run -d --memory="512m" --memory-swap="1g" nginx:alpine

# 组合限制
docker run -d \
  --cpus="1.5" \
  --memory="1g" \
  --memory-swap="2g" \
  --cpu-shares=512 \
  --restart=unless-stopped \
  nginx:alpine
```

### 2. 日志管理
```bash
# 使用 journald 驱动
docker run -d --log-driver=journald nginx:alpine

# 使用 json-file 并限制大小
docker run -d \
  --log-driver=json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  nginx:alpine

# 查看容器日志
docker logs --tail=100 -f container_name
```

### 3. 健康检查配置
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1
```

```bash
# Docker Compose 健康检查
services:
  app:
    image: nginx:alpine
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"]
      interval: 30s
      timeout: 3s
      retries: 3
      start_period: 10s
```

### 4. 镜像管理最佳实践
```bash
# 使用多阶段构建减小镜像体积
# Dockerfile 示例
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]

# 扫描镜像漏洞
docker scout cves nginx:alpine

# 查看镜像层
docker history nginx:alpine
```

### 5. 容器编排建议
```yaml
# docker-compose.yml 生产示例
version: '3.8'

services:
  app:
    image: nginx:alpine
    restart: unless-stopped
    environment:
      - TZ=Asia/Shanghai
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./html:/usr/share/nginx/html:ro
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    networks:
      - frontend

networks:
  frontend:
    driver: bridge
```

---

## 版本管理策略

### 查看 Docker 版本信息
```bash
# 查看完整版本信息
docker version

# 查看详细信息
docker info

# 查看可用版本（CentOS/RHEL）
yum list docker-ce --showduplicates | sort -r

# 查看可用版本（Ubuntu/Debian）
apt-cache madison docker-ce
```

### 版本升级流程
```bash
# 1. 备份数据
docker export -o container_backup.tar container_name
docker save -o image_backup.tar image_name

# 2. 停止服务
sudo systemctl stop docker
sudo systemctl stop docker.socket

# 3. 升级软件包
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# 4. 启动服务并验证
sudo systemctl start docker
docker version
docker ps -a
```

---

## 参考资源

### 官方文档

- [Docker 官方文档](https://docs.docker.com/)
- [Docker Engine 配置参考](https://docs.docker.com/engine/reference/commandline/dockerd/)
- [Docker daemon.json 配置](https://docs.docker.com/engine/reference/commandline/dockerd/#daemon-configuration-file)
- [Docker 存储驱动详解](https://docs.docker.com/storage/storagedriver/)
- [Docker 网络配置](https://docs.docker.com/network/)
- [Docker 安全最佳实践](https://docs.docker.com/engine/security/)
- [Docker Compose 官方文档](https://docs.docker.com/compose/)
- [containerd 官方文档](https://containerd.io/)
- [containerd 配置指南](https://github.com/containerd/containerd/blob/main/docs/cri/usage.md)

### 安全与加固

- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [Docker 安全公告](https://docs.docker.com/security/)
- [OWASP Docker 安全指南](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [Docker Bench for Security](https://github.com/docker/docker-bench-security)
- [Docker TLS 配置](https://docs.docker.com/engine/security/https/)

### 性能优化

- [Docker 性能调优指南](https://docs.docker.com/config/containers/resource_constraints/)
- [Docker 存储驱动性能对比](https://docs.docker.com/storage/storagedriver/select-storage-driver/)
- [overlay2 性能分析](https://docs.docker.com/storage/storagedriver/overlayfs-driver/)
- [Docker 日志配置](https://docs.docker.com/config/containers/logging/)

### 故障排查

- [Docker 故障排查指南](https://docs.docker.com/config/containers/resource_constraints/)
- [Docker Daemon 日志](https://docs.docker.com/config/daemon/logger/)
- [Docker 网络故障排查](https://docs.docker.com/network/problems/)
- [containerd 故障排查](https://github.com/containerd/containerd/blob/main/docs/troubleshooting.md)

### 社区与工具

- [Docker GitHub 仓库](https://github.com/moby/moby)
- [Docker Hub](https://hub.docker.com/)
- [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [Docker Scout（镜像扫描）](https://docs.docker.com/scout/)
- [Docker 社区论坛](https://forums.docker.com/)
- [Docker Slack](https://dockerslack.herokuapp.com/)

### 国内镜像源

- [阿里云镜像加速器](https://help.aliyun.com/document_detail/60750.html)（需登录获取专属地址）
- [USTC 镜像站](https://mirrors.ustc.edu.cn/help/dockerhub.html)
- [腾讯云镜像加速](https://cloud.tencent.com/document/product/1207/45549)
- [网易镜像加速](https://hub-mirror.c.163.com)

### 进阶阅读

- [《Docker 深入浅出》](https://github.com/docker/labs)
- [Dockerfile 最佳实践](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [多阶段构建指南](https://docs.docker.com/build/building/multi-stage/)
- [容器运行时安全](https://github.com/opencontainers/runtime-spec)

