---
title: 如何在不同 Linux 系统下开启防火墙
date: 2024-12-13 11:34:15
tags: 
  - Firewall
  - Ufw
  - Iptables
# comments: true
category: Linux
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;防火墙是保护系统安全的重要组成部分，它可以帮助阻止未授权的访问。本文介绍了如何在不同的 Linux 系统中开启和管理防火墙，包括 Ubuntu/Debian、CentOS/RHEL、openSUSE 和 Arch Linux 系统。我们详细讲解了每个系统中常用的防火墙工具和命令，例如 ufw、firewalld、SuSEfirewall2、iptables 和 nftables。通过这些步骤，你可以在各种 Linux 发行版上有效地开启防火墙并配置规则，从而增强系统的安全性。

<!-- more -->

## 1. Ubuntu/Debian 系统

Ubuntu 和 Debian 系统默认使用 `ufw`（Uncomplicated Firewall）作为防火墙工具。

### 检查防火墙状态
```bash
sudo ufw status
```

### 开启防火墙
```bash
sudo ufw enable
```

### 禁用防火墙
```bash
sudo ufw disable
```

### 配置示例
允许 SSH 连接：
```bash
sudo ufw allow ssh
```

---

## 2. CentOS/RHEL 系统

CentOS 和 RHEL 系统默认使用 `firewalld` 作为防火墙工具。

### 检查防火墙状态
```bash
sudo systemctl status firewalld
```

### 开启防火墙
```bash
sudo systemctl start firewalld
sudo systemctl enable firewalld
```

### 禁用防火墙
```bash
sudo systemctl stop firewalld
sudo systemctl disable firewalld
```

### 配置示例
允许 HTTP 服务：
```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
```

---

## 3. openSUSE 系统

openSUSE 系统默认使用 `firewalld`，但某些版本可能使用 `SuSEfirewall2`。

### 使用 firewalld

#### 检查防火墙状态
```bash
sudo systemctl status firewalld
```

#### 开启防火墙
```bash
sudo systemctl start firewalld
sudo systemctl enable firewalld
```

#### 配置示例
允许 HTTPS 服务：
```bash
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

### 使用 SuSEfirewall2

#### 检查防火墙状态
```bash
sudo SuSEfirewall2 status
```

#### 开启防火墙
```bash
sudo SuSEfirewall2 start
```

---

## 4. Arch Linux

Arch Linux 通常使用 `iptables` 或 `nftables` 来管理防火墙。

### 使用 iptables

#### 检查防火墙规则
```bash
sudo iptables -L
```

#### 添加规则并保存
允许所有来自端口 22 的连接：
```bash
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables-save > /etc/iptables/iptables.rules
```

#### 开启防火墙
```bash
sudo systemctl start iptables
sudo systemctl enable iptables
```

### 使用 nftables

#### 检查防火墙状态
```bash
sudo nft list ruleset
```

#### 添加规则并保存
允许 HTTP 流量：
```bash
sudo nft add rule ip filter input tcp dport 80 accept
sudo nft list ruleset > /etc/nftables.conf
```

#### 启用 nftables 服务
```bash
sudo systemctl start nftables
sudo systemctl enable nftables
```

---

## 5. 常见问题排查

- **端口未生效**：
  确保规则已永久保存并重新加载防火墙配置。
  ```bash
  sudo ufw reload  # 适用于 ufw
  sudo firewall-cmd --reload  # 适用于 firewalld
  ```

- **服务未运行**：
  确保防火墙服务已启动并设置为开机自启。
  ```bash
  sudo systemctl enable firewalld
  sudo systemctl start firewalld
  ```

---

通过以上命令，你可以在不同的 Linux 系统中有效地开启防火墙并配置规则，从而增强系统的安全性。