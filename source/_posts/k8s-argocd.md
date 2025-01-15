---
title: 如何在Kubernetes 环境中部署ArgoCD
date: 2025-01-15 17:47:25
tags:
    - ArgoCD
    - Helm
    - RBAC
    - TLS
    - Kubernetes
category: Kubernetes
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 本文详细介绍如何在 Kubernetes 集群中部署高可用的 ArgoCD，包括客户端工具安装、服务端部署、TLS 配置、用户认证、RBAC 权限管理等完整的部署和配置流程。

<!-- more -->

## 环境要求

### 基础环境
- Kubernetes 集群 (版本 >= 1.21)
- 至少三个 Worker 节点（用于 HA 部署）
- 可用的持久化存储
- 集群负载均衡能力

### 版本选择
```bash
# 查看版本兼容性
# https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/#tested-versions
```

## 客户端安装

### 下载安装
```bash
# 下载 ArgoCD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/v2.9.2/argocd-linux-amd64

# 安装到系统目录
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# 验证安装
argocd version
```

### 多节点部署
在所有需要使用 ArgoCD CLI 的节点上执行安装：
```bash
# 分发 CLI 到其他节点（根据实际环境修改节点名称）
for node in <node1> <node2> <node3>; do
  scp /usr/local/bin/argocd $node:/usr/local/bin/
  ssh $node "chmod +x /usr/local/bin/argocd"
done
```

## 服务端部署

### 准备命名空间
```bash
# 创建专用命名空间
kubectl create namespace argocd
```

### 部署 ArgoCD
```bash
# 添加 Helm 仓库
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# 创建配置文件 values.yaml
cat > values.yaml <<EOF
# 全局配置
global:
  image:
    repository: quay.io/argoproj/argocd
    tag: v2.9.2

# HA 配置
controller:
  replicas: 2

server:
  replicas: 2
  service:
    type: NodePort
    nodePortHttp: <HTTP_PORT>    # 例如：30884
    nodePortHttps: <HTTPS_PORT>  # 例如：30885

# Redis HA 配置
redis-ha:
  enabled: true
  persistentVolume:
    enabled: true
    size: 8Gi

# 认证配置
dex:
  enabled: true

# 资源限制
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
EOF

# 安装 ArgoCD
helm install argocd argo/argo-cd \
  --namespace argocd \
  --values values.yaml
```

### 验证部署
```bash
# 检查 Pod 状态
kubectl get pods -n argocd

# 检查服务状态
kubectl get svc -n argocd
```

## 访问配置

### 暴露服务
```bash
# 配置 NodePort 访问（端口号根据实际情况调整）
kubectl patch svc argocd-server -n argocd -p '{
  "spec": {
    "type": "NodePort",
    "ports": [
      {"nodePort": <HTTP_PORT>, "port": 80},
      {"nodePort": <HTTPS_PORT>, "port": 443}
    ]
  }
}'
```

### 配置 DNS
在 CoreDNS 中添加解析：
```yaml
# 编辑 CoreDNS 配置
kubectl -n kube-system edit cm coredns

# 添加以下配置（替换为实际的 IP 和域名）
hosts {
  <NODE_IP> <ARGOCD_DOMAIN>  # 例如：argocd.example.com
  fallthrough
}

# 重启 CoreDNS
kubectl delete pod -n kube-system -l k8s-app=kube-dns
```

## 初始配置

### 获取初始密码
```bash
# 获取管理员密码
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

### 修改密码
```bash
# 登录 ArgoCD（使用实际的域名和端口）
argocd login <ARGOCD_DOMAIN>:<PORT>

# 修改密码
argocd account update-password
```

## RBAC 配置

### 角色配置
编辑 `argocd-rbac-cm` 配置：
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.csv: |
    # 项目管理员角色
    p, role:project-admin, applications, create, project/*, allow
    p, role:project-admin, applications, delete, project/*, allow
    p, role:project-admin, applications, sync, project/*, allow
    p, role:project-admin, applications, update, project/*, allow
    p, role:project-admin, logs, get, project/*, allow
    
    # 只读角色
    p, role:readonly, applications, get, */*, allow
    p, role:readonly, logs, get, */*, allow
    
    # 用户组映射
    g, project-admins, role:project-admin
    g, viewers, role:readonly
  
  policy.default: role:readonly
```

### 用户管理
编辑 `argocd-cm` 配置：
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  # 启用本地用户
  accounts.project-admin: apiKey,login
  accounts.viewer: login
  
  # OIDC 配置（可选，根据实际环境配置）
  oidc.config: |
    name: <SSO_PROVIDER>
    issuer: https://<SSO_URL>/auth/realms/<REALM_NAME>
    clientID: <CLIENT_ID>
    clientSecret: <CLIENT_SECRET>
```

## 高级配置

### 资源限制
```yaml
# 设置资源限制
spec:
  template:
    spec:
      containers:
      - name: argocd-application-controller
        resources:
          limits:
            cpu: "1"
            memory: 1Gi
          requests:
            cpu: 250m
            memory: 512Mi
```

### TLS 配置
```bash
# 创建 TLS 证书（使用实际的证书文件）
kubectl create secret tls argocd-server-tls \
  --cert=<CERT_FILE> \
  --key=<KEY_FILE> \
  -n argocd

# 配置 ArgoCD 使用证书
kubectl patch deployment argocd-server \
  -n argocd \
  --type json \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--tls.certificate=/etc/argocd/tls/tls.crt"}, {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--tls.privatekey=/etc/argocd/tls/tls.key"}]'
```

## 故障排查

### 常见问题
1. 登录问题
```bash
# 检查密码是否正确
argocd admin initial-password -n argocd

# 检查服务状态
kubectl get pods -n argocd
kubectl logs -f deployment/argocd-server -n argocd
```

2. 同步失败
```bash
# 检查应用状态
argocd app get <APP_NAME>
argocd app logs <APP_NAME>

# 检查控制器日志
kubectl logs -f deployment/argocd-application-controller -n argocd
```

### 健康检查
```bash
# 检查组件状态
kubectl get pods -n argocd
kubectl get svc -n argocd

# 检查系统健康状态
argocd admin cluster info
```

## 最佳实践

### 安全建议
- 及时更新 ArgoCD 版本
- 使用 HTTPS 和证书
- 实施最小权限原则
- 定期轮换密钥和证书
- 启用审计日志

### 性能优化
- 合理配置资源限制
- 使用 Redis HA 提高可用性
- 配置合适的同步周期
- 使用项目配置限制资源范围