---
title: 开发环境中生成自签名证书
date: 2025-01-10 09:57:25
tags:
    - Development
    - Minica
    - Https
category: Development
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在本篇文章中，我们将介绍如何使用轻量级工具 `minica` 在本地开发环境中生成自签名证书，支持 macOS、Windows 和 Linux（包括 CentOS 和 Debian 系列）。内容涵盖安装方法、证书生成、根证书的安装与信任配置，以及如何在本地开发服务器（如 NGINX）中集成 HTTPS 支持。通过本教程，你可以快速实现开发环境的 HTTPS 配置，让本地站点更加安全、专业，且无需依赖外部 CA。

<!-- more -->
## 安装 `minica`

### macOS

通过 Homebrew 安装：

```shell
brew install minica
```

### Windows

1. 从 [minica GitHub](https://github.com/jsha/minica/releases) 下载最新版本的 `minica.exe`。
2. 将 `minica.exe` 移动到系统路径目录（如 `C:\Windows\System32`），方便全局调用。

### Linux (CentOS/Debian)

#### 使用源代码安装

1. 确保系统已安装 Go 编译环境。
   ```shell
   sudo yum install golang  # CentOS
   sudo apt install golang  # Debian/Ubuntu
   ```

2. 克隆 `minica` 仓库并编译：
   ```shell
   git clone https://github.com/jsha/minica.git
   cd minica
   go build
   ```

   编译完成后，你会在当前目录下得到 `minica` 可执行文件。

3. 将 `minica` 文件移动到 `/usr/local/bin`，以便全局使用：
   ```shell
   sudo mv minica /usr/local/bin/
   ```


## 生成根证书和私钥

运行以下命令生成根证书和私钥：

```shell
minica
```

生成的文件：
- `minica.pem`：根证书
- `minica-key.pem`：根证书的私钥


## 为本地开发域生成证书

以 `example.local` 为例，生成域名证书：

```shell
minica --domains example.local
```

生成的目录结构：

```shell
.
├── example.local/
│   ├── cert.pem         # 域名证书
│   └── key.pem          # 域名证书的私钥
├── minica.pem           # 根证书
└── minica-key.pem       # 根证书的私钥
```


## 安装根证书

### macOS

1. 打开 **钥匙串访问** (Keychain Access)。
2. 选择 `文件 -> 导入项目`，导入 `minica.pem`。
3. 在 **系统** 钥匙串中找到导入的证书，右键选择 `获取信息`。
4. 在 **信任** 部分，将 `使用此证书时` 设置为 `始终信任`。


### Windows

1. 双击 `minica.pem` 文件启动证书安装向导。
2. 选择 `本地计算机`，点击 `下一步`。
3. 选择 `将所有的证书放入下列存储`，点击 `浏览`。
4. 选择 `受信任的根证书颁发机构`，完成安装。


### Linux (CentOS/Debian)

1. 将根证书复制到系统证书目录：
   ```shell
   sudo cp minica.pem /usr/local/share/ca-certificates/minica.crt
   ```
2. 更新系统证书存储：
   ```shell
   sudo update-ca-certificates  # Debian 系列
   sudo update-ca-trust         # CentOS 系列
   ```


## 配置本地开发服务器

以 NGINX 为例，配置 HTTPS 服务：

```shell
server {
    listen 443 ssl;
    server_name example.local;

    ssl_certificate /path/to/example.local/cert.pem;
    ssl_certificate_key /path/to/example.local/key.pem;

    location / {
        proxy_pass http://127.0.0.1:3000;  # 替换为实际的服务地址
    }
}

server {
    listen 80;
    server_name example.local;
    return 301 https://$host$request_uri;
}
```

重启 NGINX：
```shell
sudo systemctl restart nginx
```


## 修改 `hosts` 文件

为确保浏览器可以解析 `example.local`，需要更新 `hosts` 文件。

### macOS / Linux

编辑 `hosts` 文件：
```shell
sudo vim /etc/hosts
```

添加以下内容：
```
127.0.0.1 example.local
```

保存并退出。


### Windows

1. 打开 **记事本**（管理员权限）。
2. 编辑文件 `C:\Windows\System32\drivers\etc\hosts`。
3. 添加以下内容：
   ```bash
   127.0.0.1 example.local
   ```
4. 保存文件。


## 访问本地站点

在浏览器中访问 `https://example.local`。如果根证书已正确安装，你将不会看到任何安全警告。


### 注意事项

1. **证书安全性**：妥善保存私钥文件（如 `minica-key.pem` 和 `example.local/key.pem`），避免泄露。
2. **域名管理**：避免使用通用域名（如 `example.com`），推荐使用 `.local` 或 `.test` 后缀。
3. **适配性**：如需在多个系统间共享证书，请确保根证书和域名证书的路径一致。