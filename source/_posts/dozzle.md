---
title: Docker 日志管理面板- UI 界面部署指南
date: 2025-01-14 14:44:25
tags:
    - Development
    - Docker
    - Dozzle
category: Development
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 本文详细介绍了Docker日志管理面板Dozzle的部署与使用，包括服务端/客户端部署配置、安全加固、日志管理、性能监控等核心功能。通过合理配置，可以实现多容器日志的集中管理、实时监控和分析，适合团队进行Docker容器的日志管理与问题排查。

<!-- more -->

## 基础部署配置

### 前提条件

1. 系统要求：
   - Docker >= 20.10.x
   - Docker Compose >= 2.x
   - 支持架构: AMD64、ARM64
   - 内存: 2GB及以上
   - CPU: 2核心及以上

2. 网络要求：
   - 服务端端口: 8080
   - 客户端端口: 7007
   - 服务端与客户端需要网络互通

### 在线部署

1. 服务端部署：
```yaml
# docker-compose.yml
version: '3'
services:
  dozzle:
    image: amir20/dozzle:latest
    container_name: dozzle
    restart: unless-stopped
    environment:
      - DOZZLE_HOSTNAME=server.example.com
      - DOZZLE_REMOTE_AGENT=agent.example.com:7007
      - DOZZLE_AUTH=true
      - DOZZLE_USERNAME=admin
      - DOZZLE_PASSWORD=Admin@123.com
      - TZ=Asia/Shanghai
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./data:/data
    ports:
      - "8080:8080"
```

2. 客户端部署：
```yaml
# docker-compose.yml
version: '3'
services:
  dozzle-agent:
    image: amir20/dozzle-agent:latest
    container_name: dozzle-agent
    restart: unless-stopped
    environment:
      - DOZZLE_HOSTNAME=agent.example.com
      - TZ=Asia/Shanghai
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    ports:
      - "7007:7007"
```

## 高级配置

### 安全配置

1. 用户认证：
```yaml
environment:
  - DOZZLE_AUTH=true
  - DOZZLE_AUTH_PROVIDER=basic
  - DOZZLE_USERNAME=admin
  - DOZZLE_PASSWORD_HASH=${HASHED_PASSWORD}
```

2. SSL配置：
```yaml
environment:
  - DOZZLE_ADDR=:8443
  - DOZZLE_SSL=true
  - DOZZLE_SSL_CERT=/certs/cert.pem
  - DOZZLE_SSL_KEY=/certs/key.pem
volumes:
  - ./certs:/certs:ro
```

### 日志配置

1. 日志保留策略：
```yaml
environment:
  - DOZZLE_TAILSIZE=1000
  - DOZZLE_FILTER=.*
  - DOZZLE_LEVEL=info
```

2. 高级过滤：
```yaml
environment:
  - DOZZLE_FILTER_CONTAINERS=app*
  - DOZZLE_FILTER_SERVICES=web*,api*
  - DOZZLE_EXCLUDE=*-tmp
```

## 功能使用

### 基础功能

1. 日志查看：
   - 实时日志跟踪
   - 多容器日志聚合
   - 日志搜索(Ctrl+K)
   - 日志下载

2. 容器管理：
   - 查看容器状态
   - 监控资源使用
   - 查看环境变量
   - 查看容器配置

### 高级功能

1. 日志分析：
```bash
# 正则表达式搜索
(?i)error|warning|failed

# 时间范围过滤
@time[2024-03-14 10:00:00 TO 2024-03-14 11:00:00]

# 组合查询
service:api AND level:error
```

2. 性能监控：
   - CPU使用率趋势
   - 内存占用分析
   - 网络IO统计
   - 磁盘使用监控

### 自动化集成

1. API集成：
```bash
# 获取日志
curl -u admin:password http://localhost:8080/api/logs/container_id

# 导出日志
curl -X POST http://localhost:8080/api/export/container_id
```

2. 告警集成：
```yaml
environment:
  - DOZZLE_ALERT_ENDPOINT=http://alert-service:8080/webhook
  - DOZZLE_ALERT_LEVEL=error
  - DOZZLE_ALERT_INTERVAL=5m
```

## 最佳实践

### 性能优化

1. 日志管理：
   - 实施日志轮转
   - 配置合适的缓冲区
   - 使用高效的存储方式
   - 定期清理旧日志

2. 资源控制：
   - 限制日志大小
   - 控制并发连接数
   - 优化查询性能
   - 实施缓存策略

### 安全加固

1. 访问控制：
   - 启用认证
   - 配置SSL/TLS
   - 实施IP限制
   - 审计日志记录

2. 数据安全：
   - 加密敏感信息
   - 定期备份数据
   - 实施最小权限
   - 监控异常访问

## 总结

Dozzle提供了强大的Docker日志管理能力，通过合理配置可以显著提升容器日志的管理效率。本文档涵盖了从基础部署到高级特性的完整配置指南，建议根据实际需求选择性启用功能。