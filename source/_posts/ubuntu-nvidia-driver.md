---
title: 如何在 Ubuntu 系统上安装 NVIDIA 驱动
date: 2024-12-27 11:23:25
tags:
    - Driver
    - Ubuntu
    - NVIDIA
category: Ubuntu
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;本文详细介绍了如何在 Ubuntu 系统中安装和配置 NVIDIA 显卡驱动，特别是针对多卡配置（如双卡 SLI 或 CUDA）。通过步骤化指导，从确认硬件兼容性、安装必要依赖、添加官方 PPA 到安装驱动，确保驱动正确安装并验证。还包括如何配置多卡环境（SLI 或 CUDA），以及常见问题的解决方法，帮助用户充分发挥 NVIDIA 显卡的性能。

<!-- more -->

> 这里以`Ubuntu 22.04 LTS` 环境举例。

**硬件配置**： `Intel 酷睿i9 14900K 24核心32线程 主频2.4G 128G DDR5 1T固态硬盘 NVIDIA Geforce RTX4090D 24G *2`


### 考虑因素
1. 显卡型号： `NVIDIA Geforce RTX4090D`，驱动版本需要与硬件匹配。
2. 显卡数量： `*2` 双卡配置，需要支持双卡。
3. 驱动版本： 可以通过[官方网站](https://www.nvidia.com/Download/index.aspx)来查询。
4. 操作系统： `Ubuntu 22.04 LTS` , 需要server 版而非 desktop 版，以免不稳定。另外，没有特殊需要，不安装桌面。


------  

### 确认系统和硬件信息

运行以下命令确认你的 NVIDIA 显卡是否被识别：

```shell
lspci | grep -i nvidia
```

检查当前是否已安装 NVIDIA 驱动：

```shell
nvidia-smi
```

如果没有显示正确的驱动信息，继续以下步骤。

------

### 更新系统并安装必要工具

更新软件包并安装依赖：

```shell
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential dkms gcc make
```

------

### 添加官方 NVIDIA 驱动 PPA

使用官方 PPA 安装 NVIDIA 驱动：

```shell
sudo add-apt-repository ppa:graphics-drivers/ppa
sudo apt update
```

------

### 安装 NVIDIA 驱动

查看推荐的 NVIDIA 驱动版本：

```shell
ubuntu-drivers devices
```

根据输出选择推荐的驱动版本（例如 `nvidia-driver-535`），然后运行：

```shell
sudo apt install nvidia-driver-535
```

> **注意**：如果你知道具体需要的驱动版本，也可以替换为对应的版本号。

------

### 验证驱动安装

安装完成后，重启系统：

```shell
sudo sync;reboot
```

然后检查 NVIDIA 驱动是否正常工作：

```shell
nvidia-smi
```

如果输出显示 GPU 信息，则驱动安装成功。

------

### 多卡配置（SLI 或 CUDA）

如果你计划使用双卡的 SLI 模式（用于渲染加速）或 CUDA（用于深度学习或计算），请根据用途安装附加工具。

#### 安装 CUDA 工具包

安装 CUDA 工具包和开发环境：

```shell
sudo apt install -y nvidia-cuda-toolkit
```

检查 CUDA 是否可用：

```shell
nvcc --version
```

#### 配置 SLI（可选）

确保你的主板支持 SLI，并在 BIOS 中启用相关功能。安装 NVIDIA 控制面板工具：

```shell
sudo apt install nvidia-settings
```

运行 NVIDIA 设置工具配置 SLI：

```shell
sudo nvidia-settings
```

------

### 常见问题排查

- **黑屏或无法进入桌面**：
  （如果你安装了桌面）按 `Ctrl+Alt+F2` 进入终端，然后重新安装驱动：

  ```shell
  sudo apt purge nvidia*
  sudo apt install nvidia-driver-535
  ```

- **需要最新驱动**：
  如果官方 PPA 不包含最新驱动，可以从 NVIDIA 官方下载 `.run` 文件手动安装：

  1. 下载对应版本驱动：[NVIDIA 官网](https://www.nvidia.com/Download/index.aspx)。

  2. 禁用当前驱动：

     ```shell
     sudo systemctl stop gdm
     sudo systemctl stop lightdm
     ```

  3. 安装驱动：

     ```shell
     sudo bash NVIDIA-Linux-x86_64-*.run
     ```