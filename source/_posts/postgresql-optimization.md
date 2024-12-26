---
title: 如何优化 PostgreSQL 数据库以支持高并发
date: 2024-12-26 11:34:15
tags: 
  - Linux
  - Memory
  - PostgreSQL
#comments: true
category: PostgreSQL
---


&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;本文将介绍如何优化 PostgreSQL 数据库以支持高并发场景。我们会针对内存缓存、连接数、索引、日志、查询优化等方面进行详细的优化建议，以帮助提升数据库的性能。

<!-- more -->

> 这里以16C 核心、32GB 物理内存和 20GB 虚拟内存的服务器举例。

## 常规考虑
### 共享缓冲区

- **作用**：`shared_buffers` 是 PostgreSQL 用来缓存数据页的内存区域。如果这个值设置得过小，数据库需要频繁访问磁盘，导致性能下降。
- **优化建议**：设置为物理内存的 25%-40%。对于 32GB 的物理内存，可以设置为 8GB 到 12GB 之间。
    
  ```shell
  shared_buffers = 8GB  # 可根据内存进行调整
  ```
### 工作内存

- **作用**：`work_mem` 定义了单个查询操作（如排序、哈希连接等）所能使用的内存。对于大查询，适当增加 `work_mem` 可以减少磁盘交换。

- **优化建议**: 增加每个查询的内存使用量，但不要过高，以免消耗过多内存。一般可以设置为 4MB 到 16MB，具体根据查询复杂度调整。

  ```shell
  work_mem = 16MB  # 根据实际负载进行调整
  ```

### 维护工作内存

- **作用**：`maintenance_work_mem` 定义了 PostgreSQL 用于执行某些维护操作（如创建索引、VACUUM、分析等）的内存大小。增加此值可以加速这些操作。

- **优化建议**: 增加该值可以提高 `VACUUM` 和索引创建的速度。对于 32GB 内存的机器，可以设置为 512MB 到 1GB。

  ```shell
  maintenance_work_mem = 512MB
  ```

### 自动工作内存

- **作用**：`effective_cache_size` 告诉 PostgreSQL 查询优化器可用的操作系统缓存大小，以帮助它估计缓存命中率。

- **优化建议**: 设置为系统中可用于缓存的数据量，通常为系统总内存的 50%-75%。

  ```shell
  effective_cache_size = 24GB  # 根据实际可用内存设置
  ```

### 最大连接数

- **作用**：`max_connections` 定义了数据库可以同时接入的最大客户端连接数。如果这个值设置得过高，可能导致内存和 CPU 资源过度消耗。

- **优化建议**: 适当增加最大连接数，但要确保服务器有足够的内存来处理这些连接。假设你需要支持 500-1000 个并发连接，通常设置在 200 到 500 之间。

  ```shell
  max_connections = 500
  ```

### WAL 日志设置 

- **作用**：`wal_buffers` 控制 PostgreSQL 在写入 WAL（Write-Ahead Logging）日志时的缓冲区大小。如果设置得过小，会影响数据库写入性能。

- **优化建议**: 对于大型数据库，设置一个更大的 `wal_buffers` 可以提高写入性能。可以考虑将其设置为 16MB 或更大。

  ```shell
  wal_buffers = 16MB
  ```

### WAL 日志检查点频率

- **作用**：`checkpoint_segments` 决定了日志切换点之间可以有多少个日志文件。如果这个值设置得太小，可能会导致频繁的磁盘 I/O 操作。

- **优化建议**：
  - 增加 `checkpoint_segments` 可以减少 checkpoint 的频率，从而减少磁盘 I/O。
  - 默认的 `checkpoint_timeout` 可以保持在 5 分钟左右。`checkpoint_completion_target` 控制检查点完成的目标时间，如果系统负载较高，考虑将其设为较低值。

  ```shell
  checkpoint_timeout = 5min
  checkpoint_completion_target = 0.9
  checkpoint_segments = 64
  ```

### 同步提交

- **作用**：`synchronous_commit` 控制事务是否需要等待 WAL 日志完全写入磁盘。默认情况下，这个参数是启用的，会确保数据一致性，但也可能影响性能。

- **优化建议**：如果对数据一致性要求不是极其严格，可以考虑设置为 `off`，以提高写入性能。

  ```shell
  synchronous_commit = off
  ```

### 并行查询设置

- **作用**：控制单个查询操作中使用的最大并行工作进程数。在多核 CPU 上启用并行查询可以大大提高查询性能。

- **优化建议**：在较多核心的机器上，可以适当增加该值以加速查询。假设你有多个核心，可以设置为 4 或更高。

  ```shell
  max_parallel_workers_per_gather = 4
  ```

### 查询优化器设置

- **作用**：`random_page_cost` 和 `seq_page_cost` 控制查询优化器对磁盘访问的成本估算。调优这两个参数可以帮助优化器做出更好的查询计划。

- **优化建议**：如果使用的是 SSD 硬盘，`random_page_cost` 和 `seq_page_cost` 可以适当降低，因为 SSD 具有较低的随机访问延迟。

  ```shell
  random_page_cost = 1.1  # 如果使用 SSD 硬盘
  seq_page_cost = 1.0
  ```

### 日志记录设置

- **作用**：该参数控制哪些查询会被记录到日志中。设置该参数可以帮助你识别慢查询，进行进一步的优化。

- **优化建议**：设置一个较低的时间阈值（例如 500ms），以记录可能导致性能瓶颈的慢查询。

  ```shell
  log_min_duration_statement = 500  # 记录执行超过500ms的查询
  ```

### 自动清理设置

- **作用**：`autovacuum` 用于自动清理死行（dead tuples）并进行数据库的碎片整理。如果未适当配置，可能会导致数据库膨胀，影响查询性能。

- **优化建议**：确保启用 `autovacuum` 并根据负载调整其参数，以确保定期清理死行和索引碎片。
  ```shell
  autovacuum = on
  autovacuum_vacuum_cost_delay = 20ms  # 减少自动清理对性能的影响
  autovacuum_vacuum_scale_factor = 0.2  # 当表数据增长 20% 时触发自动清理
  ```

### 优化 IO 操作

- **作用**：`effective_io_concurrency` 控制 IO 操作的并发级别，对于多磁盘系统和使用 RAID 或 SSD 时特别有用。

- **优化建议**：如果使用 SSD 或 RAID 磁盘阵列，适当增加并发级别。

  ```shell
  effective_io_concurrency = 200  # 根据磁盘性能进行调整
  ```

### 分离存储路径

- **作用**：将日志存储路径与数据存储路径分开，可以减少磁盘 I/O 竞争，提升数据库的写入性能，尤其是在高并发写入时，能有效减少 I/O 阻塞。

- **优化建议**： 
  - 将数据存储路径和 WAL 日志存储路径分开，最好使用不同的磁盘或分区。
  - 将 WAL 日志存储在 SSD 上，数据存储在机械硬盘（HDD）上。
  
  ```shell
  # 数据存储路径
  data_directory = '/data/postgresql/data'  # 数据存储在磁盘 A
  
  # 日志存储路径
  log_directory = '/var/log/postgresql/logs'  # WAL 日志存储在磁盘 B（SSD）
  ```

---

## 灵活调整
> 适用于较低配置或共享资源的服务器

```shell
shared_buffers = 4GB
work_mem = 4MB
maintenance_work_mem = 128MB 
effective_cache_size = 6GB
max_parallel_workers_per_gather = 16
max_parallel_workers = 16
autovacuum = off
log_min_duration_statement = -1 
wal_level = minimal
synchronous_commit = off
checkpoint_timeout = 30min
```

## 总结

针对 PostgreSQL 数据库的优化，需要根据具体的硬件配置和应用场景进行调整。上述建议主要针对提高数据库在高并发场景下的性能，特别是内存缓存、连接数、索引、日志、查询优化等方面。适当的内存配置和优化索引、查询及并行性设置，能有效提高数据库的并发处理能力。

如果你有更多具体的应用场景或需要进一步的调优，随时告诉我！
