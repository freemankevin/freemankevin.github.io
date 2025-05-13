---
title: MinIO 站点复制部署与测试：同步与故障恢复
date: 2025-05-13 16:38:00
tags:
    - MinIO
    - SITE Replication
    - Docker
    - High Availability
    - Error Recovery
category: Development 
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; MinIO 是一个高性能的分布式对象存储系统，其站点复制（Site Replication）功能支持跨集群的数据和元数据同步。本文记录了如何使用 Docker Compose 部署 MinIO 站点复制集群，配置两个 MinIO 实例，并进行同步测试和故障恢复测试。测试环境基于 20T 磁盘，适用于需要高可用性和灾难恢复的场景。

<!-- more -->

## MinIO 站点复制简介

MinIO 的站点复制是一种集群级别的双向同步机制，可同步数据（桶、对象）和元数据（用户、策略、配置）。其主要特性包括：
- **最终一致性**：对象数据近实时同步。
- **严格一致性**：元数据保持完全一致。
- **高可用性**：任一集群故障时，另一个集群可继续提供服务。

本文将部署两个 MinIO 实例（SITE1 和 SITE2），通过 `minio-mc` 容器配置站点复制，并测试同步和故障恢复。

## 环境与配置

### 硬件与网络
- **服务器**：两台服务器（MinIO1: `192.168.199.145`，MinIO2: `192.168.199.147`）。
- **磁盘**：每台服务器挂载 20T 磁盘。
- **网络**：1Gbps 带宽，RTT < 20ms。
- **操作系统**：Linux（支持 Docker）。

### Docker Compose 配置
以下是 MinIO 和 `minio-mc` 服务的 Docker Compose 配置：

```yaml
version: '3.8'
services:
  minio:
    image: "${MINIO_IMAGE}"
    deploy:
      resources:
        limits:
          memory: 4096M
    networks:
      - middleware
    container_name: minio
    ports:
      - "${MINIO_PORT}:9000"
      - "${MINIO_CONSOLE_PORT}:9001"
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: "${MINIO_ROOT_USER}"
      MINIO_ROOT_PASSWORD: "${MINIO_ROOT_PASSWORD}"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./data/minio/data:/data
    restart: always

  minio-mc:
    image: minio/mc:latest
    container_name: minio-mc
    environment:
      SITE1_URL: http://192.168.199.145:9000
      SITE2_URL: http://192.168.199.147:9000
      MINIO_ACCESS_KEY: "${MINIO_ROOT_USER}"
      MINIO_SECRET_KEY: "${MINIO_ROOT_PASSWORD}"
    volumes:
      - ./site-replication.sh:/site-replication.sh
    entrypoint: ["/bin/bash", "/site-replication.sh"]
    restart: on-failure

networks:
  middleware:
    driver: bridge
```

### 环境变量
环境变量存储在 `.env` 文件中：

```bash
# MinIO
MINIO_PORT=9000
MINIO_CONSOLE_PORT=9001
MINIO_ROOT_USER="admin"
MINIO_ROOT_PASSWORD="Admin@123.com"
MINIO_IMAGE="minio/minio:RELEASE.2025-04-22T22-12-26Z"
```

### 站点复制脚本
`site-replication.sh` 用于配置站点复制：

```bash
#!/bin/bash

# 检查必要的环境变量
if [ -z "$SITE1_URL" ] || [ -z "$SITE2_URL" ] || [ -z "$MINIO_ACCESS_KEY" ] || [ -z "$MINIO_SECRET_KEY" ]; then
  echo "Error: Missing required environment variables (SITE1_URL, SITE2_URL, MINIO_ACCESS_KEY, MINIO_SECRET_KEY)"
  exit 1
fi

# 设置 mc 命令的别名
echo "Configuring aliases for SITE1 and SITE2..."
/usr/bin/mc alias set SITE1 "$SITE1_URL" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY"
/usr/bin/mc alias set SITE2 "$SITE2_URL" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY"

# 检查别名是否配置成功
if ! /usr/bin/mc alias list SITE1 >/dev/null 2>&1 || ! /usr/bin/mc alias list SITE2 >/dev/null 2>&1; then
  echo "Error: Failed to configure aliases"
  exit 1
fi

# 配置站点复制
echo "Adding site replication between SITE1 and SITE2..."
/usr/bin/mc admin replicate add SITE1 SITE2

# 检查站点复制状态
if /usr/bin/mc admin replicate status SITE1 >/dev/null 2>&1; then
  echo "Site replication configured successfully!"
else
  echo "Error: Failed to configure site replication"
  exit 1
fi

# 保持容器运行
tail -f /dev/null
```

## 部署步骤

### 准备环境
1. 创建目录：
   ```bash
   mkdir -p /data/opt/installmiddleware/data/minio/data
   ```
2. 设置磁盘权限：
   确保 20T 磁盘挂载到 `/data`，并赋予权限：
   ```bash
   chown -R 1000:1000 ./data/minio/data
   ```
3. 保存配置：
   - 保存 `docker-compose.yml` 和 `.env` 文件。
   - 保存 `site-replication.sh`，设置可执行权限：
     ```bash
     chmod +x site-replication.sh
     ```

### 启动服务
在 MinIO1 和 MinIO2 服务器上分别部署 MinIO 实例：
```bash
cd /data/opt/installmiddleware
docker-compose up -d
```



### 配置站点复制
- `minio-mc` 容器自动运行 `site-replication.sh`，配置站点复制。
- 检查日志：
  ```bash
  docker logs --tail 100 minio-mc
  ```
  预期输出：
  ```
  Configuring aliases for SITE1 and SITE2...
  Adding site replication between SITE1 and SITE2...
  Site replication configured successfully!
  ```

## 同步测试

### 测试目标
验证 MinIO1 创建的桶和上传的对象是否自动同步到 MinIO2。

### 测试步骤
1. 在 MinIO1 创建桶：
   ```bash
   docker exec -it minio-mc bash
   mc mb SITE1/test-bucket
   ```
2. 上传测试文件：
   - 创建文件：
     ```bash
     echo "Hello, MinIO!" > test.txt
     ```
   - 上传到 MinIO1：
     ```bash
     mc cp test.txt SITE1/test-bucket
     ```
3. 验证 MinIO2 同步：
   - 检查桶：
     ```bash
     mc ls SITE2
     ```
     预期输出：
     ```
     [2025-05-13 16:40:00 CST]     0B test-bucket/
     ```
   - 检查文件：
     ```bash
     mc ls SITE2/test-bucket
     ```
     预期输出：
     ```
     [2025-05-13 16:40:10 CST]    14B test.txt
     ```
4. 访问 MinIO2 控制台：
   - 打开 `http://192.168.199.147:9000`，登录（`admin`/`Admin@123.com`）。
   - 确认 `test-bucket` 和 `test.txt` 存在。

### 测试结果
桶和文件成功同步，说明站点复制正常，同步延迟通常在毫秒级（RTT < 20ms）。

## 故障恢复测试

### 测试目标
模拟 MinIO1 故障，验证 MinIO2 的服务可用性，并测试 MinIO1 恢复后的同步。

### 测试步骤
1. 停止 MinIO1：
   ```bash
   docker-compose stop minio
   ```
2. 检查站点复制状态：
   - 在 `minio-mc` 容器中：
     ```bash
     mc admin replicate status SITE2
     ```
     预期输出（基于实际测试）：
     ```
     Bucket replication status:
     ●  0/1 Buckets in sync
     Bucket          | SITE1           | SITE2          
     test            |                 | ✗  in-sync     
     ...
     Object replication status:
     Link:          ● offline 5 seconds (total downtime: 4 minutes 30 seconds)
     Errors:        0 in last 1 minute; 1 in last 1hr
     ```
3. 验证 MinIO2 服务：
   - 上传新文件：
     ```bash
     echo "MinIO2 test" > test2.txt
     mc cp test2.txt SITE2/test-bucket
     ```
   - 检查：
     ```bash
     mc ls SITE2/test-bucket
     ```
     预期输出：
     ```
     [2025-05-13 16:45:00 CST]    14B test.txt
     [2025-05-13 16:45:10 CST]    12B test2.txt
     ```
4. 恢复 MinIO1：
   - 启动：
     ```bash
     docker-compose start minio
     ```
   - 验证健康：
     ```bash
     curl -f http://192.168.199.145:9000/minio/health/live
     ```
5. 重新同步：
   - 触发增量同步：
     ```bash
     mc admin replicate resync start SITE2 SITE1
     ```
   - 检查状态：
     ```bash
     mc admin replicate status SITE2
     ```
     预期输出：
     ```
     Site Replication Status:
     - Site: SITE1 (http://192.168.199.145:9000) - Online
     - Site: SITE2 (http://192.168.199.147:9000) - Online
     Replication Status: Active
     ```
6. 验证 MinIO1 同步：
   - 检查：
     ```bash
     mc ls SITE1/test-bucket
     ```
     预期输出：
     ```
     [2025-05-13 16:45:00 CST]    14B test.txt
     [2025-05-13 16:45:10 CST]    12B test2.txt
     ```

### 测试结果
- MinIO1 故障期间，MinIO2 正常提供服务。
- MinIO1 恢复后，增量数据（`test2.txt`）同步成功，站点复制恢复正常。

## 注意事项与优化建议

### 磁盘与虚拟化
- 20T 磁盘（虚拟化后 18T）可能受虚拟化影响，建议直通磁盘：
  ```yaml
  volumes:
    - /dev/sdb:/data
  ```
- 定期检查磁盘健康：
  ```bash
  smartctl -a /dev/sdb
  ```

### 网络
- 确保 RTT < 20ms，带宽 ≥ 1Gbps。
- 检查防火墙：
  ```bash
  ufw allow from 192.168.199.0/24 to any port 9000
  ```

### 安全性
- 替换默认凭据（`admin`/`Admin@123.com`）。
- 启用 TLS：
  ```yaml
  environment:
    - MINIO_SERVER_URL=https://192.168.199.145:9000
  ```

### 监控
- 启用 Prometheus：
  ```yaml
  environment:
    - MINIO_PROMETHEUS_AUTH_TYPE=public
  ```
- 使用 Grafana 监控节点状态（`minio_node_up`）和复制延迟（`minio_replication_last_hour_latency_millis`）。

### 预算
- 站点复制需要两台服务器（约 14000-25000 元）。若预算有限，可考虑单向主从复制（约 7000-13000 元）。

## 总结

通过 Docker Compose 和 `site-replication.sh`，我们部署了 MinIO 站点复制集群，实现了 MinIO1 和 MinIO2 的数据和元数据同步。同步测试验证了桶和对象的自动同步，故障恢复测试确认了 MinIO2 的高可用性和 MinIO1 恢复后的增量同步。该方案结合 20T 磁盘的存储容量，适用于高可用性场景。

如需进一步优化（如 webhook 通知、Flask API 集成），请参考 MinIO 文档：[Site Replication](https://min.io/docs/minio/linux/operations/install-deploy-manage/multi-site-replication.html)。


