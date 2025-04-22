---
title: 在Docker环境中部署Nexus的技术指南
date: 2025-04-22T15:14:25.000Z
tags: [Docker, Nexus, Maven, PostgreSQL]
categories: Development
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; Nexus是一个功能强大的仓库管理工具，用于托管Maven工件、Docker镜像等。本文将详细介绍如何在Docker环境中部署Nexus仓库管理器，并集成PostgreSQL数据库、快照清理服务和数据库备份服务。

<!-- more -->

## 环境准备

### 目录结构创建

```bash
# 创建Nexus数据目录
mkdir -p ./nexus/sonatype-work
chmod -R 755 ./nexus/sonatype-work
chown -R 200:200 ./nexus/sonatype-work

# 创建Nexus密钥目录
mkdir -p ./nexus/secret
cat > ./nexus/secret/nexus-secrets.json <<EOF
{
  "active": "nexus-key",
  "keys": [
    {
      "id": "nexus-key",
      "key": "$(openssl rand -base64 32)"
    }
  ]
}
EOF

# 设置权限
chmod 600 ./nexus/secret/nexus-secrets.json
chown 200:200 ./nexus/secret/nexus-secrets.json

# 创建PostgreSQL目录
mkdir -p ./postgres/data ./postgres/dbbackups
chmod -R 755 ./postgres/data ./postgres/dbbackups
chown -R 101:103 ./postgres/data ./postgres/dbbackups
```


### 环境变量配置

创建`.env`文件：

```ini
# Nexus配置
NEXUS_PORT=8081
NEXUS_IMAGE=sonatype/nexus3:3.79.0
NEXUS_PASS=Admin@gmail.123.com
HEALTHCHECK_PORT=8000
NEXUS_URL=http://192.168.1.100:8081
NEXUS_USER=admin
REPOSITORY_NAME=maven-snapshots

# PostgreSQL配置
POSTGRES_PORT=5432
POSTGRES_USER=nexus
POSTGRES_PASS=Nexus@gmail.123.com
POSTGRES_DB=nexus
POSTGRES_IMAGE=kartoza/postgis:17-3.5
POSTGRES_BACKUP_IMAGE=kartoza/pg-backup:17-3.5
```

## Docker Compose配置

创建`docker-compose.yaml`文件：

```yaml
#version: '3'
services:
  nexus:
    image: "${NEXUS_IMAGE}"
    container_name: nexus
    deploy:
      resources:
        limits:
          memory: 8192M
    ports:
      - "${NEXUS_PORT}:8081"
    networks:
      - middleware
    environment:
      TZ: Asia/Shanghai
      INSTALL4J_ADD_VM_PARAMS: "-Xms2g -Xmx2g -XX:MaxDirectMemorySize=2g -Djava.util.prefs.userRoot=/opt/sonatype/sonatype-work -Dnexus.datastore.enabled=true -Dnexus.datastore.nexus.jdbcUrl=jdbc:postgresql://postgres:5432/nexus?gssEncMode=disable -Dnexus.datastore.nexus.username=nexus -Dnexus.datastore.nexus.password=Nexus@gmail.123.com -Dnexus.datastore.nexus.advanced=maximumPoolSize=50 -Dkaraf.data=/opt/sonatype/sonatype-work -Dkaraf.etc=/opt/sonatype/sonatype-work/etc"
      NEXUS_SECURITY_RANDOMPASSWORD: "false"
      NEXUS_SECRETS_KEY_FILE: /opt/sonatype/sonatype-work/etc/nexus-secrets.json
    restart: always
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8081/service/rest/v1/status"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 120s
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./nexus/secret/nexus-secrets.json:/opt/sonatype/sonatype-work/etc/nexus-secrets.json:ro
      - ./nexus/sonatype-work:/opt/sonatype/sonatype-work

  nexus-cleanup:
    image: ghcr.io/freemankevin/clean-snapshots/nexus-cleanup:sha-afbc846
    container_name: nexus-cleanup
    environment:
      NEXUS_URL: "${NEXUS_URL}"
      NEXUS_USER: "${NEXUS_USER:-admin}"
      NEXUS_PASS: "${NEXUS_PASS}"
      REPOSITORY_NAME: "${REPOSITORY_NAME:-maven-snapshots}"
      RETAIN_COUNT: "3"
      DRY_RUN: "false"
      LOG_LEVEL: "INFO"
      SCHEDULE_TIME: "03:00"
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./nexus/nexus-cleanup-logs:/var/log
    ports:
      - "${HEALTHCHECK_PORT}:8000"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
    depends_on:
      nexus:
        condition: service_healthy


  postgres:
    image: "${POSTGRES_IMAGE}"
    container_name: postgres
    deploy:
      resources:
        limits:
          memory: 8192M  
    ports:
      - "${POSTGRES_PORT}:5432"
    networks:
      - middleware
    environment:
      TZ: Asia/Shanghai
      POSTGRES_DB: "${POSTGRES_DB}"
      POSTGRES_USER: "${POSTGRES_USER}"
      POSTGRES_PASS: "${POSTGRES_PASS}"
      POSTGRES_INITDB_ARGS: "--encoding=UTF8"
      ALLOW_IP_RANGE: "0.0.0.0/0"
      POSTGRES_MULTIPLE_EXTENSIONS: "postgis,hstore,postgis_topology,postgis_raster,pgrouting,pg_trgm"
      RUN_AS_ROOT: 'true'
    restart: always
    healthcheck:
      test: ["CMD-SHELL", "PGPASSWORD=${POSTGRES_PASS} pg_isready -h localhost -U ${POSTGRES_USER}"]
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./postgres/data:/var/lib/postgresql
      - ./postgres/dbbackups:/backups
      #- ./init-postgres.sql:/docker-entrypoint-initdb.d/init.sql

  postgres-backup:
    image: "${POSTGRES_BACKUP_IMAGE}"
    deploy:
      resources:
        limits:
          memory: 4096M
    container_name: postgres-backup
    hostname: postgres-backups
    networks:
      - middleware
    environment:
      TZ: Asia/Shanghai
      DUMPPREFIX: PG_db
      POSTGRES_USER: "${POSTGRES_USER}"
      POSTGRES_PASS: "${POSTGRES_PASS}"
      POSTGRES_PORT: "5432"
      POSTGRES_HOST: "postgres"
      CRON_SCHEDULE: "0 2 * * *"
      REMOVE_BEFORE: "15"
    restart: always
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./postgres/dbbackups:/backups
    depends_on:
      postgres:
        condition: service_healthy

networks:
  middleware:
    driver: bridge
```

## 服务部署

### 加载Docker镜像（离线环境）

```bash
docker load -i images/nexus_3.79.0_amd64.tar.gz
docker load -i images/nexus-cleanup.tar.gz
docker load -i images/pg-v17-3.5.tar.gz
docker load -i images/pg-backup-v17-3.5.tar.gz
```

### 启动服务

```bash
docker-compose up -d
```

验证服务状态：

```bash
docker-compose ps
```

## 密码重置

如果需要重置管理员密码：

1. 进入PostgreSQL容器：
```bash
docker exec -it postgres bash
```

2. 执行SQL：
```sql
--- 将默认admin 密码改为 admin123
UPDATE security_user 
SET password='$shiro1$SHA-512$1024$NE+wqQq/TmjZMvfI7ENh/g==$V4yPw8T64UQ6GfJfxYq2hLsVrBY8D1v+bktfOxGdt4b/9BthpWPNUy/CBk6V9iA0nHpzYzJFWO8v/tZFtES8CA==', 
status='active' 
WHERE id='admin';
```

3. 重启服务：
```bash
docker-compose restart nexus
```

## 监控与验证

### 服务健康检查

- Nexus: `curl http://localhost:18080/service/rest/v1/status`
- Cleanup: `curl http://localhost:8000/health`
- PostgreSQL: `docker exec postgres pg_isready -U nexus`

### 日志检查

```bash
docker logs nexus
tail -f ./nexus/nexus-cleanup-logs/cleanup.log
```

## 性能优化建议

1. **JVM调优**：
   ```ini
   -Xms4g -Xmx4g -XX:MaxDirectMemorySize=4g
   ```

2. **PostgreSQL配置**：
   ```ini
   max_connections = 200
   work_mem = 16MB
   ```

3. **清理策略**：
   ```yaml
   RETAIN_COUNT: "5"
   SCHEDULE_TIME: "02:00"
   ```

## 常见问题排查

| 问题 | 解决方案 |
|------|----------|
| Nexus启动失败 | 检查JVM内存设置 |
| PostgreSQL连接错误 | 验证.env文件凭据 |
| 清理服务不工作 | 检查NEXUS_URL配置 |

## 结论

本文详细介绍了Nexus在Docker环境中的完整部署方案，包含数据库集成、自动清理和备份功能。该方案适合生产环境使用，可根据实际需求进行调整优化。

**相关资源**：
- [Nexus官方文档](https://help.sonatype.com/repomanager3)
- [PostgreSQL最佳实践](https://www.postgresql.org/docs/current/runtime-config.html)
