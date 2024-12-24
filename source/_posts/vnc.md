---
title: 如何在不同 Linux 系统下安装 VNC 服务
date: 2024-12-19 10:00:00
tags:
  - VNC
  - Linux
# comments: true
category: Linux
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;VNC（Virtual Network Computing）是一个远程桌面访问协议，允许用户通过网络远程访问 Linux 系统的图形化界面。本文介绍了如何在不同的 Linux 发行版（包括 Ubuntu/Debian、CentOS/RHEL、openSUSE 和 Arch Linux）中安装和配置 VNC 服务。通过详细的步骤指导，包括安装 VNC 软件、配置 VNC 密码、创建启动脚本和启动 VNC 服务，你可以在各个系统上实现远程桌面访问。此外，本文还提供了常见问题的排查方法，以帮助解决可能遇到的连接和显示问题。

<!-- more -->

## 1. Ubuntu/Debian 系统

Ubuntu 和 Debian 系统可以通过 APT 包管理器安装常见的 VNC 服务。

### 安装 TigerVNC
```bash
sudo apt update
sudo apt install tigervnc-standalone-server tigervnc-xorg-extension
```

### 配置 VNC
1. 设置 VNC 密码：
   ```bash
   vncpasswd
   ```
   按提示输入密码。

2. 创建配置文件：
   ```bash
   mkdir -p ~/.vnc
   nano ~/.vnc/xstartup
   ```
   添加以下内容（以 GNOME 桌面为例）：
   ```bash
   #!/bin/bash
   exec /usr/bin/gnome-session &
   ```
   保存后为脚本添加可执行权限：
   ```bash
   chmod +x ~/.vnc/xstartup
   ```

3. 启动 VNC 服务：
   ```bash
   vncserver
   ```

4. 停止 VNC 服务：
   ```bash
   vncserver -kill :1
   ```

---

## 2. CentOS/RHEL 系统

CentOS 和 RHEL 通常通过 YUM 或 DNF 安装 VNC 服务。

### 安装 TigerVNC
```bash
sudo yum install tigervnc-server
```

### 配置 VNC
1. 编辑配置文件：
   ```bash
   sudo nano /etc/tigervnc/vncserver.users
   ```
   添加如下内容：
   ```
   :1=username
   ```
   替换 `username` 为实际用户。

2. 设置 VNC 密码：
   切换到指定用户并设置密码：
   ```bash
   su - username
   vncpasswd
   ```

3. 配置桌面环境（以 GNOME 为例）：
   编辑用户的 `~/.vnc/xstartup` 文件：
   ```bash
   nano ~/.vnc/xstartup
   ```
   添加以下内容：
   ```bash
   #!/bin/bash
   exec /usr/bin/gnome-session &
   ```
   保存后为脚本添加可执行权限：
   ```bash
   chmod +x ~/.vnc/xstartup
   ```

4. 启动 VNC 服务：
   ```bash
   sudo systemctl start vncserver@:1
   sudo systemctl enable vncserver@:1
   ```

---

## 3. openSUSE 系统

openSUSE 系统也支持安装和配置 VNC 服务。

### 安装 TightVNC
```bash
sudo zypper install tightvnc
```

### 配置 VNC
1. 设置 VNC 密码：
   ```bash
   vncpasswd
   ```

2. 创建配置文件：
   ```bash
   mkdir -p ~/.vnc
   nano ~/.vnc/xstartup
   ```
   添加以下内容：
   ```bash
   #!/bin/bash
   exec startkde &
   ```
   根据桌面环境选择命令，例如 KDE 使用 `startkde`，GNOME 使用 `gnome-session`。

3. 启动 VNC 服务：
   ```bash
   vncserver
   ```

4. 停止 VNC 服务：
   ```bash
   vncserver -kill :1
   ```

---

## 4. Arch Linux

在 Arch Linux 上，可以通过 `pacman` 包管理器安装 VNC 服务。

### 安装 TigerVNC
```bash
sudo pacman -S tigervnc
```

### 配置 VNC
1. 设置 VNC 密码：
   ```bash
   vncpasswd
   ```

2. 配置 VNC：
   编辑 `~/.vnc/xstartup` 文件：
   ```bash
   nano ~/.vnc/xstartup
   ```
   添加以下内容：
   ```bash
   #!/bin/bash
   exec /usr/bin/xfce4-session &
   ```
   根据桌面环境选择启动命令，例如 XFCE 使用 `xfce4-session`。

3. 启动 VNC 服务：
   ```bash
   vncserver
   ```

4. 停止 VNC 服务：
   ```bash
   vncserver -kill :1
   ```

---

## 5. 常见问题排查

- **连接失败**：
  - 检查防火墙是否允许 VNC 端口（默认 5901）。
    ```bash
    sudo ufw allow 5901
    ```

- **显示空白屏幕**：
  - 确保 `xstartup` 文件正确配置并具有可执行权限。

- **服务未启动**：
  - 检查日志文件 `~/.vnc/*.log` 获取更多信息。

---

通过以上步骤，您可以在不同的 Linux 发行版中安装和配置 VNC 服务，轻松实现远程桌面访问。