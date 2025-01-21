---
title: 如何在Kubernetes 环境中安装 INGRESS-NGINX
date: 2025-01-21 15:57:25
tags:
    - TLS
    - KubeSphere
    - Ingress-NGINX
category: Kubernetes
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 本文将详细介绍如何在 Kubernetes 中部署 Ingress-NGINX 控制器，并配置 HTTP 和 HTTPS 访问。通过 Helm 工具，您可以快速安装并设置 NGINX 来代理外部流量，同时暴露 NodePort 服务。我们还会讲解如何配置 TLS 安全连接，并使用 Kubernetes Secret 来存储证书，确保数据传输加密。跟着本文的步骤走，您就能顺利完成 Ingress 部署，让集群应用访问更加便捷安全。

<!-- more -->

### 拉取 Helm 包

首先，添加 `ingress-nginx` 官方仓库并更新仓库信息，接着拉取所需的 Helm 包。

#### 添加 Helm 仓库

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

#### 搜索并拉取指定版本的 Helm 包

```bash
helm search repo ingress-nginx/ingress-nginx -l  # 查看所有版本
helm pull ingress-nginx/ingress-nginx --version 4.8.3  # 拉取指定版本
```

#### 解压 Helm 包

```bash
tar xf ingress-nginx-4.8.3.tgz
cd ingress-nginx
```

### 修改配置文件 `values.yaml`

在安装之前，您可能需要根据需求修改 `values.yaml` 文件，以配置 `ingress-nginx` 控制器的行为。常见的配置修改包括暴露 NodePort 端口。

#### 编辑 `values.yaml` 文件

修改 `values.yaml` 文件中的 `service` 配置，将 `type` 设置为 `NodePort`，并配置 `nodePorts`。

```yaml
service:
  enabled: true
  type: NodePort  # 设置为 NodePort 类型
  nodePorts:
    http: "30886"  # HTTP 端口
    https: "30887"  # HTTPS 端口
    tcp: {}  # TCP 端口配置（如果需要）
    udp: {}  # UDP 端口配置（如果需要）
```

### 安装 `ingress-nginx` 控制器

安装 `ingress-nginx` 控制器并创建一个 `ingress-nginx` 命名空间：

```bash
helm upgrade --install ingress-nginx ./ingress-nginx --namespace ingress-nginx --create-namespace
```

安装完成后，您将看到类似以下输出：

```
Release "ingress-nginx" does not exist. Installing it now.
NAME: ingress-nginx
LAST DEPLOYED: Sat Dec 23 11:00:59 2023
NAMESPACE: ingress-nginx
STATUS: deployed
```

### 配置并测试 Ingress

#### 创建一个简单的应用服务

为测试 `Ingress` 控制器，首先创建一个简单的 HTTP 服务：

```bash
kubectl create deployment demo --image=httpd --port=80
kubectl expose deployment demo
```

#### 创建 Ingress 资源

创建一个 `Ingress` 资源，配置一个简单的路由规则，指向刚才暴露的 `demo` 服务：

```bash
kubectl create ingress demo-localhost --class=nginx \
  --rule="demo.localdev.me/*=demo:80"
```

#### 使用 `kubectl port-forward` 进行本地访问

通过 `port-forward` 将 Ingress 控制器暴露到本地端口：

```bash
kubectl port-forward --namespace=ingress-nginx service/ingress-nginx-controller 8080:80
```

接着，您可以通过以下方式测试：

```bash
curl --resolve demo.localdev.me:8080:127.0.0.1 http://demo.localdev.me:8080
```

您应当看到：

```
<html><body><h1>It works!</h1></body></html>
```

### 配置 TLS（HTTPS）

为了启用 HTTPS，需要创建一个包含证书和私钥的 Kubernetes Secret，并在 `Ingress` 资源中引用该 Secret。

#### 创建 TLS 证书

如果您没有现成的证书，可以使用 `openssl` 创建一个自签名证书（仅用于测试）：

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout demo-tls.key -out demo-tls.crt
```

这将生成 `demo-tls.crt` 和 `demo-tls.key` 文件。

#### 创建 Kubernetes TLS Secret

使用以下命令将证书和私钥创建为 Kubernetes Secret：

```bash
kubectl create secret tls demo-tls-secret \
  --cert=demo-tls.crt \
  --key=demo-tls.key \
  --namespace=default
```

#### 配置 Ingress 使用 TLS

编辑您的 `Ingress` 配置，引用刚刚创建的 `demo-tls-secret`：

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo-tls-ingress
  namespace: default
spec:
  ingressClassName: nginx
  rules:
  - host: www.demo.io
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: demo
            port:
              number: 80
  tls:
  - hosts:
    - www.demo.io
    secretName: demo-tls-secret  # 引用 TLS Secret
```

#### 测试 TLS 配置

在 `Ingress` 配置完成后，您可以通过浏览器访问 `https://www.demo.io` 来验证 HTTPS 是否正常工作。如果一切配置正确，您应该能够安全地访问您的服务。

### 配置本地 DNS（可选）

如果您希望使用自定义域名访问服务，可以修改本地 `hosts` 文件，将域名指向相应的 IP 地址：

```bash
echo "192.168.1.120 www.demo.io" | sudo tee -a /etc/hosts
```

之后，通过浏览器访问 `http://www.demo.io:30886/` 或 `https://www.demo.io:30887/` 来验证服务。

### 总结

通过以上步骤，您成功安装并配置了 `ingress-nginx` 控制器，并通过 Kubernetes Secret 配置了 TLS 加密连接，确保了流量的安全传输。您还可以根据实际需求调整端口、证书和域名等配置，进一步优化您的部署。

### Q & A

1. **如何修改暴露端口？**  
   您可以通过编辑 `values.yaml` 文件中的 `nodePorts` 配置项，来修改暴露的端口号。

2. **如何启用 TLS？**  
   在 `Ingress` 配置文件中添加 `tls` 部分，并确保 Secret 包含有效的证书和私钥。

3. **如果使用自签名证书？**  
   使用自签名证书时，浏览器可能会显示不受信任的警告，您可以忽略这个警告，或者在浏览器中将证书添加到信任列表。