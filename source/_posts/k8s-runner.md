---
title: 如何在Kubernetes 环境中部署GitLab Runner 
date: 2025-01-15 17:25:25
tags:
    - GitLab
    - Helm
    - Runner
    - Kubernetes
category: Kubernetes
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 本文将详细介绍如何在 Kubernetes 集群中部署 GitLab Runner，包括环境准备、Runner 配置、认证设置、网络支持、Harbor 集成等完整的部署和配置流程。

<!-- more -->

## 环境要求

### 基础环境
- Kubernetes 集群 (版本 >= 1.16)
- Helm (版本 >= 3.9)
- kubectl 已配置可访问集群
- GitLab 服务器已部署(版本 >= 15.11)

### 版本选择
```bash
# 查看可用的 Runner 版本
helm repo add gitlab https://charts.gitlab.io
helm repo update gitlab
helm search repo -l gitlab/gitlab-runner | grep 15.11
```

## Runner 安装配置

### 准备安装包
```bash
# 创建工作目录
mkdir -p gitlab-runner && cd gitlab-runner

# 下载 Helm Chart
helm pull gitlab/gitlab-runner --version v0.52.1
tar xf gitlab-runner-0.52.1.tgz
cp gitlab-runner/values.yaml{,.bak}
```

### 配置 Runner
编辑 `gitlab-runner/values.yaml` 配置文件：

```yaml
# Runner 镜像配置
image:
  registry: docker.io
  image: gitlab/gitlab-runner
  tag: alpine-v15.11.1
  
# Harbor 认证配置
imagePullSecrets:
  - name: "harbor-credentials"

# Runner 实例数
replicas: 1

# GitLab 服务器配置
gitlabUrl: http://your-gitlab-server:port/
#certsSecretName: runner-tls-chain   # 如果使用 HTTPS 则需要配置

# 并发任务数
concurrent: 10

# 日志级别
logLevel: info

# RBAC 配置
rbac:
  create: true

# 监控配置
metrics:
  enabled: true
  portName: metrics
  port: 9252
  serviceMonitor:
    enabled: false

# Runner 具体配置
runners:
  config: |
    [[runners]]
      [runners.kubernetes]
        namespace = "{{.Release.Namespace}}"
        image = "ubuntu:16.04"
      [runners.custom_build_dir]
        enabled = true
      # 缓存配置 - 使用 MinIO
      [runners.cache]
        Type = "s3"
        Path = "runner"
        Shared = true
        [runners.cache.s3]
          ServerAddress = "your-minio-server:9000"
          BucketName = "runner-cache"
          AccessKey = "your-access-key"
          SecretKey = "your-secret-key"
          Insecure = true

  # Runner 执行器配置
  executor: kubernetes
  privileged: true
  tags: "kubernetes"
  secret: gitlab-runner

  # 构建容器资源限制
  builds: 
    cpuLimit: 2010m
    cpuLimitOverwriteMaxAllowed: 2010m
    memoryLimit: 2060Mi
    memoryLimitOverwriteMaxAllowed: 2060Mi
    cpuRequests: 100m
    cpuRequestsOverwriteMaxAllowed: 100m
    memoryRequests: 128Mi
    memoryRequestsOverwriteMaxAllowed: 128Mi

  # 服务容器资源限制
  services: 
    cpuLimit: 200m
    memoryLimit: 256Mi
    cpuRequests: 100m
    memoryRequests: 128Mi

  # Helper 容器资源限制
  helpers:
    cpuLimit: 200m
    memoryLimit: 256Mi
    cpuRequests: 100m
    memoryRequests: 128Mi
    image: "gitlab/gitlab-runner-helper:x86_64-v15.11.1"

  # Runner Pod 资源限制
  resources: 
    limits:
      memory: 256Mi
      cpu: 200m
    requests:
      memory: 128Mi
      cpu: 100m
```

## 认证配置

### 创建命名空间
```bash
kubectl create ns gitlab-runner
```

### 配置镜像仓库认证
```bash
# 创建 Harbor 认证密钥
kubectl create secret docker-registry harbor-credentials \
    --docker-server=your-harbor-server \
    --docker-username=your-robot-account \
    --docker-password=your-robot-password \
    -n gitlab-runner
```

### 配置 Runner 注册令牌
```bash
# 创建 Runner 注册密钥
kubectl create secret generic gitlab-runner \
  --from-literal=runner-registration-token=your-registration-token \
  --from-literal=runner-token="" \
  --type=Opaque \
  -n gitlab-runner
```

## 部署 Runner

### 安装
```bash
# 部署 Runner
helm install gitlab-runner ./gitlab-runner \
  -f gitlab-runner/values.yaml \
  --namespace gitlab-runner \
  --create-namespace
```

### 更新配置
```bash
# 更新 Runner 配置
helm upgrade gitlab-runner ./gitlab-runner \
  -f gitlab-runner/values.yaml \
  --namespace gitlab-runner
```

### 卸载
```bash
# 完全卸载 Runner
helm -n gitlab-runner uninstall gitlab-runner
```

## 网络配置

### GitLab 服务器配置
1. 修改 GitLab 主配置：
```bash
# 编辑 /etc/gitlab/gitlab.rb
gitlab_rails['outbound_local_requests'] = { "allow" => true }

# 重启 GitLab 服务
gitlab-ctl restart
```

2. 配置网络访问白名单：
- 访问路径：`http(s)://<gitlab-server>:<port>/admin/application_settings/network`
- 启用以下选项：
  - [x] Allow requests to the local network from webhooks and integrations
  - [x] Allow requests to the local network from system hooks
- 添加允许访问的内网域名/IP：
  ```
  harbor.your-domain.com
  minio.your-domain.com
  traefik.your-domain.com
  argocd.your-domain.com
  yourserver-internal-ips
  ```

## Harbor 集成

### GitLab 配置 Harbor
1. 访问配置页面：`http(s)://<gitlab-server>:<port>/groups/your-group/-/settings/integrations`
2. 找到 Harbor 配置区域：
   - [x] Enable integration
   - Harbor URL: `https://your-harbor-server`
   - Harbor project name: `your-project-name`
   - Harbor username: `your-robot-account`
   - Harbor password: `your-robot-password`

### 配置 Harbor 证书
在所有 Worker 节点上配置 Harbor 证书：

```bash
# 复制证书
cp /etc/tls/harbor/ca.crt /etc/ssl/certs/
cp /etc/tls/harbor/harbor.cert /etc/ssl/certs/

# 更新证书存储
update-ca-certificates

# 重启容器运行时
systemctl restart containerd
```

## 故障排查

### 常见问题
1. 镜像拉取失败
```bash
# 检查 Harbor 认证配置
kubectl get secret harbor-credentials -n gitlab-runner
kubectl describe secret harbor-credentials -n gitlab-runner

# 检查证书配置
ls -l /etc/ssl/certs/harbor*
```

2. Runner 注册失败
```bash
# 检查 Runner 状态
kubectl get pods -n gitlab-runner
kubectl logs -f <runner-pod-name> -n gitlab-runner

# 验证 GitLab 连接
curl -k https://your-gitlab-server/
```

### 资源限制验证
检查 Runner Pod 的资源限制是否生效：
```bash
kubectl get pod <runner-pod-name> -n gitlab-runner -o yaml
```

### 日志查看
```bash
# 查看 Runner Pod 日志
kubectl logs -f <runner-pod-name> -n gitlab-runner

# 查看构建任务 Pod 日志
kubectl logs -f <build-pod-name> -n gitlab-runner
```

## 最佳实践

### 资源配置建议
- 根据项目规模和构建需求调整资源限制
- 为不同类型的构建任务设置不同的资源配置
- 合理设置缓存策略，提高构建效率

### 安全建议
- 使用专用的 Runner 命名空间
- 配置适当的 RBAC 权限
- 定期更新 Runner 版本
- 使用 HTTPS 进行安全通信
- 妥善保管各类密钥和证书