---
title: 如何在Kubernetes 环境中安装 KubeSphere
date: 2025-01-21 16:32:25
tags:
    - Linux
    - KubeSphere
    - Helm
category: Kubernetes
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 本文将介绍如何在 Kubernetes 集群中在线安装 KubeSphere，这是一个功能强大的容器管理平台，能够帮助用户方便地管理 Kubernetes 环境。我们将通过 Helm 进行安装，详细讲解每一步的操作流程，并展示如何通过浏览器访问 KubeSphere 控制台。最后，我们还会提供卸载 KubeSphere 的步骤，帮助您轻松管理平台的生命周期。

<!-- more -->

## 安装 KubeSphere

KubeSphere 是一个开源的容器管理平台，可以轻松实现 Kubernetes 集群的统一管理。要安装 KubeSphere，我们可以通过 Helm 工具进行在线安装，步骤如下：

首先，在 Kubernetes 集群中应用 KubeSphere 的安装文件：

```shell
kubectl apply -f https://github.com/kubesphere/ks-installer/releases/download/v3.4.1/kubesphere-installer.yaml
kubectl apply -f https://github.com/kubesphere/ks-installer/releases/download/v3.4.1/cluster-configuration.yaml
```

接着，设置区域为中国：

```shell
export KKZONE=cn
echo "export KKZONE=cn" >> /etc/profile
source /etc/profile
```

然后，通过 Helm 安装 KubeSphere：

```shell
helm repo add kubesphere https://charts.kubesphere.io/main
helm repo update
helm install ks kubesphere/kubesphere --namespace kubesphere-system --create-namespace
```

安装过程会自动拉取所需的镜像并配置相应的服务。

安装完成后，您可以使用以下命令查看 KubeSphere 安装日志，确保安装成功：

```shell
kubectl logs -n kubesphere-system -l app=ks-installer -f
```

然后，使用浏览器访问 KubeSphere 控制台：

```
控制台: http://<Your-IP>:30880
账户: admin
密码: P@88w0rd
```

---

## 卸载 KubeSphere

如果需要卸载 KubeSphere，您可以通过以下命令进行操作。请注意，卸载过程会删除 KubeSphere 所有相关资源，请谨慎操作。

首先，执行卸载命令：

```shell
helm uninstall ks --namespace kubesphere-system
```

然后，清理残留的资源：

```shell
kubectl delete namespace kubesphere-system
```

如果遇到命名空间无法删除的情况，可以手动删除 `finalizers` 字段：

```shell
kubectl get namespace kubesphere-system -o json > kubesphere-system-temp.json
vim kubesphere-system-temp.json
# 删除 "finalizers" 字段
kubectl replace --raw "/api/v1/namespaces/kubesphere-system/finalize" -f ./kubesphere-system-temp.json
```

完成后，KubeSphere 就会被彻底卸载。

## 配置 KubeSphere 代理

在一些场景下，您可能需要为 KubeSphere 控制台添加一个代理，以便更方便地通过自定义域名访问。下面是如何通过 Docker Compose 配置 Nginx 代理服务的步骤。

首先，创建一个 `docker-compose.yaml` 文件，配置 Nginx 代理，并映射 KubeSphere 控制台的端口。以下是完整的配置文件内容：

```yaml
version: '3.8'
services:
  ks-console-proxy:
    image: harbor.dockerregistry.com/library/nginx:1.21.6-alpine
    container_name: ks-console-proxy
    ports:
      - "8080:8080"   # 映射 HTTP 端口
      - "8443:8443"   # 映射 HTTPS 端口
    volumes:
      - '/etc/localtime:/etc/localtime:ro'                       # 确保容器使用宿主机的时区设置
      - './nginx/ssl:/etc/nginx/ssl'                               # 绑定 SSL 证书文件
      - './nginx/nginx.conf:/etc/nginx/nginx.conf'                 # 配置 Nginx 主配置文件
      - './nginx/conf.d/ks-console.conf:/etc/nginx/conf.d/default.conf'  # 配置 KubeSphere 控制台的反向代理
      - '/data/nginx/logs:/var/log/nginx'                          # 映射日志文件
    restart: always
    healthcheck:
      test: ["CMD-SHELL", "curl --silent --fail --insecure https://localhost:8443 || exit 1"]
      interval: 1m30s
      timeout: 10s
      retries: 3
      start_period: 3s
```

### 文件说明
- `ks-console-proxy`：此服务为 KubeSphere 控制台提供反向代理。
- `ports`：映射容器的 HTTP (8080) 和 HTTPS (8443) 端口，方便用户通过浏览器访问控制台。
- `volumes`：
  - `/etc/localtime:/etc/localtime:ro`：使容器时区与宿主机一致。
  - `./nginx/ssl:/etc/nginx/ssl`：存放 SSL 证书的目录，用于加密 HTTPS 访问。
  - `./nginx/nginx.conf:/etc/nginx/nginx.conf`：Nginx 的主配置文件。
  - `./nginx/conf.d/ks-console.conf:/etc/nginx/conf.d/default.conf`：配置 KubeSphere 控制台的反向代理规则。
  - `/data/nginx/logs:/var/log/nginx`：容器的日志文件存放目录。
- `healthcheck`：配置健康检查，确保容器正常运行。

### 目录结构
在您的服务器上，创建以下目录结构：

```
ks-console
├── docker-compose.yaml           # Docker Compose 配置文件
└── nginx
    ├── conf.d
    │   └── ks-console.conf      # KubeSphere 控制台的代理配置文件
    ├── nginx.conf               # Nginx 主配置文件
    └── ssl
        ├── kubesphere.k8scluster.com.crt  # KubeSphere SSL 证书
        └── kubesphere.k8scluster.com.key  # KubeSphere SSL 密钥
```

### 配置文件示例

1. **Nginx 配置文件 `nginx.conf`**（位于 `./nginx/nginx.conf`）：
   ```nginx
   user nginx;
   worker_processes auto;
   error_log /var/log/nginx/error.log;
   pid /var/run/nginx.pid;

   events {
       worker_connections 1024;
   }

   http {
       include       /etc/nginx/mime.types;
       default_type  application/octet-stream;
       access_log /var/log/nginx/access.log;

       sendfile on;
       tcp_nopush on;
       tcp_nodelay on;
       keepalive_timeout 65;
       types_hash_max_size 2048;

       include /etc/nginx/conf.d/*.conf;
   }
   ```

2. **KubeSphere 控制台代理配置 `ks-console.conf`**（位于 `./nginx/conf.d/ks-console.conf`）：
   ```nginx
    # HTTP server
    server {
        listen 8080;

        server_name kubesphere.k8scluster.com;

        # 强制将所有 HTTP 流量重定向到 HTTPS
        location / {
            return 301 https://$host:8443$request_uri;
        }
    }

    # HTTPS server
    server {
        listen 8443 ssl;

        server_name kubesphere.k8scluster.com;

        # 访问日志和错误日志配置
        access_log /var/log/nginx/access.log main;
        error_log  /var/log/nginx/error.log;

        # 默认首页文件
        index index.html index.htm;

        # SSL 配置
        ssl_certificate     /etc/nginx/ssl/kubesphere.k8scluster.com.crt;
        ssl_certificate_key /etc/nginx/ssl/kubesphere.k8scluster.com.key;

        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_prefer_server_ciphers on;
        ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH";
        ssl_ecdh_curve secp384r1;
        ssl_session_cache shared:SSL:10m;
        ssl_session_tickets off;
        
        add_header Strict-Transport-Security "max-age=63072000; includeSubDomains";
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;

        # 强制 HTTPS 协议
        if ($ssl_protocol = "") {
            return 301 https://$host$request_uri;
        }

        # 全局代理设置
        proxy_http_version 1.1;
        proxy_set_header    Host $host:$server_port;
        proxy_set_header    X-Real-IP $remote_addr;
        proxy_set_header    X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 3600s;
        proxy_read_timeout  3600s;
        proxy_send_timeout  3600s;
        send_timeout        3600s;

        # 代理到 KubeSphere 控制台
        location / {
            proxy_pass http://<kubesphere_address>:30880;  # 替换为 KubeSphere 控制台实际地址
            proxy_redirect off;
        }

        # API 路径代理
        location /api/ {
            proxy_pass http://<kubesphere_address>:30880;
            proxy_set_header    Upgrade $http_upgrade;
            proxy_set_header    X-Forwarded-Proto $scheme;
            proxy_set_header    Connection "upgrade"; 
            proxy_redirect off;
        }

        # 一些特定 API 路径代理
        location ~ /apis/monitoring.coreos.com/|/api/v1/|/apis/storage.k8s.io|/apis/apps/v1/namespaces/|/kapis/resources.kubesphere.io/v1alpha2/namespaces|/kapis/resources.kubesphere.io/|/apis/devops.kubesphere.io/|/apis/apps/v1/|/apis/|/api/v1/watch/namespaces|/kapis/terminal.kubesphere.io/ {
            proxy_pass http://<kubesphere_address>:30880;
            proxy_redirect off;
        }
    }

   ```

### 启动服务

完成配置后，进入 `ks-console` 目录并运行以下命令启动 Nginx 代理服务：

```bash
docker-compose up -d
```

通过浏览器访问 KubeSphere 控制台，您应该能够通过配置的自定义域名访问控制台，如 `https://kubesphere.k8scluster.com:8443`。
