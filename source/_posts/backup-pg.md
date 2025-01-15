---
title: PostgreSQL 数据库备份与恢复指南
date: 2025-01-15 16:09:25
tags:
    - PITR
    - PostgreSQL
    - Backup
category: PostgreSQL
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 本文详细介绍了PostgreSQL数据库的两种主要备份方案：基于归档日志的PITR和基于pg_basebackup的物理备份。文档涵盖了系统配置、性能优化、监控告警、灾难恢复等完整解决方案，并提供了详细的脚本示例和最佳实践建议，帮助数据库管理员实现可靠的数据备份与恢复策略。

<!-- more -->

## 备份策略选择

1. PITR适用场景：
   - 需要精确时间点恢复
   - 对数据一致性要求高
   - 有充足的存储空间
   - 可以承受一定的性能开销

2. 物理备份适用场景：
   - 需要完整的数据库副本
   - 对备份和恢复速度要求高
   - 存储空间有限
   - 主要用于灾难恢复

## 方案一：归档日志备份(PITR)

### 系统要求

1. 存储空间：
   - WAL日志空间 = 每日WAL生成量 × 保留天数
   - 归档空间 = WAL日志空间 × 1.2(压缩比)
   - 基础备份空间 = 数据库大小 × 2

2. 性能影响：
   - CPU: 额外5-10%负载(归档压缩)
   - I/O: 额外10-20%写入量
   - 网络: 归档传输带宽

### 详细配置

1. postgresql.conf核心参数：

```bash
# WAL配置
wal_level = replica                    # 启用必要的WAL信息
archive_mode = on                      # 开启归档
archive_command = 'test ! -f /archive/%f && cp %p /archive/%f'  # 归档命令
archive_timeout = 60                   # 最大归档间隔(秒)
wal_keep_segments = 32                 # 保留的WAL数量
max_wal_size = 1GB                    # WAL最大大小
min_wal_size = 80MB                   # WAL最小大小

# 检查点配置
checkpoint_timeout = 5min              # 检查点间隔
checkpoint_completion_target = 0.9     # 检查点完成目标
checkpoint_warning = 30s               # 检查点警告阈值

# 归档参数
archive_timeout = 60                   # 强制切换WAL的时间
archive_library = ''                   # 自定义归档模块
```

2. 高级归档命令示例：

```bash
# 带压缩的归档
archive_command = 'gzip < %p > /archive/%f.gz'

# 带验证的归档
archive_command = 'cp %p /archive/%f && sha256sum /archive/%f > /archive/%f.sha256'

# 远程归档
archive_command = 'rsync -a %p backup_server:/archive/%f'

# 多目标归档
archive_command = 'cp %p /archive1/%f && cp %p /archive2/%f'
```

### 监控和维护

1. 归档状态监控：

```sql
-- 归档统计信息
SELECT * FROM pg_stat_archiver;

-- WAL生成速率
SELECT 
    current_timestamp,
    pg_walfile_name(pg_current_wal_lsn()),
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0'::pg_lsn)) as total_wal_size;

-- 归档延迟监控
SELECT 
    archived_count,
    failed_count,
    stats_reset,
    CASE WHEN last_failed_wal IS NOT NULL 
         THEN 'Warning: Archive failed for ' || last_failed_wal 
         ELSE 'OK' 
    END as archive_status
FROM pg_stat_archiver;
```

2. 空间监控脚本：

```bash
#!/bin/bash

ARCHIVE_DIR="/archive"
THRESHOLD=80  # 空间使用率警告阈值

# 检查归档目录空间
usage=$(df -h ${ARCHIVE_DIR} | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $usage -gt $THRESHOLD ]; then
    echo "Warning: Archive directory usage is ${usage}%"
    # 可以添加告警通知
fi

# 检查最老的归档文件
oldest_archive=$(find ${ARCHIVE_DIR} -type f -name "*.gz" -printf '%T+ %p\n' | sort | head -n 1)
echo "Oldest archive file: ${oldest_archive}"
```

## 方案二：物理备份

### 高级配置

1. 备份压缩选项：

```bash
# GZIP压缩(默认)
pg_basebackup -Z 9 -D /backup/base

# ZSTD压缩(推荐)
pg_basebackup -Z zstd -D /backup/base

# 并行压缩
pg_basebackup -j 4 -Z zstd -D /backup/base
```

2. 增强的备份脚本：

```bash
#!/bin/bash

# 配置
BACKUP_DIR="/backup/pg"
RETENTION_DAYS=90
DATE=$(date +%Y%m%d_%H%M%S)
LOG_DIR="/var/log/pg_backup"
ALERT_EMAIL="dba@example.com"

# 初始化
mkdir -p "${BACKUP_DIR}/${DATE}"
mkdir -p "$LOG_DIR"

# 备份前检查
check_prerequisites() {
    # 检查空间
    local required_space=$(du -s $PGDATA | awk '{print $1}')
    local available_space=$(df $BACKUP_DIR | awk 'NR==2 {print $4}')
    if [ $available_space -lt $required_space ]; then
        echo "Error: Insufficient space" | mail -s "Backup Failed" $ALERT_EMAIL
        exit 1
    }
    
    # 检查连接性
    if ! psql -c "SELECT 1" > /dev/null 2>&1; then
        echo "Error: Cannot connect to database" | mail -s "Backup Failed" $ALERT_EMAIL
        exit 1
    }
}

# 执行备份
perform_backup() {
    pg_basebackup \
        -D "${BACKUP_DIR}/${DATE}" \
        -Ft -j 4 \
        -Z zstd \
        -P \
        -X stream \
        -U backup_user \
        --checkpoint=fast \
        --wal-method=stream \
        --progress \
        --verbose

    # 验证备份
    if [ $? -eq 0 ]; then
        # 创建校验和
        cd "${BACKUP_DIR}/${DATE}"
        sha256sum * > SHA256SUMS
        # 记录备份元数据
        echo "Backup completed at $(date)" > backup_info.txt
        echo "PostgreSQL Version: $(psql -V)" >> backup_info.txt
        echo "Backup Size: $(du -sh .)" >> backup_info.txt
    else
        echo "Backup failed" | mail -s "Backup Failed" $ALERT_EMAIL
        exit 1
    fi
}

# 清理
cleanup_old_backups() {
    find $BACKUP_DIR -maxdepth 1 -mtime +$RETENTION_DAYS -exec rm -rf {} \;
    # 保留最新的5个备份，即使超过保留天数
    ls -t $BACKUP_DIR | tail -n +6 | xargs -I {} rm -rf "$BACKUP_DIR/{}"
}

# 主流程
check_prerequisites
perform_backup
cleanup_old_backups
```

### 恢复验证

1. 自动恢复验证脚本：

```bash
#!/bin/bash

# 配置测试环境
TEST_DIR="/tmp/pg_restore_test"
BACKUP_DIR="/backup/pg"
LATEST_BACKUP=$(ls -t $BACKUP_DIR | head -n1)

# 准备测试环境
mkdir -p $TEST_DIR
cd $TEST_DIR

# 解压最新备份
tar xf $BACKUP_DIR/$LATEST_BACKUP/base.tar.zst
tar xf $BACKUP_DIR/$LATEST_BACKUP/pg_wal.tar.zst

# 配置测试实例
initdb -D $TEST_DIR/data
cp postgresql.conf postgresql.conf.orig
sed -i 's/port = 5432/port = 5433/' postgresql.conf

# 启动测试实例
pg_ctl -D $TEST_DIR/data -l logfile start

# 验证数据
psql -p 5433 -c "SELECT count(*) FROM pg_database;"

# 清理
pg_ctl -D $TEST_DIR/data stop
rm -rf $TEST_DIR
```

## 性能优化

### I/O优化

1. 文件系统优化：

```bash
# 使用XFS文件系统
mkfs.xfs -f -d agcount=16 -l size=128m /dev/sdb1

# 挂载选项
mount -o noatime,nodiratime,logbufs=8 /dev/sdb1 /archive
```

2. I/O调度优化：
```bash
# 设置I/O调度器
echo deadline > /sys/block/sda/queue/scheduler

# 调整预读大小
blockdev --setra 16384 /dev/sda
```

### 网络优化

1. TCP参数优化：

```bash
# /etc/sysctl.conf
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_window_scaling = 1
```

2. 网络接口优化：

```bash
# 调整网卡队列长度
ethtool -G eth0 rx 4096 tx 4096

# 开启网卡多队列
ethtool -L eth0 combined 4
```

## 监控与告警

1. 备份监控指标：

```sql
-- 备份延迟监控
CREATE OR REPLACE FUNCTION check_backup_delay()
RETURNS TABLE (
    backup_type text,
    last_backup timestamp,
    delay_hours numeric,
    status text
) AS $$
BEGIN
    RETURN QUERY
    WITH backup_status AS (
        SELECT
            'Physical Backup' as type,
            COALESCE(
                (SELECT MAX(modified_time)
                 FROM pg_ls_dir_timestamp('/backup/pg')),
                '1970-01-01'::timestamp
            ) as last_time
    )
    SELECT
        type,
        last_time,
        EXTRACT(EPOCH FROM (now() - last_time))/3600 as hours,
        CASE
            WHEN EXTRACT(EPOCH FROM (now() - last_time))/3600 > 24 
            THEN 'CRITICAL'
            WHEN EXTRACT(EPOCH FROM (now() - last_time))/3600 > 12 
            THEN 'WARNING'
            ELSE 'OK'
        END
    FROM backup_status;
END;
$$ LANGUAGE plpgsql;
```

2. 告警集成：

```python
#!/usr/bin/env python3

import psycopg2
import requests

def check_backup_status():
    conn = psycopg2.connect("dbname=postgres")
    cur = conn.cursor()
    
    cur.execute("SELECT * FROM check_backup_delay()")
    results = cur.fetchall()
    
    for result in results:
        if result[3] != 'OK':
            send_alert(f"Backup Alert: {result[0]} is {result[3]}, delay: {result[2]} hours")
    
    conn.close()

def send_alert(message):
    webhook_url = "https://alert.example.com/webhook"
    payload = {"text": message}
    requests.post(webhook_url, json=payload)

if __name__ == "__main__":
    check_backup_status()
```

## 灾难恢复

### 恢复时间目标(RTO)评估

1. 评估因素：
   - 数据库大小
   - 可用网络带宽
   - 存储性能
   - WAL重放速度

2. 计算公式：

```python
def calculate_rto(db_size_gb, network_speed_mbps, storage_iops):
    # 传输时间
    transfer_time = (db_size_gb * 1024 * 8) / (network_speed_mbps * 60)
    
    # 解压时间
    decompress_time = db_size_gb * 0.5  # 估算值
    
    # WAL重放时间
    wal_replay_time = db_size_gb * 0.3  # 估算值
    
    total_time = transfer_time + decompress_time + wal_replay_time
    return total_time
```

### 恢复演练

1. 演练计划：
   - 每季度进行一次完整恢复演练
   - 每月进行一次部分数据恢复测试
   - 记录并优化恢复流程

   
   
2. 演练文档模板：

```markdown
# 恢复演练报告

## 基本信息
- 演练日期：
- 演练环境：
- 数据库版本：
- 备份大小：

## 恢复步骤
1. 准备阶段
   - [ ] 验证备份完整性
   - [ ] 准备恢复环境
   - [ ] 确认存储空间

2. 执行阶段
   - [ ] 解压备份文件
   - [ ] 配置恢复参数
   - [ ] 启动数据库
   - [ ] 验证数据一致性

3. 验证阶段
   - [ ] 检查系统表
   - [ ] 验证用户数据
   - [ ] 测试应用连接

## 结果分析
- 恢复总耗时：
- 问题记录：
- 优化建议：
```

## 最佳实践

### 安全建议

1. 加密配置：

```bash
# 使用GPG加密备份
gpg --encrypt --recipient backup@example.com base.tar.zst

# 或使用openssl
openssl enc -aes-256-cbc -salt -in base.tar.zst -out base.tar.zst.enc
```



2. 访问控制：

```bash
# 备份目录权限
chmod 700 /backup/pg
setfacl -m u:postgres:rx /backup/pg

# 加密密钥管理
gpg --gen-key
gpg --export-secret-keys --armor > backup-key.asc
```

### 存储管理

1. 备份压缩率监控：

```bash
#!/bin/bash
# 监控备份压缩效率
for backup in /backup/pg/*/base.tar.zst; do
    original_size=$(zstd -l "$backup" | awk 'NR==4 {print $4}')
    compressed_size=$(zstd -l "$backup" | awk 'NR==4 {print $2}')
    ratio=$(echo "scale=2; $compressed_size/$original_size * 100" | bc)
    echo "$backup: $ratio% of original size"
done
```



2. 存储空间预测：

```python
#!/usr/bin/env python3

import psutil
import datetime
import numpy as np

def predict_storage_usage(backup_dir, days=30):
    # 获取历史使用数据
    usage_data = []
    for _ in range(days):
        usage = psutil.disk_usage(backup_dir).used
        usage_data.append(usage)
    
    # 线性回归预测
    X = np.arange(days).reshape(-1, 1)
    y = np.array(usage_data)
    
    from sklearn.linear_model import LinearRegression
    model = LinearRegression()
    model.fit(X, y)
    
    # 预测下一周期
    future_days = np.arange(days, days+7).reshape(-1, 1)
    predictions = model.predict(future_days)
    
    return predictions
```

## 总结

本文档提供了PostgreSQL数据库备份与恢复的完整解决方案，包括PITR和物理备份两种方案的详细配置、监控、优化和最佳实践。建议根据实际需求选择合适的备份策略，并定期进行恢复演练以确保数据安全。