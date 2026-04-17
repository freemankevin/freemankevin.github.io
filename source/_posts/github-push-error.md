---
title: GitHub 推送代码失败的解决方案
date: 2024-12-11 12:17:25
tags:
    - GitHub
    - Git
    - Proxy
category: GitHub
---

在中国大陆访问 GitHub 时，经常遇到网络连接不稳定、推送失败等问题。本文详细介绍 Git 代理配置的多种方法，包括 HTTP/HTTPS 代理、SSH 代理、SOCKS5 代理等配置方案，并提供完整的故障排查指南和最佳实践，帮助你在受限网络环境中顺畅使用 Git 和 GitHub。

<!-- more -->

## GitHub 连接问题概述

### 问题现象

1. **推送失败**
   ```bash
   git push origin master
   # 错误信息
   fatal: unable to access 'https://github.com/...': Failed to connect to github.com
   ```

2. **克隆超时**
   ```bash
   git clone https://github.com/user/repo.git
   # 错误信息
   error: RPC failed; curl 56 Recv failure: Connection was reset
   ```

3. **连接慢**
   - 网页访问正常，但 Git 操作缓慢
   - 上传和下载带宽测试正常
   - Git 操作频繁超时或失败

### 问题原因

1. **Git 不使用系统代理**
   - Git 独立于系统代理设置
   - 即使设置全局代理也不生效
   - 需要单独配置 Git 代理

2. **网络防火墙**
   - 企业防火墙限制 HTTPS 连接
   - 代理服务器认证要求
   - SSL 证书验证问题

3. **DNS 解析**
   - GitHub IP 被污染或封锁
   - DNS 解析超时或失败
   - CDN 连接问题



## 解决方案一：配置 HTTP/HTTPS 代理

### 方法1：命令行配置

最快速的配置方法：

```bash
# 配置 HTTP 代理
git config --global http.proxy http://127.0.0.1:7890

# 配置 HTTPS 代理
git config --global https.proxy https://127.0.0.1:7890

# 验证配置
git config --global --get http.proxy
git config --global --get https.proxy
```

**参数说明**:
- `--global`: 全局配置，影响所有仓库
- `http://127.0.0.1:7890`: 代理地址和端口
- 根据你的代理软件修改地址和端口

### 方法2：编辑配置文件

手动编辑 Git 配置文件：

```bash
# 打开全局配置文件
git config --global --edit

# 或直接编辑文件
vim ~/.gitconfig
```

添加以下内容：

```ini
[http]
    proxy = http://127.0.0.1:7890
    
[https]
    proxy = https://127.0.0.1:7890
```

### 方法3：仅对 GitHub 配置代理

只对 GitHub 域名配置代理：

```bash
# 配置 GitHub 专用代理
git config --global http.https://github.com.proxy http://127.0.0.1:7890

# 取消其他域名的代理（可选）
git config --global --unset http.proxy
git config --global --unset https.proxy
```

### 验证配置

验证代理是否生效：

```bash
# 查看所有配置
git config --global --list | grep proxy

# 测试连接
git ls-remote https://github.com/git/git.git

# 测试推送
git push origin master
```

## 解决方案二：配置 SOCKS5 代理

### SOCKS5 代理配置

如果你使用 SOCKS5 代理（如 Shadowsocks、V2Ray）：

```bash
# 配置 SOCKS5 代理
git config --global http.proxy socks5://127.0.0.1:1080
git config --global https.proxy socks5://127.0.0.1:1080

# 或使用 socks5h（远程 DNS 解析）
git config --global http.proxy socks5h://127.0.0.1:1080
git config --global https.proxy socks5h://127.0.0.1:1080
```

**SOCKS5 代理类型说明**:
- `socks5://`: 本地 DNS 解析
- `socks5h://`: 远程 DNS 解析（推荐，避免 DNS 污染）

## 解决方案三：SSH 协议代理

### SSH 代理配置

使用 SSH 协议访问 GitHub 时配置代理：

```bash
# 编辑 SSH 配置文件
vim ~/.ssh/config

# 添加以下内容
Host github.com
    HostName github.com
    User git
    ProxyCommand nc -X 5 -x 127.0.0.1:1080 %h %p
```

**ProxyCommand 参数说明**:
- `-X 5`: 使用 SOCKS5 协议
- `-x 127.0.0.1:1080`: SOCKS5 代理地址
- `%h %p`: 目标主机和端口

### Windows 系统 SSH 代理

Windows 系统配置 SSH 代理：

```bash
# 安装 connect-proxy 或使用 Git Bash 内置工具
# 编辑 ~/.ssh/config

Host github.com
    HostName github.com
    User git
    ProxyCommand "C:/Program Files/Git/mingw64/bin/connect.exe" -S 127.0.0.1:1080 %h %p
```

### 测试 SSH 连接

验证 SSH 代理配置：

```bash
# 测试 SSH 连接
ssh -T git@github.com

# 查看连接详情
ssh -vT git@github.com

# 使用 SSH 协议克隆
git clone git@github.com:user/repo.git
```

## 解决方案四：认证代理配置

### 用户名密码认证代理

如果代理需要认证：

```bash
# 配置带认证的代理
git config --global http.proxy http://username:password@proxy-server:port

# 注意：密码中的特殊字符需要 URL 编码
# 例如：password@123 -> password%40123
```

### URL 编码特殊字符

常见特殊字符的 URL 编码：

| 字符 | URL编码 |
|------|---------|
| @    | %40     |
| :    | %3A     |
| /    | %2F     |
| #    | %23     |
| &    | %26     |

## 代理管理

### 查看代理配置

```bash
# 查看所有代理配置
git config --global --list | grep proxy

# 查看特定配置
git config --global http.proxy
git config --global https.proxy
```

### 取消代理配置

```bash
# 取消 HTTP 代理
git config --global --unset http.proxy

# 取消 HTTPS 代理
git config --global --unset https.proxy

# 取消所有代理
git config --global --unset-all http.proxy
git config --global --unset-all https.proxy

# 取消 GitHub 专用代理
git config --global --unset http.https://github.com.proxy
```

### 临时使用代理

临时启用代理（不影响全局配置）：

```bash
# 方法1：环境变量
export ALL_PROXY=socks5://127.0.0.1:1080
git clone https://github.com/user/repo.git

# 方法2：命令参数
git clone -c http.proxy=http://127.0.0.1:7890 https://github.com/user/repo.git

# 方法3：单次推送
git -c http.proxy=http://127.0.0.1:7890 push origin master
```

## 自动化脚本

### 代理开关脚本

便捷的代理管理脚本：

```bash
#!/bin/bash
# git-proxy-toggle.sh

PROXY_ADDR="http://127.0.0.1:7890"

enable_proxy() {
    echo "启用 Git 代理..."
    git config --global http.proxy "$PROXY_ADDR"
    git config --global https.proxy "$PROXY_ADDR"
    echo "代理已启用: $PROXY_ADDR"
}

disable_proxy() {
    echo "禁用 Git 代理..."
    git config --global --unset http.proxy
    git config --global --unset https.proxy
    echo "代理已禁用"
}

show_status() {
    echo "当前代理配置："
    git config --global --list | grep proxy || echo "未配置代理"
}

case "$1" in
    enable|on|1)
        enable_proxy
        ;;
    disable|off|0)
        disable_proxy
        ;;
    status|show|s)
        show_status
        ;;
    *)
        echo "用法: $0 {enable|disable|status}"
        echo "  enable/on/1  - 启用代理"
        echo "  disable/off/0 - 禁用代理"
        echo "  status/show/s - 查看状态"
        exit 1
        ;;
esac
```

使用方法：

```bash
# 添加执行权限
chmod +x git-proxy-toggle.sh

# 启用代理
./git-proxy-toggle.sh enable

# 禁用代理
./git-proxy-toggle.sh disable

# 查看状态
./git-proxy-toggle.sh status
```

### 自动检测代理脚本

智能检测并配置代理：

```bash
#!/bin/bash
# auto-git-proxy.sh

# 检测常见代理端口
PROXY_PORTS=(7890 1080 8080 10809)

detect_proxy() {
    for port in "${PROXY_PORTS[@]}"; do
        if nc -z 127.0.0.1 "$port" 2>/dev/null; then
            echo "检测到代理端口: $port"
            return "$port"
        fi
    done
    return 0
}

configure_proxy() {
    local port=$1
    
    if [ "$port" -eq 7890 ]; then
        # Clash 默认 HTTP 代理端口
        PROXY_TYPE="http"
        PROXY_ADDR="http://127.0.0.1:$port"
    elif [ "$port" -eq 1080 ]; then
        # Shadowsocks SOCKS5 端口
        PROXY_TYPE="socks5h"
        PROXY_ADDR="socks5h://127.0.0.1:$port"
    elif [ "$port" -eq 10809 ]; then
        # V2Ray SOCKS5 端口
        PROXY_TYPE="socks5h"
        PROXY_ADDR="socks5h://127.0.0.1:$port"
    else
        # 默认 HTTP 代理
        PROXY_TYPE="http"
        PROXY_ADDR="http://127.0.0.1:$port"
    fi
    
    git config --global http.proxy "$PROXY_ADDR"
    git config --global https.proxy "$PROXY_ADDR"
    
    echo "已配置 Git 代理: $PROXY_ADDR"
}

# 主逻辑
PORT=$(detect_proxy)

if [ "$PORT" -gt 0 ]; then
    configure_proxy "$PORT"
else
    echo "未检测到本地代理服务"
    echo "请手动配置代理: git config --global http.proxy http://address:port"
fi
```

## 高级配置

### 多代理配置

配置不同域名使用不同代理：

```bash
# GitHub 使用代理
git config --global http.https://github.com.proxy http://127.0.0.1:7890

# 内部 Git 服务器不使用代理
git config --global http.https://internal.company.com.proxy ""

# 其他域名使用其他代理
git config --global http.https://gitlab.com.proxy http://127.0.0.1:8080
```

### 代理超时设置

设置代理连接超时：

```bash
# 配置超时时间（秒）
git config --global http.lowSpeedLimit 1000
git config --global http.lowSpeedTime 30

# 配置连接超时
git config --global core.askPass ""

# 配置 SSL 后端
git config --global http.sslBackend openssl
```

### SSL 证书问题处理

处理 SSL 证书验证问题：

```bash
# 方法1：禁用 SSL 验证（不推荐，仅测试用）
git config --global http.sslVerify false

# 方法2：添加证书到 Git
git config --global http.sslCAInfo /path/to/certificate.crt

# 方法3：使用系统证书
git config --global http.sslBackend schannel  # Windows
git config --global http.sslBackend openssl   # Linux/Mac
```

## 故障排查

### 问题1：代理配置不生效

**解决方案**:
```bash
# 检查配置
git config --global --list

# 检查代理服务状态
curl -I --proxy http://127.0.0.1:7890 https://github.com

# 测试 Git 连接
GIT_CURL_VERBOSE=1 git ls-remote https://github.com/user/repo.git

# 查看详细错误
git config --global core.askPass ""
GIT_TRACE=1 GIT_CURL_VERBOSE=1 git push origin master
```

### 问题2：推送速度慢

**解决方案**:
```bash
# 增加缓冲区大小
git config --global http.postBuffer 524288000

# 使用压缩
git config --global core.compression 9

# 禁用进度显示
git config --global core.packedGitLimit 512m
git config --global core.packedGitWindowSize 32k

# 使用浅克隆
git clone --depth 1 https://github.com/user/repo.git
```

### 问题3：大文件推送失败

**解决方案**:
```bash
# 方法1：分批推送
git push origin master --force-with-lease

# 方法2：使用 SSH 协议
git remote set-url origin git@github.com:user/repo.git

# 方法3：取消大小限制
git config --global http.postBuffer 0

# 方法4：使用 Git LFS
git lfs install
git lfs track "*.zip"
git add .gitattributes
```

### 问题4：代理认证失败

**解决方案**:
```bash
# 检查认证信息
echo "http://username:password@proxy-server:port"

# 使用 URL 编码密码
python3 -c "import urllib.parse; print(urllib.parse.quote('password@123'))"

# 配置认证代理
git config --global http.proxy http://username:encoded_password@proxy-server:port

# 使用代理环境变量
export HTTP_PROXY="http://username:password@proxy-server:port"
export HTTPS_PROXY="http://username:password@proxy-server:port"
```

## 最佳实践

### 1. 选择合适的代理协议

- **HTTP 代理**: 适用于大多数场景，配置简单
- **SOCKS5h 代理**: 避免 DNS 污染，推荐用于 GitHub
- **SSH 协议**: 安全性更高，适合长期使用

### 2. 定期检查代理状态

```bash
# 添加检查脚本到 crontab
*/5 * * * * /path/to/check-git-proxy.sh >> /var/log/git-proxy.log 2>&1
```

### 3. 仓库级配置

针对特定仓库配置代理：

```bash
# 在仓库目录内配置
cd /path/to/repo
git config http.proxy http://127.0.0.1:7890

# 仅影响当前仓库
git config --list --local | grep proxy
```

### 4. 代理切换策略

根据网络环境动态切换：

```bash
# 创建代理配置文件
mkdir -p ~/.git-proxy-configs

# 家庭网络配置
cat > ~/.git-proxy-configs/home << EOF
http.proxy=http://127.0.0.1:7890
https.proxy=http://127.0.0.1:7890
EOF

# 公司网络配置
cat > ~/.git-proxy-configs/work << EOF
http.proxy=http://proxy.company.com:8080
https.proxy=http://proxy.company.com:8080
EOF

# 切换脚本
switch_git_proxy() {
    local env=$1
    cp ~/.git-proxy-configs/$env ~/.gitconfig.proxy
    git config --global --add include.path ~/.gitconfig.proxy
}
```

## 总结

Git 代理配置是在受限网络环境中使用 GitHub 的必要技能。通过本文的详细指导，你掌握了：

1. **多种代理配置方法** - HTTP、SOCKS5、SSH 代理配置
2. **认证代理处理** - 用户名密码认证、URL 编码
3. **自动化管理脚本** - 快速启用/禁用、自动检测
4. **高级配置技巧** - 多代理、超时设置、SSL 处理
5. **完整的故障排查** - 诊断和解决常见问题

掌握这些技能后，你可以在任何网络环境中顺畅使用 Git 和 GitHub，提高开发效率。

**相关资源**:
- [Git 官方文档](https://git-scm.com/docs/git-config)
- [GitHub SSH 配置](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)
- [代理工具推荐](https://github.com/topics/proxy)