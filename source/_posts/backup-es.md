---
title: ElasticSearch 索引的自动备份
date: 2024-12-22 12:17:25
tags:
    - Cron
    - ElasticSearch
    - Backup
category: ElasticSearch
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在本文中，我们将介绍如何使用 Docker Compose 部署带有用户和密码认证的 Elasticsearch 服务，并实现索引的自动备份。首先，我们将展示如何准备配置文件并启动 Elasticsearch 服务。接着，我们将讲解如何配置并验证快照仓库。最后，我们提供了一个用于自动备份 Elasticsearch 索引的脚本，并通过 Crontab 定时任务实现自动备份。本文将帮助你确保数据的安全性和可恢复性。

<!-- more -->

## 1. 部署 Elasticsearch 服务

使用 Docker Compose 部署 Elasticsearch 服务，带有用户、密码认证的单节点配置。

### 1.1 准备文件

#### .env 文件

```env
ELASTIC_VERSION=8.10.2
ELASTIC_PASSWORD=yourpassword
ES_JAVA_OPTS=-Xms4g -Xmx4g
```

#### es.yaml 文件

```yaml
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:${ELASTIC_VERSION}
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - ELASTIC_PASSWORD=${ELASTIC_PASSWORD}
      - xpack.security.enabled=true
      - path.repo=/usr/share/elasticsearch/snapshots
      - path.plugins=/usr/share/elasticsearch/plugins
    ports:
      - 9200:9200
    volumes:
      - es-data:/usr/share/elasticsearch/data
      - es-snapshots:/usr/share/elasticsearch/snapshots
      - es-plugins:/usr/share/elasticsearch/plugins

volumes:
  es-data:
  es-snapshots:
  es-plugins:
```


### 1.2 部署服务

1. 启动 Elasticsearch 服务：

```bash
docker-compose -f es.yaml up -d
```

2. 验证服务是否运行成功：

```bash
curl -u "elastic:${ELASTIC_PASSWORD}" -X GET "http://localhost:9200"
```

返回集群信息表示服务启动成功。

---

## 2. 接口调用与验证

在开始备份前，需要确保以下几点：
1. 已有访问 Elasticsearch 集群的权限。
2. 确保集群健康状态为绿色或黄色。

### 2.1 测试连接

通过以下命令测试连接：

```bash
curl -u "elastic:${ELASTIC_PASSWORD}" -X GET "http://<your-es-host>:9200"
```

如果连接成功，将返回集群的基本信息（JSON 格式）。

### 2.2 验证快照仓库

在 ES 中，备份索引需要先配置一个快照仓库。

1. 创建快照仓库：

```bash
curl -u "elastic:${ELASTIC_PASSWORD}" -X PUT "http://<your-es-host>:9200/_snapshot/backup_repo" -H 'Content-Type: application/json' -d'
{
  "type": "fs",
  "settings": {
    "location": "/usr/share/elasticsearch/snapshots",
    "compress": true
  }
}'
```

2. 验证快照仓库是否可用：

```bash
curl -u "elastic:${ELASTIC_PASSWORD}" -X GET "http://<your-es-host>:9200/_snapshot/backup_repo"
```

返回结果中 `"status": "SUCCESS"` 表示仓库配置正确。

---

## 3. 备份脚本的实现

以下是一个用于自动备份 Elasticsearch 索引的脚本：

```bash
#!/bin/bash

# 配置参数
ES_HOST="http://<your-es-host>:9200"
USERNAME="elastic"
PASSWORD="<yourpassword>"
BACKUP_REPO="backup_repo"
BACKUP_NAME="snapshot_$(date +%Y-%m-%d-%H-%M)"
INDEX_NAME="<your-index-name>"

# 创建备份
curl -u "$USERNAME:$PASSWORD" -X PUT "$ES_HOST/_snapshot/$BACKUP_REPO/$BACKUP_NAME" -H 'Content-Type: application/json' -d'
{
  "indices": "'$INDEX_NAME'",
  "ignore_unavailable": true,
  "include_global_state": false
}'

# 检查备份状态
curl -u "$USERNAME:$PASSWORD" -X GET "$ES_HOST/_snapshot/$BACKUP_REPO/$BACKUP_NAME/_status"
```

保存脚本为 `es_backup.sh`，并赋予可执行权限：

```bash
chmod +x es_backup.sh
```

---

## 4. 定时任务的配置

通过 `crontab` 设置定时任务，实现备份脚本的自动执行。

1. 编辑 crontab：

```bash
crontab -e
```

2. 添加以下条目，设置每天凌晨 2 点执行备份脚本：

```bash
0 2 * * * /path/to/es_backup.sh
```

3. 保存并退出。

---

## 5. 验证备份

1. 查看已有的快照：

```bash
curl -u "elastic:${ELASTIC_PASSWORD}" -X GET "http://<your-es-host>:9200/_snapshot/backup_repo/_all"
```

2. 恢复快照：

```bash
curl -u "elastic:${ELASTIC_PASSWORD}" -X POST "http://<your-es-host>:9200/_snapshot/backup_repo/<snapshot-name>/_restore" -H 'Content-Type: application/json' -d'
{
  "indices": "<your-index-name>",
  "ignore_unavailable": true,
  "include_global_state": false
}'
```

---

## 6. 总结

通过本文档的步骤，你可以快速实现 Elasticsearch 索引的自动备份，并通过 Docker Compose 快速部署一个带用户和密码认证的 Elasticsearch 单节点服务。确保备份脚本和定时任务配置正确，以降低数据丢失的风险。在生产环境中，请根据业务需求调整备份策略和存储位置。
