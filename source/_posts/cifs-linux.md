---
title: 在 Linux 上部署 CIFS 服务端并挂载客户端
date: 2025-01-10 14:57:25
tags:
    - Mount
    - CIFS
    - Linux
category: Linux
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;CIFS 是一种网络文件系统协议，可以在 Linux 和 Windows 系统间共享文件。CIFS 既可以作为客户端使用，也可以作为服务端提供共享服务。本文将介绍如何在 Linux 系统上安装并配置 CIFS 服务端，如何在 Linux 上挂载 CIFS 共享，以及如何在 Windows 上访问 CIFS 共享。我们将同时支持 CentOS、Debian 和 Windows 环境。

<!-- more -->

## 安装和配置 CIFS 服务端

### 安装 Samba（CIFS 服务端）

CIFS 服务端依赖于 Samba 来提供文件共享功能。首先，我们需要在 Linux 系统上安装 Samba。

#### CentOS / RHEL

在 CentOS 或 RHEL 上安装 Samba：

```shell
sudo yum install -y samba samba-client samba-common
```

#### Debian / Ubuntu

在 Debian 或 Ubuntu 上安装 Samba：

```shell
sudo apt update
sudo apt install -y samba samba-common-bin
```

### 配置 Samba 共享

安装完成后，编辑 Samba 配置文件 `/etc/samba/smb.conf`，在文件末尾添加共享目录配置。假设我们要共享目录 `/srv/samba/share`，并使用用户名和密码进行访问。

编辑 `smb.conf` 配置文件：

```shell
sudo vi /etc/samba/smb.conf
```

在文件末尾添加以下配置：

```ini
[share]
   path = /data/samba/share
   browsable = yes
   writable = yes
   guest ok = no
   valid users = your_username
```

- `path`：指定共享目录路径
- `browsable`：允许浏览共享目录
- `writable`：允许写入
- `guest ok`：禁止匿名访问
- `valid users`：设置可以访问该共享的用户

### 创建共享目录并设置权限

确保共享目录存在，并设置适当的权限：

```shell
sudo mkdir -p /data/samba/share
sudo chown -R your_username:your_username /data/samba/share
```

### 配置 Samba 用户

添加一个 Samba 用户，该用户将用于访问共享目录：

```shell
sudo smbpasswd -a your_username
```

然后，启用 Samba 服务并使其开机自启：

```shell
sudo systemctl enable smb nmb
sudo systemctl start smb nmb
```

### 检查 Samba 服务

验证 Samba 服务是否正在运行：

```shell
sudo systemctl status smb nmb
```

确保服务已启动并正常运行。

### 使用 Smbclient 查看共享
你在使用 Smbclient 连接共享时，错误 NT_STATUS_BAD_NETWORK_NAME 显示无法找到共享。你可以尝试列出所有共享，看看是否能正确获取共享列表：

```shell
smbclient -L //192.168.1.100 -U your_username
```
如果能列出共享列表，确认共享名称是否正确。否则，需要检查 Samba 配置文件或重新启动 Samba 服务。

## 在 Linux 客户端挂载 CIFS 共享

### 安装 CIFS 工具

#### CentOS / RHEL

在 CentOS 或 RHEL 上，安装 `cifs-utils` 包：

```shell
sudo yum install -y cifs-utils
```

#### Debian / Ubuntu

在 Debian 或 Ubuntu 上，安装 `cifs-utils` 包：

```shell
sudo apt update
sudo apt install -y cifs-utils
```

### 创建挂载点

在本地创建一个挂载点目录：

```shell
sudo mkdir -p /data/cifs
```

### 手动挂载 CIFS 共享

使用 `mount` 命令挂载 CIFS 共享。假设服务器 IP 地址为 `192.168.1.100`，共享名称为 `share`，挂载点为 `/data/cifs`，用户名和密码为 `your_username` 和 `your_password`。

```shell
sudo mount -t cifs //192.168.1.100/share /data/cifs -o username=your_username,password=your_password
```

### 永久挂载 CIFS 共享

为了让 CIFS 共享在系统重启后自动挂载，我们需要将挂载配置添加到 `/etc/fstab` 文件中：

```shell
//192.168.1.100/share /data/cifs cifs credentials=/etc/samba/.smbcredentials,uid=1000,gid=1000 0 0
```

其中，`.smbcredentials` 文件保存了 CIFS 共享的用户名和密码。该文件的内容如下：

```shell
username=your_username
password=your_password
```

确保该文件的权限为 `600`：

```shell
chmod 600 /etc/samba/.smbcredentials
```

这样配置后，CIFS 共享将在每次启动时自动挂载。


## 在 Windows 客户端访问 CIFS 共享

### 通过文件资源管理器访问

在 Windows 系统上，可以通过文件资源管理器访问 CIFS 共享：

1. 打开 **文件资源管理器**。
2. 在地址栏中输入 `\\192.168.1.100\share`，然后按回车。
3. 输入 CIFS 共享的用户名和密码。

这样，Windows 就可以访问共享文件夹。


## 批量挂载 CIFS 共享的自动化脚本

如果你需要批量挂载多个 CIFS 共享，以下是一个 shell 脚本，它会自动挂载指定的多个 CIFS 共享并将挂载信息添加到 `/etc/fstab` 中。

```shell
#!/bin/bash

# 配置变量
USERNAME="your_username"                         # CIFS 用户名
PASSWORD="your_password"                         # CIFS 密码
SHARE_PATH="//192.168.1.100/share"               # CIFS 共享路径
MOUNT_POINT="/data/cifs"                         # 本地挂载点
CREDENTIALS_FILE="/etc/samba/.smbcredentials"    # 凭据文件路径
CIFS_PORT=445                                    # CIFS 使用的默认端口

# 检查操作系统类型
OS_TYPE=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_TYPE=$ID
else
    echo "无法检测操作系统类型，脚本退出。"
    exit 1
fi

# 检查和安装 CIFS 客户端
install_cifs_client() {
    echo "检查并安装 CIFS 客户端工具..."
    if [[ "$OS_TYPE" == "centos" || "$OS_TYPE" == "rhel" ]]; then
        if ! rpm -q cifs-utils > /dev/null 2>&1; then
            echo "安装 cifs-utils..."
            yum install -y cifs-utils
        else
            echo "cifs-utils 已安装。"
        fi
    elif [[ "$OS_TYPE" == "debian" || "$OS_TYPE" == "ubuntu" ]]; then
        if ! dpkg -l | grep -q cifs-utils; then
            echo "安装 cifs-utils..."
            apt-get update && apt-get install -y cifs-utils
        else
            echo "cifs-utils 已安装。"
        fi
    else
        echo "不支持的操作系统类型：$OS_TYPE"
        exit 1
    fi
}

# 检查网络连通性
check_network() {
    echo "检查网络连通性..."
    if ! ping -c 2 -W 2 $(echo $SHARE_PATH | awk -F'//' '{print $2}' | awk -F'/' '{print $1}') > /dev/null 2>&1; then
        echo "无法访问服务器，请检查网络连接！"
        exit 1
    else
        echo "网络连通正常。"
    fi
}

# 检查 CIFS 端口连通性
check_port() {
    echo "检查 CIFS 端口 ($CIFS_PORT) 连通性..."
    if ! ss -lnt | grep ":$CIFS_PORT" > /dev/null 2>&1; then
        echo "端口 $CIFS_PORT 不可用，请检查防火墙设置！"
        exit 1
    else
        echo "端口 $CIFS_PORT 连通正常。"
    fi
}

# 创建挂载点目录
create_mount_point() {
    if [ ! -d "$MOUNT_POINT" ]; then
        echo "创建挂载点目录：$MOUNT_POINT"
        mkdir -p "$MOUNT_POINT"
    else
        echo "挂载点目录已存在：$MOUNT_POINT"
    fi
}

# 创建凭据文件
create_credentials_file() {
    echo "创建凭据文件：$CREDENTIALS_FILE"
    cat <<EOF > "$CREDENTIALS_FILE"
username=$USERNAME
password=$PASSWORD
EOF
    chmod 600 "$CREDENTIALS_FILE"
}

# 添加挂载配置到 /etc/fstab
configure_fstab() {
    echo "配置挂载到 /etc/fstab..."
    if grep -q "$SHARE_PATH" /etc/fstab; then
        echo "$SHARE_PATH 已存在于 /etc/fstab 中，跳过配置。"
    else
        echo "$SHARE_PATH $MOUNT_POINT cifs credentials=$CREDENTIALS_FILE,uid=0,gid=0 0 0" >> /etc/fstab
        echo "挂载配置已添加到 /etc/fstab。"
    fi
}

# 执行挂载
mount_share() {
    echo "执行挂载..."
    mount -a
    if mount | grep -q "$MOUNT_POINT"; then
        echo "挂载成功！共享路径 $SHARE_PATH 已挂载到 $MOUNT_POINT"
    else
        echo "挂载失败，请检查配置！"
        exit 1
    fi
}

# 主函数
main() {
    install_cifs_client
    check_network
    check_port
    create_mount_point
    create_credentials_file
    configure_fstab
    mount_share
}

# 执行主函数
main
```


## 总结

本文介绍了如何在 CentOS 和 Debian 系统上安装和配置 CIFS 服务端，如何在客户端挂载 CIFS 共享，并在 Windows 客户端访问共享文件夹。通过批量挂载脚本，可以轻松管理多个 CIFS 共享并实现自动挂载。