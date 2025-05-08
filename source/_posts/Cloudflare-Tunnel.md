---
title: 使用 Cloudflare Tunnel 安全暴露本地服务到公网
date: 2025-04-23T15:14:25.000Z
tags: ["Cloudflare", "Intranet penetration", "DevOps"]
categories: Development
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; Cloudflare Tunnel 是一种强大的反向隧道服务，允许用户将本地服务器或内部网络资源安全暴露到公网，而无需开放防火墙端口或拥有公网 IP 地址。本文将详细介绍 Cloudflare Tunnel 的工作原理、功能特点、使用场景，并结合实际操作步骤，展示如何通过 Cloudflare Tunnel 将本地服务映射到公网域名。

<!-- more -->

## 什么是 Cloudflare Tunnel？

Cloudflare Tunnel 是 Cloudflare 提供的一项服务，通过运行轻量级客户端 `cloudflared`，在本地设备与 Cloudflare 全球网络之间建立安全的出站连接（outbound-only）。外部用户可以通过 Cloudflare 的网络访问你的本地服务，而无需直接暴露服务器的 IP 或端口。

### 工作原理

1. **安装客户端**：在本地服务器或设备上安装 `cloudflared`，这是 Cloudflare 提供的隧道守护进程。
2. **创建隧道**：使用 `cloudflared` 创建一个隧道，与 Cloudflare 边缘网络建立连接，无需公网 IP。
3. **路由流量**：在 Cloudflare 仪表盘中配置域名或子域名，外部请求通过 Cloudflare 转发到本地服务。
4. **安全性保障**：所有流量经过 Cloudflare 的加密，支持 HTTPS，并可结合 Cloudflare Access 添加身份验证。

### 主要特点

- **无需端口转发**：无需配置路由器或开放防火墙端口，适合家庭网络或受限环境。
- **免费基础服务**：基本功能（如创建隧道、绑定域名）免费，适合个人用户或小型项目。
- **安全性增强**：提供 DDoS 防护、SSL/TLS 加密，流量通过 Cloudflare 全球网络。
- **灵活性**：支持多种协议（如 HTTP、SSH、RDP），可暴露网页服务、远程桌面或游戏服务器。

### 使用场景

- **远程访问本地服务**：如在家运行 NAS，想通过公网访问文件管理界面。
- **开发测试**：快速将本地开发环境暴露到公网，测试 webhook 或第三方回调。
- **替代 VPN**：相比传统 VPN，Cloudflare Tunnel 配置简单，适合快速部署。

### 对比 ngrok

与类似的反向隧道工具 ngrok 相比，Cloudflare Tunnel 有以下优势：

- **成本**：ngrok 免费版有严格的时长（2小时断开）和连接限制，而 Cloudflare Tunnel 免费版更宽松。
- **域名**：ngrok 免费版提供随机域名，Cloudflare 支持自定义域名。
- **安全性**：Cloudflare 提供额外的 DDoS 防护和全球 CDN 加速。

## 实践：使用 Cloudflare Tunnel 暴露本地服务

下面，我们将通过实际操作，展示如何使用 Cloudflare Tunnel 将本地运行的网页服务（`http://localhost:19000`）映射到公网域名 `share.freemankevin.uk`。

### 准备工作

1. 注册 Cloudflare 账号：登录 Cloudflare 仪表盘，添加你的域名并确保 DNS 托管在 Cloudflare。
2. 安装 `cloudflared`：
   - 在 Windows 上，下载 [cloudflared.exe](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/)（官方下载地址）。
   - 将 `cloudflared.exe` 放置在合适目录（如 `C:\cloudflared\`）。

### 安装 Cloudflare Tunnel 服务

运行以下命令以安装 `cloudflared` 服务并绑定 Cloudflare 账户：

```powershell
cloudflared.exe service install eyJhIjoiMjc0YzhmYzViSa2kih1k3MzVhNjBjNWQ1MTkzOWQyMDEiLCJ0IjoiMDEwNDI5MmEtNzEwYS00NTBkLWI3OGYtOTNjZTExYjhmYTZlIiwicyI6Ik56Um1ZVGcyT0dRdE9XUm1OaTAwWkRJM0xUbGxZemN0TWpKbFlUWmhabiJzTlRRMiJ9
```

> **注意**：`eyJh...` 是 Cloudflare 提供的认证令牌，请替换为你自己的令牌（从 Cloudflare 仪表盘获取）。

成功后，`cloudflared` 将作为系统服务运行。

### 创建隧道

创建名为 `share` 的隧道：

```powershell
cloudflared tunnel create share
```

输出类似以下内容：

```
Tunnel credentials written to C:\Users\Devops\.cloudflared\ab9d567c-00c0-46f3-83b7-680ei8b2f3f6.json. cloudflared chose this file based on where your origin certificate was found. Keep this file secret. To revoke these credentials, delete the tunnel.

Created tunnel share with id ab9d567c-00c0-46f3-83b7-680ei8b2f3f6
```

这会生成一个隧道 ID（`ab9d567c-00c0-46f3-83b7-680ei8b2f3f6`）和凭证文件（`ab9d567c-00c0-46f3-83b7-680ei8b2f3f6.json`）。请妥善保存凭证文件，避免泄露。

### 配置隧道

创建配置文件 `config.yml`，内容如下：

```yaml
tunnel: share
credentials-file: C:\Users\Devops\.cloudflared\ab9d567c-00c0-46f3-83b7-680ei8b2f3f6.json
ingress:
  - hostname: share.freemankevin.uk
    service: http://localhost:19000
  - service: http_status:404
```

- `tunnel`：指定隧道名称（`share`）。
- `credentials-file`：指定凭证文件路径。
- `ingress`：定义路由规则，将 `share.freemankevin.uk` 的请求转发到本地 `http://localhost:19000`，其他请求返回 404。

将 `config.yml` 保存到 `C:\Users\Devops\.cloudflared\` 目录。

### 配置 DNS 记录

在 Cloudflare 仪表盘中，添加 CNAME 记录：

| 类型  | 名称  | 目标                                  |
|-------|-------|---------------------------------------|
| CNAME | share | ab9d567c-00c0-46f3-83b7-680ei8b2f3f6.cfargotunnel.com |

或者，使用以下命令自动配置 DNS：

```powershell
cloudflared tunnel route dns share share.freemankevin.uk
```

### 运行隧道

运行以下命令启动隧道：

```powershell
cloudflared tunnel --config C:\Users\Devops\.cloudflared\config.yml --origin-ca-pool C:\Users\Devops\.cloudflared\ca-certificates.pem --logfile C:\Users\Devops\.cloudflared\cloudflared.log run share
```

参数说明：
- `--config`：指定配置文件路径。
- `--origin-ca-pool`：指定 CA 证书路径（可选，通常用于企业环境）。
- `--logfile`：指定日志文件路径，便于调试。

启动后，`share.freemankevin.uk` 将可通过公网访问，并指向本地 `http://localhost:19000` 的服务。

### 测试访问

在浏览器中访问 `https://share.freemankevin.uk`，确认是否能正常访问本地服务。如果无法访问，检查以下内容：

1. 确保本地服务（`http://localhost:19000`）正在运行。
2. 检查 Cloudflare 仪表盘中的 DNS 记录是否正确。
3. 查看 `cloudflared` 日志（`C:\Users\Devops\.cloudflared\cloudflared.log`）以排查错误。

### 添加系统服务
为了方便启动和管理隧道，我们可以将上面的隧道共享服务添加到系统服务中：

#### 添加服务
```powershell
# 以管理员身份打开 PowerShell
# 创建系统服务
sc create CloudflaredTunnel binPath= "C:\Program Files (x86)\cloudflared\cloudflared.exe tunnel --config C:\Users\Devops\.cloudflared\config.yml run share" start= auto DisplayName= "Cloudflare Tunnel Service"

# 设置服务描述
sc description CloudflaredTunnel "Cloudflare Tunnel for secure remote access"

# 配置故障恢复（自动重启）
sc failure CloudflaredTunnel reset= 30 actions= restart/5000


# 启动服务
sc start CloudflaredTunnel
```
添加后，`cloudflared` 将作为系统服务运行，无需手动启动。

#### 卸载服务
如果不再需要该服务，可以卸载：
```powershell
sc delete CloudflaredTunnel
```
## 免费版限制

- **带宽**：Cloudflare Tunnel 免费版没有明确的带宽限制，但可能对滥用行为进行限制。
- **功能**：高级功能（如负载均衡、Zero Trust 策略）需要付费计划。
- **域名**：需使用 Cloudflare 托管的域名（可免费注册或迁移现有域名）。

## 常见问题

### 隧道无法连接？

- 检查 `cloudflared` 是否正常运行，查看日志文件。
- 确保网络允许 `cloudflared` 的出站连接（端口 443）。

### DNS 配置失败？

- 确认域名已正确托管在 Cloudflare。
- 检查 CNAME 记录是否指向正确的隧道地址。

### 如何停止隧道？

- 按 `Ctrl+C` 停止 `cloudflared` 进程。
- 或删除隧道：`cloudflared tunnel delete share`。

## 总结

Cloudflare Tunnel 是一个简单、安全且免费的工具，适合将本地服务暴露到公网。通过以上步骤，你可以轻松将本地网页服务映射到自定义域名，并享受 Cloudflare 提供的加密和 DDoS 防护。相比 ngrok，Cloudflare Tunnel 在成本、灵活性和安全性上更具优势，非常适合个人开发者、家庭用户或小型项目。
