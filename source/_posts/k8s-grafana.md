---
title: 如何在Kubernetes 环境中安装 Grafana 部署指南
date: 2025-01-21 16:53:25
tags:
    - TLS
    - KubeSphere
    - Ingress-NGINX
category: Kubernetes
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 本文介绍如何通过 Helm 部署 Grafana 并配置反向代理，以便在 Kubernetes 集群中使用 Grafana，支持 HTTPS 加密和基本认证。

<!-- more -->

## 下载 Helm Chart

首先创建目录并下载 Grafana 的 Helm Chart。

```shell
mkdir -p grafana 
cd grafana
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm search repo grafana/grafana -l
helm search repo grafana/grafana --versions

# 如果需要下载指定版本
# helm pull grafana/grafana --version 7.2.3 
tar xf grafana-7.2.3.tgz
cp -rvf grafana/values.yaml{,.bak}
```

## 创建自定义 `values.yaml`

Grafana 的 `values.yaml` 文件用于配置 Helm Chart 部署的参数。以下是常用的配置项：

```yaml
image:
  registry: docker.io
  repository: grafana/grafana
  tag: "10.2.3"  # 修改为固定版本的镜像标签
  
ingress:
  enabled: true  # 启用 Ingress
  annotations:  # 添加注释
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/rewrite-target: /$1
    nginx.ingress.kubernetes.io/use-regex: "true"
  hosts:
    - grafana.k8scluster.com  # 使用域名访问 Grafana
  
persistence:
  type: pvc 
  enabled: true  # 启用 PVC 持久化存储
  storageClassName: default  # 使用默认存储类
  accessModes:
    - ReadWriteOnce
  size: 1Gi  # 设置 PVC 大小为 1Gi

extraVolumeMounts:  # 配置额外的挂载路径
  - name: grafana-data
    mountPath: /var/lib/grafana/plugins
    subPath: plugins
    readOnly: false
  - name: grafana-data
    mountPath: /var/lib/grafana/dashboards
    subPath: dashboards
    readOnly: false
  - name: grafana-data
    mountPath: /etc/grafana/provisioning
    subPath: provisioning
    readOnly: false

extraVolumes:
  - name: grafana-data
    persistentVolumeClaim:
      claimName: grafana-data-pvc  # 使用指定的 PVC
```

### 配置解释

- **镜像配置 (`image`)**：选择正确的 Grafana 镜像版本。这里的 `tag` 参数设置为具体版本，如 `10.2.3`。
  
- **Ingress 配置 (`ingress`)**：
  - 启用 Ingress 以便通过域名访问 Grafana。
  - `nginx.ingress.kubernetes.io/rewrite-target`：将请求路径重写为适合 Grafana 的路径。
  - `path` 和 `pathType` 配置了访问路径，并使用正则匹配来灵活处理请求。
  - `hosts` 配置为本地域名，确保 Grafana 可以通过指定域名访问。

- **持久化配置 (`persistence`)**：
  - 使用 PVC 进行持久化存储，以便在 Grafana Pod 重启时不会丢失数据。
  - 配置存储大小为 `1Gi`，并选择合适的存储类 `default`。

- **额外的挂载配置 (`extraVolumeMounts`)**：
  - 将 Grafana 的插件、仪表盘和配置文件夹挂载到指定路径，确保 Grafana 启动时能够使用这些资源。

## 使用 Helm 安装 Grafana

使用以下命令来安装 Grafana 并指定自定义的 `values.yaml` 配置文件：

```shell
helm install grafana -f grafana/values.yaml ./grafana --namespace grafana --create-namespace
```

### 安装完成后输出

安装完成后，您可以通过以下命令获取 Grafana 的默认管理员密码：

```shell
kubectl get secret --namespace grafana grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

Grafana 控制台可以通过以下 DNS 地址访问：

```text
http://grafana.k8scluster.com
```

登录时，使用管理员账户 `admin` 和密码。

## 更新 Helm 部署

若需要对已部署的 Grafana 进行更新（例如修改配置），可以使用以下命令：

```shell
helm upgrade grafana -f grafana/values.yaml ./grafana --namespace grafana
```

### 更新后输出

更新后同样可以通过以下命令获取更新后的管理员密码：

```shell
kubectl get secret --namespace grafana grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

## 登录 Grafana 控制台

Grafana 控制台可以通过浏览器访问以下地址：

```text
http://grafana.k8scluster.com:30886/grafana
```

登录时，使用之前获取的管理员密码进行登录。

## 导出 Prometheus 和 Alertmanager

### 创建 Prometheus 和 Alertmanager 的 Ingress

为 Prometheus 和 Alertmanager 创建一个 Ingress 资源，使其通过域名访问。

```yaml
kind: Ingress
apiVersion: networking.k8s.io/v1
metadata:
  name: prometheus-ingress
  namespace: kubesphere-monitoring-system
  annotations:
    nginx.ingress.kubernetes.io/auth-realm: Authentication Required
    nginx.ingress.kubernetes.io/auth-secret: prometheus-basic-auth
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/proxy-body-size: 2048m
    nginx.ingress.kubernetes.io/proxy-connect-timeout: '1800'
    nginx.ingress.kubernetes.io/proxy-read-timeout: '1800'
    nginx.ingress.kubernetes.io/proxy-send-timeout: '1800'
spec:
  ingressClassName: nginx
  rules:
    - host: prometheus.k8scluster.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: prometheus-k8s
                port:
                  name: web
    - host: alertmanager.k8scluster.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: alertmanager-main
                port:
                  name: web
```

### 创建 HTTP 基本认证

通过 `htpasswd` 创建一个基本认证文件，并将其作为 Secret 存储：

```shell
htpasswd -c auth admin  # 设置管理员密码
```

### 创建 Secret

创建 Kubernetes Secret，用于存储基本认证凭证：

```shell
kubectl create secret generic prometheus-basic-auth --from-file=auth -n monitoring
```
