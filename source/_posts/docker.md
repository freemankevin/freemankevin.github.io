---
title: 如何在不同 Linux 系统下安装 Docker
date: 2024-12-19 09:00:00
tags:
  - Docker
  - Container
  - Linux
# comments: true
category: Linux
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Docker 是一种开源的容器化平台，可以简化应用程序的开发、部署和运行。本文介绍了如何在不同的 Linux 系统中安装 Docker，包括 Ubuntu/Debian、CentOS/RHEL、openSUSE 和 Arch Linux。我们详细讲解了每个系统的安装步骤，包括更新系统、安装依赖、添加 Docker 软件源、安装 Docker 引擎以及验证安装。最后，我们还介绍了如何配置非 root 用户使用 Docker。通过这些步骤，你可以在各种 Linux 发行版上轻松安装和配置 Docker。

<!-- more -->

## 1. Ubuntu/Debian 系统

### 更新系统
```bash
sudo apt update
sudo apt upgrade -y
```

### 安装依赖
```bash
sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
```

### 添加 Docker 的官方 GPG 密钥
```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

### 设置 Docker 软件源
```bash
echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### 安装 Docker 引擎
```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### 验证安装
```bash
docker --version
```

---

## 2. CentOS/RHEL 系统

### 更新系统
```bash
sudo yum update -y
```

### 安装依赖
```bash
sudo yum install -y yum-utils
```

### 添加 Docker 软件源
```bash
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
```

### 安装 Docker 引擎
```bash
sudo yum install -y docker-ce docker-ce-cli containerd.io
```

### 启动 Docker 服务
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

### 验证安装
```bash
docker --version
```

---

## 3. openSUSE 系统

### 更新系统
```bash
sudo zypper refresh
```

### 安装 Docker
```bash
sudo zypper install -y docker
```

### 启动 Docker 服务
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

### 验证安装
```bash
docker --version
```

---

## 4. Arch Linux

### 更新系统
```bash
sudo pacman -Syu
```

### 安装 Docker
```bash
sudo pacman -S docker
```

### 启动 Docker 服务
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

### 验证安装
```bash
docker --version
```

---

## 5. 配置非 root 用户使用 Docker

默认情况下，只有 root 用户或具有 sudo 权限的用户可以运行 Docker。你可以通过以下步骤允许非 root 用户使用 Docker：

### 添加用户到 Docker 组
```bash
sudo usermod -aG docker $USER
```

### 重新登录
重新登录后，非 root 用户即可运行 Docker 命令。

### 测试
```bash
docker run hello-world
```

---

通过以上步骤，你可以在不同的 Linux 系统中安装和配置 Docker。安装完成后，可以开始体验 Docker 的强大功能，如运行容器、构建镜像等。

