---
title: Jenkins 部署与使用教程
date: 2025-01-13 16:05:25
tags:
    - Development
    - Linux
    - Jenkins
category: Development
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;本篇文章详细介绍了Jenkins的部署与使用教程，涵盖了从基础部署配置、系统核心配置、流水线配置到高级特性配置的完整指南。文章分为六大部分，包括基础部署、系统配置、流水线配置、高级特性、运维管理和最佳实践，并提供了大量实用的代码示例和配置说明。无论是Jenkins新手还是有经验的DevOps工程师，都能从本文中找到有价值的内容，帮助更好地使用Jenkins进行持续集成和持续部署。

<!-- more -->


## 基础部署配置

### 前提条件

1. Docker 已安装
2. Docker Compose 已安装
3. 最小系统配置要求:
   - CPU: 2核心
   - 内存: 4GB
   - 磁盘: 50GB

### 版本选择

建议选择 LTS 版本，并且使用与 Jenkins 兼容的 JDK 版本。



例如，可以选择使用 Docker 镜像 `jenkins/jenkins:2.452.2-lts-jdk17`，该镜像基于 Java 17，确保了良好的性能和最新的安全特性。

### Docker Compose 部署

**创建配置文件**

1. 创建 `docker-compose.yml` 文件：

```yaml
services:
  jenkins:
    image: jenkins/jenkins:2.452.2-lts-jdk17 
    container_name: jenkins
    environment:
      JAVA_OPTS: "-Djenkins.install.runSetupWizard=false -Dhudson.PluginManager.noPluginExtensions=true"
      TZ: "Asia/Shanghai"
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock
      - /data/jenkins:/var/jenkins_home
    restart: always
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/login"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

**启动服务**

1. 创建数据目录并设置权限:

```bash
mkdir -p /data/jenkins
chown 1000:1000 /data/jenkins
```

2. 启动服务:

```bash
docker compose up -d
```

3. 检查服务状态:

```bash
docker compose ps
docker compose logs -f
```

### 初始化配置

**系统登录**

1. 访问 Jenkins 网址: `http://<your-server-ip>:8080`
2. 获取初始密码:

```bash
cat /data/jenkins/secrets/initialAdminPassword
```

**基础设置**

1. 选择自定义安装插件
2. 创建管理员账号（建议使用: admin/Admin@123.com）
3. 配置访问地址（保持默认）

### 插件管理

**核心插件安装**

建议安装以下基础插件：

1. **Pipeline**: 流水线核心插件
2. **GitLab**: GitLab 集成插件
3. **Publish Over SSH**: SSH 发布插件
4. **File Parameter**: 文件参数插件
5. **Role-Based Strategy**: 权限管理插件
6. **Docker Pipeline**: Docker 集成插件
7. **Blue Ocean**: 现代化界面插件
8. **Kubernetes**: K8s集成插件

**插件安装方式**

1. 在线安装:

```text
Manage Jenkins > Plugins > Available plugins
```

2. 离线安装:

```bash
# 下载插件(.hpi文件)到 /data/jenkins/plugins/
chown 1000:1000 /data/jenkins/plugins/*.hpi
# 重启Jenkins
docker compose restart jenkins
```

**插件更新策略**

1. 定期检查更新
2. 优先更新安全相关插件
3. 重要插件版本变更需要测试
4. 建议配置插件更新源:

```text
Manage Jenkins > Manage Plugins > Advanced > Update Site
https://mirrors.tuna.tsinghua.edu.cn/jenkins/updates/update-center.json
```

## 系统核心配置

### 系统基础设置

**全局工具配置**

1. JDK配置:

```text
Manage Jenkins > Global Tool Configuration > JDK
- Name: JDK17
- JAVA_HOME: /opt/java/openjdk
```

2. Maven配置:

```text
Manage Jenkins > Global Tool Configuration > Maven
- Name: Maven3
- Install automatically: 选中
- Version: 3.8.4
```

3. Git配置:

```text
Manage Jenkins > Global Tool Configuration > Git
- Name: Default
- Path to Git executable: git
```

**系统配置**

1. 执行器数量设置:

```text
Manage Jenkins > System Configuration > Configure System
Number of executors: 根据服务器CPU核心数设置(建议: CPU核心数 - 1)
```

2. 构建任务配置:

```text
- 默认构建保留策略: 保留最近10次
- 工作空间清理策略: 每次构建后清理
```

### 安全配置

**认证配置**

1. 基于数据库认证:

```text
Manage Jenkins > Security > Configure Global Security
Security Realm: Jenkins' own user database
```

2. LDAP认证配置:

```text
Security Realm: LDAP
- Server: ldap://ldap.example.com:389
- Root DN: dc=example,dc=com
- User search base: ou=users
- Group search base: ou=groups
```

**授权配置**

1. 基于角色的权限控制:

```text
Authorization: Role-Based Strategy
```

2. 角色定义:

```groovy
// 全局角色
globalRoles.create('admin', [
    'Overall/Administer',
    'Overall/Read',
    'Job/Create',
    'Job/Delete',
    'Job/Configure'
])

// 项目角色
projectRoles.create('developer', 'project-.*', [
    'Job/Build',
    'Job/Read',
    'Job/Workspace'
])

// 只读角色
globalRoles.create('viewer', [
    'Overall/Read',
    'Job/Read'
])
```

### 节点管理

**主节点配置**

1. 资源限制:

```text
Manage Jenkins > System Configuration > Configure System
- 工作目录: /var/jenkins_home/workspace
- 构建历史: 保留30天
```

2. 标签配置:

```text
Labels: master-node
Usage: 尽可能使用
```

**从节点配置**

1. 添加节点:

```text
Manage Jenkins > Nodes > New Node
- Node name: slave-01
- Type: Permanent Agent
```

2. 节点配置:

```yaml
Remote root directory: /data/jenkins/agent
Labels: slave-node docker kubernetes
Launch method: Launch agent via SSH
Host: slave-node-ip
Credentials: SSH Username with private key
```

3. Docker Agent配置:

```yaml
version: '3.8'
services:
  jenkins-agent:
    image: jenkins/inbound-agent:latest-jdk17
    container_name: jenkins-agent
    environment:
      JENKINS_URL: "http://jenkins-master:8080"
      JENKINS_SECRET: "${AGENT_SECRET}"
      JENKINS_AGENT_NAME: "docker-agent"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /data/jenkins-agent:/home/jenkins/agent
    restart: unless-stopped
```

### 凭证管理

**凭证类型**

1. 用户名密码:

```text
Kind: Username with password
Scope: Global
ID: gitlab-auth
Description: GitLab访问凭证
```

2. SSH密钥:

```text
Kind: SSH Username with private key
Scope: Global
ID: ssh-deploy-key
Description: 部署服务器SSH密钥
```

3. Secret文本:

```text
Kind: Secret text
Scope: Global
ID: api-token
Description: API访问令牌
```

**凭证使用**

1. 在Pipeline中使用:

```groovy
withCredentials([
    usernamePassword(
        credentialsId: 'gitlab-auth',
        usernameVariable: 'GITLAB_USER',
        passwordVariable: 'GITLAB_PASS'
    )
]) {
    sh """
        git clone https://${GITLAB_USER}:${GITLAB_PASS}@gitlab.example.com/project.git
    """
}
```

### 视图管理

**视图类型**

1. 列表视图:

```text
New View > List View
- Name: Backend Projects
- Job Filters: 
  - Job name pattern: backend-.*
```

2. 我的视图:

```text
New View > My View
- Name: My Tasks
```

3. 仪表板视图:

```text
New View > Dashboard View
- Name: Project Status
- 显示内容:
  - Build History
  - Build Statistics
  - Jenkins Jobs Statistics
```

## 流水线配置

### 基础流水线

**Pipeline语法**

1. 声明式Pipeline基本结构:

```groovy
pipeline {
    agent any
    
    environment {
        JAVA_HOME = '/usr/local/jdk17'
        MAVEN_HOME = '/usr/local/maven'
    }
    
    stages {
        stage('检出代码') {
            steps {
                git branch: 'main', 
                    url: 'https://gitlab.example.com/project.git'
            }
        }
        
        stage('编译构建') {
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }
        
        stage('单元测试') {
            steps {
                sh 'mvn test'
            }
            post {
                always {
                    junit '**/target/surefire-reports/*.xml'
                }
            }
        }
    }
    
    post {
        success {
            echo '构建成功'
        }
        failure {
            echo '构建失败'
        }
    }
}
```

2. 脚本式Pipeline示例:

```groovy
node {
    def mvnHome = tool 'Maven3'
    
    stage('检出代码') {
        git 'https://gitlab.example.com/project.git'
    }
    
    stage('编译构建') {
        sh "${mvnHome}/bin/mvn clean package"
    }
}
```

### Pipeline共享库

**共享库配置**

1. 创建共享库仓库结构:

```
├── src                     # Java源码目录
│   └── org/devops/utils
│       ├── Builder.groovy
│       └── Deploy.groovy
├── vars                    # Pipeline脚本目录
│   ├── buildJava.groovy
│   ├── buildNode.groovy
│   └── k8sDeploy.groovy
└── resources               # 资源文件目录
    └── templates
        ├── deployment.yaml
        └── service.yaml
```

2. 配置共享库:

```groovy
// 在Jenkins系统配置中添加
library identifier: 'jenkins-shared-lib@master',
        retriever: modernSCM([
            $class: 'GitSCMSource',
            remote: 'https://gitlab.example.com/devops/jenkins-shared-lib.git',
            credentialsId: 'gitlab-credentials'
        ])
```

3. 共享库使用示例:

```groovy
@Library('jenkins-shared-lib') _

pipeline {
    agent any
    stages {
        stage('构建') {
            steps {
                buildJava(
                    jdkVersion: '17',
                    mvnGoals: 'clean package'
                )
            }
        }
        stage('部署') {
            steps {
                k8sDeploy(
                    namespace: 'production',
                    appName: 'demo-app'
                )
            }
        }
    }
}
```

### 多分支流水线

**配置示例**

1. 分支发现配置:

```groovy
properties([
    pipelineTriggers([
        [$class: 'GitLabPushTrigger',
         branchFilterType: 'All',
         triggerOnPush: true,
         triggerOnMergeRequest: true,
         triggerOpenMergeRequestOnPush: "never",
         triggerOnNoteRequest: true,
         noteRegex: "Jenkins please retry",
         skipWorkInProgressMergeRequest: true,
         secretToken: "YOUR-TOKEN-HERE",
         ciSkip: false,
         setBuildDescription: true,
         addNoteOnMergeRequest: true,
         addCiMessage: true,
         addVoteOnMergeRequest: true,
         acceptMergeRequestOnSuccess: false,
         branchFilterType: "NameBasedFilter",
         includeBranchesSpec: "main develop feature/* release/*",
         excludeBranchesSpec: ""]
    ])
])
```

2. 环境配置:

```groovy
pipeline {
    agent any
    
    environment {
        // 根据分支动态设置环境变量
        DEPLOY_ENV = "${BRANCH_NAME == 'main' ? 'prod' : 
                      BRANCH_NAME == 'develop' ? 'test' : 'dev'}"
    }
    
    stages {
        stage('部署') {
            steps {
                script {
                    // 根据环境选择不同的部署策略
                    switch(env.DEPLOY_ENV) {
                        case 'prod':
                            deployToProd()
                            break
                        case 'test':
                            deployToTest()
                            break
                        default:
                            deployToDev()
                    }
                }
            }
        }
    }
}
```

## 高级特性配置

### GitLab集成

**Webhook配置**

1. GitLab系统配置:

```text
Admin Area > Settings > Network > Outbound requests
Allow requests to the local network from web hooks and services: 启用
```

2. 项目Webhook配置:

```text
Project > Settings > Webhooks
URL: http://jenkins-url/project/your-project
Secret Token: your-secret-token
Trigger:
- Push events
- Merge request events
- Tag push events
```

3. Jenkins触发器配置:

```groovy
triggers {
    gitlab(
        triggerOnPush: true,
        triggerOnMergeRequest: true,
        branchFilterType: 'All',
        secretToken: env.GITLAB_WEBHOOK_TOKEN
    )
}
```

### Docker集成

**Docker构建配置**

1. Dockerfile示例:

```dockerfile
FROM openjdk:17-jdk-slim
WORKDIR /app
COPY target/*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
```

2. Pipeline中的Docker构建:

```groovy
pipeline {
    agent any
    environment {
        DOCKER_REGISTRY = 'registry.example.com'
        IMAGE_NAME = 'demo-app'
        IMAGE_TAG = "${BUILD_NUMBER}"
    }
    stages {
        stage('构建镜像') {
            steps {
                script {
                    docker.build("${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}")
                }
            }
        }
        stage('推送镜像') {
            steps {
                script {
                    docker.withRegistry("https://${DOCKER_REGISTRY}", 'docker-registry-credentials') {
                        docker.image("${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}").push()
                        docker.image("${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}").push('latest')
                    }
                }
            }
        }
    }
}
```

### Kubernetes集成

**K8s部署配置**

1. 凭证配置:

```text
Kind: Secret file
Scope: Global
ID: k8s-config
File: ~/.kube/config
```

2. 部署脚本:

```groovy
def deployToK8s(String namespace, String deployment, String container, String image) {
    withKubeConfig([credentialsId: 'k8s-config']) {
        sh """
            kubectl -n ${namespace} set image deployment/${deployment} ${container}=${image}
            kubectl -n ${namespace} rollout status deployment/${deployment}
        """
    }
}
```

## 运维管理

### 备份策略

**配置备份**

1. 定时备份脚本:

```bash
#!/bin/bash

# 备份配置
BACKUP_ROOT="/backup/jenkins"
JENKINS_HOME="/data/jenkins"
DATE=$(date +%Y%m%d)
BACKUP_DIR="${BACKUP_ROOT}/${DATE}"
RETAIN_DAYS=30

# 创建备份目录
mkdir -p ${BACKUP_DIR}

# 备份Jenkins配置
tar -czf ${BACKUP_DIR}/jenkins_home.tar.gz ${JENKINS_HOME}

# 清理旧备份
find ${BACKUP_ROOT} -type d -mtime +${RETAIN_DAYS} -exec rm -rf {} \;
```

2. 自动备份配置:

```text
Manage Jenkins > Configure System > 定期备份
Schedule: H 0 * * *
```

### 监控告警

**监控指标**

1. 系统监控:

```text
- CPU使用率
- 内存使用率
- 磁盘使用率
- 构建队列长度
```

2. 构建监控:

```text
- 构建成功率
- 构建时长
- 测试覆盖率
- 代码质量指标
```

3. Prometheus集成:

```yaml
- job_name: 'jenkins'
  metrics_path: '/prometheus'
  static_configs:
    - targets: ['jenkins:8080']
```

### 日志管理

**日志配置**

1. 系统日志:

```text
Manage Jenkins > System Log
- Log Level: INFO
- Log Rotation: 7天
```

2. 构建日志:

```text
- 保留策略: 保留最近100次构建
- 日志轮转: 超过50MB自动归档
```

## 最佳实践

### 开发规范

1. 代码规范:

```text
- 使用声明式Pipeline
- 避免在Pipeline中硬编码配置
- 合理使用共享库
- 保持Pipeline简洁清晰
```

2. 命名规范:

```text
- 任务命名: <项目>-<环境>-<功能>
- 标签命名: role-<功能>
- 参数命名: 使用大写字母
```

### 安全建议

1. 系统安全:

```text
- 及时更新Jenkins版本
- 定期更新插件
- 使用HTTPS访问
- 启用审计日志
```

2. 权限控制:

```text
- 最小权限原则
- 定期审查权限
- 使用密钥凭证
- 避免明文密码
```

### 性能优化

1. 系统优化:

```text
- 合理设置执行器数量
- 及时清理工作空间
- 使用代理节点分担负载
- 配置构建超时时间
```

2. Pipeline优化:

```text
- 并行执行无依赖步骤
- 使用缓存加速构建
- 避免不必要的构建
- 合理使用触发器
```

### 常见问题

1. 构建失败处理:

```text
- 检查代码变更
- 查看构建日志
- 验证环境配置
- 检查资源使用
```

2. 性能问题处理:

```text
- 分析系统负载
- 检查内存使用
- 优化构建流程
- 清理历史数据
```

## 总结

Jenkins是一个强大的持续集成工具，通过合理配置和使用，可以显著提高开发团队的效率。本文档涵盖了从基础部署到高级特性的完整配置指南，希望能帮助您更好地使用Jenkins。

建议根据实际需求选择性地参考本文档中的配置，并结合团队实际情况进行调整和优化。同时，要注意持续关注Jenkins的版本更新和安全公告，确保系统的安全性和稳定性。