---
title: 如何给 Ubuntu 系统配置国内源
date: 2024-12-27 10:45:25
tags:
    - Linux
    - Ubuntu
    - Netplan
category: Ubuntu
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在本文中，我们将介绍如何将 Ubuntu 系统的默认源替换为国内镜像源，以加速软件包的下载速度。以清华源为例，我们提供了详细的步骤，从备份原有源配置、编辑源文件到更新软件包索引等操作。此外，还介绍了如何使用阿里云、网易云和中科大的源地址作为替代，帮助用户提高软件安装和系统更新的效率。
<!-- more -->

> 这里以`Ubuntu 22.04 LTS` 举例。 


### 备份原有的源配置

首先，备份当前的源配置文件：

```shell
sudo cp /etc/apt/sources.list{,.bak}
```

------

### 编辑源配置文件

使用文本编辑器打开源配置文件：

```shell
sudo vim /etc/apt/sources.list # 如果没有vim ，可以使用nano
```

------

### 替换为清华源

将文件内容替换为以下清华源配置：

```shell
# tsinghua repo for Ubuntu 22.04 LTS 
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-security main restricted universe multiverse

# tsinghua src repo for Ubuntu 22.04 LTS 
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-security main restricted universe multiverse
```
保存并退出编辑器。

------

### 更新软件包索引

运行以下命令更新软件包索引，以验证新的源配置是否正常：

```shell
sudo apt update 
```

如果新的源配置正确，应该能够成功拉取软件包列表。

------

### 升级系统（可选）

如果需要升级系统软件，可以运行以下命令：

```shell
sudo apt upgrade
```

------

### 验证新源是否生效

查看下载软件包时的源地址：

```shell
sudo apt install '任意软件包名称' -y   # 正常会显示来自： mirrors.tuna.tsinghua.edu.cn
```

------

### 常见问题

- 无法访问清华源: 检查网络连通性，使用以下命令测试：

  ```shell
  ping mirrors.tuna.tsinghua.edu.cn
  ```

- **需要替换为其他国内镜像源**：例如阿里云、网易或中科大等，可以根据需要修改为对应的镜像地址。

  ```shell
  # 阿里云
  sudo sed -i 's|http://archive.ubuntu.com|http://mirrors.aliyun.com|g' /etc/apt/sources.list
  sudo sed -i 's|http://security.ubuntu.com|http://mirrors.aliyun.com|g' /etc/apt/sources.list

  # 网易云
  sudo sed -i 's|http://archive.ubuntu.com|http://mirrors.163.com|g' /etc/apt/sources.list
  sudo sed -i 's|http://security.ubuntu.com|http://mirrors.163.com|g' /etc/apt/sources.list

  # 中科大
  sudo sed -i 's|http://archive.ubuntu.com|http://mirrors.ustc.edu.cn|g' /etc/apt/sources.list
  sudo sed -i 's|http://security.ubuntu.com|http://mirrors.ustc.edu.cn|g' /etc/apt/sources.list
  ```
