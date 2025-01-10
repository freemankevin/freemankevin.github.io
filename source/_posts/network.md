---
title: 如何测试 Linux 服务器网络带宽
date: 2025-01-10 13:57:25
tags:
    - Test
    - Network
    - Linux
category: Test
---


&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在本博客中，我们将介绍几款常用的网络带宽测试工具，包括 iPerf3、NetFlow/sFlow 和 Speedtest CLI。每个工具都具有独特的功能，适用于不同的网络性能测试需求。从简单的带宽测量到详细的流量分析，这些工具能够帮助网络管理员和开发人员快速评估网络性能、排查问题，优化网络设置。本文将为您提供详细的安装方法、配置技巧及使用实例，帮助您选择和高效使用这些工具，提升网络管理的能力。

<!-- more -->

## iPerf3

### 背景介绍
iPerf3 是一个非常流行的开源网络性能测试工具，主要用于测量网络带宽、延迟以及丢包情况。它支持 TCP 和 UDP 两种协议，适用于多个操作系统（如 Linux、macOS 和 Windows）。iPerf3 通过客户端-服务器架构来进行网络性能测试，广泛应用于网络管理员和开发人员在进行网络优化、故障排查以及带宽评估时。

### 安装
#### macOS
在 macOS 上，使用 Homebrew 安装：

```bash
brew install iperf3
```

#### CentOS / RHEL / Fedora
在 CentOS 或 RHEL 系统上，首先启用 EPEL 仓库，然后安装 iPerf3：

```bash
sudo yum install epel-release
sudo yum install iperf3
```

#### Debian / Ubuntu
在 Debian 或 Ubuntu 上，可以直接使用 apt 包管理器安装：

```bash
sudo apt update
sudo apt install iperf3
```

### 使用方法

#### 启动 iPerf3 服务端
在目标机器上启动 iPerf3 服务端，监听默认端口 5201（可以指定其他端口）。

```bash
iperf3 -s
```

#### 启动 iPerf3 客户端
在测试机（客户端）上，指定服务端的 IP 地址并进行带宽测试。例如：

```bash
iperf3 -c <server-ip> -t 30 -u -b 100M
```

- `-c <server-ip>`：指定服务端的 IP 地址。
- `-t 30`：测试持续时间为 30 秒。
- `-u`：使用 UDP 协议（默认为 TCP）。
- `-b 100M`：指定 UDP 测试时的带宽为 100 Mbps。

#### 测试其他参数
- 测试 10 个并发连接：

```bash
iperf3 -c <server-ip> -t 30 -P 10
```

- 测试 TCP 带宽：

```bash
iperf3 -c <server-ip> -t 30
```

### 结果输出
iPerf3 测试结果将包括以下内容：
- **带宽**：单位为 Mbps 或 Gbps。
- **丢包率**（仅 UDP）：测量数据包的丢失情况。
- **延迟**：TCP 连接的 RTT（Round Trip Time）。
- **抖动**（仅 UDP）：测量 UDP 流的抖动（变化率）。


## NetFlow / sFlow

### 背景介绍
NetFlow 和 sFlow 是两种广泛使用的网络流量监控和带宽测试协议。NetFlow 最初由 Cisco 提出，并被许多网络设备支持，能够提供详细的网络流量分析，包括每个流的源 IP、目的 IP、端口号、协议类型等信息。而 sFlow 是一种采样协议，适用于需要大规模监控的环境，它通过随机采样流量来降低对网络性能的影响。两者都广泛应用于网络管理和监控，特别是用于分析网络带宽使用情况和流量模式。

### 使用方法

#### NetFlow 安装与配置
##### 在路由器/交换机上启用 NetFlow
NetFlow 需要在支持 NetFlow 的网络设备（如 Cisco 路由器）上启用。以下是一个启用 NetFlow 的配置示例：

```bash
flow exporter MY_EXPORTER
 destination 192.168.1.100
 source GigabitEthernet0/0
 transport udp 2055
```

该命令将 NetFlow 数据导出到 IP 地址为 `192.168.1.100` 的收集器。

##### 安装 NetFlow 收集器
在 Debian 或 CentOS 上安装 `nfdump`（NetFlow 数据收集工具）：

```bash
sudo apt install nfdump    # Debian/Ubuntu
sudo yum install nfdump    # CentOS/RHEL
```

##### 使用 NetFlow 查看流量
使用以下命令查看流量数据：

```bash
nfdump -R /path/to/flow/data -o csv
```

#### sFlow 安装与配置
##### 在交换机/路由器上启用 sFlow
启用 sFlow 功能，并指定数据导出目标：

```bash
sflow enable
sflow destination 192.168.1.100 6343
```

##### 安装 sFlow 收集器
在 Debian 或 CentOS 上安装 `sflowtool`，这是一个常用的 sFlow 数据分析工具。

```bash
sudo apt install sflowtool    # Debian/Ubuntu
sudo yum install sflowtool    # CentOS/RHEL
```

##### 使用 sFlow 收集数据
使用以下命令读取 sFlow 数据并进行分析：

```bash
sflowtool -r /path/to/sflow/data
```


## Speedtest CLI

### 背景介绍
Speedtest CLI 是由 Ookla 提供的一个命令行版本的 Speedtest 工具，广泛用于测试网络连接的下载速度、上传速度和延迟。通过它，用户可以直接从命令行界面进行测速，并获得详细的结果输出。它的优势在于可以快速集成到自动化脚本中，适合开发人员、系统管理员以及网络工程师进行带宽性能测试。

### 安装

#### macOS
在 macOS 上使用 Homebrew 安装：

```bash
brew install speedtest-cli
```

#### CentOS / RHEL / Fedora
在 CentOS 或 RHEL 上，使用 `pip` 安装：

```bash
sudo yum install python3-pip
sudo pip3 install speedtest-cli
```

#### Debian / Ubuntu
在 Debian 或 Ubuntu 上，可以直接通过 `apt` 安装：

```bash
sudo apt update
sudo apt install speedtest-cli
```

### 使用方法

#### 运行 Speedtest 测试
运行以下命令来测试与最近服务器之间的网络带宽：

```bash
speedtest-cli
```

这将显示下载速度、上传速度以及延迟。

#### 选择特定服务器进行测试
首先列出所有可用的服务器：

```bash
speedtest-cli --list
```

然后选择一个服务器进行测试（例如，选择 `12345` 作为服务器 ID）：

```bash
speedtest-cli --server 12345
```

#### 输出结果格式
Speedtest CLI 支持以多种格式输出结果：

- 输出为简洁文本格式：

```bash
speedtest-cli --simple
```

- 输出为 JSON 格式：

```bash
speedtest-cli --json
```

- 输出为 CSV 格式：

```bash
speedtest-cli --csv
```

### 测试其他参数
- 强制使用指定的下载服务器：

```bash
speedtest-cli --server <server-id>
```

- 使用不同的连接类型（如 10Mbps）：

```bash
speedtest-cli --bandwidth 10M
```


## 总结

这些工具的背景和具体使用方法如下：

- **iPerf3**：广泛用于网络带宽性能测试，支持多平台和多协议（TCP、UDP），通过客户端和服务端架构进行高效测试。
- **NetFlow / sFlow**：用于大规模网络流量监控，NetFlow 提供详细的流量信息，sFlow 使用采样方法减少对网络的影响，适用于流量分析和带宽使用评估。
- **Speedtest CLI**：适合测量公网带宽，通过命令行界面进行快速测试，支持自定义服务器和多种输出格式，非常适合自动化集成。

选择合适的工具，能够帮助您在不同场景下精准评估和优化网络性能。