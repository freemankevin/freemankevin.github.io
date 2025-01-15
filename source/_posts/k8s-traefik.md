---
title: 如何在Kubernetes 环境中部署Traefik
date: 2025-01-15 17:10:25
tags:
    - TLS
    - NGINX
    - Traefik
    - Kubernetes
category: Kubernetes
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 本文将详细介绍如何在 Kubernetes 集群中安装和配置带有 TLS 的 Traefik Ingress Controller。包括环境准备、安装配置、TLS 证书管理、认证设置以及常见问题排查等完整流程。

<!-- more -->

## 环境要求

### 基础环境要求

- Kubernetes 集群 (版本 >= 1.16)
- Helm (版本 >= 3.9)
- kubectl 已配置可访问集群

### 版本信息
```bash
# 检查 helm 版本
helm version
```

## 安装 Traefik

### 添加 Helm 仓库
```bash
# 添加官方 helm 仓库
helm repo add traefik https://traefik.github.io/charts
helm repo update

# 查看可用版本
helm search repo traefik/traefik -l
```

### 准备配置文件

创建 `values.yaml` 配置文件：

```yaml
# Traefik 基础配置
ingressRoute:
  dashboard:
    enabled: true

ingressClass:
  enabled: true
  isDefaultClass: false

providers:
  kubernetesCRD:
    enabled: true
    allowCrossNamespace: true
    allowExternalNameServices: true

  kubernetesIngress:
    enabled: true
    allowExternalNameServices: true

# 日志配置
logs:
  general:
    level: DEBUG
  access:
    enabled: true

# 服务配置
service:
  enabled: true
  single: true
  type: ClusterIP

# 额外参数
additionalArguments:
  - "--log.level=DEBUG"
```

### 部署 Traefik

```bash
# 创建命名空间并安装 Traefik
helm install traefik traefik/traefik \
  --namespace=traefik-v2 \
  --create-namespace \
  --values=values.yaml \
  --version 25.0.0

# 查看部署状态
kubectl get pods -n traefik-v2
```

## 配置 TLS

### 生成证书
```bash
# 创建证书目录
mkdir -p tls && cd tls

# 创建 CA 配置文件
cat > openssl-ca.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
default_days = 3650
default_md = sha256
prompt = no

[req_distinguished_name]
CN = My Root CA

[v3_ca]
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer
basicConstraints = critical, CA:true 
EOF

# 创建服务器证书配置
cat > openssl-server.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no
default_days = 3650
default_md = sha256

[req_distinguished_name]
CN = traefik.k8scluster.com

[v3_req]
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = traefik.k8scluster.com
EOF

# 生成证书
openssl genrsa -out rootCA.key 2048
openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 3650 -out rootCA.crt -config openssl-ca.cnf
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr -config openssl-server.cnf
openssl x509 -req -in server.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out server.crt -days 3650 -sha256 -extensions v3_req -extfile openssl-server.cnf
```

### 创建 TLS Secret
```bash
kubectl create secret tls traefik-ingress-dashboard \
  --namespace traefik-v2 \
  --key ./server.key \
  --cert ./server.crt

# 验证证书
kubectl -n traefik-v2 get secret traefik-ingress-dashboard -o jsonpath="{.data.tls\.crt}" | base64 --decode | openssl x509 -inform pem -text -noout
```

## 配置认证

### 创建 Basic Auth
```bash
# 安装 htpasswd 工具
apt-get update && apt-get install apache2-utils -y

# 生成密码
htpasswd -nb admin <your-password> | kubectl create secret generic basic-auth \
  --namespace=traefik-v2 \
  --from-file=auth=/dev/stdin
```

### 创建 IngressRoute
```yaml
# traefik-websecure-dashboard.yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: websecure-dashboard
  namespace: traefik-v2
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`traefik.k8scluster.com`) && (PathPrefix(`/dashboard`) || PathPrefix(`/api`))
      kind: Rule
      services:
        - name: api@internal
          kind: TraefikService
      middlewares:
        - name: basic-auth
          namespace: traefik-v2
  tls:
    secretName: traefik-ingress-dashboard
```

### 创建认证中间件
```yaml
# traefik-middleware.yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: basic-auth
  namespace: traefik-v2
spec:
  basicAuth:
    secret: basic-auth
```

## 暴露服务

```bash
# 配置 NodePort 服务
kubectl patch svc traefik -n traefik-v2 -p '{
  "spec": {
    "type": "NodePort",
    "ports": [
      {
        "name": "web",
        "port": 80,
        "targetPort": "web",
        "nodePort": 30882
      },
      {
        "name": "websecure",
        "port": 443,
        "targetPort": "websecure",
        "nodePort": 30883
      }
    ]
  }
}'

# 验证服务状态
kubectl get svc -n traefik-v2
```

## 访问控制台

1. 添加域名解析（本地测试可修改 hosts 文件）：
```bash
echo "${NODE_IP} traefik.k8scluster.com" >> /etc/hosts
```

2. 访问地址：
- Dashboard: https://traefik.k8scluster.com:30883/dashboard/
- 使用之前设置的用户名密码登录

## 常见问题排查

### 证书问题
```bash
# 检查证书是否正确创建
kubectl get secret -n traefik-v2
kubectl describe secret traefik-ingress-dashboard -n traefik-v2
```

### 访问问题
```bash
# 检查 Pod 状态
kubectl get pods -n traefik-v2
kubectl describe pod -n traefik-v2 <pod-name>

# 检查日志
kubectl logs -n traefik-v2 <pod-name>
```

### 配置更新
```bash
# 更新 Traefik 配置
helm upgrade traefik traefik/traefik \
  --namespace=traefik-v2 \
  --values=values.yaml
```