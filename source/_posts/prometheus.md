
---
title: Prometheus 部署与使用教程
date: 2025-01-13 17:59:25
tags:
    - Development
    - Linux
    - Prometheus
category: Development
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;本文详细介绍了 Prometheus 监控系统的部署与使用，包括基础部署配置、高级特性配置、告警配置、监控指标以及最佳实践等核心内容。文档提供了丰富的配置示例和实践建议，特别深入介绍了高可用部署、联邦集群、告警抑制机制等企业级特性，适合运维团队搭建企业级监控告警平台参考。

<!-- more -->

## 基础部署配置

### 前提条件

1. 系统要求：
   - CPU: 4核心及以上
   - 内存: 8GB及以上
   - 磁盘: 50GB及以上(建议SSD)
   - 网络: 100Mbps及以上

2. 环境要求：
   - Docker 20.10.x及以上
   - Docker Compose 2.x及以上
   - 服务器端口要求：
     - Prometheus: 9090
     - Grafana: 3000
     - Node Exporter: 9100
     - AlertManager: 9093
     - Thanos: 10901(可选)
     - 确保以上端口未被占用

### 组件说明

1. 核心组件：
   - Prometheus Server: 监控数据采集和存储
   - Grafana: 数据可视化平台
   - Node Exporter: 主机监控数据采集
   - AlertManager: 告警管理
   - Thanos: 大规模部署方案(可选)

2. 版本选择：
```yaml
versions:
  prometheus: v2.45.6
  grafana: 9.5.20
  node_exporter: v1.8.1
  alertmanager: v0.25.0
  thanos: v0.32.0
```

### 基础配置

1. Prometheus配置文件：
```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  scrape_timeout: 10s
  external_labels:
    cluster: 'prod'
    replica: 'replica1'

rule_files:
  - "rules/*.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
```

2. Docker Compose配置：
```yaml
services:
  prometheus:
    image: prom/prometheus:v2.45.6
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./rules:/etc/prometheus/rules
      - /data/prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=90d'
      - '--web.enable-lifecycle'
      - '--web.enable-admin-api'
      - '--enable-feature=exemplar-storage'
    ports:
      - '9090:9090'
    restart: unless-stopped
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:9.5.20
    user: "472:472"
    ports:
      - '3000:3000'
    volumes:
      - /data/grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_AUTH_ANONYMOUS_ENABLED=false
      - GF_INSTALL_PLUGINS=grafana-piechart-panel,grafana-worldmap-panel
    restart: unless-stopped
    networks:
      - monitoring

  node-exporter:
    image: prom/node-exporter:v1.8.1
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)($$|/)'
      - '--collector.systemd'
      - '--collector.processes'
    ports:
      - '9100:9100'
    restart: unless-stopped
    networks:
      - monitoring

  alertmanager:
    image: prom/alertmanager:v0.25.0
    volumes:
      - ./alertmanager:/etc/alertmanager
    command:
      - '--config.file=/etc/alertmanager/config.yml'
      - '--storage.path=/alertmanager'
      - '--cluster.listen-address=0.0.0.0:9094'
    ports:
      - '9093:9093'
      - '9094:9094'
    restart: unless-stopped
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge
```

### 目录准备

```bash
# 创建必要目录
mkdir -p /data/{grafana-data,prometheus-data} \
         ./rules/{recording,alerting} \
         ./grafana/provisioning/{datasources,dashboards} \
         ./alertmanager

# 设置权限
chown -R 472:472 /data/grafana-data
chown -R nobody:nobody /data/prometheus-data
```

## 高级特性配置

### 高可用部署

1. Thanos集成配置：
```yaml
# thanos-sidecar.yaml
thanos:
  image: thanosio/thanos:v0.32.0
  args:
    - "sidecar"
    - "--tsdb.path=/prometheus"
    - "--prometheus.url=http://localhost:9090"
    - "--objstore.config-file=/etc/thanos/storage.yml"
  volumes:
    - ./thanos-storage.yml:/etc/thanos/storage.yml

# thanos-storage.yml
type: S3
config:
  bucket: "thanos-metrics"
  endpoint: "minio:9000"
  access_key: "admin"
  secret_key: "password"
  insecure: true
```

2. 集群配置：
```yaml
# prometheus-ha.yml
global:
  external_labels:
    cluster: 'cluster1'
    replica: 'replica1'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets:
        - 'prometheus-1:9090'
        - 'prometheus-2:9090'
        - 'prometheus-3:9090'

# 高可用规则
rule_files:
  - "rules/ha/*.yml"
```

### 联邦集群配置

1. 全局Prometheus配置：
```yaml
# prometheus-global.yml
scrape_configs:
  - job_name: 'federate'
    scrape_interval: 15s
    honor_labels: true
    metrics_path: '/federate'
    params:
      'match[]':
        - '{job=~".+"}'
    static_configs:
      - targets:
        - 'prometheus-dc1:9090'
        - 'prometheus-dc2:9090'
```

2. 分层联邦：
```yaml
# 层级结构配置
federation_configs:
  - job_name: 'upper_federation'
    scrape_interval: 30s
    metrics_path: '/federate'
    params:
      'match[]':
        - '{__name__=~"job:.+"}'
    static_configs:
      - targets:
        - 'prometheus-global:9090'
```

### 服务发现配置

1. Kubernetes服务发现：
```yaml
scrape_configs:
  - job_name: 'kubernetes-nodes'
    kubernetes_sd_configs:
      - role: node
        api_server: https://kubernetes.default.svc:443
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
      - source_labels: [__meta_kubernetes_node_name]
        target_label: node
```

2. Consul服务发现：
```yaml
scrape_configs:
  - job_name: 'consul-services'
    consul_sd_configs:
      - server: 'consul:8500'
        services: ['web', 'api']
    relabel_configs:
      - source_labels: [__meta_consul_service]
        target_label: service
```

### 存储优化配置

1. TSDB优化：
```yaml
storage:
  tsdb:
    # 块压缩
    compression: "snappy"
    # 最大块持续时间
    block_duration: "2h"
    # WAL段大小
    wal_segment_size: "128MB"
    # 保留策略
    retention:
      size: "500GB"
      time: "90d"
    # 并发写入
    write_queue_size: 20000
    # 内存映射
    memory_mapped: true
```

2. 远程存储集成：
```yaml
remote_write:
  - url: "http://victoriametrics:8428/api/v1/write"
    queue_config:
      max_samples_per_send: 10000
      capacity: 500000
      max_shards: 10

remote_read:
  - url: "http://victoriametrics:8428/api/v1/read"
    read_recent: true
```

## 告警配置

### 基础告警规则

1. 主机监控规则：
```yaml
# rules/host_alerts.yml
groups:
- name: host_alerts
  rules:
  - alert: HighCPUUsage
    expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High CPU usage on {{ $labels.instance }}"
      description: "CPU usage is above 80% for 5 minutes"

  - alert: HighMemoryUsage
    expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High memory usage on {{ $labels.instance }}"
```

2. 服务监控规则：
```yaml
# rules/service_alerts.yml
groups:
- name: service_alerts
  rules:
  - alert: ServiceDown
    expr: up == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Service {{ $labels.job }} is down"
```

### 告警抑制配置

1. 基础抑制规则：
```yaml
# alertmanager/config.yml
inhibit_rules:
  # 当出现严重告警时，抑制相关的警告级别告警
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'cluster', 'service']

  # 当出现集群级告警时，抑制相关的节点级告警
  - source_match:
      scope: 'cluster'
    target_match:
      scope: 'node'
    equal: ['cluster', 'instance']
```

2. 场景抑制配置：
```yaml
inhibit_rules:
  # 数据库主从切换场景
  - source_match:
      alertname: 'DatabaseFailover'
      status: 'switching'
    target_match_re:
      alertname: 'DatabaseHighLatency|DatabaseConnectionError'
    equal: ['database_cluster']

  # 网络故障场景
  - source_match:
      alertname: 'NetworkOutage'
    target_match_re:
      alertname: 'ServiceDown|EndpointDown'
    equal: ['datacenter', 'rack']
```

### 消息通知集成

1. 钉钉告警配置：
```yaml
receivers:
  - name: 'dingtalk'
    webhook_configs:
      - url: 'http://dingtalk-webhook:8060/dingtalk/webhook1/send'
        send_resolved: true
```

2. 企业微信告警配置：
```yaml
receivers:
  - name: 'wechat'
    wechat_configs:
    - corp_id: 'ww92940f************************'
      api_url: 'https://qyapi.weixin.qq.com/cgi-bin/'
      api_secret: 'Th6******************************************'
      to_party: '1'
      agent_id: '1000001'
```

## 监控指标

### 系统监控

1. 主机指标：
```promql
# CPU使用率
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# 内存使用率
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100

# 磁盘使用率
100 - ((node_filesystem_avail_bytes * 100) / node_filesystem_size_bytes)
```

2. 容器指标：
```promql
# 容器CPU使用率
sum(rate(container_cpu_usage_seconds_total[5m])) by (container_name)

# 容器内存使用
container_memory_usage_bytes{container_name!=""}
```

### 应用监控

1. 服务指标：
```promql
# 请求总量
rate(http_requests_total[5m])

# 错误率
sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100
```

## 运维管理

### 备份策略

1. 数据备份：
```bash
#!/bin/bash
BACKUP_DIR="/backup/prometheus"
DATE=$(date +%Y%m%d)

# 创建备份目录
mkdir -p ${BACKUP_DIR}/${DATE}

# 备份数据
tar czf ${BACKUP_DIR}/${DATE}/prometheus_data.tar.gz /data/prometheus-data/

# 清理旧备份
find ${BACKUP_DIR} -type d -mtime +30 -exec rm -rf {} \;
```

### 监控告警

1. 系统监控：
```yaml
# rules/system_alerts.yml
groups:
- name: system_alerts
  rules:
  - alert: HighLoad
    expr: node_load1 > 10
    for: 5m
    labels:
      severity: warning
```

## 最佳实践

### 性能优化

1. 采集优化：
   - 合理设置采集间隔
   - 使用适当的采集超时
   - 优化标签数量
   - 实施采集过滤

2. 存储优化：
   - 配置合适的保留期
   - 使用压缩功能
   - 实施数据下采样
   - 配置远程存储

### 安全建议

1. 访问控制：
   - 启用认证
   - 配置TLS
   - 实施RBAC
   - 限制网络访问

2. 数据安全：
   - 定期备份
   - 加密敏感数据
   - 审计日志
   - 漏洞扫描

## 总结

Prometheus是一个强大的开源监控系统，通过合理配置和使用，可以为团队提供全面的监控和告警服务。本文档涵盖了从基础部署到高级特性的完整配置指南，建议根据实际需求选择性地启用功能，并持续优化监控策略。
