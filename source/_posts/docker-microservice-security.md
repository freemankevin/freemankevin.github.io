---
title: Docker 微服务架构安全实践指南
date: 2026-04-17 11:00:00
tags:
  - Docker
  - Security
  - Microservice
  - Network
category: Docker
---

在 Docker 容器化微服务架构中,安全是一个不可忽视的重要环节。本文将分享一套完整的 Docker 微服务环境安全加固方案,涵盖端口暴露最小化、网络隔离、敏感信息管理以及多层防御策略。通过本指南,你可以有效缩减 90%+ 的攻击面,提升整体系统安全性。

<!-- more -->

**适用版本与环境说明：**
- Docker Engine: 20.10.x 及以上版本
- Docker Compose: 2.x 及以上版本
- 操作系统: Ubuntu 20.04+/Debian 11+/CentOS 7.9+
- 内核版本: 建议 4.18+ 以支持完整的网络和安全特性
- 更新日期: 2026-04-17（建议每季度检查 Docker 安全公告）

## 核心安全原则

## 核心安全原则

### 端口最小化暴露原则

在容器化环境中,端口暴露应遵循最小权限原则:

| 端口类型 | 是否映射到宿主机 | 说明 |
|---------|----------------|------|
| 22/tcp (SSH) | ✅ 是 | 系统管理必需 |
| 80/tcp (HTTP) | ✅ 是 | Web 业务入口 |
| 443/tcp (HTTPS) | ✅ 是 | 安全 Web 入口(推荐) |
| 数据库端口 (5432, 3306等) | ❌ 否 | 仅容器内部访问 |
| 缓存端口 (6379, 11211等) | ❌ 否 | 仅容器内部访问 |
| 注册中心端口 (8848, 8500等) | ❌ 否 | 仅容器内部访问 |
| 后端服务端口 | ❌ 否 | 通过网关转发 |
| 管理后台端口 | ❌ 否 | 通过反向代理或VPN访问 |

### 网络分层架构

```
                     [ 用户/外部网络 ]
                            |
                            | HTTP/HTTPS (80/443)
                            v
                   [ Nginx 容器 (唯一入口) ]
                            |
               ---( Docker 内部网络: apps、middleware等 )---
                            |
                            v
                 [ gateway 容器 (网关) ]
                        /   |   \
                       /    |    \  (通过容器名称转发)
                      v     v     v
    [ auth-service ]  [ user-service ]  [ business-service ]
         |             |                |
         |             |                |
         +-------------+----------------+
                       |
                       v
           [ 中间件层 ]
         为了安全，以上所有容器均无端口映射到外部
```

**网络分层说明**:

1. **外部入口层**: 仅开放 HTTP(80) 和 HTTPS(443) 端口,所有流量必须通过 Nginx
2. **网关层**: API Gateway 负责路由转发和权限验证
3. **应用服务层**: 各业务微服务,通过容器名称互相调用
4. **中间件层**: 数据库、缓存、注册中心等基础服务,严格内部访问

{% note warning %}
**重要说明**: 
在 Docker Compose 环境中,服务间通信应使用**容器名称**(`container_name`)而非服务名称(`service name`)。容器名称是容器在网络中的唯一标识,确保服务间能够正确解析和访问。
{% endnote %}

**安全策略**:
- 所有内部服务容器均无端口映射到宿主机
- 外部请求只能到达 Nginx 容器
- 内部服务通过 Docker 网络隔离,无法直接从外部访问

## 宿主机防火墙配置

### 启用 UFW 防火墙

```bash
# 启用 UFW 防火墙
sudo ufw enable

# 设置默认策略:拒绝所有入站,允许所有出站
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 仅开放必要端口
sudo ufw allow 22/tcp comment 'SSH Management'
sudo ufw allow 80/tcp comment 'HTTP Web Entry'
sudo ufw allow 443/tcp comment 'HTTPS Web Entry'

# 验证配置
sudo ufw status verbose
```

预期输出:

```
Status: active
Default: deny (incoming), allow (outgoing)

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
80/tcp                     ALLOW IN    Anywhere
443/tcp                    ALLOW IN    Anywhere
```

## Docker 网络架构配置

### 创建隔离网络

```yaml
# docker-compose.yml 顶层网络配置
networks:
  # 前端接入层网络
  frontend:
    driver: bridge
    internal: false  # 允许外部访问
  
  # 应用服务层网络
  apps:
    driver: bridge
    internal: true   # 仅内部通信(可选,根据需求)
  
  # 中间件层网络
  middleware:
    driver: bridge
    internal: true   # 严格内部访问
  
  # 模型服务层网络
  ai-services:
    driver: bridge
    internal: true
```

### 服务网络归属原则

| 服务类型 | 网络归属 | 端口映射 |
|---------|---------|---------|
| Nginx (反向代理) | frontend + apps | 80:80, 443:443 |
| API Gateway | apps + middleware | 无 |
| Java 微服务 | apps + middleware | 无 |
| Python 后端 | apps + ai-services | 无 |
| PostgreSQL | middleware + apps | 无 |
| Redis | middleware + apps | 无 |
| Nacos | middleware + apps | 无 |
| MinIO | middleware + apps | 无 |
| AI 模型服务 | ai-services + apps | 无 |

### 跨 Compose 文件的外部网络配置

当服务分布在不同 Docker Compose 文件中时,需要使用外部网络实现互联互通。**关键步骤**:

1. **查看现有 Docker 网络**:

```bash
# 查看所有 Docker 网络
docker network ls

# 输出示例:
# NETWORK ID     NAME                      DRIVER    SCOPE
# abc123def456   installapps_apps          bridge    local
# def789ghi012   middleware                bridge    local
```

2. **在 Compose 文件中引用外部网络**:

```yaml
services:
  nginx:
    image: nginx:1.29.0-alpine
    container_name: nginx
    ports:
      - "80:80"
      - "443:443"
    environment:
      - TZ=Asia/Shanghai
    networks:
      - middleware
      - installapps_apps  # 引用外部网络(来自其他 compose 文件)
    healthcheck:
      test: ["CMD", "nginx", "-t"]
      interval: 30s
      timeout: 10s
      retries: 3
    volumes:
      - ./conf/mime.types:/etc/nginx/mime.types:ro
      - ./conf/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./conf/web.conf:/etc/nginx/conf.d/default.conf:ro
      - ./data/nginx/html:/usr/share/nginx/html
      - ./data/nginx/logs:/var/log/nginx:rw
    restart: always

networks:
  installapps_apps:
    external: true  # 声明为外部网络
  middleware:
    driver: bridge
```

{% note danger %}
外部网络的名称必须与 `docker network ls` 中显示的名称完全一致。
{% endnote %}

## 端口映射配置规范

### 正确示例:仅映射必要端口

```yaml
services:
  # 唯一对外入口
  nginx:
    image: nginx:1.29-alpine
    container_name: nginx
    ports:
      - "80:80"
      - "443:443"
    networks:
      - frontend
      - apps

  # 后端服务:不映射端口
  gateway:
    image: <your-registry>/gateway:<tag>
    container_name: gateway
    # ports: 删除所有端口映射
    networks:
      - apps
      - middleware

  # 数据库:不映射端口
  postgres:
    image: <your-registry>/postgres:<tag>
    container_name: postgres
    # ports: 删除所有端口映射
    networks:
      - middleware

  # 缓存:不映射端口
  redis:
    image: <your-registry>/redis:<tag>
    container_name: redis
    # ports: 删除所有端口映射
    networks:
      - middleware
```

{% note info %}
**关键点**:
- `ports` 配置中的端口是**容器自身服务端口**,如 Nginx 默认 80、PostgreSQL 默认 5432
- 容器间通信使用 `container_name` 作为主机名,而非 `service name`
{% endnote %}

### 错误示例:过度暴露端口

```yaml
# 危险!不要这样配置
services:
  postgres:
    image: postgres:17
    container_name: postgres
    ports:
      - "5432:5432"  # ⚠️ 数据库端口暴露在外
  
  redis:
    image: redis:8
    container_name: redis
    ports:
      - "6379:6379"  # ⚠️ 缓存端口暴露在外
  
  backend:
    image: backend:latest
    container_name: backend
    ports:
      - "8080:8080"  # ⚠️ 后端端口暴露在外
```

## 敏感信息安全处理

### 配置文件脱敏规范

#### 镜像名称脱敏

```yaml
# ❌ 原始配置(含敏感信息)
services:
  app:
    image: "mycompany/app-server:v1.2.3"
    image: "registry.internal.com/project/backend:abc123"

# ✅ 脱敏后配置
services:
  app:
    image: "<your-registry>/<image-name>:<tag>"
    # 或使用环境变量
    image: "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
```

#### 密码凭证脱敏

```yaml
# ❌ 原始配置(硬编码密码)
services:
  postgres:
    container_name: postgres
    environment:
      POSTGRES_PASSWORD: "MyP@ssw0rd123"
  
  nacos:
    container_name: nacos
    environment:
      SPRING_CLOUD_NACOS_PASSWORD: "Nacos@123.com"

# ✅ 方案一:使用环境变量文件
services:
  postgres:
    container_name: postgres
    env_file:
      - .env.postgres  # 添加到 .gitignore
  
  nacos:
    container_name: nacos
    env_file:
      - .env.nacos

# ✅ 方案二:使用 Docker Secrets(Swarm模式)
services:
  postgres:
    container_name: postgres
    secrets:
      - postgres_password
secrets:
  postgres_password:
    external: true

# ✅ 方案三:使用变量引用
services:
  postgres:
    container_name: postgres
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
# .env 文件(不提交到版本库)
# POSTGRES_PASSWORD=<strong-password>
```

#### IP 地址和域名脱敏

```yaml
# ❌ 原始配置
services:
  app:
    container_name: app
    extra_hosts:
      - "server01.internal:192.168.1.100"
    environment:
      SPRING_CLOUD_NACOS_DISCOVERY_IP: "192.168.1.100"
      SERVER_URL: "https://api.example.com"

# ✅ 脱敏后配置
services:
  app:
    container_name: app
    extra_hosts:
      - "<hostname>:<ip-address>"
    environment:
      SPRING_CLOUD_NACOS_DISCOVERY_IP: "${SERVER_IP}"
      SERVER_URL: "${API_BASE_URL}"
```

### .gitignore 配置

```gitignore
# 敏感配置文件
.env
.env.*
*.env
secrets/

# 包含敏感信息的配置
docker-compose.override.yml
docker-compose.prod.yml

# 日志文件(可能含敏感信息)
logs/
*.log
```

### 环境变量模板文件

```bash
# .env.template(提交到版本库)
# 复制此文件为 .env 并填写实际值

# 数据库配置
POSTGRES_DB=<database-name>
POSTGRES_USER=<database-user>
POSTGRES_PASSWORD=<strong-password>

# Nacos 配置
NACOS_USERNAME=<nacos-user>
NACOS_PASSWORD=<nacos-password>

# MinIO 配置
MINIO_ROOT_USER=<minio-user>
MINIO_ROOT_PASSWORD=<minio-password>

# Redis 配置
REDIS_PASSWORD=<redis-password>

# 服务发现配置
SERVER_IP=<your-server-ip>
GATEWAY_PORT=<gateway-port>
```

## Nginx 安全请求头配置

### 基础安全头配置

```nginx
server {
    listen 80;
    server_tokens off;  # 隐藏 Nginx 版本号
    absolute_redirect off;
    
    # 防止 MIME 类型嗅探
    add_header X-Content-Type-Options "nosniff" always;
    
    # XSS 防护
    add_header X-XSS-Protection "1; mode=block" always;
    
    # 防止点击劫持
    add_header X-Frame-Options "DENY" always;
    
    # 引用策略
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # 下载安全
    add_header X-Download-Options "noopen" always;
    
    # 跨域策略
    add_header X-Permitted-Cross-Domain-Policies "none" always;
    
    # 内容安全策略(根据实际需求调整)
    add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' http: https:; frame-ancestors 'none';" always;
    
    # HSTS(需配合 HTTPS 使用)
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
    
    # 后端 API 代理(通过容器名称访问,不暴露端口)
    location /api/ {
        proxy_pass http://gateway:8080/;  # 使用容器名称
        proxy_buffering off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**说明**: Nginx 反向代理配置中使用的是**容器名称**(`gateway`),这是容器在网络中的标识符,确保请求能正确路由到目标容器。

### 安全请求头验证

```bash
# 验证安全头是否生效
curl -I http://<your-server>/

# 预期输出应包含所有安全头
HTTP/1.1 200 OK
Server: nginx
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
X-Frame-Options: DENY
Referrer-Policy: strict-origin-when-cross-origin
X-Download-Options: noopen
X-Permitted-Cross-Domain-Policies: none
Content-Security-Policy: default-src 'self'; ...
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

## 服务间通信配置

### 连接地址标准化

| 连接场景 | ❌ 错误配置 | ✅ 正确配置 |
|---------|-----------|-----------|
| Java 连接 Nacos | `<ip>:38848` | `nacos:8848` |
| Java 连接 PostgreSQL | `<ip>:35433` | `postgres:5432` |
| Java 连接 Redis | `<ip>:36379` | `redis:6379` |
| Nginx 转发请求 | `http://<ip>:8080` | `http://gateway:8080` |
| 服务注册地址 | 宿主机 IP | 容器内部 IP(自动) |

**核心原则**: 所有服务间通信使用**容器名称**作为主机名,Docker 内部 DNS 会自动解析为容器的内部 IP 地址。

### 配置示例

```yaml
services:
  # API 网关
  gateway:
    image: <your-registry>/gateway:<tag>
    container_name: gateway
    networks:
      - apps
      - middleware
    environment:
      # 服务发现:使用容器名称
      SPRING_CLOUD_NACOS_CONFIG_SERVER_ADDR: nacos:8848
      SPRING_CLOUD_NACOS_DISCOVERY_SERVER_ADDR: nacos:8848
      # 数据库:使用容器名称
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/<db-name>
      # 缓存:使用容器名称
      SPRING_REDIS_HOST: redis
      SPRING_REDIS_PORT: 6379

  # 业务服务
  app-service:
    image: <your-registry>/app-service:<tag>
    container_name: app-service
    networks:
      - apps
      - middleware
    environment:
      # 通过网关访问其他服务
      SERVICE_URL: http://gateway:8080
      # 直接访问中间件
      DATABASE_URL: postgres://postgres:5432/<db-name>
      CACHE_URL: redis://redis:6379

  # 中间件
  postgres:
    image: <your-registry>/postgres:<tag>
    container_name: postgres
    networks:
      - middleware
    # 不映射端口,仅容器内访问
    
  redis:
    image: <your-registry>/redis:<tag>
    container_name: redis
    networks:
      - middleware
    # 不映射端口,仅容器内访问

  nacos:
    image: <your-registry>/nacos:<tag>
    container_name: nacos
    networks:
      - middleware
    # 不映射端口,仅容器内访问
```

## 安全审计检查清单

### 端口暴露检查

```bash
# 检查 Docker 端口映射
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -v "^NAMES"

# 仅应看到:
# nginx    0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp

# 检查宿主机监听端口
sudo netstat -tulnp | grep LISTEN

# 应仅看到: 22, 80, 443
```

### 网络隔离检查

```bash
# 查看容器网络
docker network ls

# 查看网络详情
docker network inspect apps
docker network inspect middleware

# 确认容器间可通过容器名称访问
docker exec -it <container-name> ping postgres
docker exec -it <container-name> ping redis
docker exec -it <container-name> ping nacos
```

### 防火墙规则检查

```bash
# 检查 UFW 状态
sudo ufw status verbose

# 应显示:
# Default: deny (incoming), allow (outgoing)
# 22/tcp ALLOW IN Anywhere
# 80/tcp ALLOW IN Anywhere
# 443/tcp ALLOW IN Anywhere

# 从外部扫描端口(应在其他机器上执行)
nmap -p 22,80,443,5432,6379,8848 <your-server-ip>

# 应仅看到 22, 80, 443 为 open
```

### 敏感信息检查

```bash
# 检查配置文件中的敏感信息
grep -r "password\|Password\|PASSWORD" docker-compose*.yml
grep -r "secret\|Secret\|SECRET" docker-compose*.yml
grep -r "[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}" docker-compose*.yml

# 检查 .env 文件是否被忽略
git status | grep -i env

# 确认 .gitignore 包含敏感文件
cat .gitignore | grep -E "\.env|secret"
```

## 完整配置模板

### docker-compose.yml 模板

```yaml
version: '3.8'

# 网络配置
networks:
  frontend:
    driver: bridge
  apps:
    driver: bridge
  middleware:
    driver: bridge

# 通用配置
x-common-config: &common-config
  restart: unless-stopped
  networks:
    - apps
  logging:
    driver: "json-file"
    options:
      max-size: "10m"
      max-file: "3"

services:
  # ============ 前端层 ============
  nginx:
    image: <your-registry>/nginx:<tag>
    container_name: nginx
    ports:
      - "80:80"
      - "443:443"
    networks:
      - frontend
      - apps
    volumes:
      - ./conf/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./conf/web.conf:/etc/nginx/conf.d/default.conf:ro
      - ./data/certs:/etc/ssl/private:ro
      - ./data/html:/usr/share/nginx/html
    healthcheck:
      test: ["CMD", "nginx", "-t"]
      interval: 30s
      timeout: 10s
      retries: 3
    depends_on:
      - gateway

  # ============ 网关层 ============
  gateway:
    <<: *common-config
    image: <your-registry>/gateway:<tag>
    container_name: gateway
    networks:
      - apps
      - middleware
    environment:
      SPRING_CLOUD_NACOS_CONFIG_SERVER_ADDR: nacos:8848
      SPRING_CLOUD_NACOS_DISCOVERY_SERVER_ADDR: nacos:8848
    env_file:
      - .env.gateway
    depends_on:
      - nacos

  # ============ 应用层 ============
  app-service:
    <<: *common-config
    image: <your-registry>/app-service:<tag>
    container_name: app-service
    networks:
      - apps
      - middleware
    env_file:
      - .env.app

  # ============ 中间件层 ============
  postgres:
    image: <your-registry>/postgres:<tag>
    container_name: postgres
    networks:
      - middleware
    # 无端口映射
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "${POSTGRES_USER}"]
      interval: 30s
      timeout: 10s
      retries: 3

  redis:
    image: <your-registry>/redis:<tag>
    container_name: redis
    networks:
      - middleware
    # 无端口映射
    command: ["redis-server", "/usr/local/etc/redis/redis.conf"]
    volumes:
      - ./conf/redis.conf:/usr/local/etc/redis/redis.conf
      - ./data/redis:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 3

  nacos:
    image: <your-registry>/nacos:<tag>
    container_name: nacos
    networks:
      - middleware
    # 无端口映射
    environment:
      MODE: standalone
      SPRING_DATASOURCE_PLATFORM: mysql
    env_file:
      - .env.nacos
    volumes:
      - ./data/nacos:/home/nacos/data
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8848/nacos/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
```

### 环境变量文件模板

```bash
# .env.gateway
SPRING_CLOUD_NACOS_USERNAME=<nacos-username>
SPRING_CLOUD_NACOS_PASSWORD=<nacos-password>

# .env.app
DATABASE_URL=jdbc:postgresql://postgres:5432/<db-name>
DATABASE_USER=<db-user>
DATABASE_PASSWORD=<db-password>
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=<redis-password>

# .env.nacos
MYSQL_SERVICE_HOST=<mysql-host>
MYSQL_SERVICE_PORT=<mysql-port>
MYSQL_SERVICE_USER=<mysql-user>
MYSQL_SERVICE_PASSWORD=<mysql-password>
```

## 故障排查诊断流程

### 网络隔离故障诊断

**诊断流程图：**

```
┌─────────────────────────────────────────────────────────────┐
│                    网络故障诊断流程                           │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
        ┌──────────────────────────────────┐
        │  1. 检查容器是否在同一网络        │
        │     docker network inspect <net> │
        └──────────────────────────────────┘
                           │
                  ┌────────┴────────┐
                  │                 │
              同一网络          不同网络
                  │                 │
                  ▼                 ▼
        ┌──────────────┐   ┌──────────────────┐
        │ 2. 测试连通性 │   │ 加入正确网络     │
        │ ping/dig     │   │ docker network   │
        │ curl         │   │ connect          │
        └──────────────┘   └──────────────────┘
                  │
                  ▼
        ┌──────────────────────────┐
        │  3. 检查端口映射配置      │
        │     docker ps --format   │
        └──────────────────────────┘
                  │
         ┌────────┴─────────┐
         │                  │
      端口未映射          端口已映射
      (预期状态)          (检查是否必要)
         │                  │
         ▼                  ▼
  ┌────────────┐    ┌──────────────────┐
  │ 服务正常    │    │ 评估安全风险     │
  └────────────┐    │ 考虑移除映射     │
                  └──────────────────┘
```

**诊断命令链：**

```bash
# ===== 第一阶段：网络连通性检查 =====

# 1. 查看所有网络
docker network ls

# 2. 检查特定网络中的容器
docker network inspect apps

# 3. 测试容器间连通性
docker exec -it gateway ping postgres
docker exec -it gateway ping redis
docker exec -it gateway ping nacos

# 4. 检查 DNS 解析
docker exec -it gateway dig postgres
docker exec -it gateway nslookup redis

# ===== 第二阶段：端口暴露检查 =====

# 5. 查看所有容器端口映射
docker ps --format "table {{.Names}}\t{{.Ports}}"

# 6. 检查宿主机监听端口
sudo netstat -tulnp | grep LISTEN
sudo ss -tulnp | grep LISTEN

# 7. 从外部扫描端口（在其他机器上执行）
nmap -p 22,80,443,5432,6379,8848 <server-ip>

# ===== 第三阶段：防火墙检查 =====

# 8. 检查 UFW 状态
sudo ufw status verbose

# 9. 检查 iptables 规则
sudo iptables -L -n -v

# 10. 检查 Docker iptables 规则
sudo iptables -t nat -L DOCKER -n -v
```

### 常见故障案例

#### 案例 1：服务间无法通信

**现象：** Java 微服务无法连接 Nacos 或数据库

**排查步骤：**

```bash
# 1. 确认容器在同一网络
docker inspect gateway | grep -A 20 "Networks"
docker inspect nacos | grep -A 20 "Networks"

# 2. 检查容器名称
docker ps --format "{{.Names}}" | grep -E "gateway|nacos|postgres"

# 3. 测试 DNS 解析
docker exec -it gateway getent hosts nacos
# 如果返回空，说明 DNS 解析失败

# 4. 检查网络配置
docker network inspect apps --format '{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{end}}'

# 5. 临时修复：手动添加 hosts
# 在 docker-compose.yml 中添加：
extra_hosts:
  - "nacos:<nacos-ip>"
```

**根因分析：**
- 容器不在同一网络（最常见）
- 容器名称不匹配（docker-compose.yml 中 container_name 配置错误）
- Docker 内部 DNS 缓存问题（重启 Docker Daemon）

#### 案例 2：外部无法访问服务

**现象：** 外部请求无法到达 Nginx 或返回 502

**排查步骤：**

```bash
# 1. 检查 Nginx 容器状态
docker ps | grep nginx
docker logs nginx --tail 100

# 2. 检查 Nginx 配置语法
docker exec nginx nginx -t

# 3. 测试 Nginx 到后端的连通性
docker exec nginx curl -v http://gateway:8080/
# 如果失败，说明 Nginx 无法访问后端

# 4. 检查端口映射
docker port nginx

# 5. 检查防火墙规则
sudo ufw status | grep -E "80|443"

# 6. 检查宿主机端口监听
sudo netstat -tulnp | grep -E ":80|:443"
```

**根因分析：**
- Nginx 端口未正确映射到宿主机
- 防火墙规则阻止了外部访问
- Nginx 配置中使用了错误的后端地址（IP而非容器名称）

#### 案例 3：敏感信息泄露

**现象：** git status 显示 .env 文件或密码出现在日志中

**排查步骤：**

```bash
# 1. 检查 .gitignore 配置
cat .gitignore | grep -E "\.env|secret"

# 2. 检查是否有敏感文件被提交
git log --all --full-history -- "*.env"
git log --all --full-history -- "*password*"

# 3. 检查容器日志中的敏感信息
docker logs <container> | grep -i "password"
docker logs <container> | grep -E "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"

# 4. 检查 docker-compose.yml 硬编码密码
grep -r "password\|Password\|PASSWORD" docker-compose*.yml

# 5. 清理 Git 历史（如果已提交）
# 使用 BFG Repo-Cleaner 或 git filter-branch
```

**修复方案：**

```bash
# 1. 更新 .gitignore
cat >> .gitignore << EOF
.env
.env.*
*.env
secrets/
docker-compose.override.yml
EOF

# 2. 从 Git 中移除已提交的敏感文件
git rm --cached .env
git rm --cached docker-compose.override.yml

# 3. 使用环境变量替代硬编码密码
# 编辑 docker-compose.yml，改为：
environment:
  POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
```

## 参考资源

### 官方文档

- [Docker 官方文档](https://docs.docker.com/)
- [Docker 安全最佳实践](https://docs.docker.com/engine/security/)
- [Docker 网络配置指南](https://docs.docker.com/network/)
- [Docker Compose 官方文档](https://docs.docker.com/compose/)
- [Nginx 官方文档](https://nginx.org/en/docs/)
- [Nginx 安全配置指南](https://nginx.org/en/docs/http/configuring_https_servers.html)

### 安全标准与最佳实践

- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker) - Docker 安全配置基准
- [OWASP Docker 安全](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [Docker 安全扫描指南](https://docs.docker.com/scout/)
- [容器安全检查清单](https://github.com/konstruktoid/Docker-security-configuration-checklist)

### 工具与扫描器

- [Trivy - 容器漏洞扫描器](https://github.com/aquasecurity/trivy)
- [Docker Bench for Security](https://github.com/docker/docker-bench-security) - Docker 安全审计脚本
- [Falco - 容器运行时安全](https://falco.org/)
- [Clair - 镜像漏洞分析](https://github.com/quay/clair)

### 网络与隔离

- [Docker 网络架构详解](https://docs.docker.com/network/#network-drivers)
- [Docker 内部网络 DNS](https://docs.docker.com/network/#dns-services)
- [CNI 网络插件规范](https://www.cni.dev/)
- [Linux 网络 namespaces](https://man7.org/linux/man-pages/man7/network_namespaces.7.html)

### 社区资源

- [Docker GitHub 仓库](https://github.com/moby/moby)
- [Docker 安全公告](https://docs.docker.com/security/)
- [Nginx 安全头配置](https://github.com/h5bp/server-configs-nginx)
- [docker-microservice-security GitHub 讨论](https://github.com/docker-library/official-images/discussions)

### 进阶阅读

- [《Docker 安全最佳实践》电子书](https://container-solutions.com/docker-security-best-practices/)
- [云原生安全白皮书](https://github.com/cncf/sig-security)
- [容器隔离技术深度解析](https://lwn.net/Articles/531114/)

## 总结

### 核心安全措施

1. **端口最小化**: 仅开放 80/443 (Web) 和 22 (SSH)
2. **网络隔离**: 所有服务通过 Docker 内部网络通信
3. **配置脱敏**: 使用环境变量和 secrets 管理敏感信息
4. **安全请求头**: Nginx 注入完整的安全响应头
5. **防火墙双重防护**: Docker 网络隔离 + 宿主机 UFW 防火墙
6. **服务发现**: 使用容器名称而非 IP 地址
7. **定期审计**: 执行安全检查脚本

### 安全收益

- **攻击面缩减 90%+**: 数据库、缓存、后端服务端口完全隐藏
- **网络嗅探防护**: 内部流量在容器网络内闭环
- **配置安全性**: 敏感信息不入代码库
- **可维护性提升**: 服务发现机制自动适应环境变化
- **符合最佳实践**: 遵循云原生安全部署标准

通过本指南的实施,你可以构建一个安全、可靠的 Docker 微服务架构环境,有效降低安全风险,保护业务系统免受外部威胁。