---
title: Gitlab-ce 部署与使用教程
date: 2025-01-13 16:45:25
tags:
    - Development
    - Linux
    - Gitlab
category: Development
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;本篇文章详细介绍了GitLab-CE的部署与使用教程，包括基础部署配置、系统配置、CI/CD配置、项目管理、运维管理、高可用配置、Jenkins集成、容器镜像仓库集成以及项目协作与问题管理等核心内容。文档提供了大量实用的配置示例和最佳实践建议，适合DevOps工程师和开发团队参考，帮助搭建和优化GitLab平台，提升团队开发效率。

<!-- more -->

## 基础部署配置

### 前提条件

1. 系统要求：
   - CPU: 4核心及以上
   - 内存: 8GB及以上
   - 磁盘: 50GB及以上(建议SSD)
   - 网络: 100Mbps及以上

2. 环境要求：
   - Docker 已安装(20.10.x及以上)
   - Docker Compose 已安装(2.x及以上)
   - 服务器端口要求：
     - HTTP: 80(默认)或自定义
     - HTTPS: 443(默认)或自定义
     - SSH: 22(默认)或自定义
     - 确保以上端口未被占用

### Docker Compose部署

1. 创建部署配置文件：

```yaml
services:
  gitlab:
    restart: always
    image: gitlab/gitlab-ce:16.9.9-ce.0
    container_name: gitlab
    hostname: gitlab.example.com    # 修改为实际域名
    ports:
      - "9980:80"
      - '9443:443' 
      - "9922:22"
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock
      - /data/gitlab/config:/etc/gitlab
      - /data/gitlab/data:/var/opt/gitlab
      - /data/gitlab/logs:/var/log/gitlab
    environment:
      TZ: Asia/Shanghai
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'http://gitlab.example.com:9980'
        gitlab_rails['time_zone'] = 'Asia/Shanghai'
        
        # 邮件服务配置
        gitlab_rails['smtp_enable'] = false
        gitlab_rails['gitlab_email_enabled'] = false
        gitlab_rails['incoming_email_enabled'] = false

        # 性能优化配置
        puma['worker_processes'] = 0
        puma['min_threads'] = 1
        puma['max_threads'] = 2
        sidekiq['max_concurrency'] = 5

        # 禁用不需要的服务
        gitlab_rails['registry_enabled'] = false
        gitlab_rails['packages_enabled'] = false
        gitlab_kas['enable'] = false
        gitlab_pages['enable'] = false
        prometheus_monitoring['enable'] = false

        # 数据库配置
        postgresql['shared_buffers'] = "256MB"
        postgresql['work_mem'] = "8MB"
        postgresql['maintenance_work_mem'] = "64MB"

        # Redis配置
        redis['maxmemory'] = "256mb"
        redis['maxmemory_policy'] = "allkeys-lru"
```

2. 创建必要目录并设置权限：

```bash
mkdir -p /data/gitlab/{config,data,logs}
chmod 0700 /data/gitlab/logs -R 
chown -R 998:998 /data/gitlab
```

3. 启动服务：

```bash
docker compose up -d
docker compose logs -f --tail 1000 gitlab
```

## 系统配置

### 初始化配置

1. 获取root初始密码：

```bash
docker exec -it gitlab grep 'Password:' /etc/gitlab/initial_root_password
```

2. 访问Gitlab：

```text
http://<your-gitlab-ip>:9980
```

### 基础安全配置

1. 修改root密码：
   - 登录后立即修改默认密码
   - 使用强密码策略(至少12位，包含大小写字母、数字和特殊字符)
   - 定期更换密码(建议90天)

2. 关闭注册功能：

```text
Admin Area > Settings > General > Sign-up restrictions
取消选中 "Sign-up enabled"
```

3. 配置SSH密钥：

```bash
# 生成SSH密钥
ssh-keygen -t ed25519 -C "your-email@example.com"

# 查看公钥
cat ~/.ssh/id_ed25519.pub

# 测试连接
ssh -T git@gitlab.example.com
```

### 系统优化配置

1. 关闭不必要的功能：

```text
Admin Area > Settings > General
- 关闭Gravatar
- 关闭AutoDevOps
- 禁用不必要的集成功能
```

2. 性能优化配置：

```ruby
# 在GITLAB_OMNIBUS_CONFIG中添加
# CPU优化
puma['worker_processes'] = (CPU核心数 - 1)
puma['min_threads'] = 1
puma['max_threads'] = 4

# 内存优化
unicorn['worker_memory_limit_min'] = "400MB"
unicorn['worker_memory_limit_max'] = "600MB"

# 缓存配置
gitlab_rails['redis_cache_instance'] = "redis://:password@redis:6379/1"
```

## CI/CD配置

### Runner配置

1. 安装GitLab Runner：

```bash
docker run -d --name gitlab-runner --restart always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /srv/gitlab-runner/config:/etc/gitlab-runner \
  gitlab/gitlab-runner:latest
```

2. 注册Runner：

```bash
docker exec -it gitlab-runner gitlab-runner register \
  --non-interactive \
  --url "http://gitlab.example.com:9980" \
  --registration-token "PROJECT_REGISTRATION_TOKEN" \
  --executor "docker" \
  --docker-image alpine:latest \
  --description "docker-runner" \
  --tag-list "docker,aws" \
  --run-untagged="true" \
  --locked="false" \
  --access-level="not_protected"
```

3. Runner配置优化：

```toml
concurrent = 4
check_interval = 0

[[runners]]
  name = "docker-runner"
  url = "http://gitlab.example.com:9980"
  token = "PROJECT_TOKEN"
  executor = "docker"
  [runners.docker]
    tls_verify = false
    image = "alpine:latest"
    privileged = false
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache"]
    shm_size = 0
    pull_policy = "if-not-present"
```

### CI/CD Pipeline配置

1. 基础Pipeline示例：

```yaml
# .gitlab-ci.yml
image: maven:3.8.4-openjdk-17

variables:
  MAVEN_OPTS: "-Dmaven.repo.local=.m2/repository"
  MAVEN_CLI_OPTS: "--batch-mode --errors --fail-at-end --show-version"

cache:
  paths:
    - .m2/repository/
    - target/

stages:
  - build
  - test
  - analyze
  - deploy

build:
  stage: build
  script:
    - mvn $MAVEN_CLI_OPTS clean package -DskipTests
  artifacts:
    paths:
      - target/*.jar

test:
  stage: test
  script:
    - mvn $MAVEN_CLI_OPTS test
  artifacts:
    reports:
      junit: target/surefire-reports/TEST-*.xml

sonarqube:
  stage: analyze
  script:
    - mvn sonar:sonar
  only:
    - main
    - develop

deploy:
  stage: deploy
  script:
    - ./deploy.sh
  environment:
    name: production
  when: manual
  only:
    - main
```

## 项目管理

### 分支管理

1. 分支策略：

```text
- main: 主分支，用于生产发布
- develop: 开发分支，用于功能集成
- feature/*: 功能分支，用于新功能开发
- release/*: 发布分支，用于版本发布准备
- hotfix/*: 热修复分支，用于生产问题修复
```

2. 分支保护规则：

```text
Protected Branches:
- main: 
  - 需要两人审批
  - 禁止强制推送
  - 需要通过所有CI检查
- develop:
  - 需要一人审查
  - 需要通过基本CI检查
```

### 代码审查

1. Merge Request模板：

```markdown
## 变更说明
- [ ] 功能变更
- [ ] Bug修复
- [ ] 性能优化
- [ ] 文档更新

## 测试说明
- [ ] 单元测试
- [ ] 集成测试
- [ ] 性能测试

## 检查清单
- [ ] 代码规范检查
- [ ] 测试用例覆盖
- [ ] 文档更新
```

## 运维管理

### 备份策略

1. 自动备份脚本：

```bash
#!/bin/bash
BACKUP_DIR="/backup/gitlab"
DATE=$(date +%Y%m%d)
RETENTION_DAYS=7

# 创建备份
docker exec gitlab gitlab-backup create STRATEGY=copy

# 复制备份文件
cp /data/gitlab/data/backups/*.tar ${BACKUP_DIR}/${DATE}/

# 清理旧备份
find ${BACKUP_DIR} -type d -mtime +${RETENTION_DAYS} -exec rm -rf {} \;
```

2. 配置文件备份：

```bash
#!/bin/bash
cp -r /data/gitlab/config ${BACKUP_DIR}/${DATE}/config
```

### 监控告警

1. Prometheus配置：

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'gitlab'
    static_configs:
      - targets: ['gitlab.example.com:9090']
```

2. 告警规则：

```yaml
groups:
- name: gitlab_alerts
  rules:
  - alert: HighCPUUsage
    expr: cpu_usage_idle{job="gitlab"} < 10
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High CPU usage"
```

## 最佳实践

### 安全建议

1. 访问控制：
   - 使用HTTPS
   - 启用2FA认证
   - 实施密码策略
   - 定期审计用户权限

2. 系统维护：
   - 定期更新版本
   - 监控系统资源
   - 定期清理未使用的数据
   - 配置告警机制

### 性能优化

1. 资源配置：
   - 根据负载调整worker数量
   - 优化缓存配置
   - 使用外部数据库服务
   - 配置合适的JVM参数

2. 使用建议：
   - 合理规划项目结构
   - 使用.gitignore过滤文件
   - 定期清理旧分支
   - 使用LFS存储大文件

## 高可用配置

### PostgreSQL主从配置

1. 主节点配置:

```ruby
postgresql['listen_address'] = '0.0.0.0'
postgresql['hot_standby'] = 'on'
postgresql['wal_level'] = 'replica'
postgresql['max_wal_senders'] = 10
postgresql['max_replication_slots'] = 10
postgresql['wal_keep_segments'] = 100
```

2. 从节点配置:

```ruby
postgresql['enable'] = true
postgresql['listen_address'] = '0.0.0.0'
postgresql['hot_standby'] = 'on'
postgresql['primary_conninfo'] = 'host=PRIMARY_HOST port=5432 user=gitlab_repl password=PASSWORD'
```

### Redis集群配置

1. Redis Sentinel配置:

```ruby
# 主节点配置
redis['bind'] = '0.0.0.0'
redis['port'] = 6379
redis['password'] = 'redis-password'

# Sentinel配置
sentinel['enable'] = true
sentinel['bind'] = '0.0.0.0'
sentinel['port'] = 26379
sentinel['quorum'] = 2
```

### 负载均衡配置

1. Nginx配置示例:

```nginx
upstream gitlab {
    server gitlab-1.example.com:9980;
    server gitlab-2.example.com:9980;
    server gitlab-3.example.com:9980;
}

server {
    listen 80;
    server_name gitlab.example.com;
    
    location / {
        proxy_pass http://gitlab;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## Jenkins集成

### Jenkins用户配置

1. 创建专用账号:

```text
Admin Area > Users > New user
- Username: jenkins-ci
- Name: Jenkins CI
- Access Level: Regular
```

2. 访问令牌配置:

```text
User Settings > Access Tokens
Name: jenkins-api-token
Scopes:
- api
- read_repository
- write_repository
- read_registry
- write_registry
```

3. Webhook配置:

```text
Project Settings > Webhooks
URL: https://jenkins.example.com/project/your-project
Secret Token: your-secret-token
Triggers:
- Push events
- Tag push events
- Merge request events
```

### Jenkins Pipeline集成

1. Jenkinsfile示例:

```groovy
pipeline {
    agent any
    
    environment {
        GITLAB_TOKEN = credentials('gitlab-token')
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout([$class: 'GitSCM',
                    branches: [[name: '*/main']],
                    extensions: [],
                    userRemoteConfigs: [[
                        url: 'https://gitlab.example.com/group/project.git',
                        credentialsId: 'gitlab-credentials'
                    ]]
                ])
            }
        }
        
        stage('Update Build Status') {
            steps {
                updateGitlabCommitStatus(name: 'build', state: 'running')
                script {
                    try {
                        // 构建步骤
                        updateGitlabCommitStatus(name: 'build', state: 'success')
                    } catch (exc) {
                        updateGitlabCommitStatus(name: 'build', state: 'failed')
                        throw exc
                    }
                }
            }
        }
    }
}
```

## 容器镜像仓库集成

### Harbor集成配置

1. 全局变量配置:

```text
Admin Area > Settings > CI/CD > Variables
添加以下变量:
- HARBOR_URL: https://harbor.example.com
- HARBOR_USERNAME: harbor-user
- HARBOR_PASSWORD: harbor-password
- HARBOR_PROJECT: project-name
```

2. CI/CD配置示例:

```yaml
variables:
  DOCKER_TLS_CERTDIR: ""
  HARBOR_IMAGE: ${HARBOR_URL}/${HARBOR_PROJECT}/${CI_PROJECT_NAME}

.docker_login: &docker_login
  before_script:
    - docker login -u ${HARBOR_USERNAME} -p ${HARBOR_PASSWORD} ${HARBOR_URL}

build_image:
  <<: *docker_login
  stage: build
  script:
    - docker build -t ${HARBOR_IMAGE}:${CI_COMMIT_SHA} .
    - docker push ${HARBOR_IMAGE}:${CI_COMMIT_SHA}
    - |
      if [[ "$CI_COMMIT_BRANCH" == "main" ]]; then
        docker tag ${HARBOR_IMAGE}:${CI_COMMIT_SHA} ${HARBOR_IMAGE}:latest
        docker push ${HARBOR_IMAGE}:latest
      fi
```

## 项目协作与问题管理

### Issue管理

1. Issue类型模板配置：

```yaml
# .gitlab/issue_templates/feature.yml
name: 功能需求
description: 提交新功能需求
title: "[Feature] "
labels: ["feature", "待评估"]
assignees: ["product-owner"]

body:
  - type: markdown
    attributes:
      value: "## 功能需求描述模板"
  
  - type: input
    id: business-value
    attributes:
      label: 业务价值
      description: 此功能可以解决什么问题
    validations:
      required: true

  - type: textarea
    id: detailed-description
    attributes:
      label: 详细说明
      description: 功能的具体要求
      value: |
        1. 功能点1
        2. 功能点2
    validations:
      required: true

  - type: dropdown
    id: priority
    attributes:
      label: 优先级
      options:
        - P0-紧急
        - P1-高
        - P2-中
        - P3-低
```

2. 工作流配置：

```yaml
# .gitlab/workflow.yml
workflow:
  rules:
    - if: $CI_MERGE_REQUEST_ID
      when: never
    - if: $CI_COMMIT_TAG
      when: never
    - when: always

stages:
  - triage
  - review
  - implementation
  - verification

triage:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      when: never
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      when: never
    - when: always
```

### 项目看板

1. 敏捷开发看板配置：

```yaml
board:
  name: "Sprint Board"
  lists:
    - name: "待处理"
      label: "backlog"
    - name: "开发中"
      label: "in-progress"
    - name: "待审核"
      label: "review"
    - name: "测试中"
      label: "testing"
    - name: "已完成"
      label: "done"

automation:
  - trigger: "issue.labeled"
    label: "in-progress"
    action: "move_to_list"
    target_list: "开发中"
    assign_to: "@creator"
```

### 时间管理

1. 工时跟踪配置：

```yaml
time_tracking:
  default_estimate: "4h"
  increment_minutes: 15
  time_format: "absolute"
  report_frequency: "weekly"
```

2. Sprint配置：

```yaml
sprint:
  duration: 2weeks
  start_day: monday
  planning_template: |
    ## Sprint 计划会议
    1. 回顾上个Sprint
    2. 确定本次Sprint目标
    3. 评估任务工时
    4. 分配任务责任人
```

### 团队协作

1. Code Review规则：

```yaml
review_rules:
  - name: "代码审查"
    conditions:
      min_approvals: 2
      required_reviewers:
        - tech-lead
        - senior-developer
      block_on:
        - failing_tests
        - merge_conflicts
    actions:
      auto_merge: false
      notify_channel: "#code-review"
```

2. 团队报告模板：

```markdown
## 每日站会报告

### 昨日完成
- [ ] 任务1 (2h/预估3h)
- [ ] 任务2 (4h/预估4h)

### 今日计划
1. 功能开发
   - [ ] 任务A (预估4h)
   - [ ] 任务B (预估2h)
2. 问题修复
   - [ ] Bug#123 (预估1h)

### 遇到的问题
1. 问题描述
2. 解决方案

### 需要协助
- [ ] 需求澄清
- [ ] 技术支持
```

### 度量与报告

1. 项目度量配置：

```yaml
metrics:
  cycle_time:
    enabled: true
    alert_threshold: "48h"
  
  code_quality:
    enabled: true
    minimum_coverage: 80%
    
  team_velocity:
    enabled: true
    sprint_length: 2weeks
    
  burndown:
    enabled: true
    chart_type: "story_points"
```

2. 自动化报告：

```yaml
reports:
  schedule: "0 9 * * MON"
  recipients: 
    - project-manager
    - team-lead
  format:
    - pdf
    - html
  content:
    - sprint_progress
    - issue_statistics
    - merge_request_metrics
```

## 总结

GitLab-CE是一个功能强大的代码托管和CI/CD平台，通过合理配置和优化，可以为团队提供高效稳定的开发环境。本文档涵盖了从基础部署到高级特性的完整配置指南，建议根据实际需求选择性地启用功能，并持续关注系统的性能和安全性。