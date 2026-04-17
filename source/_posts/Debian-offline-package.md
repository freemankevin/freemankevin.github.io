---
title: Debian 系统下制作离线安装包
date: 2024-12-20 12:17:25
tags:
    - Apt
    - Offline
    - Debian
category: Linux
---

在企业内网环境或安全受限的场景中，服务器往往无法直接连接互联网进行软件安装。Debian/Ubuntu 系统的离线包管理成为运维工程师必备技能。本文详细介绍如何在 Debian 系列操作系统上创建、管理和使用离线安装包，包括依赖解析、本地仓库构建、批量部署等核心流程，并提供自动化脚本和最佳实践指导。

<!-- more -->

## 离线安装概述

### 适用场景

1. **企业内网环境**
   - 生产服务器无法访问外网
   - 安全合规要求限制网络访问
   - 需要统一软件版本管理

2. **特殊环境需求**
   - 远程站点或分支机构
   - 军工或政府保密网络
   - 数据中心隔离环境

3. **应急场景**
   - 网络故障临时离线安装
   - 系统恢复和灾难恢复
   - 测试环境快速部署

### 技术架构

离线包管理涉及以下核心组件：

- **APT 包管理器**: Debian 系统的包管理工具
- **dpkg**: 底层包管理工具，处理单个 .deb 文件
- **本地仓库**: 存放离线包的目录，包含 Packages 索引
- **依赖解析**: APT 自动处理包之间的依赖关系

## 准备工作

### 环境要求

1. **联网机器**
   - Debian/Ubuntu 系统
   - 与目标机器相同的系统版本
   - 充足的磁盘空间存储下载包
   - 移动存储设备（USB/移动硬盘）

2. **离线机器**
   - 与联网机器系统版本一致
   - root 或 sudo 权限
   - 移动存储设备接口

### 版本匹配注意事项

**重要**: 离线包必须在相同版本的系统上制作和使用，否则会出现依赖冲突。

```bash
# 检查系统版本
cat /etc/os-release

# 检查系统架构
dpkg --print-architecture

# 确保两台机器版本一致
uname -a
lsb_release -a
```

## 方法一：下载单个软件包

### 下载软件包及其依赖

使用 APT 的下载功能获取软件包及其所有依赖，但不安装：

```bash
# 清理缓存（可选）
sudo apt-get clean

# 下载指定软件包及依赖
sudo apt-get install --download-only <package-name>

# 查看下载的包
ls -lh /var/cache/apt/archives/
```

**参数说明**:
- `--download-only`: 只下载不安装
- 包会下载到 `/var/cache/apt/archives/` 目录
- 包含该软件的所有依赖项

### 复制下载的包

将下载的 `.deb` 包复制到移动存储设备：

```bash
# 创建目标目录
mkdir -p /path/to/usb-drive/debian-offline-packages

# 复制所有 .deb 包
cp /var/cache/apt/archives/*.deb /path/to/usb-drive/debian-offline-packages/

# 验证复制结果
ls -l /path/to/usb-drive/debian-offline-packages/
```

### 创建本地APT仓库索引

使用 `dpkg-scanpackages` 创建 `Packages.gz` 索引文件：

```bash
# 安装工具（如果未安装）
sudo apt-get install dpkg-dev

# 进入包目录
cd /path/to/usb-drive/debian-offline-packages

# 创建索引文件
dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz

# 验证索引文件
zcat Packages.gz | head -20
```

**索引文件作用**:
- 记录每个包的名称、版本、依赖等信息
- APT 通过索引文件解析包的关系
- `gzip -9c` 提供最高压缩率

## 方法二：批量下载多个软件包

### 创建下载列表

创建包含所有需要软件包名称的文件：

```bash
# 创建包列表文件
cat > packages-list.txt << EOF
nginx
postgresql
redis-server
docker-ce
docker-ce-cli
containerd.io
EOF

# 或者从已安装系统导出
dpkg --get-selections | awk '{print $1}' > packages-list.txt
```

### 批量下载脚本

使用自动化脚本批量下载所有包及其依赖：

```bash
#!/bin/bash
# offline-package-downloader.sh

PACKAGES_LIST="packages-list.txt"
DOWNLOAD_DIR="/path/to/usb-drive/debian-offline-packages"

# 创建下载目录
mkdir -p "${DOWNLOAD_DIR}"

# 清理APT缓存
sudo apt-get clean

# 批量下载
while read package; do
    echo "Downloading package: ${package}"
    sudo apt-get install --download-only -y "${package}"
done < "${PACKAGES_LIST}"

# 复制所有下载的包
sudo cp /var/cache/apt/archives/*.deb "${DOWNLOAD_DIR}/"

# 创建仓库索引
cd "${DOWNLOAD_DIR}"
sudo apt-get install -y dpkg-dev
dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz

echo "Offline packages created successfully!"
echo "Total packages: $(ls -1 *.deb | wc -l)"
```

### 执行下载

```bash
# 添加执行权限
chmod +x offline-package-downloader.sh

# 执行脚本
./offline-package-downloader.sh
```

## 方法三：完整系统镜像

### 使用 apt-mirror 工具

下载完整的 Debian/Ubuntu 仓库镜像：

```bash
# 安装 apt-mirror
sudo apt-get install apt-mirror

# 配置镜像列表
sudo vim /etc/apt/mirror.list

# 配置示例
############# config ##################
set base_path    /path/to/mirror
set nthreads     20
set _tilde       0
############# end config ##############

deb http://mirrors.aliyun.com/debian bullseye main contrib non-free
deb http://mirrors.aliyun.com/debian bullseye-updates main contrib non-free
deb-src http://mirrors.aliyun.com/debian bullseye main contrib non-free

# 执行镜像下载
sudo apt-mirror

# 清理脚本
sudo /var/spool/apt-mirror/clean.sh
```

### 使用 apt-offline 工具

apt-offline 是专门的离线包管理工具：

```bash
# 在联网机器上安装
sudo apt-get install apt-offline

# 生成需求文件
sudo apt-offline set offline-package.sig \
    --install-packages nginx,postgresql \
    --update

# 下载包
sudo apt-offline get offline-package.sig \
    --bundle offline-package.zip \
    --threads 5

# 在离线机器上安装
sudo apt-offline install offline-package.zip
```

## 离线安装步骤

### 准备本地APT仓库

将移动存储设备连接到离线的 Debian 系统：

```bash
# 创建本地仓库目录
mkdir -p /opt/offline-repo

# 挂载 USB 设备（如需要）
mount /dev/sdb1 /mnt/usb

# 复制包文件
cp -r /mnt/usb/debian-offline-packages/* /opt/offline-repo/

# 验证复制
ls -lh /opt/offline-repo/
```

### 配置本地APT源

创建 APT 源配置文件：

```bash
# 创建源配置
sudo cat > /etc/apt/sources.list.d/local-offline.list << EOF
# 离线本地仓库
deb [trusted=yes] file:///opt/offline-repo ./
EOF

# 解释配置
# [trusted=yes]: 信任本地包，不检查签名
# file:///opt/offline-repo: 本地文件路径
# ./: 表示当前目录
```

### 更新软件包索引

更新本地包数据库：

```bash
# 更新APT索引
sudo apt-get update

# 查看可用包
apt-cache policy | grep -A 5 file:

# 搜索特定包
apt-cache search nginx
```

### 安装软件包

使用 apt-get 安装软件，APT 会自动处理依赖：

```bash
# 安装单个包
sudo apt-get install nginx

# 安装多个包
sudo apt-get install nginx postgresql redis-server

# 查看安装状态
dpkg -l | grep nginx

# 验证服务状态
systemctl status nginx
```

## 高级技巧

### 依赖冲突处理

如果遇到依赖问题：

```bash
# 查看依赖关系
apt-cache depends nginx

# 强制安装缺失依赖
sudo apt-get install -f

# 使用 dpkg 直接安装
sudo dpkg -i package.deb
sudo apt-get install -f
```

### 包版本锁定

防止包被意外升级：

```bash
# 查看包状态
apt-cache policy nginx

# 锁定包版本
sudo apt-mark hold nginx

# 查看锁定状态
apt-mark showhold

# 解除锁定
sudo apt-mark unhold nginx
```

### 离线更新系统

创建系统更新包：

```bash
# 在联网机器上
sudo apt-get update
sudo apt-get dist-upgrade --download-only

# 复制包到离线机器
# 按照上述步骤安装更新
```

## 自动化部署脚本

完整的离线包管理自动化脚本：

```bash
#!/bin/bash
# complete-offline-deployment.sh

REPO_DIR="/opt/offline-repo"
USB_MOUNT="/mnt/usb"
PACKAGE_DIR="debian-offline-packages"

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
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
        mount /dev/sdb1 "$USB_MOUNT" || {
            log_error "无法挂载USB设备"
            exit 1
        }
    fi
}

# 复制包文件
copy_packages() {
    log_info "复制离线包文件..."
    
    mkdir -p "$REPO_DIR"
    cp -r "${USB_MOUNT}/${PACKAGE_DIR}"/* "$REPO_DIR/" || {
        log_error "复制失败"
        exit 1
    }
    
    PACKAGE_COUNT=$(ls -1 "$REPO_DIR/*.deb" 2>/dev/null | wc -l)
    log_info "已复制 $PACKAGE_COUNT 个软件包"
}

# 配置APT源
configure_apt_source() {
    log_info "配置本地APT源..."
    
    cat > /etc/apt/sources.list.d/local-offline.list << EOF
deb [trusted=yes] file://${REPO_DIR} ./
EOF
    
    log_info "APT源配置完成"
}

# 更新APT索引
update_apt_cache() {
    log_info "更新APT软件包索引..."
    
    apt-get update || {
        log_error "APT更新失败"
        exit 1
    }
    
    log_info "APT索引更新完成"
}

# 安装软件包
install_packages() {
    log_info "安装软件包..."
    
    # 从文件读取包列表
    if [ -f "${USB_MOUNT}/packages-list.txt" ]; then
        PACKAGES=$(cat "${USB_MOUNT}/packages-list.txt")
        apt-get install -y $PACKAGES || {
            log_error "包安装失败"
            exit 1
        }
    else
        log_info "未找到包列表文件，手动安装"
        apt-get install -y nginx postgresql redis-server
    fi
    
    log_info "软件包安装完成"
}

# 验证安装
verify_installation() {
    log_info "验证安装..."
    
    dpkg -l | grep -E 'nginx|postgresql|redis-server'
    
    log_info "安装验证完成"
}

# 主执行流程
main() {
    check_environment
    copy_packages
    configure_apt_source
    update_apt_cache
    install_packages
    verify_installation
    
    log_info "离线部署完成！"
}

# 执行主函数
main
```

## 最佳实践

### 版本管理

1. **建立版本库**
   - 为不同 Debian/Ubuntu 版本创建独立目录
   - 标注系统版本和架构
   - 定期更新和维护

2. **包分类存储**
   ```
   offline-packages/
   ├── debian11-amd64/
   │   ├── base-packages/
   │   ├── web-packages/
   │   └── database-packages/
   ├── ubuntu20.04-amd64/
   └── ubuntu22.04-arm64/
   ```

### 安全考虑

1. **包完整性验证**
   ```bash
   # 验证包完整性
   dpkg --verify package.deb
   
   # 检查包签名（如果有）
   debsig-verify package.deb
   ```

2. **权限管理**
   ```bash
   # 设置合适的权限
   chmod 755 /opt/offline-repo
   chmod 644 /opt/offline-repo/*.deb
   ```

### 维护建议

1. **定期更新**
   - 每季度更新离线包库
   - 记录包版本变更
   - 测试新包兼容性

2. **文档记录**
   - 维护包列表清单
   - 记录安装步骤
   - 保存问题解决方案

## 常见问题排查

### 问题1：依赖缺失

**现象**: 安装时提示缺少依赖包

**解决方案**:
```bash
# 查看缺失依赖
apt-cache depends package-name

# 补充下载缺失依赖
sudo apt-get install --download-only dependency-package
```

### 问题2：版本冲突

**现象**: 系统版本与包版本不匹配

**解决方案**:
```bash
# 检查系统版本
cat /etc/os-release

# 重新下载匹配版本的包
# 使用正确的系统版本制作离线包
```

### 问题3：架构不匹配

**现象**: 提示架构不兼容

**解决方案**:
```bash
# 检查系统架构
dpkg --print-architecture

# 下载正确架构的包
# amd64: 64位Intel/AMD
# arm64: ARM 64位
# i386: 32位Intel/AMD
```

### 问题4：仓库索引损坏

**现象**: APT 无法识别本地包

**解决方案**:
```bash
# 重新生成索引
cd /opt/offline-repo
dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz

# 清理APT缓存
sudo apt-get clean
sudo apt-get update
```

## 与 CentOS/RHEL 离线包对比

| 特性 | Debian/Ubuntu | CentOS/RHEL |
|------|---------------|-------------|
| 包管理器 | apt/dpkg | yum/rpm |
| 包格式 | .deb | .rpm |
| 仓库工具 | dpkg-scanpackages | createrepo |
| 依赖解析 | 自动解析 | 自动解析 |
| 索引文件 | Packages.gz | repodata/ |

## 总结

Debian 系统的离线包管理是企业内网环境运维的核心技能。通过本文的详细指导，你掌握了：

1. **多种离线包制作方法** - 单包下载、批量下载、完整镜像
2. **完整的部署流程** - 从制作到安装的端到端过程
3. **自动化脚本应用** - 提高效率，减少人工错误
4. **最佳实践和问题排查** - 确保离线部署的可靠性

掌握这些技能后，你可以在各种受限网络环境中高效地进行软件部署和管理。

**相关资源**:
- [Debian 官方文档](https://www.debian.org/doc/)
- [APT 用户指南](https://wiki.debian.org/Apt)
- [apt-offline 项目](https://github.com/rickysaraf/apt-offline)



