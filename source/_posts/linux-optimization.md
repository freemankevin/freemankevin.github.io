---
title: 如何优化 Linux 系统性能以支持高并发
date: 2024-12-27 15:00:00
tags:
  - Optimization 
  - Container
  - Linux
category: Linux
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在本篇文章中，我们将详细介绍针对高并发场景下的系统性能瓶颈的优化实践，涉及网络层（TCP参数、Offloading）、文件描述符、CPU调度、内存管理（HugePages）、I/O调度、容器化（Docker）以及日志监控等关键技术点，旨在提升系统在高负载下的吞吐量和响应速度。

<!-- more -->
> 这里以 `CentOS 7.9` 环境举例。

## 文件系统 

### 文件描述符

在高并发环境中，文件描述符的限制往往成为性能瓶颈。通过配置系统的软硬文件描述符限制，可以避免文件描述符不足的问题。

```bash
# 配置文件描述符限制
grep -qxF '* soft nofile 1048576' /etc/security/limits.conf || echo '* soft nofile 1048576' >> /etc/security/limits.conf
grep -qxF '* hard nofile 1048576' /etc/security/limits.conf || echo '* hard nofile 1048576' >> /etc/security/limits.conf
```

在 `sysctl.conf` 中也需要增加相关配置：

```bash
# 文件描述符限制
tee -a /etc/sysctl.conf << EOF
fs.file-max = 1048576
EOF
```

## CPU

### CPU 调度器

在多核系统上，可以通过调整 CPU 调度器来提高并发性能。使用 `isolcpus` 参数将一些 CPU 核心从系统调度中隔离出来，使其专门用于高负载任务，避免系统其他任务和中断占用这些资源。

```bash
# 隔离特定的 CPU 核心
GRUB_CMDLINE_LINUX="isolcpus=2,3"
update-grub
reboot
```



## 内存

### 内存大页

启用 HugePages 可以减少内存分配和释放的开销，尤其对数据库和内存密集型应用非常有利。

```bash
# 查看当前 HugePages 配置
cat /proc/meminfo | grep HugePages

# 配置 HugePages 数量
echo 2048 > /proc/sys/vm/nr_hugepages

# 永久配置，修改 /etc/sysctl.conf 或使用 sysctl
tee -a /etc/sysctl.conf << EOF
vm.nr_hugepages = 2048
EOF
```

### 内存管理

通过调整内存管理相关参数，可以提高系统性能。

```bash
# 内存管理
tee -a /etc/sysctl.conf << EOF
vm.drop_caches = 3
vm.max_map_count = 262144
EOF
```

## 内核

### 调试与日志

禁用一些内核调试信息和日志，以减少不必要的系统开销。

```bash
# 内核调试信息与日志
tee -a /etc/sysctl.conf << EOF
kernel.sysrq = 0
kernel.dmesg_restrict = 1
EOF
```

### 信号量

调整信号量参数，优化系统性能。

```bash
# 信号量设置
tee -a /etc/sysctl.conf << EOF
kernel.sem = 250 32000 100 128
EOF
```

## 网络

### 网络中断

为了提高网络性能，启用 `irqbalance` 服务，它可以自动平衡网络中断处理，减少单个 CPU 核心的负载，从而提高整体性能。

```bash
# 启动 irqbalance 服务
systemctl enable irqbalance
systemctl start irqbalance
```

### 常规配置

#### 启用 IP 转发

启用 IP 转发，如果服务器需要作为路由器或网关，则需要启用此选项。

```bash
tee -a /etc/sysctl.conf << EOF
net.ipv4.ip_forward = 1
EOF
```

#### 禁用 ICMP 重定向

禁用 ICMP 重定向可以防止中间人攻击，并减少网络流量。

```bash
tee -a /etc/sysctl.conf << EOF
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
EOF
```

#### 禁用源路由

禁用源路由是一种安全措施，可以防止攻击者伪造源 IP 地址。

```bash
tee -a /etc/sysctl.conf << EOF
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
EOF
```

#### 禁用接受重定向

禁用接受重定向也是一种安全措施，类似于禁用发送重定向。

```bash
tee -a /etc/sysctl.conf << EOF
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
EOF
```

#### 禁用安全重定向

禁用安全重定向，进一步提高网络安全性。

```bash
tee -a /etc/sysctl.conf << EOF
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
EOF
```

#### 忽略 ICMP 广播回显请求

忽略 ICMP 广播回显请求可以防止 Smurf 攻击。

```bash
tee -a /etc/sysctl.conf << EOF
net.ipv4.icmp_echo_ignore_broadcasts = 1
EOF
```

#### 忽略错误的 ICMP 错误响应

忽略错误的 ICMP 错误响应。

```bash
tee -a /etc/sysctl.conf << EOF
net.ipv4.icmp_ignore_bogus_error_responses = 1
EOF
```

#### 启用反向路径过滤

启用反向路径过滤，可以防止 IP 地址欺骗。

```bash
tee -a /etc/sysctl.conf << EOF
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
EOF
```

#### 启用 TCP 同步 Cookie

启用 TCP 同步 Cookie，可以防止 SYN Flood 攻击。

```bash
tee -a /etc/sysctl.conf << EOF
net.ipv4.tcp_syncookies = 1
EOF
```

#### 设置本地端口范围

设置本地端口范围。

```bash
tee -a /etc/sysctl.conf << EOF
net.ipv4.ip_local_port_range = 1024 65535
EOF
```

#### 设置接收和发送缓冲区大小

设置接收和发送缓冲区的默认值和最大值，这些值与 TCP 缓冲区大小相关，但影响的是所有 socket。

```bash
tee -a /etc/sysctl.conf << EOF
net.core.rmem_default = 16777216
net.core.rmem_max = 16777216
net.core.wmem_default = 16777216
net.core.wmem_max = 16777216
EOF
```

### TCP 连接管理

调整 TCP 参数，以优化连接管理。

```bash
# 优化 TCP 连接管理
tee -a /etc/sysctl.conf << EOF
net.ipv4.tcp_fin_timeout = 30  # 减少 TIME_WAIT 状态持续时间
net.ipv4.tcp_tw_reuse = 1  # 启用 TCP 连接复用
net.ipv4.tcp_tw_recycle = 1  # 启用 TCP TIME_WAIT 连接快速回收
EOF
```

### 调整 TCP 参数

调整 TCP 参数能显著提高网络吞吐量并减少延迟，特别是在高并发场景下。

```bash
# 启用 TCP 快速打开（TCP Fast Open）
tee -a /etc/sysctl.conf << EOF
net.ipv4.tcp_fastopen = 3

# 调整 TCP buffer 大小
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216

# 增大 TCP 监听队列长度，避免连接排队
net.ipv4.tcp_max_syn_backlog = 2048
EOF
```

### 启用 TCP Offloading

现代网卡支持 TCP Offloading 技术，可以将部分 TCP 处理工作交给硬件完成，减轻 CPU 的负担。

```bash
# 查看网络设备支持的 Offloading 功能
ethtool -S eth0

# 启用 TCP Segmentation Offload (TSO)
ethtool -K eth0 tso on
```



## 磁盘

### 调度器

在高并发场景中，优化磁盘调度器可以减少 I/O 请求的延迟，尤其是在 SSD 上，`noop` 调度器通常是最合适的。

```bash
# 设置磁盘调度器为 noop
echo noop > /sys/block/vda/queue/scheduler  # vda 为磁盘名，根据实际情况调整

# 永久配置（通过 udev 或系统服务）
# /etc/udev/rules.d/60-io-scheduler.rules
ACTION=="add|change", KERNEL=="vd[a-z]", ATTR{queue/scheduler}="noop"
```

### 请求队列

通过增加磁盘的 I/O 请求队列长度，可以提高高并发时的磁盘性能。

```bash
# 查看当前磁盘队列长度
cat /sys/block/vda/queue/nr_requests

# 设置更大的队列长度
echo 128 > /sys/block/vda/queue/nr_requests
```

## 容器化

### 服务配置

为了提升 Docker 容器在高并发环境下的性能，可以采取以下措施：

*   使用 `overlay2` 存储驱动，而不是 `aufs` 或 `devicemapper`。
*   增加容器的 `ulimit` 设置，避免因文件描述符限制导致容器崩溃。

```json
# 修改 Docker 配置文件（/etc/docker/daemon.json）
{
  "storage-driver": "overlay2",
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 10
}
```

### 资源限制

为每个容器设置合适的 CPU 和内存限制，可以避免容器过度消耗主机资源，影响整体性能。

```bash
# 限制容器的 CPU 使用
docker run --cpus="2.0" ...

# 限制容器的内存使用
docker run --memory="4g" ...
```

## 日志和监控

### 禁用日志

高并发时，过多的日志记录会增加系统负担，建议禁用不必要的日志，尤其是系统日志。

```bash
# 停止不必要的日志服务
systemctl stop rsyslog
```

### 监控工具

配置合适的监控工具如 `Prometheus`、`Grafana `或 `Netdata`，可以实时监控系统的各项指标，如 CPU、内存、磁盘、网络等，及时发现性能瓶颈。

## 刷新生效

```shell
sysctl -p
# 建议重启
sync;reboot
