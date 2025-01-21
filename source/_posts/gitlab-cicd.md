---
title: GitLab 配置优化与 CICD 集成指南
date: 2025-01-21 17:32:25
tags:
    - CICD
    - Development
    - GitLab
category: Development 
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 本文档旨在提供 GitLab 配置优化、集成最佳实践、安全加固、备份与恢复策略以及监控方法，帮助团队在使用 GitLab 进行源代码管理和持续集成/持续交付（CICD）时提升性能、安全性及稳定性。

<!-- more -->

## GitLab 添加内网信任

### 目的
为 GitLab 配置内网信任，允许 GitLab 访问内网服务。

### 操作步骤
1. 进入 GitLab 管理员界面。
2. 进入设置页面，选择 **网络**。
3. 进入 **出站请求**，勾选以下选项：
   - 允许来自 **webhooks** 和集成对本地网络的请求
   - 允许系统钩子向本地网络发送请求
4. 在空白框中粘贴需要调用的内网IP、域名。
5. 登录 GitLab 服务器，编辑 **/etc/hosts** 文件，添加自定义域名映射。

```shell
192.168.x.x traefik.k8scluster.com
192.168.x.x harbor.dockerregistry.com
192.168.x.x argocd.k8scluster.com
192.168.x.x grpc.argocd.k8scluster.com
```

## GitLab 集成 ArgoCD

### 目的
通过 GitLab 与 ArgoCD 集成，实现流水线中对 ArgoCD 应用的自动化操作，同时隐藏 ArgoCD 真实服务器信息。

### 操作步骤
1. 进入项目组页面，选择 **设置** -> **CI/CD** -> **变量**。
2. 添加以下变量：
   - **ARGOCD_USERNAME**: 自定义值，勾选 Masked
   - **ARGOCD_SERVER**: 自定义值，勾选 Masked
   - **ARGOCD_PASSWORD**: 自定义值，勾选 Masked

## GitLab 集成 Minio

### 目的
将构建的制品存储到 Minio，减轻 GitLab 服务器的负担。

### 操作步骤
1. 修改 GitLab 配置文件：
   
    ```shell
    sudo vim /etc/gitlab/gitlab.rb
    gitlab_rails['artifacts_enabled'] = true
    gitlab_rails['artifacts_object_store_enabled'] = true
    gitlab_rails['artifacts_object_store_remote_directory'] = 'gitlab-artifacts'
    gitlab_rails['artifacts_object_store_connection'] = {
    'provider' => 'AWS',
    'region' => 'us-east-1',
    'aws_access_key_id' => 'your_access_key',
    'aws_secret_access_key' => 'your_secret_key',
    'endpoint' => 'http://<minio_server>:9000',
    'path_style' => true
    }
    ```

2. 重载配置：
```shell
sudo gitlab-ctl reconfigure
```

## GitLab 集成 Harbor

### 目的
将构建的 Docker 镜像直接推送到 Harbor，无需重复配置。

### 操作步骤
1. 进入 **管理界面** 或 **项目组管理界面**，选择 **设置** -> **集成**。
2. 添加 Harbor 集成，输入以下信息：
   - **域名**：Harbor 地址
   - **项目名称**：目标项目
   - **用户**：使用机器人名称
   - **用户密码**：Harbor 认证密码

## GitLab 文件大小限制调整

### 目的
调整 GitLab 上传文件的大小限制，以适应大文件的上传需求。

### 操作步骤
1. 进入 **管理员界面** 或 **项目组页面**，选择 **设置** -> **CI/CD** -> **流水线通用设置**，调整 **最大工件大小**。
2. 如果以上设置无效，修改 GitLab 服务器配置文件：
   
    ```shell
    sudo vim /etc/gitlab/gitlab.rb
    nginx['client_max_body_size'] = '200m'
    ```

3. 重载配置：
```shell
sudo gitlab-ctl reconfigure
```

## GitLab 集成 CICD

### 目的
配置 GitLab CI/CD，使机器人能够自动化更新代码。

### 操作步骤
1. 进入项目页面，选择 **设置** -> **访问令牌**，创建一个长期有效的开发者身份令牌。
2. 进入 **CI/CD** -> **变量**，添加以下变量：
   - **GITLAB_CI_TOKEN**: 自定义值，勾选 Masked

## GitLab 性能优化

### 目的
优化 GitLab 性能，提高并发处理能力，减少响应时间。

### 操作步骤
1. **优化数据库**：调整 PostgreSQL 配置，增加 `shared_buffers` 和 `work_mem` 设置：
   
```shell
sudo vim /etc/gitlab/postgresql.conf
shared_buffers = 1GB
work_mem = 64MB
```

2. **启用 Redis 缓存**：配置 GitLab 使用 Redis 缓存：
   
```shell
sudo vim /etc/gitlab/gitlab.rb
gitlab_rails['redis_host'] = 'localhost'
gitlab_rails['redis_port'] = 6379
```

3. **使用 SSD 存储**：为 GitLab 配置 SSD 存储，提高 I/O 性能。

4. **优化 Nginx 配置**：调整 Nginx 设置，提高吞吐量：
   
```shell
sudo vim /etc/gitlab/nginx/gitlab-http.conf
worker_processes auto;
worker_connections 4096;
```

5. **分离 GitLab 服务**：将 GitLab 服务分离到不同服务器，减轻单台服务器负担。

## GitLab 安全加固

### 目的
加强 GitLab 的安全性，防止潜在的安全漏洞。

### 操作步骤
1. **启用 HTTPS**：为 GitLab 配置 SSL，确保数据传输加密：
   
```shell
sudo vim /etc/gitlab/gitlab.rb
external_url 'https://gitlab.example.com'
nginx['ssl_certificate'] = "/etc/ssl/certs/gitlab.crt"
nginx['ssl_certificate_key'] = "/etc/ssl/private/gitlab.key"
```

2. **启用双因素认证（2FA）**：在 GitLab 设置页面启用 2FA。

3. **使用 LDAP 或 OAuth 实现企业认证**：
   
```shell
sudo vim /etc/gitlab/gitlab.rb
gitlab_rails['ldap_enabled'] = true
gitlab_rails['ldap_servers'] = YAML.load <<-EOS
main:
  label: 'LDAP'
  host: '_your_ldap_server_'
  port: 389
  uid: 'sAMAccountName'
  bind_dn: 'CN=bind_user,CN=Users,DC=example,DC=com'
  password: '_your_password_'
EOS
```

## GitLab 备份与恢复

### 目的
配置自动备份，以确保 GitLab 数据的安全性。

### 操作步骤
1. **配置自动备份**：

```shell
sudo vim /etc/gitlab/gitlab.rb
gitlab_rails['backup_path'] = '/var/opt/gitlab/backups'
gitlab_rails['backup_keep_time'] = 604800  # 保留7天备份

# 配置 crontab 定期备份
crontab -e
0 2 * * * gitlab-rake gitlab:backup:create
```

2. **恢复备份**：

```shell
sudo gitlab-rake gitlab:backup:restore BACKUP=timestamp_of_backup
```

3. **备份恢复测试**：定期进行恢复测试，确保备份数据可用。

## GitLab 日志与监控

### 目的
通过日志管理和监控 GitLab 服务，及时发现和解决问题。

### 操作步骤
1. **配置日志收集**：使用 `logrotate` 管理 GitLab 日志文件：
   
```shell
sudo vim /etc/logrotate.d/gitlab
/var/log/gitlab/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
```

2. **使用 Prometheus 和 Grafana 监控 GitLab**：通过 Prometheus 集成监控 GitLab 性能，使用 Grafana 展示数据。

3. **设置邮件通知**：配置 GitLab 邮件通知，及时了解系统状态。

## 结语

本文档涵盖了 GitLab 的常见配置优化、集成 CICD、备份恢复、安全加固和监控等方面。通过这些操作，您可以有效提升 GitLab 的性能、安全性和可靠性。如果您有任何问题或进一步的需求，欢迎留言讨论。