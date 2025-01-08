---
title: 如何给Linux 服务器做系统初始化
date: 2025-01-06 15:57:25
tags:
    - Linux
    - Debian
    - CentOS
category: Linux
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;本文将指导您如何为Linux服务器进行系统初始化，涵盖了常见的操作系统（Debian和CentOS）配置。无论是设置静态IP、配置NTP时间同步，还是优化系统内核，本教程将一步步帮助您做好基础设置，确保系统运行稳定且高效。适合开发人员与运维工程师参考。

<!-- more -->


### 配置 NTP（必须）

NTP（网络时间协议）是保持系统时间同步的常用工具。以下配置将帮助确保系统时间的准确性。

#### 安装 NTP 服务

在 Red Hat 系统（如 CentOS、RHEL）和 Debian 系统（如 Ubuntu）上，您可以使用如下命令安装 `chrony` 或 `ntpd` 来配置 NTP：

**Red Hat 系统（如 CentOS/RHEL）:**

```bash
yum install chrony -y
systemctl enable chronyd
systemctl start chronyd
```

**Debian 系统（如 Ubuntu）:**

```bash
apt update
apt install chrony -y
systemctl enable chrony
systemctl start chrony
```

#### 配置 NTP 服务器

修改 `/etc/chrony/chrony.conf` 文件，配置自己的 NTP 服务器。

```bash
# 编辑配置文件
vim /etc/chrony/chrony.conf

# 添加或修改为本地 NTP 服务器
pool ntp.aliyun.com iburst
```

#### 时间同步检查

确保服务正常运行并同步时间：

```bash
# 检查 NTP 同步状态
chronyc tracking

# 检查 NTP 源
chronyc sources
```

---

### 配置静态 IP 地址（可选项）

对于静态 IP 的配置，通常需要编辑网络配置文件。配置文件位置和内容在不同的 Linux 发行版中有所不同。

**Red Hat 系统（如 CentOS/RHEL）:**

```bash
vim /etc/sysconfig/network-scripts/ifcfg-ens32
```

在该文件中，配置静态 IP：

```shell
TYPE="Ethernet"
BOOTPROTO="none"
DEFROUTE="yes"
IPV4_FAILURE_FATAL="no"
IPV6INIT="no"
NAME="ens32"
UUID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
DEVICE="ens32"
ONBOOT="yes"
IPADDR="192.168.1.100"
NETMASK="255.255.255.0"
GATEWAY="192.168.1.1"
DNS1="8.8.8.8"
DNS2="8.8.4.4"
```

**Debian 系统（如 Ubuntu）:**

编辑 `/etc/network/interfaces` 或 `/etc/netplan/` 配置（具体取决于使用的网络管理工具）。

```bash
vim /etc/network/interfaces
```

然后添加以下内容（根据你的实际需求调整）：

```shell
auto ens32
iface ens32 inet static
    address 192.168.1.100
    netmask 255.255.255.0
    gateway 192.168.1.1
    dns-nameservers 8.8.8.8 8.8.4.4
```

如果使用的是 `netplan`，则在 `/etc/netplan/` 文件夹内进行配置。

#### 重启网络服务

完成配置后，重启网络服务使配置生效。

**Red Hat 系统（如 CentOS/RHEL）:**

```bash
systemctl restart NetworkManager
```

**Debian 系统（如 Ubuntu）:**

```bash
systemctl restart networking
```

---

### 升级内核（可选项）

建议将系统内核升级到至少 4.15.x 版本，以确保系统的稳定性和兼容性。

**Red Hat 系统（如 CentOS/RHEL）:**

```bash
yum install -y kernel
```

**Debian 系统（如 Ubuntu）:**

```bash
apt install linux-image-$(uname -r) -y
```

重启后确认内核版本：

```bash
uname -r
```

---

### 关闭防火墙和 SELinux（必须）

根据项目的需要，初期部署时通常会关闭防火墙和 SELinux。在完成部署后，可以根据需求重新启用。

**Red Hat 系统（如 CentOS/RHEL）:**

```bash
# 关闭防火墙
systemctl stop firewalld
systemctl disable firewalld

# 关闭 SELinux
setenforce 0
sed -i 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
```

**Debian 系统（如 Ubuntu）:**

```bash
# 关闭防火墙
systemctl stop ufw
systemctl disable ufw

# Debian 默认不启用 SELinux, 使用 AppArmor
systemctl stop apparmor
systemctl disable apparmor
```

---

### 关闭不需要的服务（必须）

关闭不必要的服务，如 SMTP 服务（Postfix）和 RPC 服务。

**Red Hat 系统（如 CentOS/RHEL）:**

```bash
systemctl stop postfix
systemctl disable postfix
systemctl stop rpcbind
systemctl disable rpcbind
```

**Debian 系统（如 Ubuntu）:**

```bash
systemctl stop postfix
systemctl disable postfix
systemctl stop rpcbind
systemctl disable rpcbind
```

---

### 更新系统配置（必须）

以下是通用的系统参数配置，适用于大多数 Linux 发行版。使用以下命令将配置添加到 `/etc/sysctl.conf`，然后应用配置。

```bash
# 清空原有配置
echo -e '' > /etc/sysctl.conf

# 使用优化后的配置
tee -a /etc/sysctl.conf << EOF
# 文件描述符限制
fs.file-max = 1048576

# 异步IO限制
fs.aio-max-nr = 1048576

# 内存管理
vm.drop_caches = 3
vm.max_map_count = 262144 # 524288
kernel.shmall = 4294967296
kernel.shmmax = 4294967295
kernel.shmmni = 4096

# 内核调试信息和日志
kernel.sysrq = 0
kernel.dmesg_restrict = 1

# 信号量设置
kernel.sem = 250 32000 100 128

# 网络配置
net.ipv4.ip_forward = 1
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.ip_local_port_range = 1024 65535
net.core.rmem_default = 16777216
net.core.rmem_max = 16777216
net.core.wmem_default = 16777216
net.core.wmem_max = 16777216

# 优化 TCP 连接管理
net.ipv4.tcp_fin_timeout = 30  # 减少 TIME_WAIT 状态的持续时间
net.ipv4.tcp_tw_reuse = 1  # 启用 TCP 连接复用
net.ipv4.tcp_tw_recycle = 1  # 启用 TCP TIME_WAIT 连接快速回收
EOF

# 刷新配置
sysctl -p
```

---

### 数据盘挂载与格式化（可选项）

对于新添加的磁盘或数据盘，您需要对其进行格式化并挂载。

```bash
# 查看当前磁盘
lsblk

# 格式化磁盘
mkfs.ext4 /dev/vdb

# 创建挂载点
mkdir /data

# 挂载磁盘
mount /dev/vdb /data

# 配置开机自动挂载
echo '/dev/vdb /data ext4 defaults 0 0' >> /etc/fstab
```

---

### 修改 vim 格式化（可选项）

根据需求修改 `vim` 的别名和配置，优化使用体验。

```bash
# 不显示隐藏文件等符号
sudo sed -ri "s/alias ll='ls -alF'/alias ll='ls -l'/" ~/.bashrc
sudo egrep "alias ll" ~/.bashrc
source ~/.bashrc
```

---

### 重启系统（必须）

完成所有操作后，建议重启系统，确保所有配置生效。

```bash
# 重启系统
sync; reboot

# 检查磁盘
lsblk
blkid 

# 检查防火墙状态
systemctl status firewalld

# 检查 NTP 时间同步
systemctl status chronyd
```