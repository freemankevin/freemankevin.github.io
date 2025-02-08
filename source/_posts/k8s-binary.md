---
title: 二进制方式部署Kubernetes 集群
date: 2025-02-08 16:23:25
tags:
    - ETCD
    - NFS
    - Harbor
    - Kubernetes
    - Debian
category: Kubernetes
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 本文详细介绍如何使用二进制方式在 Debian 系统上搭建一个生产级别的高可用 Kubernetes 集群。

<!-- more -->

---

# 部署规划

## 服务器清单

| 角色 | 主机名 | IP地址 | 配置 | 系统 |
|------|--------|--------|------|------|
| LB-1 | lb1.k8s.com | 192.168.171.134 | 2C4G | Debian 12 |
| LB-2 | lb2.k8s.com | 192.168.171.135 | 2C4G | Debian 12 |
| VIP | - | 192.168.171.133 | - | - |
| ETCD-1 | etcd1.k8s.com | 192.168.171.136 | 4C8G | Debian 12 |
| ETCD-2 | etcd2.k8s.com | 192.168.171.137 | 4C8G | Debian 12 |
| ETCD-3 | etcd3.k8s.com | 192.168.171.138 | 4C8G | Debian 12 |
| Master-1 | master1.k8s.com | 192.168.171.136 | 4C8G | Debian 12 |
| Master-2 | master2.k8s.com | 192.168.171.137 | 4C8G | Debian 12 |
| Master-3 | master3.k8s.com | 192.168.171.138 | 4C8G | Debian 12 |
| Worker-1 | worker1.k8s.com | 192.168.171.139 | 8C16G | Debian 12 |
| Harbor | harbor.k8s.com | 192.168.171.50 | 4C8G | Debian 12 |
| NFS | nfs.k8s.com | 192.168.171.140 | 4C8G | Debian 12 |

## 网络规划

- 节点网段: 192.168.171.0/24
- Pod 网段: 10.244.0.0/16
- Service 网段: 10.96.0.0/12
- DNS 服务: CoreDNS

## 组件版本

- Kubernetes: v1.27.8
- Etcd: v3.5.9
- Docker: 24.0.7
- Containerd: 1.7.6
- Calico: v3.26.1
- CoreDNS: v1.10.1
- Harbor: v2.9.1

---
# 系统初始化

## 添加软件源

```shell
# 备份原始源文件
cp /etc/apt/sources.list /etc/apt/sources.list.bak

# 清理并配置新的软件源
# 删除注释行和空行
sed -i '/^#/d; /^$/d' /etc/apt/sources.list
# 注释掉原始行
sed -i 's/^deb cdrom:\[Debian GNU\/Linux.*$/#&/' /etc/apt/sources.list
# 删除旧的安全源
sed -i '/^deb http:\/\/security.debian.org\/debian-security/d' /etc/apt/sources.list
sed -i '/^deb-src http:\/\/security.debian.org\/debian-security/d' /etc/apt/sources.list

# 添加清华源
cat > /etc/apt/sources.list << EOF
deb http://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye main contrib non-free
deb http://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-updates main contrib non-free
deb http://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-backports main contrib non-free
deb http://mirrors.tuna.tsinghua.edu.cn/debian-security bullseye-security main contrib non-free

# 源码镜像（可选）
# deb-src http://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye main contrib non-free
# deb-src http://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-updates main contrib non-free
# deb-src http://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-backports main contrib non-free
# deb-src http://mirrors.tuna.tsinghua.edu.cn/debian-security bullseye-security main contrib non-free
EOF
```

## 系统更新

```shell
# 更新软件包索引
apt update 

# 升级所有已安装的软件包
apt upgrade -y 

# 安装重要的系统更新（如果有的话）
apt dist-upgrade -y
```

## 基础工具安装

```shell
# 安装基础工具包
apt update
apt install -y \
    # 系统工具
    apt-transport-https \
    ca-certificates \
    vim \
    net-tools \
    sudo \
    telnet \
    ufw \
    iotop \
    rsync \
    unzip \
    iputils-ping \
    gawk \
    sed \
    cron \
    gnupg \
    locales \
    curl \
    wget \
    tree \
    htop \
    nmon \
    lsof \
    # 网络工具
    nfs-common \
    sshpass \
    software-properties-common \
    # 系统监控
    sysstat \
    # 文本处理
    jq \
    # 版本控制
    git

# 清理不需要的包
apt autoremove -y
```

## 系统语言配置

```shell
# 生成英文语言环境
locale-gen en_US.UTF-8

# 配置系统默认语言
cat > /etc/default/locale << EOF
LC_ALL=en_US.utf8
LANG=en_US.utf8
LANGUAGE=en_US.utf8
EOF

# 配置语言生成
sed -i 's/^zh_CN.UTF-8 UTF-8/#zh_CN.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen

# 重新生成语言文件
locale-gen

# 配置环境变量
echo "export LANG=en_US.utf8" >> /etc/profile
echo "export LANGUAGE=en_US.utf8" >> /etc/profile
source /etc/profile
```

## SSH远程访问配置

```shell
# 配置SSH允许root登录
sed -ri 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# 加强SSH安全配置
cat >> /etc/ssh/sshd_config << EOF
# SSH认证配置
# 同时启用密码和密钥认证，便于初始化后的管理
PasswordAuthentication yes
PubkeyAuthentication yes

# 设置SSH协议版本
Protocol 2

# 限制最大认证尝试次数
MaxAuthTries 3

# 禁用空密码
PermitEmptyPasswords no

# 设置登录超时时间（秒）
LoginGraceTime 60

# 启用严格模式
StrictModes yes

# 安全加固建议（等系统完全配置好后可以考虑启用）：
# 1. 禁用密码认证，只使用密钥认证
# PasswordAuthentication no
# 2. 限制允许登录的用户
# AllowUsers your-user-name
# 3. 更改默认端口
# Port 2222
EOF

# 重启SSH服务
systemctl restart ssh

# 验证配置
egrep '^PermitRootLogin' /etc/ssh/sshd_config
```

## Shell环境优化

```shell
# 配置.bashrc
cat >> ~/.bashrc << EOF
# 配置命令别名
alias ll='ls -l'
alias la='ls -A'
alias l='ls -CF'
alias vi='vim'
alias cls='clear'

# 配置命令历史记录
HISTSIZE=5000
HISTFILESIZE=10000
HISTTIMEFORMAT="%F %T "

# 配置PS1提示符
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# 启用颜色支持
export LS_OPTIONS='--color=auto'
eval "$(dircolors)"
alias ls='ls $LS_OPTIONS'
EOF

# 应用新配置
source ~/.bashrc
```

## 网络配置（可选）

```shell
# 配置静态IP
cat > /etc/network/interfaces << EOF
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto ens32
iface ens32 inet static
    address 192.168.171.136
    netmask 255.255.255.0
    gateway 192.168.171.2
    # DNS配置
    dns-nameservers 8.8.8.8 8.8.4.4
EOF
```

## 系统优化

```shell
# 关闭swap
swapoff -a
sed -i '/swap/d' /etc/fstab

# 配置系统限制
cat > /etc/security/limits.conf << EOF
* soft nofile 65535
* hard nofile 65535
* soft nproc 65535
* hard nproc 65535
EOF

# 优化内核参数
cat > /etc/sysctl.d/99-sysctl.conf << EOF
# 系统级别的最大文件句柄数
fs.file-max = 2097152

# TCP连接参数优化
net.ipv4.tcp_max_syn_backlog = 8192
net.core.somaxconn = 32768
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_fin_timeout = 30

# 内存参数优化
vm.swappiness = 0
vm.overcommit_memory = 1
EOF

# 应用内核参数
sysctl -p
```

## 系统服务优化

```shell
# 禁用不需要的服务
systemctl stop rpcbind
systemctl disable rpcbind
apt autoremove rpcbind -y

# 配置防火墙（UFW）
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
# 根据需要添加其他端口

# 启用防火墙
ufw --force enable
```

## 完成初始化

```shell
# 同步文件系统
sync

# 重启系统使所有更改生效
reboot
```

## 自动化部署

```shell
# 创建一个初始化脚本
cat > init-debian.sh << 'EOF'
#!/bin/bash
# Debian系统初始化脚本
# 使用方法: ./init-debian.sh

# 检查是否为root用户
if [ "$(id -u)" != "0" ]; then
   echo "此脚本必须以root权限运行" 
   exit 1
fi

# 这里放入上述所有配置步骤
# ...

echo "系统初始化完成，请重启服务器"
EOF

# 添加执行权限
chmod +x init-debian.sh

# 运行脚本
./init-debian.sh
```

## 注意事项

1. 在执行初始化操作前，建议先备份重要数据
2. 修改网络配置时需要特别小心，错误的配置可能导致无法远程访问
3. 防火墙规则要根据实际需求配置
4. 建议保存一份配置文件的备份
5. 初始化完成后要及时修改root密码和SSH配置

## 故障排除

如果在初始化过程中遇到问题，可以检查以下几点：

1. 查看系统日志：`journalctl -xe`
2. 检查服务状态：`systemctl status <服务名>`
3. 检查网络连接：`ping -c 4 8.8.8.8`
4. 验证软件源可用性：`apt update`

---

# 高可用负载均衡部署

## 环境准备

```shell
# 更新系统并安装基础工具
apt-get update
apt-get install -y \
    psmisc \
    curl \
    wget \
    net-tools \
    ipvsadm \
    ipset

# 检查网络配置
ip a
```

## Keepalived 部署

### 安装 Keepalived

```shell
# 在所有负载均衡节点上安装
apt install -y keepalived
```

### 配置健康检查脚本

```shell
# 创建健康检查脚本
cat > /etc/keepalived/check_apiserver.sh << EOF
#!/bin/bash

API_URL="https://192.168.171.133:6443/healthz"
TIMEOUT=3

# 检查API服务器健康状态
if curl -k -s --connect-timeout ${TIMEOUT} ${API_URL} | grep -q "ok"; then
    exit 0
else
    exit 1
fi
EOF

# 添加执行权限
chmod +x /etc/keepalived/check_apiserver.sh
```

### 主节点配置

```shell
# 配置主节点的keepalived
cat > /etc/keepalived/keepalived.conf << EOF
! Configuration File for keepalived
global_defs {
    router_id LVS_DEVEL
    script_user root
    enable_script_security
}

# HAProxy进程检查
vrrp_script check_haproxy {
    script "/usr/bin/killall -0 haproxy"
    interval 2
    weight 2
    fall 2
    rise 1
}

# API服务器健康检查
vrrp_script check_apiserver {
    script "/etc/keepalived/check_apiserver.sh"
    interval 3
    weight -2
    fall 10
    rise 2
}

vrrp_instance VI_1 {
    state MASTER
    interface ens192                # 根据实际网卡名修改
    virtual_router_id 51
    priority 101
    advert_int 1
    
    authentication {
        auth_type PASS
        auth_pass K8SHA_KA_AUTH    # 建议修改密码
    }
    
    virtual_ipaddress {
        192.168.171.133             # VIP地址
    }
    
    # 使用单播模式（推荐）
    unicast_src_ip 192.168.171.134  # 本机IP（LB-1）
    unicast_peer {
        192.168.171.135             # 对端IP（LB-2）
    }
    
    # 配置追踪脚本
    track_script {
        check_apiserver
        check_haproxy
    }
}
EOF
```

### 备节点配置

```shell
# 配置备节点的keepalived
cat > /etc/keepalived/keepalived.conf << EOF
! Configuration File for keepalived
global_defs {
    router_id LVS_DEVEL
    script_user root
    enable_script_security
}

vrrp_script check_haproxy {
    script "/usr/bin/killall -0 haproxy"
    interval 2
    weight 2
    fall 2
    rise 1
}

vrrp_script check_apiserver {
    script "/etc/keepalived/check_apiserver.sh"
    interval 3
    weight -2
    fall 10
    rise 2
}

vrrp_instance VI_1 {
    state BACKUP
    interface ens192                # 根据实际网卡名修改
    virtual_router_id 51
    priority 100
    advert_int 1
    
    authentication {
        auth_type PASS
        auth_pass K8SHA_KA_AUTH    # 与主节点保持一致
    }
    
    virtual_ipaddress {
        192.168.171.133             # VIP地址
    }
    
    unicast_src_ip 192.168.171.135  # 本机IP（LB-2）
    unicast_peer {
        192.168.171.134             # 对端IP（LB-1）
    }
    
    track_script {
        check_apiserver
        check_haproxy
    }
}
EOF
```

### 启动服务

```shell
# 检查配置文件语法
keepalived -t -f /etc/keepalived/keepalived.conf

# 启动并设置开机自启
systemctl start keepalived
systemctl enable keepalived

# 检查服务状态
systemctl status keepalived
```

## HAProxy 部署

### 安装 HAProxy

```shell
# 在所有负载均衡节点上安装
apt install -y haproxy
```

### 配置 HAProxy

```shell
# 备份原配置
cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak

# 创建新配置
cat > /etc/haproxy/haproxy.cfg << EOF
#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global
    log /dev/log local0
    log /dev/log local1 notice
    daemon
    maxconn 100000
    user haproxy
    group haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners

#---------------------------------------------------------------------
# Default settings
#---------------------------------------------------------------------
defaults
    log     global
    mode    tcp
    option  dontlognull
    timeout connect 5000ms
    timeout client  50000ms
    timeout server  50000ms

#---------------------------------------------------------------------
# Statistics settings
#---------------------------------------------------------------------
listen stats
    bind *:9090
    mode http
    stats enable
    stats uri /stats
    stats refresh 30s
    stats auth admin:Admin@123.com    # 访问统计页面的用户名和密码

#---------------------------------------------------------------------
# Frontend configuration for API server
#---------------------------------------------------------------------
frontend k8s-apiserver
    bind *:6443
    mode tcp
    option tcplog
    default_backend k8s-apiserver

#---------------------------------------------------------------------
# Backend configuration for API server
#---------------------------------------------------------------------
backend k8s-apiserver
    mode tcp
    option tcp-check
    balance roundrobin
    default-server inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100
    server master1 192.168.171.136:6443 check
    server master2 192.168.171.137:6443 check
    server master3 192.168.171.138:6443 check
EOF
```

### 启动服务

```shell
# 检查配置文件语法
haproxy -f /etc/haproxy/haproxy.cfg -c

# 启动并设置开机自启
systemctl start haproxy
systemctl enable haproxy

# 检查服务状态
systemctl status haproxy
```

## 验证部署

```shell
# 检查VIP是否生效
ip a | grep 192.168.1.110

# 检查HAProxy统计页面
curl -u admin:Admin@123.com http://localhost:9090/stats

# 测试API服务器访问
curl -k https://192.168.171.133:6443/healthz

# 测试故障转移
# 1. 在主节点上停止HAProxy
systemctl stop haproxy

# 2. 观察VIP是否漂移到备节点
ip a
```

## 故障排除

1. Keepalived 故障排查：
```shell
# 检查日志
journalctl -u keepalived -f

# 检查配置
keepalived -t -f /etc/keepalived/keepalived.conf

# 检查网络接口
ip a
```

2. HAProxy 故障排查：
```shell
# 检查日志
journalctl -u haproxy -f

# 检查配置
haproxy -f /etc/haproxy/haproxy.cfg -c

# 检查端口监听
netstat -ntlp | grep haproxy
```

## 注意事项

1. 网络配置：
   - 确保防火墙允许VRRP协议（端口112）
   - 允许HAProxy监听端口（6443, 9090）
   - 检查网卡名称是否正确

2. 安全建议：
   - 修改Keepalived认证密码
   - 更改HAProxy统计页面的访问凭据
   - 限制HAProxy统计页面的访问IP

3. 维护建议：
   - 定期检查服务状态
   - 监控日志信息
   - 定期测试故障转移功能

4. 性能优化：
   - 根据实际负载调整HAProxy的连接数限制
   - 适当调整超时时间
   - 监控系统资源使用情况

---
# ETCD 集群部署

## 环境准备

### 主机配置

```shell
# 修改主机名
# 在 etcd1 上执行
hostnamectl set-hostname etcd1

# 在 etcd2 上执行
hostnamectl set-hostname etcd2

# 在 etcd3 上执行
hostnamectl set-hostname etcd3

# 配置 hosts 解析
cat >> /etc/hosts << EOF
192.168.171.136 etcd1
192.168.171.137 etcd2
192.168.171.138 etcd3
EOF
```

### 配置免密登录

```shell
# 在 etcd1 上执行
# 生成密钥对
ssh-keygen -t rsa -b 2048 -N "" -f ~/.ssh/id_rsa

# 分发公钥
for host in etcd1 etcd2 etcd3; do
    sshpass -p 'your_password' ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub "root@$host"
done
```

### 配置环境变量

```shell
# 在所有节点上执行
cat >> /etc/profile << EOF
# ETCD API 版本
export ETCDCTL_API=3
EOF

source /etc/profile
```

## 组件安装

### 安装 CFSSL 工具

```shell
# 在所有节点上执行
# 安装 CFSSL（下载地址：https://github.com/cloudflare/cfssl/releases）
cp cfssl_1.6.3_linux_amd64 /usr/local/bin/cfssl
cp cfssljson_1.6.3_linux_amd64 /usr/local/bin/cfssljson

# 添加执行权限
chmod +x /usr/local/bin/cfssl /usr/local/bin/cfssljson

# 验证安装
cfssl version
cfssljson -version
```

### 安装 ETCD

```shell
# 在所有节点上执行
# 设置环境变量
export ETCD_VER=v3.5.9
export DOWNLOAD_URL="https://github.com/etcd-io/etcd/releases/download"
export INSTALL_DIR="/usr/local/bin"

# 下载 ETCD 二进制文件
wget ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz

# 验证下载文件完整性
wget ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz.asc
# 如果需要验证签名
# gpg --verify etcd-${ETCD_VER}-linux-amd64.tar.gz.asc

# 解压安装包
tar -xzf etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp/

# 复制二进制文件到安装目录
cp /tmp/etcd-${ETCD_VER}-linux-amd64/etcd* ${INSTALL_DIR}/

# 清理临时文件
rm -rf /tmp/etcd-${ETCD_VER}-linux-amd64* etcd-${ETCD_VER}-linux-amd64.tar.gz*

# 创建数据目录
mkdir -p /data/etcd

# 验证安装
${INSTALL_DIR}/etcd --version
${INSTALL_DIR}/etcdctl version
```

## 配置 TLS 证书

### 创建证书配置

```shell
# 在 etcd1 上执行
mkdir -p /etc/etcd/ssl
cd /etc/etcd/ssl

# 创建 CA 配置文件
cat > ca-config.json << EOF
{
    "signing": {
        "default": {
            "expiry": "876000h"
        },
        "profiles": {
            "server": {
                "expiry": "876000h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth",
                    "client auth"
                ]
            },
            "client": {
                "expiry": "876000h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "client auth"
                ]
            },
            "peer": {
                "expiry": "876000h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth",
                    "client auth"
                ]
            }
        }
    }
}
EOF

# 创建 CA 证书请求文件
cat > etcd-ca-csr.json << EOF
{
    "key": {
        "algo": "rsa",
        "size": 4096
    },
    "names": [
        {
            "C": "CN",
            "L": "Beijing",
            "ST": "Beijing",
            "O": "k8s",
            "OU": "System"
        }
    ]
}
EOF

# 创建客户端证书请求文件
cat > client-csr.json << EOF
{
    "CN": "client",
    "key": {
        "algo": "rsa",
        "size": 2048
    }
}
EOF

# 创建服务端证书请求文件
cat > etcd-server-csr.json << EOF
{
    "CN": "etcd-server",
    "hosts": [
        "192.168.171.136",
        "192.168.171.137",
        "192.168.171.138",
        "127.0.0.1"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "Beijing",
            "O": "etcd-cluster",
            "OU": "System",
            "ST": "Beijing"
        }
    ]
}
EOF

# 创建对等证书请求文件
cat > etcd-peer-csr.json << EOF
{
    "CN": "etcd-peer",
    "hosts": [
        "192.168.171.136",
        "192.168.171.137",
        "192.168.171.138",
        "127.0.0.1"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "Beijing",
            "O": "etcd-cluster",
            "OU": "System",
            "ST": "Beijing"
        }
    ]
}
EOF
```

### 生成证书

```shell
# 在 etcd1 上执行
cd /etc/etcd/ssl

# 生成 CA 证书
cfssl gencert -initca etcd-ca-csr.json | cfssljson -bare etcd-ca

# 生成客户端证书
cfssl gencert \
    -ca=etcd-ca.pem \
    -ca-key=etcd-ca-key.pem \
    -config=ca-config.json \
    -profile=client client-csr.json | cfssljson -bare client

# 生成服务端证书
cfssl gencert \
    -ca=etcd-ca.pem \
    -ca-key=etcd-ca-key.pem \
    -config=ca-config.json \
    -profile=server etcd-server-csr.json | cfssljson -bare etcd-server

# 生成对等证书
cfssl gencert \
    -ca=etcd-ca.pem \
    -ca-key=etcd-ca-key.pem \
    -config=ca-config.json \
    -profile=peer etcd-peer-csr.json | cfssljson -bare etcd-peer

# 分发证书到其他节点
for host in etcd2 etcd3; do
    ssh $host "mkdir -p /etc/etcd/ssl"
    scp /etc/etcd/ssl/* $host:/etc/etcd/ssl/
done
```

## 配置 ETCD 服务

### 创建服务配置文件

```shell
# 在 etcd1 上执行
cat > /lib/systemd/system/etcd.service << EOF
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target
Before=kube-apiserver.service
Documentation=https://github.com/coreos

[Service]
Type=notify
WorkingDirectory=/data/etcd/
ExecStart=/usr/local/bin/etcd \\
  --name=etcd1 \\
  --cert-file=/etc/etcd/ssl/etcd-server.pem \\
  --key-file=/etc/etcd/ssl/etcd-server-key.pem \\
  --peer-cert-file=/etc/etcd/ssl/etcd-peer.pem \\
  --peer-key-file=/etc/etcd/ssl/etcd-peer-key.pem \\
  --trusted-ca-file=/etc/etcd/ssl/etcd-ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ssl/etcd-ca.pem \\
  --initial-advertise-peer-urls=https://192.168.171.136:2380 \\
  --listen-peer-urls=https://192.168.171.136:2380 \\
  --listen-client-urls=https://192.168.171.136:2379 \\
  --advertise-client-urls=https://192.168.171.136:2379 \\
  --initial-cluster-token=etcd-cluster-0 \\
  --initial-cluster=etcd1=https://192.168.171.136:2380,etcd2=https://192.168.171.137:2380,etcd3=https://192.168.171.138:2380 \\
  --initial-cluster-state=new \\
  --data-dir=/data/etcd \\
  --snapshot-count=50000 \\
  --auto-compaction-retention=1 \\
  --max-request-bytes=10485760 \\
  --quota-backend-bytes=8589934592
Restart=always
RestartSec=15
LimitNOFILE=65536
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
EOF

# 分发到其他节点并修改配置
for host in etcd2 etcd3; do
    scp /lib/systemd/system/etcd.service $host:/lib/systemd/system/
    ssh $host "sed -i 's/etcd1/$host/g; s/192.168.171.136/192.168.171.$(expr 136 + $(echo $host | cut -c5))/g' /lib/systemd/system/etcd.service"
done
```

### 启动服务

```shell
# 在所有节点上执行
# 创建数据目录
mkdir -p /data/etcd

# 重载服务配置
systemctl daemon-reload

# 启动并设置开机自启
systemctl enable --now etcd

# 查看服务状态
systemctl status etcd
```

## 集群验证

### 配置命令别名

```shell
# 在所有节点上执行
cat >> ~/.bashrc << EOF
# ETCD 集群操作别名
alias etcdctl='etcdctl \\
    --endpoints=192.168.171.136:2379,192.168.171.137:2379,192.168.171.138:2379 \\
    --cacert=/etc/etcd/ssl/etcd-ca.pem \\
    --cert=/etc/etcd/ssl/etcd-server.pem \\
    --key=/etc/etcd/ssl/etcd-server-key.pem'
EOF

source ~/.bashrc
```

### 检查集群状态

```shell
# 查看集群成员
etcdctl member list -w table

# 查看集群健康状态
etcdctl endpoint health -w table

# 写入测试数据
etcdctl put test "hello etcd"

# 读取测试数据
etcdctl get test

# 删除测试数据
etcdctl del test
```

## 集群备份

### 配置自动备份

```shell
# 创建备份目录
mkdir -p /data/etcd-backups

# 创建备份脚本
cat > /data/etcd-backups/etcd-backup.sh << EOF
#!/bin/bash

# 备份配置
BACKUP_DIR="/data/etcd-backups"
DATE=\$(date +%Y%m%d%H%M%S)
LOG_FILE="\${BACKUP_DIR}/backup-\${DATE}.log"

# 备份命令
/usr/local/bin/etcdctl \\
    --endpoints=192.168.171.136:2379 \\
    --cacert=/etc/etcd/ssl/etcd-ca.pem \\
    --cert=/etc/etcd/ssl/etcd-server.pem \\
    --key=/etc/etcd/ssl/etcd-server-key.pem \\
    snapshot save \${BACKUP_DIR}/backup-\${DATE}.db > \${LOG_FILE} 2>&1

# 清理旧备份
find \${BACKUP_DIR} -name "backup-*.db" -mtime +7 -delete
find \${BACKUP_DIR} -name "backup-*.log" -mtime +7 -delete
EOF

# 添加执行权限
chmod +x /data/etcd-backups/etcd-backup.sh

# 添加定时任务
echo "0 2 * * * /data/etcd-backups/etcd-backup.sh" >> /var/spool/cron/crontabs/root
```

## 故障排除

### 常见问题排查

1. 证书问题：
```shell
# 检查证书有效期
openssl x509 -in /etc/etcd/ssl/etcd-server.pem -text -noout | grep -A2 Validity

# 检查证书权限
ls -l /etc/etcd/ssl/
```

2. 网络问题：
```shell
# 检查端口监听
netstat -ntlp | grep etcd

# 检查端口连通性
for port in 2379 2380; do
    for host in 192.168.171.136 192.168.171.137 192.168.171.138; do
        echo "Testing $host:$port..."
        nc -zv $host $port
    done
done
```

3. 日志排查：
```shell
# 查看实时日志
journalctl -u etcd -f

# 查看错误日志
journalctl -u etcd -p err
```

## 性能优化

1. 系统参数优化：
```shell
# 调整系统限制
cat >> /etc/security/limits.conf << EOF
* soft nofile 65536
* hard nofile 65536
EOF

# 调整内核参数
cat >> /etc/sysctl.conf << EOF
net.ipv4.ip_local_port_range = 1024 65000
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 16384
net.ipv4.tcp_max_syn_backlog = 8096
net.ipv4.tcp_tw_reuse = 1
EOF

sysctl -p
```

2. ETCD 参数优化：
- 适当调整 `--snapshot-count`
- 根据实际情况调整 `--quota-backend-bytes`
- 配置合适的 `--auto-compaction-retention`

## 注意事项

1. 安全建议：
   - 定期更新证书
   - 限制访问权限
   - 配置防火墙规则

2. 维护建议：
   - 定期备份数据
   - 监控集群状态
   - 及时清理历史数据

3. 性能建议：
   - 使用 SSD 存储
   - 独立的磁盘空间
   - 足够的内存配置

4. 高可用建议：
   - 节点跨机架部署
   - 配置监控告警
   - 定期进行故障演练

---
# Harbor 私有镜像仓库部署

## 环境准备

### DNS 配置

```shell
# 配置本地解析
cat >> /etc/hosts << EOF
192.168.171.50 harbor.k8s.com
EOF

# 修改主机名
hostnamectl set-hostname harbor.k8s.com
```

### 存储配置

```shell
# 安装 LVM 工具
apt-get update
apt-get install -y lvm2

# 创建物理卷
pvcreate /dev/sdb1

# 创建卷组
vgcreate data_vg /dev/sdb1

# 创建逻辑卷
lvcreate -l +100%FREE -n data_lv data_vg

# 格式化逻辑卷
mkfs.ext4 /dev/data_vg/data_lv

# 清理旧配置
#sed -i '/\/data/d' /etc/fstab

# 配置挂载
echo "/dev/data_vg/data_lv /data ext4 defaults 0 0" >> /etc/fstab
mkdir -p /data
mount -a

# 验证挂载
df -h /data
```

## Docker 环境配置

### 安装 Docker

```shell
# 安装依赖包
apt-get update
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# 添加 Docker 官方 GPG 密钥
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# 添加 Docker 软件源
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# 安装 Docker
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
```

### 配置 Docker

```shell
# 创建 Docker 配置目录
mkdir -p /etc/docker

# 配置 Docker daemon
cat > /etc/docker/daemon.json << 'EOF'
{
  "registry-mirrors": ["https://ustc-edu-cn.mirror.aliyuncs.com"],
  "debug": false,
  "ip-forward": true,
  "ipv6": false,
  "live-restore": true,
  "log-driver": "json-file",
  "log-level": "warn",
  "log-opts": {
    "max-size": "100m",
    "max-file": "2"
  },
  "selinux-enabled": false,
  "experimental": true,
  "storage-driver": "overlay2",
  "metrics-addr": "0.0.0.0:9323",
  "data-root": "/data/docker",
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    }
  },
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

# 重启 Docker 服务
systemctl daemon-reload
systemctl restart docker
systemctl enable docker
```

### 安装 Docker Compose

```shell
# 下载 Docker Compose
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# 添加执行权限
chmod +x /usr/local/bin/docker-compose

# 验证安装
docker-compose version
```

## Harbor 部署

### 下载 Harbor

```shell
# 设置 Harbor 版本
export HARBOR_VERSION="v2.9.1"

# 下载 Harbor 安装包
wget https://github.com/goharbor/harbor/releases/download/${HARBOR_VERSION}/harbor-offline-installer-${HARBOR_VERSION}.tgz

# 解压安装包
tar xzvf harbor-offline-installer-${HARBOR_VERSION}.tgz -C /data
```

### 配置 Harbor

```shell
# 创建配置文件
cp /data/harbor/harbor.yml.tmpl /data/harbor/harbor.yml

# 修改配置文件
cat > /data/harbor/harbor.yml << EOF
hostname: harbor.k8s.com
https:
  certificate: /data/harbor/ssl/harbor.k8s.com.crt
  private_key: /data/harbor/ssl/harbor.k8s.com.key
harbor_admin_password: Harbor@123.com
data_volume: /data/harbor/harbor-data
log:
  location: /data/harbor/harbor-logs
  level: info
  local:
    rotate_count: 50
    rotate_size: 200M
database:
  password: root123
  max_idle_conns: 100
  max_open_conns: 900
storage_service:
  ca_bundle: /etc/ssl/certs/ca-certificates.crt
  redirect:
    disabled: false
  cache:
    enabled: true
    expire_hours: 24
trivy:
  enabled: true
  ignore_unfixed: false
  skip_update: false
  offline_scan: false
EOF
```

### 配置 TLS 证书

```shell
# 创建证书目录
mkdir -p /data/harbor/ssl
cd /data/harbor/ssl

# 生成 CA 私钥和证书
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -sha512 -days 3650 \
    -subj "/C=CN/ST=Beijing/L=Beijing/O=example/OU=Personal/CN=harbor.k8s.com" \
    -key ca.key \
    -out ca.crt

# 生成服务器私钥
openssl genrsa -out harbor.k8s.com.key 4096

# 生成证书签名请求
openssl req -sha512 -new \
    -subj "/C=CN/ST=Beijing/L=Beijing/O=example/OU=Personal/CN=harbor.k8s.com" \
    -key harbor.k8s.com.key \
    -out harbor.k8s.com.csr

# 配置证书扩展信息
cat > v3.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage=digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage=serverAuth
subjectAltName=@alt_names

[alt_names]
DNS.1=harbor.k8s.com
DNS.2=harbor
IP.1=192.168.171.50
EOF

# 生成服务器证书
openssl x509 -req -sha512 -days 3650 \
    -extfile v3.ext \
    -CA ca.crt -CAkey ca.key -CAcreateserial \
    -in harbor.k8s.com.csr \
    -out harbor.k8s.com.crt

# 生成客户端证书
openssl x509 -inform PEM -in harbor.k8s.com.crt -out harbor.k8s.com.cert

# 配置 Docker 证书
mkdir -p /etc/docker/certs.d/harbor.k8s.com/
cp ca.crt /etc/docker/certs.d/harbor.k8s.com/
cp harbor.k8s.com.cert /etc/docker/certs.d/harbor.k8s.com/
cp harbor.k8s.com.key /etc/docker/certs.d/harbor.k8s.com/
```

### 安装 Harbor

```shell
cd /data/harbor

# 安装 Harbor
./prepare --with-trivy
./install.sh --with-trivy

# 验证安装
docker ps

# 测试登录
docker login -u admin -p 'Harbor@123.com' harbor.k8s.com
```

## 客户端配置

### 配置 Docker 客户端

```shell
# 复制证书到客户端
mkdir -p /etc/docker/certs.d/harbor.k8s.com/
scp harbor-server:/etc/docker/certs.d/harbor.k8s.com/* /etc/docker/certs.d/harbor.k8s.com/

# 重启 Docker 服务
systemctl restart docker

# 测试登录
docker login harbor.k8s.com
```

## 维护管理

### 备份配置

```shell
# 创建备份脚本
cat > /data/harbor/backup.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="/data/harbor/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# 创建备份目录
mkdir -p ${BACKUP_DIR}/${DATE}

# 停止服务
cd /data/harbor
docker-compose down

# 备份数据
tar czf ${BACKUP_DIR}/${DATE}/harbor_data.tar.gz /data/harbor/harbor-data
tar czf ${BACKUP_DIR}/${DATE}/harbor_config.tar.gz /data/harbor/harbor.yml /data/harbor/ssl

# 启动服务
docker-compose up -d

# 清理旧备份
find ${BACKUP_DIR} -type d -mtime +7 -exec rm -rf {} \;

# 记录备份日志
echo "Backup completed at $(date '+%Y-%m-%d %H:%M:%S')" >> /data/harbor/harbor-logs/backup.log
EOF

# 添加执行权限
chmod +x /data/harbor/backup.sh

# 创建日志目录
mkdir -p /data/harbor/harbor-logs

# 添加到 root 用户的定时任务
(crontab -l 2>/dev/null; echo "0 2 * * * /data/harbor/backup.sh > /dev/null 2>&1") | crontab -

# 验证定时任务
crontab -l
```

### 监控配置

```shell
# 创建监控脚本
cat > /data/harbor/monitor.sh << 'EOF'
#!/bin/bash

# 检查 Harbor 服务状态
check_harbor() {
    local containers=$(docker ps --format '{{.Names}}' | grep '^harbor-')
    if [ $(echo "$containers" | wc -l) -lt 7 ]; then
        echo "Warning: Some Harbor containers are not running"
        return 1
    fi
    return 0
}

# 检查存储空间
check_storage() {
    local usage=$(df -h /data | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ $usage -gt 80 ]; then
        echo "Warning: Storage usage is above 80%"
        return 1
    fi
    return 0
}

# 主检查逻辑
main() {
    check_harbor || echo "Harbor service check failed"
    check_storage || echo "Storage check failed"
}

main
EOF

chmod +x /data/harbor/monitor.sh

# 添加到 crontab
echo "*/5 * * * * /data/harbor/monitor.sh >> /data/harbor/harbor-logs/monitor.log 2>&1" >> /var/spool/cron/crontabs/root
```

## 故障排除

### 常见问题

1. 证书问题：
```shell
# 检查证书有效期
openssl x509 -in /data/harbor/ssl/harbor.k8s.com.crt -text -noout | grep -A2 Validity

# 检查证书配置
ls -l /etc/docker/certs.d/harbor.k8s.com/
```

2. 存储问题：
```shell
# 检查存储空间
df -h /data

# 检查 Docker 存储
docker system df
```

3. 服务问题：
```shell
# 检查服务状态
cd /data/harbor
docker-compose ps

# 查看服务日志
docker-compose logs
```

## 性能优化

1. 系统优化：
```shell
# 调整系统限制
cat >> /etc/security/limits.conf << EOF
* soft nofile 65535
* hard nofile 65535
EOF

# 调整内核参数
cat >> /etc/sysctl.conf << EOF
net.ipv4.ip_local_port_range = 1024 65000
net.core.somaxconn = 32768
fs.file-max = 1000000
EOF

sysctl -p
```

2. Docker 优化：
- 配置合适的日志轮转策略
- 使用高性能存储
- 定期清理未使用的镜像和容器

## 注意事项

1. 安全建议：
   - 及时更新系统和组件
   - 定期轮换密码和证书
   - 限制访问权限
   - 配置防火墙规则

2. 维护建议：
   - 定期备份数据
   - 监控系统资源
   - 及时清理垃圾数据
   - 保持日志分析

3. 高可用建议：
   - 配置负载均衡
   - 实现数据备份
   - 监控告警配置
   - 故障恢复演练

---
# Kubernetes 集群环境部署

## 环境准备

### 主机配置

```shell
# 配置主机名
# Master 节点
hostnamectl set-hostname master1.k8s.com
hostnamectl set-hostname master2.k8s.com
hostnamectl set-hostname master3.k8s.com

# Worker 节点
hostnamectl set-hostname worker1.k8s.com

# 配置 DNS 解析
cat >> /etc/hosts << EOF
192.168.171.136 etcd1
192.168.171.50  harbor harbor.k8s.com
192.168.171.136 master1 master1.k8s.com
192.168.171.137 master2 master2.k8s.com
192.168.171.138 master3 master3.k8s.com
192.168.171.139 worker1 worker1.k8s.com
EOF

# 配置免密登录
ssh-keygen -t rsa -b 2048 -N "" -f ~/.ssh/id_rsa

# 分发公钥
for host in harbor etcd1 master{1..3} worker1; do
    sshpass -p 'your_password' ssh-copy-id -o StrictHostKeyChecking=no root@${host}
done

# 分发hosts文件
for host in master{2..3} worker1; do
    scp /etc/hosts ${host}:/etc/
done
```

### 系统配置

```shell
# 在所有节点上执行
# 关闭 swap
swapoff -a
sed -i '/swap/d' /etc/fstab

# 加载内核模块
cat > /etc/modules-load.d/k8s.conf << EOF
overlay
br_netfilter
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack
EOF

# 加载模块
modprobe overlay
modprobe br_netfilter
modprobe ip_vs
modprobe ip_vs_rr
modprobe ip_vs_wrr
modprobe ip_vs_sh
modprobe nf_conntrack

# 更新内核设置
cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
vm.swappiness                       = 0
fs.file-max                         = 1000000
net.ipv4.ip_local_port_range       = 1024 65000
net.ipv4.tcp_tw_reuse              = 1
net.ipv4.tcp_fin_timeout           = 30
net.core.somaxconn                 = 32768
EOF

sysctl --system
```

## 组件安装

### 容器运行时

```shell
# 安装 containerd
export CONTAINERD_VERSION="1.7.6"
wget https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz
tar Cxzvf /usr/local containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz

# 配置 containerd 服务
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -O /usr/local/lib/systemd/system/containerd.service

# 生成默认配置
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

# 修改配置
sed -i 's|/var/lib/containerd|/data/containerd|g' /etc/containerd/config.toml
sed -i 's|k8s.gcr.io/pause:3.6|registry.aliyuncs.com/google_containers/pause:3.9|g' /etc/containerd/config.toml

# 添加镜像仓库配置
cat >> /etc/containerd/config.toml << EOF
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
        endpoint = ["https://docker.mirrors.ustc.edu.cn","http://hub-mirror.c.163.com"]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors."gcr.io"]
        endpoint = ["https://gcr.mirrors.ustc.edu.cn"]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors."k8s.gcr.io"]
        endpoint = ["https://gcr.mirrors.ustc.edu.cn/google-containers/"]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors."quay.io"]
        endpoint = ["https://quay.mirrors.ustc.edu.cn"]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors."harbor.k8s.com"]
        endpoint = ["https://harbor.k8s.com"]
EOF

# 启动服务
systemctl daemon-reload
systemctl enable --now containerd
```

### 安装 CNI 插件

```shell
# 下载并安装 CNI 插件
CNI_VERSION="v1.2.0"
wget https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-amd64-${CNI_VERSION}.tgz
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-${CNI_VERSION}.tgz
```

### 安装 nerdctl

```shell
# 下载并安装 nerdctl
NERDCTL_VERSION="1.6.2"
wget https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-full-${NERDCTL_VERSION}-linux-amd64.tar.gz
tar Cxzvf /usr/local nerdctl-full-${NERDCTL_VERSION}-linux-amd64.tar.gz

# 配置别名
cat >> /etc/profile << EOF
alias docker='nerdctl --namespace k8s.io'
alias docker-compose='nerdctl compose'
alias crictl='crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock'
EOF

source /etc/profile

# 配置 nerdctl
mkdir -p /etc/nerdctl
cat > /etc/nerdctl/nerdctl.toml << EOF
namespace = "k8s.io"
insecure_registry = true
cni_path = "/opt/cni/bin/"
EOF
```

### 安装 Kubernetes 组件

```shell
# 添加 Kubernetes 软件源
curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
cat > /etc/apt/sources.list.d/kubernetes.list << EOF
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF

# 安装指定版本
export KUBE_VERSION="1.27.8"
apt update
apt install -y kubelet=${KUBE_VERSION}-00 kubeadm=${KUBE_VERSION}-00 kubectl=${KUBE_VERSION}-00

# 锁定版本
apt-mark hold kubelet kubeadm kubectl

# 启用自动补全
apt install -y bash-completion
echo 'source <(kubectl completion bash)' >> ~/.bashrc
source ~/.bashrc

# 预拉取镜像
kubeadm config images pull --kubernetes-version=v${KUBE_VERSION} \
    --image-repository='registry.aliyuncs.com/google_containers'
```

## 证书配置

```shell
# 创建证书目录
mkdir -p /etc/kubernetes/pki/etcd

# 复制 ETCD 证书
scp etcd1:/etc/etcd/ssl/etcd-ca.pem /etc/kubernetes/pki/etcd/
scp etcd1:/etc/etcd/ssl/client.pem /etc/kubernetes/pki/apiserver-etcd-client.pem
scp etcd1:/etc/etcd/ssl/client-key.pem /etc/kubernetes/pki/apiserver-etcd-client-key.pem

# 复制 Harbor 证书
mkdir -p /etc/tls/harbor/
scp -r harbor:/etc/docker/certs.d/harbor.k8s.com /etc/tls/harbor/

# 更新系统证书
cp /etc/tls/harbor/harbor.k8s.com/ca.crt /usr/local/share/ca-certificates/
cp /etc/tls/harbor/harbor.k8s.com/harbor.k8s.com.cert /usr/local/share/ca-certificates/
update-ca-certificates
```

## 系统优化

### 性能调优

```shell
# 调整系统限制
cat >> /etc/security/limits.conf << EOF
* soft nofile 65536
* hard nofile 65536
* soft nproc 65536
* hard nproc 65536
EOF

# 调整内核参数
cat >> /etc/sysctl.conf << EOF
net.ipv4.tcp_max_syn_backlog = 8192
net.core.somaxconn = 32768
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_fin_timeout = 30
EOF

sysctl -p
```

### 安全加固

```shell
# 禁用不必要的服务
systemctl stop apparmor
systemctl disable apparmor

# 配置防火墙规则
ufw allow 6443/tcp  # Kubernetes API
ufw allow 2379/tcp  # etcd client API
ufw allow 2380/tcp  # etcd peer API
ufw allow 10250/tcp # Kubelet API
ufw allow 10251/tcp # kube-scheduler
ufw allow 10252/tcp # kube-controller-manager
```

## 验证部署

```shell
# 验证模块加载
lsmod | grep -e br_netfilter -e overlay -e ip_vs

# 验证端口
netstat -ntlp | grep -e containerd -e kubelet

# 验证镜像
crictl images

# 验证 Kubernetes 组件
systemctl status kubelet
kubectl version --client
kubeadm version
```

## 注意事项

1. 网络要求：
   - 节点间网络互通
   - 可访问外网（用于下载组件）
   - 防火墙开放必要端口

2. 安全建议：
   - 及时更新系统和组件
   - 使用最新的稳定版本
   - 配置适当的安全策略

3. 维护建议：
   - 定期检查系统资源
   - 监控关键组件状态
   - 保持日志分析和审计

---

# Kubernetes 集群部署

## 初始化配置

### 创建集群配置文件

```shell
# 在 master1 节点上执行
# 生成默认配置
kubeadm config print init-defaults > kubeadm-init.yaml

# 修改配置文件
cat > kubeadm-init.yaml << EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 192.168.171.136
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  taints:
    - effect: NoSchedule
      key: node-role.kubernetes.io/control-plane
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager: {}
dns:
  type: CoreDNS
etcd:
  external:
    endpoints:
      - https://192.168.171.136:2379
      - https://192.168.171.137:2379
      - https://192.168.171.138:2379
    caFile: /etc/kubernetes/pki/etcd/etcd-ca.pem
    certFile: /etc/kubernetes/pki/apiserver-etcd-client.pem
    keyFile: /etc/kubernetes/pki/apiserver-etcd-client-key.pem
kubernetesVersion: 1.27.8
imageRepository: registry.aliyuncs.com/google_containers
networking:
  serviceSubnet: 10.96.0.0/12
  podSubnet: 10.244.0.0/16
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
EOF
```

## 集群初始化

### 初始化主节点

```shell
# 在 master1 节点上执行
# 初始化集群
kubeadm init --config=kubeadm-init.yaml --upload-certs

# 配置 kubectl
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# 配置环境变量
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> /etc/profile
source /etc/profile
```

### 添加节点

```shell
# 在其他 master 节点上执行
# 加入控制平面节点
kubeadm join 192.168.171.136:6443 --token <token> \
    --discovery-token-ca-cert-hash sha256:<hash> \
    --control-plane --certificate-key <key> \
    --cri-socket=unix:///var/run/containerd/containerd.sock

# 在 worker 节点上执行
# 加入工作节点
kubeadm join 192.168.171.136:6443 --token <token> \
    --discovery-token-ca-cert-hash sha256:<hash> \
    --cri-socket=unix:///var/run/containerd/containerd.sock

# 配置环境变量
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> /etc/profile
source /etc/profile
```

### 节点标签管理

```shell
# 添加 worker 标签
kubectl label nodes worker1.k8s.com node-role.kubernetes.io/worker=

# 添加污点
kubectl taint nodes master1.k8s.com node-role.kubernetes.io/control-plane=:NoSchedule
kubectl taint nodes master2.k8s.com node-role.kubernetes.io/control-plane=:NoSchedule
kubectl taint nodes master3.k8s.com node-role.kubernetes.io/control-plane=:NoSchedule
```

## 网络配置

### 安装 Calico

```shell
# 添加 Helm 仓库
helm repo add projectcalico https://docs.tigera.io/calico/charts
helm repo update

# 创建配置文件
cat > calico-values.yaml << EOF
installation:
  cni:
    type: Calico
  ipPools:
  - cidr: 10.244.0.0/16
    encapsulation: IPIP
    natOutgoing: true
    nodeSelector: all()
  registry: docker.io
EOF

# 安装 Calico
helm install calico projectcalico/tigera-operator -f calico-values.yaml
```

### CoreDNS 配置

```shell
# 配置 CoreDNS
kubectl -n kube-system get cm coredns -o yaml > coredns-cm.yaml

# 修改配置
cat > coredns-cm.yaml << EOF
apiVersion: v1
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        hosts {
          192.168.171.50 harbor.k8s.com
          fallthrough
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
EOF

# 应用配置
kubectl apply -f coredns-cm.yaml

# 重启 CoreDNS
kubectl -n kube-system delete pod -l k8s-app=kube-dns
```

## 组件配置

### 暴露组件端口

```shell
# 在所有 master 节点上执行
# 修改 kube-scheduler 配置
sed -i 's/- --bind-address=127.0.0.1/- --bind-address=0.0.0.0/' /etc/kubernetes/manifests/kube-scheduler.yaml

# 修改 kube-controller-manager 配置
sed -i 's/- --bind-address=127.0.0.1/- --bind-address=0.0.0.0/' /etc/kubernetes/manifests/kube-controller-manager.yaml
```

## 集群验证

```shell
# 验证集群状态
kubectl get nodes
kubectl get pods -A
kubectl cluster-info
kubectl get componentstatuses

# 验证网络
kubectl run test-nginx --image=nginx
kubectl expose pod test-nginx --port=80 --type=NodePort
curl http://<node-ip>:<node-port>
```

## 维护操作

### 证书更新

```shell
# 查看证书过期时间
kubeadm certs check-expiration

# 更新证书
kubeadm certs renew all
```

### 集群升级

```shell
# 升级 kubeadm
apt-mark unhold kubeadm
apt-get update
apt-get install -y kubeadm=<version>
apt-mark hold kubeadm

# 升级控制平面
kubeadm upgrade plan
kubeadm upgrade apply v<version>

# 升级 kubelet 和 kubectl
apt-mark unhold kubelet kubectl
apt-get install -y kubelet=<version> kubectl=<version>
apt-mark hold kubelet kubectl
systemctl restart kubelet
```

## 故障处理

### 重置节点

```shell
# 清理节点
kubeadm reset
iptables -F && iptables -X
iptables -t nat -F && iptables -t nat -X
iptables -t mangle -F && iptables -t mangle -X
ipvsadm --clear
rm -rf /etc/kubernetes/ /var/lib/kubelet/ /var/lib/etcd/
```

### 常见问题排查

```shell
# 查看组件日志
journalctl -xeu kubelet
kubectl logs -n kube-system <pod-name>

# 检查网络
kubectl exec -it <pod-name> -- ping <service-name>
kubectl get endpoints <service-name>
```

## 注意事项

1. 高可用配置：
   - 至少部署三个 master 节点
   - 使用负载均衡器
   - 配置外部 etcd 集群

2. 安全建议：
   - 及时更新组件版本
   - 配置网络策略
   - 使用 RBAC 控制访问
   - 定期备份 etcd 数据

3. 性能优化：
   - 合理配置资源限制
   - 优化网络配置
   - 监控系统性能

4. 运维建议：
   - 实施监控告警
   - 定期进行备份
   - 制定故障恢复预案
   - 保持文档更新

---

# NFS StorageClass 部署

## 存储服务器配置

### 安装 NFS 服务

```shell
# 安装 NFS 服务器
apt-get update
apt-get install -y nfs-kernel-server

# 创建共享目录
mkdir -p /data/ifs/kubernetes
chown -R nobody:nogroup /data/ifs/kubernetes

# 配置共享权限
cat >> /etc/exports << EOF
/data/ifs/kubernetes 192.168.171.0/24(no_root_squash,rw,sync,no_subtree_check)
EOF

# 启动服务
systemctl enable --now nfs-kernel-server

# 验证配置
exportfs -av
```

### 配置防火墙

```shell
# 允许 NFS 相关端口
ufw allow 2049/tcp  # NFS
ufw allow 111/tcp   # portmapper
ufw allow 111/udp
ufw allow 32765:32768/tcp  # NFS 动态端口
ufw allow 32765:32768/udp
```

## 客户端配置

### 安装 NFS 客户端

```shell
# 在所有 Kubernetes 节点上执行
apt-get update
apt-get install -y nfs-common

# 配置 NFS 服务器解析
echo "192.168.171.140 nfs.k8s.com" >> /etc/hosts

# 验证 NFS 挂载
showmount -e nfs.k8s.com
```

## StorageClass 部署

### 安装 NFS Provisioner

```shell
# 创建命名空间
kubectl create namespace nfs-provisioner

# 创建 ServiceAccount
cat > rbac.yaml << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nfs-client-provisioner
  namespace: nfs-provisioner
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-client-provisioner-runner
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]
EOF

kubectl apply -f rbac.yaml

# 创建 Deployment
cat > deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-client-provisioner
  namespace: nfs-provisioner
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: nfs-client-provisioner
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          image: registry.aliyuncs.com/google_containers/sig-storage/nfs-subdir-external-provisioner:v4.0.2
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: k8s-sigs.io/nfs-subdir-external-provisioner
            - name: NFS_SERVER
              value: nfs.k8s.com
            - name: NFS_PATH
              value: /data/ifs/kubernetes
      volumes:
        - name: nfs-client-root
          nfs:
            server: nfs.k8s.com
            path: /data/ifs/kubernetes
EOF

kubectl apply -f deployment.yaml

# 创建 StorageClass
cat > storageclass.yaml << EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-client
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: k8s-sigs.io/nfs-subdir-external-provisioner
parameters:
  archiveOnDelete: "false"
EOF

kubectl apply -f storageclass.yaml
```

### 验证部署

```shell
# 创建测试 PVC
cat > test-claim.yaml << EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-claim
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Mi
EOF

kubectl apply -f test-claim.yaml

# 创建测试 Pod
cat > test-pod.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
    - name: test-pod
      image: busybox
      command:
        - "/bin/sh"
      args:
        - "-c"
        - "touch /mnt/SUCCESS && exit 0 || exit 1"
      volumeMounts:
        - name: nfs-pvc
          mountPath: "/mnt"
  restartPolicy: "Never"
  volumes:
    - name: nfs-pvc
      persistentVolumeClaim:
        claimName: test-claim
EOF

kubectl apply -f test-pod.yaml
```

## 监控配置

```shell
# 创建监控脚本
cat > /usr/local/bin/monitor-nfs.sh << 'EOF'
#!/bin/bash

# 检查 NFS 服务状态
check_nfs_service() {
    if ! systemctl is-active --quiet nfs-kernel-server; then
        echo "NFS service is not running"
        return 1
    fi
    return 0
}

# 检查存储空间
check_storage() {
    local usage=$(df -h /data/ifs/kubernetes | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ $usage -gt 80 ]; then
        echo "Storage usage is above 80%"
        return 1
    fi
    return 0
}

# 检查 NFS 挂载点
check_mounts() {
    if ! mountpoint -q /data/ifs/kubernetes; then
        echo "NFS directory is not mounted"
        return 1
    fi
    return 0
}

# 主检查逻辑
main() {
    check_nfs_service || echo "NFS service check failed"
    check_storage || echo "Storage check failed"
    check_mounts || echo "Mount check failed"
}

main
EOF

chmod +x /usr/local/bin/monitor-nfs.sh

# 添加到 crontab
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/monitor-nfs.sh >> /var/log/nfs-monitor.log 2>&1") | crontab -
```

## 注意事项

1. 性能优化：
   - 使用 SSD 存储
   - 调整 NFS 缓存参数
   - 配置合适的网络带宽

2. 安全建议：
   - 限制 NFS 访问IP
   - 配置防火墙规则
   - 定期更新系统

3. 维护建议：
   - 定期备份数据
   - 监控存储使用量
   - 及时清理无用数据

4. 高可用建议：
   - 配置 NFS 服务器集群
   - 使用网络存储备份
   - 配置自动故障转移
