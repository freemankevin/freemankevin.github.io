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

| 配置项 | 说明 | 推荐值 |
|-------|------|-------|
| `storage-driver` | 存储驱动 | overlay2（首选） |
| `log-driver` | 日志驱动 | json-file / journald |
| `log-opts.max-size` | 单个日志文件最大值 | 100m |
| `log-opts.max-file` | 日志文件保留数量 | 5 |
| `live-restore` | 守护进程重启时保持容器运行 | true |
| `registry-mirrors` | 镜像加速地址 | 根据地区选择 |
| `exec-opts` | Cgroup 驱动 | systemd（K8s 必需） |

### 应用配置
```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl status docker
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

- [Docker 官方文档](https://docs.docker.com/)
- [Docker 安全最佳实践](https://docs.docker.com/engine/security/)
- [Docker 性能调优指南](https://docs.docker.com/config/containers/resource_constraints/)
- [containerd 项目](https://containerd.io/)

