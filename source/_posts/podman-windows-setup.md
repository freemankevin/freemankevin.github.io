---
title: Podman CLI on Windows 安装与配置指南
date: 2026-04-30 14:51:00
keywords:
  - Podman
  - Windows
  - WSL2
  - Container
categories:
  - DevOps
  - Container
tags:
  - Podman
  - Windows
  - WSL2
  - Docker
---

Podman 是 Docker 的开源替代方案，在 Windows 上通过 WSL2 虚拟机运行容器。本文档详细阐述 Podman on Windows 的完整部署流程，包括安装配置、代理设置、私有仓库信任、开机自启动及日常维护等关键环节，适用于需要在 Windows 环境下使用容器技术的开发与运维场景。

<!-- more -->

**适用版本与环境说明：**
- Podman: 5.x（本文示例版本）
- 操作系统: Windows 10/11（需启用 WSL2）
- 代理软件: v2rayN（或其他支持局域网访问的代理）
- 私有仓库: Harbor（HTTP 或自签名证书）
- 更新日期: 2026-04-30（建议关注 Podman GitHub Releases）

{% note info %}
Podman on Windows 通过 WSL2 虚拟机运行，与 Docker Desktop 的架构类似但无需付费许可。本文配置示例基于 Podman 5.x 版本，不同版本配置参数可能略有差异。
{% endnote %}

## Podman 架构概述

### 核心概念

Podman on Windows 采用以下架构：

| 组件 | 功能 | 说明 |
|------|------|------|
| Podman CLI | 命令行客户端 | 与 Docker CLI 命令兼容 |
| Podman Machine | WSL2 虚拟机 | 容器运行环境 |
| containerd | 容器运行时 | 管理容器生命周期 |
| crun/runc | OCI 运行时 | 创建和运行容器 |

### 与 Docker 的差异

| 特性 | Podman | Docker Desktop |
|------|--------|----------------|
| 运行模式 | 无守护进程（daemonless） | 需要 dockerd 守护进程 |
| Root 权限 | 支持 rootless 模式 | 默认需要 root |
| Pod 支持 |原生支持 Kubernetes Pod | 需要额外工具 |
| 许可费用 | 开源免费 | 企业版收费 |
| 架构 | WSL2 轻量虚拟机 | WSL2 + Hyper-V |

## 安装 Podman

### 方式一：winget（推荐）

```powershell
winget install RedHat.Podman
```

### 方式二：手动下载

前往 [Podman Releases](https://github.com/containers/podman/releases/latest) 下载最新 `.exe` 安装包。

安装完成后验证：

```powershell
podman --version
```

---

## 初始化 Podman Machine

Podman on Windows 通过 WSL2 虚拟机运行，需要初始化一个 Machine 实例。

```powershell
podman machine init

podman machine set --rootful

podman machine start

podman machine list
```

**预期输出：**

```
NAME                     VM TYPE     CREATED        LAST UP            CPUS   MEMORY   DISK SIZE
podman-machine-default*  wsl         X minutes ago  Currently running  8      2GiB     100GiB
```

**参数说明：**

| 参数 | 说明 | 推荐值 |
|------|------|--------|
| `--rootful` | 以 root 用户运行容器 | 生产环境推荐，兼容性更好 |
| `--cpus` | 分配 CPU 核数 | 默认 8 |
| `--memory` | 分配内存大小 | 默认 2GiB |
| `--disk-size` | 虚拟磁盘大小 | 默认 100GiB |

---

## 清理系统代理环境变量

{% note warning %}
Windows 系统代理会被传入 VM，如果代理软件监听的是 `127.0.0.1`，在 VM 内会指向虚拟机本身而非宿主机，导致连接失败，必须清除。
{% endnote %}

```powershell
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyServer -Value ""

[System.Environment]::SetEnvironmentVariable("HTTP_PROXY", $null, "Machine")
[System.Environment]::SetEnvironmentVariable("HTTPS_PROXY", $null, "Machine")

[System.Environment]::SetEnvironmentVariable("HTTP_PROXY", $null, "User")
[System.Environment]::SetEnvironmentVariable("HTTPS_PROXY", $null, "User")

Remove-Item Env:HTTP_PROXY -ErrorAction SilentlyContinue
Remove-Item Env:HTTPS_PROXY -ErrorAction SilentlyContinue

echo $env:HTTP_PROXY
echo $env:HTTPS_PROXY
```

---

## 配置 VM 内部代理

Podman Machine 运行在 WSL2 中，需要在 VM 内部配置代理，且代理地址必须使用宿主机在 WSL 网卡上的 IP。

### 查找宿主机 WSL IP

在 Windows 侧执行：

```powershell
ipconfig
```

找到 `vEthernet (WSL)` 对应的 IPv4 地址，通常为 `172.20.128.1`。

### 开启代理软件局域网访问

以 v2rayN 为例：

**设置 → Core 基础设置 → 允许来自局域网的连接 → On → 确定 → 重启服务**

### 写入 VM 代理配置

```powershell
podman machine ssh
```

进入 VM 后执行（将 `172.20.128.1` 替换为你的实际 WSL IP，`10808` 替换为你的代理端口）：

```bash
tee /etc/profile.d/default-env.sh << 'EOF'
export http_proxy=http://172.20.128.1:10808
export https_proxy=http://172.20.128.1:10808
export HTTP_PROXY=http://172.20.128.1:10808
export HTTPS_PROXY=http://172.20.128.1:10808
export no_proxy=localhost,127.0.0.1,::1,<HARBOR_IP>
export NO_PROXY=localhost,127.0.0.1,::1,<HARBOR_IP>
EOF

cat /etc/profile.d/default-env.sh

exit
```

### 重启 Machine 使配置生效

```powershell
podman machine stop
podman machine start
```

---

## 配置私有 Harbor 仓库信任

内网 Harbor 通常使用 HTTP 或自签名证书，需要添加 insecure 信任。

```powershell
podman machine ssh
```

```bash
tee /etc/containers/registries.conf.d/harbor.conf << 'EOF'
[[registry]]
location = "<HARBOR_IP>"
insecure = true
EOF

cat /etc/containers/registries.conf.d/harbor.conf

exit
```

{% note info %}
`<HARBOR_IP>` 已在 `NO_PROXY` 中，访问私有仓库会自动绕过代理，直连内网。
{% endnote %}

---

## 配置开机自启动

Podman Machine 默认不随 Windows 启动，通过计划任务实现自动启动。

```powershell
$action = New-ScheduledTaskAction -Execute "podman" -Argument "machine start"
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 2)

Register-ScheduledTask -TaskName "PodmanMachineStart" `
  -Action $action `
  -Trigger $trigger `
  -Settings $settings `
  -RunLevel Highest `
  -Force
```

验证注册成功：

```powershell
Get-ScheduledTask -TaskName "PodmanMachineStart"
```

取消自启动：

```powershell
Unregister-ScheduledTask -TaskName "PodmanMachineStart" -Confirm:$false
```

{% note info %}
触发时机为用户登录时。若需要真正的开机启动（无需登录），将 `-AtLogOn` 改为 `-AtStartup` 并配置 Windows 自动登录。
{% endnote %}

---

## 验证完整环境

```powershell
podman machine list

podman pull docker.io/library/nginx:latest

podman pull <HARBOR_IP>/<your-image>:<tag>

podman run --rm nginx:latest echo "Podman is working!"
```

---

## 日常维护命令

```powershell
podman machine start
podman machine stop
podman machine stop && podman machine start

podman machine ssh

podman images

podman ps

podman ps -a

podman container prune

podman image prune
```

---

## 故障排查指南

### 常见问题与解决方案

| 错误信息 | 原因 | 解决方案 |
|---------|------|---------|
| `proxyconnect tcp: connection refused` | 代理软件未运行或端口错误 | 启动代理软件，确认端口一致 |
| `proxyconnect tcp: 127.0.0.1:xxxx` | Windows 系统代理传入 VM | 执行「清理系统代理环境变量」步骤 |
| `Trying to pull...` 无响应 | 代理未开启局域网访问 | v2rayN 开启「允许来自局域网的连接」 |
| `permission denied /var/run/docker.sock` | 非 rootful 模式 | `podman machine set --rootful` |
| `VM already exists` | Machine 未完全清理 | `podman machine rm --force podman-machine-default` |

---

## 参考资源

### 官方文档

- [Podman 官方文档](https://podman.io/)
- [Podman Windows 安装指南](https://github.com/containers/podman/blob/main/docs/tutorials/podman-for-windows.md)
- [Podman Machine 配置](https://github.com/containers/podman/blob/main/docs/tutorials/podman-machine.md)
- [containers/registries.conf 配置](https://github.com/containers/image/blob/main/docs/containers-registries.conf.5.md)

### 相关工具

- [WSL2 官方文档](https://learn.microsoft.com/zh-cn/windows/wsl/)
- [v2rayN GitHub](https://github.com/2dust/v2rayN)
- [Harbor 部署指南](https://github.com/goharbor/harbor)

### 进阶阅读

- [Podman vs Docker 对比](https://podman.io/comparison/)
- [Podman Pod 管理](https://github.com/containers/podman/blob/main/docs/tutorials/pods.md)
- [Podman Kubernetes 集成](https://github.com/containers/podman/blob/main/docs/tutorials/kubernetes.md)