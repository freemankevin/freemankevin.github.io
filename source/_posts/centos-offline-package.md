---
title: CentOS 系统下制作离线安装包
date: 2024-12-20 12:17:25
tags:
    - Yum
    - Offline
    - CentOS
category: Linux
---

在企业内网环境、安全隔离网络或无互联网连接的场景中，CentOS/RHEL 系统的离线包管理是运维工程师的核心技能。本文详细介绍如何在 CentOS 系列操作系统上创建、管理和使用离线安装包，包括依赖解析、本地 YUM 仓库构建、批量部署等完整流程，并提供自动化脚本和最佳实践指导，帮助你实现高效可靠的离线软件部署。

<!-- more -->

## 离线安装概述

### 适用场景

1. **企业内网环境**
   - 生产服务器无法访问外网
   - 金融、政府等行业合规要求
   - 数据中心安全隔离要求

2. **特殊环境需求**
   - 远程站点或分支机构部署
   - 军工保密网络环境
   - 灾备系统快速恢复

3. **运维场景**
   - 系统初始化批量部署
   - 版本标准化管理
   - 应急修复和补丁安装

### 技术架构

离线包管理涉及以下核心组件：

- **YUM 包管理器**: CentOS/RHEL 的高级包管理工具
- **rpm**: 底层包管理工具，处理单个 .rpm 文件
- **createrepo**: 创建 YUM 仓库索引工具
- **本地仓库**: 存放离线 RPM 包的目录，包含 repodata 索引
- **依赖解析**: YUM 自动处理包之间的依赖关系

## 准备工作

### 环境要求

1. **联网机器**
   - CentOS/RHEL 系统（推荐 7.x 或 8.x）
   - 与目标机器相同的系统版本
   - 充足的磁盘空间存储下载包
   - 移动存储设备（USB/移动硬盘）

2. **离线机器**
   - 与联网机器系统版本一致
   - root 或 sudo 权限
   - 移动存储设备接口

### 版本匹配注意事项

**重要**: 离线包必须在相同版本的系统上制作和使用，否则会出现依赖冲突和兼容性问题。

```bash
# 检查系统版本
cat /etc/centos-release
cat /etc/redhat-release

# 检查系统架构
uname -m

# 检查内核版本
uname -r

# 确保两台机器版本一致
rpm -qa | grep centos-release
```

### YUM 仓库配置

确保联网机器的 YUM 仓库配置正确：

```bash
# 检查 YUM 仓库
yum repolist

# 备份原有仓库配置
cp -r /etc/yum.repos.d/ /etc/yum.repos.d.backup

# 清理缓存
yum clean all
yum makecache
```

## 方法一：下载单个软件包

### 下载软件包及其依赖

使用 YUM 的下载功能获取软件包及其所有依赖：

```bash
# 创建下载目录
mkdir -p /data/offline-packages

# 下载指定软件包及依赖
yum install --downloadonly --downloaddir=/data/offline-packages httpd

# 查看下载的包
ls -lh /data/offline-packages/
```

**参数说明**:
- `--downloadonly`: 只下载不安装
- `--downloaddir`: 指定下载目录
- YUM 会自动下载该软件的所有依赖项

### 创建本地 YUM 仓库

使用 `createrepo` 创建仓库索引：

```bash
# 安装 createrepo（如果未安装）
yum install -y createrepo

# 进入包目录
cd /data/offline-packages

# 创建仓库索引
createrepo .

# 验证索引文件
ls -l repodata/
```

**repodata 目录作用**:
- 包含 repomd.xml 主索引文件
- 记录所有包的元数据信息
- YUM 通过索引解析包的依赖关系

### 打包下载目录

将离线包目录打包以便传输：

```bash
# 打包目录
tar -czvf httpd-offline.tar.gz -C /data/offline-packages .

# 验证打包文件
tar -tzvf httpd-offline.tar.gz | head -20

# 查看文件大小
ls -lh httpd-offline.tar.gz
```

## 方法二：批量下载多个软件包

### 创建下载列表

创建包含所有需要软件包名称的文件：

```bash
# 创建包列表文件
cat > packages-list.txt << EOF
httpd
nginx
mariadb-server
php
php-mysqlnd
docker-ce
docker-ce-cli
containerd.io
EOF

# 或者从已安装系统导出
rpm -qa > packages-list.txt
```

### 批量下载脚本

使用自动化脚本批量下载所有包及其依赖：

```bash
#!/bin/bash
# offline-package-downloader.sh

PACKAGES_LIST="packages-list.txt"
DOWNLOAD_DIR="/data/offline-packages"

# 创建下载目录
mkdir -p "${DOWNLOAD_DIR}"

# 清理YUM缓存
yum clean all

# 批量下载
while read package; do
    echo "Downloading package: ${package}"
    yum install --downloadonly --downloaddir="${DOWNLOAD_DIR}" -y "${package}" || {
        echo "Failed to download: ${package}"
        continue
    }
done < "${PACKAGES_LIST}"

# 创建仓库索引
createrepo "${DOWNLOAD_DIR}"

echo "Offline packages created successfully!"
echo "Total packages: $(ls -1 ${DOWNLOAD_DIR}/*.rpm | wc -l)"
```

### 执行下载

```bash
# 添加执行权限
chmod +x offline-package-downloader.sh

# 执行脚本
./offline-package-downloader.sh

# 验证下载结果
ls -lh /data/offline-packages/
createrepo --update /data/offline-packages
```

## 方法三：同步远程仓库

### 使用 reposync 工具

同步完整的 YUM 仓库到本地：

```bash
# 安装 reposync
yum install -y yum-utils

# 查看可用仓库
yum repolist

# 同步指定仓库
reposync --repoid=base --download_path=/data/mirror/

# 同步多个仓库
reposync --repoid=base,updates,extras --download_path=/data/mirror/

# 创建仓库索引
for repo in base updates extras; do
    createrepo /data/mirror/${repo}/
done
```

### 使用镜像站同步

从国内镜像站同步 CentOS 仓库：

```bash
# 使用阿里云镜像
rsync -avz --delete \
    rsync://mirrors.aliyun.com/centos/7.9.2009/ \
    /data/centos-mirror/

# 创建索引
createrepo /data/centos-mirror/

# 更新索引
createrepo --update /data/centos-mirror/
```

## 离线安装步骤

### 传输离线包到目标机器

将打包的离线包文件传输到离线的 CentOS 系统：

```bash
# 挂载 USB 设备（如需要）
mkdir -p /mnt/usb
mount /dev/sdb1 /mnt/usb

# 复制离线包文件
cp /mnt/usb/httpd-offline.tar.gz /tmp/

# 解压离线包
mkdir -p /opt/offline-repo
tar -xzvf /tmp/httpd-offline.tar.gz -C /opt/offline-repo

# 验证解压结果
ls -lh /opt/offline-repo/
```

### 配置本地 YUM 仓库

创建 YUM 仓库配置文件：

```bash
# 创建仓库配置
cat > /etc/yum.repos.d/local-offline.repo << EOF
[local-offline]
name=Local Offline Repository
baseurl=file:///opt/offline-repo
enabled=1
gpgcheck=0
EOF

# 解释配置参数
# [local-offline]: 仓库ID，唯一标识
# name: 仓库描述名称
# baseurl: 仓库路径，file://表示本地路径
# enabled: 是否启用仓库（1=启用）
# gpgcheck: 是否检查GPG签名（0=不检查）
```

### 更新 YUM 缓存

更新本地 YUM 软件包索引：

```bash
# 清理所有缓存
yum clean all

# 生成新的缓存
yum makecache

# 查看本地仓库
yum repolist | grep local

# 查看可用包
yum list available | grep httpd
```

### 安装软件包

使用 YUM 从本地仓库安装软件：

```bash
# 禁用其他仓库，只使用本地仓库
yum install --disablerepo='*' --enablerepo='local-offline' httpd

# 安装多个包
yum install --disablerepo='*' --enablerepo='local-offline' \
    httpd nginx mariadb-server

# 查看安装状态
rpm -qa | grep httpd

# 验证服务状态
systemctl status httpd
```

## 高级技巧

### 依赖冲突处理

遇到依赖问题时的解决方案：

```bash
# 查看包依赖关系
yum deplist httpd

# 查看依赖包是否可用
yum list available | grep dependency-package

# 强制安装（不推荐）
rpm -ivh --nodeps package.rpm

# 修复依赖关系
yum install --skip-broken package-name

# 使用 yum-utils 解决依赖
yum install -y yum-utils
yumdownloader --resolve --destdir=/tmp/packages httpd
```

### 包版本锁定

防止包被意外升级：

```bash
# 安装版本锁定插件
yum install -y yum-plugin-versionlock

# 锁定包版本
yum versionlock add httpd

# 查看锁定列表
yum versionlock list

# 清除锁定
yum versionlock clear
```

### 离线系统更新

创建系统更新离线包：

```bash
# 在联网机器上
yum update --downloadonly --downloaddir=/data/update-packages

# 打包更新文件
tar -czvf system-update.tar.gz -C /data/update-packages .

# 在离线机器上更新
yum update --disablerepo='*' --enablerepo='local-offline'
```

### ISO 镜像方式

使用 CentOS ISO 镜像作为离线源：

```bash
# 挂载 ISO 镜像
mount -o loop CentOS-7.9.iso /mnt/cdrom

# 配置本地源
cat > /etc/yum.repos.d/cdrom.repo << EOF
[cdrom]
name=CentOS-7.9 ISO Repository
baseurl=file:///mnt/cdrom
enabled=1
gpgcheck=0
EOF

# 使用ISO源安装
yum install --disablerepo='*' --enablerepo='cdrom' httpd
```

## 自动化部署脚本

完整的离线包管理自动化脚本：

```bash
#!/bin/bash
# complete-offline-deployment.sh

REPO_DIR="/opt/offline-repo"
USB_MOUNT="/mnt/usb"
PACKAGE_FILE="offline-packages.tar.gz"

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# 检查环境
check_environment() {
    log_info "检查系统环境..."
    
    # 检查root权限
    if [ "$EUID" -ne 0 ]; then 
        log_error "请使用root权限运行"
        exit 1
    fi
    
    # 检查USB挂载
    if ! mount | grep -q "$USB_MOUNT"; then
        log_info "挂载USB设备..."
        mkdir -p "$USB_MOUNT"
        
        # 自动检测USB设备
        USB_DEVICE=$(lsblk -o KNAME,TYPE,MOUNTPOINT | grep disk | awk '{print $1}' | head -1)
        mount "/dev/${USB_DEVICE}" "$USB_MOUNT" || {
            log_error "无法挂载USB设备"
            exit 1
        }
    fi
    
    log_info "环境检查完成"
}

# 解压离线包
extract_packages() {
    log_info "解压离线包..."
    
    mkdir -p "$REPO_DIR"
    
    if [ -f "${USB_MOUNT}/${PACKAGE_FILE}" ]; then
        tar -xzvf "${USB_MOUNT}/${PACKAGE_FILE}" -C "$REPO_DIR" || {
            log_error "解压失败"
            exit 1
        }
        
        PACKAGE_COUNT=$(ls -1 "$REPO_DIR/*.rpm" 2>/dev/null | wc -l)
        log_info "已解压 $PACKAGE_COUNT 个软件包"
    else
        log_error "未找到离线包文件: ${USB_MOUNT}/${PACKAGE_FILE}"
        exit 1
    fi
}

# 配置YUM源
configure_yum_repo() {
    log_info "配置本地YUM源..."
    
    # 备份原有配置
    if [ -d /etc/yum.repos.d.backup ]; then
        log_warn "备份目录已存在"
    else
        cp -r /etc/yum.repos.d/ /etc/yum.repos.d.backup
    fi
    
    # 创建本地源配置
    cat > /etc/yum.repos.d/local-offline.repo << EOF
[local-offline]
name=Local Offline Repository
baseurl=file://${REPO_DIR}
enabled=1
gpgcheck=0
EOF
    
    log_info "YUM源配置完成"
}

# 更新YUM缓存
update_yum_cache() {
    log_info "更新YUM软件包索引..."
    
    yum clean all || {
        log_error "清理缓存失败"
        exit 1
    }
    
    yum makecache || {
        log_error "生成缓存失败"
        exit 1
    }
    
    log_info "YUM索引更新完成"
}

# 安装软件包
install_packages() {
    log_info "安装软件包..."
    
    # 从文件读取包列表
    if [ -f "${USB_MOUNT}/packages-list.txt" ]; then
        PACKAGES=$(cat "${USB_MOUNT}/packages-list.txt")
        
        for package in $PACKAGES; do
            log_info "安装: $package"
            yum install --disablerepo='*' --enablerepo='local-offline' -y "$package" || {
                log_error "安装失败: $package"
                # 继续安装下一个包
                continue
            }
        done
    else
        log_warn "未找到包列表文件，使用默认安装"
        yum install --disablerepo='*' --enablerepo='local-offline' -y \
            httpd nginx mariadb-server || {
            log_error "默认包安装失败"
            exit 1
        }
    fi
    
    log_info "软件包安装完成"
}

# 验证安装
verify_installation() {
    log_info "验证安装..."
    
    # 检查已安装包
    rpm -qa | grep -E 'httpd|nginx|mariadb'
    
    # 检查服务状态
    for service in httpd nginx mariadb; do
        if systemctl is-enabled "$service" &>/dev/null; then
            log_info "$service 服务已启用"
        fi
    done
    
    log_info "安装验证完成"
}

# 生成安装报告
generate_report() {
    log_info "生成安装报告..."
    
    REPORT_FILE="/var/log/offline-install-report.log"
    
    cat > "$REPORT_FILE" << EOF
========================================
离线安装报告
========================================
时间: $(date '+%Y-%m-%d %H:%M:%S')
系统: $(cat /etc/centos-release)
内核: $(uname -r)
架构: $(uname -m)

已安装软件包:
$(rpm -qa | grep -E 'httpd|nginx|mariadb')

服务状态:
$(systemctl list-unit-files | grep -E 'httpd|nginx|mariadb')

========================================
EOF
    
    log_info "报告已保存到: $REPORT_FILE"
}

# 主执行流程
main() {
    log_info "开始离线部署..."
    
    check_environment
    extract_packages
    configure_yum_repo
    update_yum_cache
    install_packages
    verify_installation
    generate_report
    
    log_info "离线部署完成！"
}

# 执行主函数
main
```

## 最佳实践

### 版本管理

1. **建立版本库**
   - 为不同 CentOS 版本创建独立目录
   - 标注系统版本和架构信息
   - 定期更新和维护

2. **包分类存储**
   ```
   offline-packages/
   ├── centos7-amd64/
   │   ├── base-packages/
   │   ├── web-packages/
   │   ├── database-packages/
   │   └── development-packages/
   ├── centos8-amd64/
   └── centos7-arm64/
   ```

3. **版本标记**
   ```bash
   # 创建版本标记文件
   echo "CentOS 7.9.2009 x86_64" > /data/offline-packages/VERSION
   
   # 记录包创建时间
   date '+%Y-%m-%d %H:%M:%S' > /data/offline-packages/CREATED_AT
   ```

### 安全考虑

1. **包完整性验证**
   ```bash
   # 验证RPM包完整性
   rpm -K package.rpm
   
   # 检查包签名
   rpm --checksig package.rpm
   
   # 导入GPG密钥
   rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
   ```

2. **权限管理**
   ```bash
   # 设置合适的权限
   chmod 755 /opt/offline-repo
   chmod 644 /opt/offline-repo/*.rpm
   chown root:root /opt/offline-repo
   ```

3. **访问控制**
   ```bash
   # 限制仓库访问
   setfacl -m u:deploy:r /opt/offline-repo
   setfacl -m g:admin:rwx /opt/offline-repo
   ```

### 维护建议

1. **定期更新**
   ```bash
   # 创建更新脚本
   cat > /usr/local/bin/update-offline-repo.sh << 'EOF'
   #!/bin/bash
   REPO_DIR="/data/offline-packages"
   LOG_FILE="/var/log/offline-repo-update.log"
   
   echo "$(date): 开始更新离线仓库" >> "$LOG_FILE"
   
   # 更新仓库索引
   createrepo --update "$REPO_DIR"
   
   # 验证更新
   yum repolist | grep local-offline
   
   echo "$(date): 更新完成" >> "$LOG_FILE"
   EOF
   
   chmod +x /usr/local/bin/update-offline-repo.sh
   
   # 添加定时任务
   echo "0 2 * * 0 /usr/local/bin/update-offline-repo.sh" >> /var/spool/cron/root
   ```

2. **文档记录**
   - 维护包列表清单
   - 记录安装步骤和配置
   - 保存问题解决方案
   - 定期审查和更新文档

3. **测试验证**
   ```bash
   # 在测试环境验证离线包
   yum install --downloadonly --downloaddir=/tmp/test httpd
   yum install --disablerepo='*' --enablerepo='local-offline' httpd
   
   # 运行集成测试
   systemctl start httpd
   curl http://localhost
   ```

## 常见问题排查

### 问题1：依赖缺失

**现象**: 安装时提示缺少依赖包

**解决方案**:
```bash
# 查看缺失依赖
yum deplist package-name

# 补充下载缺失依赖
yum install --downloadonly --downloaddir=/data/missing-deps dependency-package

# 更新仓库索引
createrepo --update /opt/offline-repo

# 重新安装
yum install --disablerepo='*' --enablerepo='local-offline' package-name
```

### 问题2：版本冲突

**现象**: 系统版本与包版本不匹配

**解决方案**:
```bash
# 检查系统版本
cat /etc/centos-release

# 检查包要求的版本
rpm -qip package.rpm | grep Distribution

# 重新下载匹配版本的包
# 使用正确的系统版本制作离线包
```

### 问题3：架构不匹配

**现象**: 提示架构不兼容

**解决方案**:
```bash
# 检查系统架构
uname -m

# 检查包架构
rpm -qip package.rpm | grep Architecture

# 下载正确架构的包
# x86_64: 64位Intel/AMD
# i386/i686: 32位Intel/AMD
# aarch64: ARM 64位
```

### 问题4：仓库索引损坏

**现象**: YUM 无法识别本地包

**解决方案**:
```bash
# 清理索引目录
rm -rf /opt/offline-repo/repodata/

# 重新生成索引
createrepo /opt/offline-repo

# 清理YUM缓存
yum clean all
yum makecache

# 验证仓库
yum repolist | grep local-offline
```

### 问题5：GPG签名错误

**现象**: 提示GPG签名验证失败

**解决方案**:
```bash
# 禁用GPG检查
sed -i 's/gpgcheck=1/gpgcheck=0/' /etc/yum.repos.d/local-offline.repo

# 或者导入GPG密钥
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

# 重新安装
yum install package-name
```

## 与 Debian/Ubuntu 离线包对比

| 特性 | CentOS/RHEL | Debian/Ubuntu |
|------|-------------|---------------|
| 包管理器 | yum/rpm | apt/dpkg |
| 包格式 | .rpm | .deb |
| 仓库工具 | createrepo | dpkg-scanpackages |
| 依赖解析 | 自动解析 | 自动解析 |
| 索引文件 | repodata/ | Packages.gz |
| 同步工具 | reposync | apt-mirror |
| 配置文件 | .repo | sources.list |

## 生产环境建议

### 规范化流程

1. **制定离线包管理规范**
   - 明确包制作流程和标准
   - 规定版本管理策略
   - 建立测试验证机制

2. **建立离线包库**
   - 集中存储和管理离线包
   - 定期更新和维护
   - 提供统一的访问接口

3. **自动化部署**
   - 开发自动化部署脚本
   - 集成到运维平台
   - 记录部署日志和报告

### 监控和告警

```bash
# 监控离线包仓库状态
cat > /usr/local/bin/monitor-offline-repo.sh << 'EOF'
#!/bin/bash
REPO_DIR="/opt/offline-repo"
ALERT_EMAIL="admin@example.com"

# 检查仓库完整性
if [ ! -d "$REPO_DIR/repodata" ]; then
    echo "离线仓库索引丢失" | mail -s "离线仓库告警" "$ALERT_EMAIL"
fi

# 检查磁盘空间
USAGE=$(df -h "$REPO_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $USAGE -gt 80 ]; then
    echo "离线仓库磁盘使用率 $USAGE%" | mail -s "磁盘空间告警" "$ALERT_EMAIL"
fi

# 检查包数量
PACKAGE_COUNT=$(ls -1 "$REPO_DIR/*.rpm" 2>/dev/null | wc -l)
echo "当前包数量: $PACKAGE_COUNT"
EOF

chmod +x /usr/local/bin/monitor-offline-repo.sh

# 添加定时监控
echo "*/30 * * * * /usr/local/bin/monitor-offline-repo.sh" >> /var/spool/cron/root
```

## 总结

CentOS/RHEL 系统的离线包管理是企业内网环境运维的核心技能。通过本文的详细指导，你掌握了：

1. **多种离线包制作方法** - 单包下载、批量下载、仓库同步
2. **完整的部署流程** - 从制作到安装的端到端过程
3. **自动化脚本应用** - 提高效率，减少人工错误
4. **最佳实践和问题排查** - 确保离线部署的可靠性
5. **生产环境规范** - 建立标准化的管理体系

掌握这些技能后，你可以在各种受限网络环境中高效地进行软件部署和管理，为企业的安全运维提供可靠保障。

**相关资源**:
- [CentOS 官方文档](https://docs.centos.org/)
- [YUM 包管理器指南](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/system_administrators_guide/ch-yum)
- [createrepo 项目](http://createrepo.baseurl.org/)

