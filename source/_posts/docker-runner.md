---
title: 如何在 Docker 环境中部署 GitLab Runner
date: 2025-01-21 17:14:25
tags:
    - Docker
    - GitLab Runner
    - GitLab
category: Development 
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 在本篇文章中，我们将介绍如何在 Docker 环境中部署 GitLab Runner，以便使用 GitLab CI/CD 实现自动化构建与部署。我们将通过 Docker Compose 配置并管理 GitLab Runner 容器，详细讲解配置文件和注册过程。

<!-- more -->

## 部署 GitLab Runner

GitLab Runner 是 GitLab CI/CD 的一个组成部分，用于执行 CI/CD 作业。本文将介绍如何在 Docker 环境中部署 GitLab Runner，并配置其与 GitLab 服务器的连接。我们将使用 Docker Compose 来管理 GitLab Runner 容器的启动和配置。

### 创建 Docker Compose 配置文件

首先，我们需要为 GitLab Runner 创建一个 `docker-compose.yml` 配置文件。在该文件中，我们定义了 GitLab Runner 容器的基本配置信息，包括使用的镜像、挂载的卷以及容器的特权模式。

```yaml
version: '3'

services:
  gitlab-runner-npm:
    image: gitlab/gitlab-runner:latest  # 使用 GitLab Runner 的最新版本镜像
    container_name: gitlab-runner-npm  # 容器名称
    privileged: true  # 启用特权模式，允许容器执行 Docker 操作
    restart: always  # 容器崩溃时自动重启
    volumes:
      - ./gitlab-runner/:/etc/gitlab-runner  # 将本地的 GitLab Runner 配置文件挂载到容器中
      - ~/.docker:/root/.docker  # 将本地 Docker 配置挂载到容器中，确保 Runner 可以使用 Docker 客户端
      - /var/run/docker.sock:/var/run/docker.sock  # 共享 Docker 套接字，允许 Runner 执行 Docker 命令
      #- ./cache:/cache  # 可选的缓存挂载，用于加速构建过程
```

在这个 `docker-compose.yml` 文件中，我们挂载了几个目录和文件以确保容器能够正确工作：
- `./gitlab-runner/`：用于存储 GitLab Runner 配置。
- `~/.docker`：将主机上的 Docker 配置挂载到容器中。
- `/var/run/docker.sock`：容器通过这个挂载与宿主机的 Docker 守护进程进行通信，允许 Runner 执行 Docker 命令。

### 注册 GitLab Runner

GitLab Runner 需要在注册后才能与 GitLab 服务进行通信。以下是注册 GitLab Runner 的脚本，它通过 Docker 执行 `gitlab-runner register` 命令。

```shell
#!/bin/bash

REGISTRATION_TOKEN="YOUR_REGISTRATION_TOKEN"  # GitLab 注册令牌，替换为实际值
RUNNER_NAME="gitlab-runner-npm-group"  # Runner 的名称

docker exec -it "${RUNNER_NAME}" gitlab-runner register \
  --non-interactive \
  --url "http://gitlab.example.com/" \  # GitLab 服务器地址，替换为实际地址
  --registration-token "${REGISTRATION_TOKEN}" \
  --executor "docker" \  # 使用 Docker 执行器
  --docker-image "docker:19.03.12" \  # Docker 镜像，选择适合的版本
  --description "Docker Runner" \  # Runner 描述
  --tag-list "docker-npm" \  # Runner 标签，帮助过滤任务
  --locked=true \  # 锁定 Runner，防止其他 GitLab 实例注册
  --docker-privileged=true \  # 启用 Docker 特权模式
  --run-untagged=false \  # 不运行未打标签的作业
  --docker-tlsverify=false \  # 禁用 Docker TLS 验证
  --docker-disable-entrypoint-overwrite=false \  # 不禁用容器入口点覆盖
  --docker-oom-kill-disable=false \  # 启用 OOM 杀死
  --docker-disable-cache=false \  # 启用 Docker 缓存
  --docker-shm-size=0 \  # 设置共享内存大小
  --cache-type="s3" \  # 配置 S3 缓存
  --cache-path="runner" \  # 缓存路径
  --cache-shared=true \  # 启用共享缓存
  --cache-s3-server-address="s3.example.com:9000" \  # S3 服务器地址，替换为实际值
  --cache-s3-access-key="YOUR_S3_ACCESS_KEY" \  # S3 访问密钥
  --cache-s3-secret-key="YOUR_S3_SECRET_KEY" \  # S3 秘密访问密钥
  --cache-s3-bucket-name="runner-cache" \  # S3 存储桶名称
  --cache-s3-insecure=true  # 启用不安全连接
```

### GitLab Runner 配置

在容器中，我们可以编辑 GitLab Runner 的配置文件 `config.toml`，以设置并优化 Runner 的行为。以下是 `config.toml` 文件的示例，其中包含了多个重要的配置项：

```toml
concurrent = 1  # 限制同时运行的作业数
check_interval = 0  # 检查任务队列的间隔时间

[session_server]
  session_timeout = 1800  # 会话超时设置（单位：秒）

[[runners]]
  name = "Docker Runner"  # Runner 名称
  url = "http://gitlab.example.com/"  # GitLab 实例的 URL
  token = "YOUR_REGISTRATION_TOKEN"  # 注册令牌，替换为实际值
  executor = "docker"  # 使用 Docker 执行作业

  [runners.custom_build_dir]
  #[runners.cache]  # 缓存配置，通常用于加速构建过程
  #  Type = "local"
  #  Path = "/cache"
  #  Shared = true
  [runners.cache]
    Type = "s3"  # 使用 S3 作为缓存类型
    Path = "runner"  # 缓存路径
    Shared = true  # 启用共享缓存
    [runners.cache.s3]
      ServerAddress = "s3.example.com:9000"  # S3 服务器地址，替换为实际地址
      AccessKey = "YOUR_S3_ACCESS_KEY"  # S3 访问密钥
      SecretKey = "YOUR_S3_SECRET_KEY"  # S3 秘密访问密钥
      BucketName = "runner-cache"  # S3 存储桶名称
      Insecure = true  # 启用不安全连接

  [runners.docker]
    tls_verify = false  # 禁用 Docker TLS 验证
    image = "docker:19.03.12"  # Docker 镜像版本
    privileged = true  # 启用特权模式
    disable_entrypoint_overwrite = false  # 启用容器入口点覆盖
    oom_kill_disable = false  # 启用 OOM 杀死
    disable_cache = false  # 启用缓存
    volumes = ["/cache"]  # 挂载的目录
    shm_size = 536870912  # 设置共享内存大小
    memory = "24000m"  # 分配内存
    memory_swap = "26g"  # 设置交换内存
    cpus = "12"  # 分配 CPU 核数
    allowed_images = [  # 限制 Runner 使用的镜像列表
      "harbor.dockerregistry.com/kubernetes/maven:3.6.3-openjdk-8-slim",
      "harbor.dockerregistry.com/kubernetes/kaniko-project/executor:v1.14.0-debug",
      "harbor.dockerregistry.com/kubernetes/argocli-git:v2.7.14",
      "harbor.dockerregistry.com/kubernetes/nodejs:*"
    ]
```

#### 重要配置说明：

- **`privileged`**：启用特权模式，允许容器执行 Docker 操作。这是必需的，因为 GitLab Runner 需要能够在容器中执行构建任务。
- **`executor`**：指定运行作业的执行器，通常为 `docker`，可以在容器中运行任务。
- **`volumes`**：挂载卷，允许容器访问宿主机的文件系统。例如，挂载 Docker 套接字和共享缓存目录。
- **`memory` 和 `cpus`**：为 Runner 分配内存和 CPU 资源，根据需要调整这些参数以优化构建性能。

### 启动 GitLab Runner

完成以上配置后，我们可以通过以下命令启动 GitLab Runner 容器：

```shell
docker-compose up -d  # 在后台启动服务
```

这将启动 GitLab Runner，并且它会自动与 GitLab 实例注册。您可以登录 GitLab 查看 Runner 是否成功注册并开始处理作业。