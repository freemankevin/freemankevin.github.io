---
title: 如何给 Ubuntu 系统配置静态 IP 地址
date: 2024-12-27 10:21:25
tags:
    - Linux
    - Ubuntu
    - Netplan
category: Ubuntu
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;本文将详细介绍如何在 Ubuntu 系统中通过 `Netplan` 配置静态 IP 地址。`Netplan` 是当前 Ubuntu 默认的网络管理工具，支持简便的 YAML 配置文件格式。在这篇文章中，你将学习如何查找网卡名称、编辑 `Netplan` 配置文件、设置静态 IP、应用配置并进行验证。通过本教程，你可以确保服务器或工作站的网络配置稳定可靠。

<!-- more -->

> 这里以`Ubuntu 22.04 LTS` 环境举例。

### 查找网络接口名称

运行以下命令查看网卡名称：

```shell
ip a
```

通常，网卡名称类似于 `eth0`、`enp0s3` 或 `ens33`。



### 编辑 Netplan 配置文件

`Netplan` 的配置文件通常位于 `/etc/netplan/` 目录下，并以 `.yaml` 结尾。

列出配置文件：

```shell
cd /etc/netplan/

ls -lash *.yaml
```

假设文件名为 `50-cloud.yaml`，用文本编辑器打开它：

```shell
sudo vim /etc/netplan/50-cloud.yaml # 没有vim，可以使用nano
```

------

### 配置静态 IP

将文件内容修改为类似以下配置：

```yaml
network:
  version: 2
  ethernets:
    enp0s3:  # 替换为你的网络接口名称
      addresses:
        - 192.168.1.100/24  # 设置静态IP地址和子网掩码
      gateway4: 192.168.1.1  # 设置网关
      nameservers:
        addresses:
          - 8.8.8.8           # 设置首选DNS
          - 8.8.4.4           # 设置备用DNS
      dhcp4: false            # 禁用 DHCP
```

> **注意**： 
> - `192.168.1.100` 是静态 IP 地址，请替换为适合你网络的 IP。
> - `192.168.1.1` 是网关地址，请根据你的网络实际情况修改。

------

### 应用配置

保存文件后，应用 `Netplan` 配置：

```shell
sudo netplan apply 
```
如果没有报错，静态 IP 应该已经生效。

这里最好重启下机器以确保完全生效。
```shell
sudo sync;reboot
```

------

### 验证网络配置

使用以下命令检查网络配置是否正确：

```shell
ip a
```

查看是否分配了静态 IP。

测试网络连通性：

```shell
ping 8.8.8.8
# ping www.google.com 
ping baidu.com
```

------

### 常见问题排查

执行下面命令

  ```shell
  sudo netplan apply
  ```

- 如果遇到错误：
  - 检查 `.yaml` 文件是否缩进正确（使用空格，不要用 Tab）。
  - 确保接口名称正确无误。

- 如果网络不可用：
  - 检查网关和 DNS 是否正确。
  - 确认 IP 地址没有与网络中的其他设备冲突。

------
如果你的服务器使用的是 WiFi 而非有线连接，请参考 WiFi 的配置方法。