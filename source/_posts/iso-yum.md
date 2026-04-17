---
title: 使用镜像 ISO 文件制做本地Yum 源
date: 2024-12-20 12:17:25
tags:
    - Yum
    - Linux
    - CentOS
category: Linux
---

在企业内网环境或离线场景中，使用 CentOS ISO 镜像文件制作本地 YUM 源是快速部署软件包的有效方法。本文详细介绍如何下载、挂载 CentOS ISO 文件，创建本地 YUM 仓库，配置开机自动挂载，并提供多种使用场景和最佳实践指导，帮助你在离线环境中高效管理软件包。

<!-- more -->

## ISO 本地源概述

### 适用场景

1. **离线环境部署**
   - 企业内网服务器无法访问外网
   - 生产环境安全隔离要求
   - 快速批量部署系统

2. **系统安装和维护**
   - 系统初始化时安装基础软件
   - 系统恢复和灾难恢复
   - 版本标准化管理

3. **测试和开发**
   - 本地测试环境搭建
   - 软件兼容性测试
   - 快速创建测试镜像

### 技术原理

ISO 本地源的核心原理：
- **ISO 文件**: 包含完整的 RPM 包和仓库索引
- **挂载**: 将 ISO 作为文件系统挂载到本地目录
- **YUM 配置**: 配置本地路径作为 YUM 仓库
- **自动挂载**: 通过 fstab 实现开机自动挂载

## 准备工作

### ISO 文件下载

从国内镜像站下载 CentOS ISO 文件，速度更快：

```bash
# CentOS 7.9 ISO下载地址
# 阿里云镜像
https://mirrors.aliyun.com/centos/7.9.2009/isos/x86_64/

# 清华镜像
https://mirrors.tuna.tsinghua.edu.cn/centos/7.9.2009/isos/x86_64/

# 华为云镜像
https://mirrors.huawei.com/centos/7.9.2009/isos/x86_64/
```

**ISO 文件选择建议**:
- **CentOS-7-x86_64-DVD-2009.iso**: 完整版（约4.5GB），推荐使用
- **CentOS-7-x86_64-Everything-2009.iso**: 包含所有软件包（约10GB）
- **CentOS-7-x86_64-Minimal-2009.iso**: 最小化版本（约1GB），不推荐用于制作本地源

### 上传 ISO 文件

将下载的 ISO 文件上传到服务器：

```bash
# 方法1：使用 scp 上传
scp CentOS-7-x86_64-DVD-2009.iso root@server-ip:/data/iso/

# 方法2：使用 FTP 工具上传（FileZilla等）

# 方法3：使用 rz 命令（需要安装 lrzsz）
yum install -y lrzsz
rz CentOS-7-x86_64-DVD-2009.iso

# 验证上传完整性
md5sum CentOS-7-x86_64-DVD-2009.iso
# 对比官方 MD5 值
```

## 基础配置步骤

### 创建挂载点

创建 ISO 文件挂载目录：

```bash
# 创建标准挂载点
sudo mkdir -p /mnt/cdrom

# 或创建在数据目录
sudo mkdir -p /data/iso-mount

# 设置权限
sudo chmod 755 /mnt/cdrom
```

### 挂载 ISO 文件

使用 mount 命令挂载 ISO 文件：

```bash
# 临时挂载
sudo mount -o loop /data/iso/CentOS-7-x86_64-DVD-2009.iso /mnt/cdrom

# 查看挂载结果
mount | grep cdrom
df -h | grep cdrom

# 查看挂载内容
ls -lh /mnt/cdrom/
```

**挂载参数说明**:
- `-o loop`: 使用 loop 设备将文件作为块设备挂载
- ISO 文件会被挂载为只读模式
- 挂载后可以访问 ISO 内的所有文件

### 创建 YUM 仓库配置

配置本地 YUM 仓库：

```bash
# 备份原有配置
sudo cp -r /etc/yum.repos.d/ /etc/yum.repos.d.backup

# 创建本地源配置
sudo cat > /etc/yum.repos.d/CentOS-Local.repo << EOF
[local-cdrom]
name=CentOS-7.9 Local Repository
baseurl=file:///mnt/cdrom
enabled=1
gpgcheck=0
gpgkey=file:///mnt/cdrom/RPM-GPG-KEY-CentOS-7
EOF
```

**配置参数详解**:
- `[local-cdrom]`: 仓库ID，唯一标识符
- `name`: 仓库描述名称
- `baseurl=file:///mnt/cdrom`: 本地文件路径
- `enabled=1`: 启用仓库
- `gpgcheck=0`: 禁用 GPG 签名检查（本地源推荐）
- `gpgkey`: GPG 密钥文件路径（可选）

### 清理和更新 YUM 缓存

清理 YUM 缓存并生成新索引：

```bash
# 清理所有缓存
sudo yum clean all

# 生成缓存
sudo yum makecache

# 查看仓库列表
sudo yum repolist

# 验证本地源
yum repolist | grep local-cdrom
```

### 测试本地源

测试软件包安装：

```bash
# 搜索软件包
yum search nginx

# 查看软件包信息
yum info httpd

# 安装测试包
sudo yum install -y --disablerepo='*' --enablerepo='local-cdrom' httpd

# 验证安装
rpm -qa | grep httpd
systemctl status httpd
```

## 高级配置

### 设置开机自动挂载

配置 `/etc/fstab` 实现开机自动挂载：

```bash
# 编辑 fstab 文件
sudo vim /etc/fstab

# 添加以下行（选择一种方式）
# 方式1：使用 loop 设备
/data/iso/CentOS-7-x86_64-DVD-2009.iso /mnt/cdrom iso9660 loop,ro 0 0

# 方式2：使用 UUID（更稳定）
# 先获取 ISO 文件 UUID
blkid /data/iso/CentOS-7-x86_64-DVD-2009.iso
# UUID="xxxx" /mnt/cdrom iso9660 loop,ro 0 0
```

**fstab 字段说明**:
```
文件路径    挂载点    文件系统类型    挂载选项    dump频率    fsck顺序
```
- `iso9660`: ISO 文件系统类型
- `loop,ro`: loop 设备，只读模式
- `0 0`: 不进行 dump 和 fsck 检查

验证 fstab 配置：

```bash
# 测试挂载所有 fstab 条目
sudo mount -a

# 查看挂载状态
mount | grep cdrom

# 重启测试
sudo reboot
```

### 多 ISO 文件挂载

如果有多个 ISO 文件（如 Everything 版本）：

```bash
# 创建多个挂载点
mkdir -p /mnt/iso-dvd
mkdir -p /mnt/iso-everything

# 挂载多个 ISO
mount -o loop CentOS-7-x86_64-DVD-2009.iso /mnt/iso-dvd
mount -o loop CentOS-7-x86_64-Everything-2009.iso /mnt/iso-everything

# 配置多个仓库
cat > /etc/yum.repos.d/CentOS-Multi-ISO.repo << EOF
[local-dvd]
name=CentOS DVD Repository
baseurl=file:///mnt/iso-dvd
enabled=1
gpgcheck=0

[local-everything]
name=CentOS Everything Repository  
baseurl=file:///mnt/iso-everything
enabled=1
gpgcheck=0
EOF
```

### NFS 共享 ISO 源

将 ISO 源通过 NFS 共享给其他服务器：

```bash
# 在 NFS 服务器上配置
yum install -y nfs-utils

# 配置 NFS 导出
cat >> /etc/exports << EOF
/mnt/cdrom 192.168.1.0/24(ro,sync,no_root_squash)
EOF

# 启动 NFS 服务
systemctl start nfs-server
systemctl enable nfs-server

# 在客户端挂载
mount -t nfs nfs-server:/mnt/cdrom /mnt/nfs-iso

# 配置客户端 YUM 源
cat > /etc/yum.repos.d/NFS-ISO.repo << EOF
[nfs-iso]
name=NFS Shared ISO Repository
baseurl=file:///mnt/nfs-iso
enabled=1
gpgcheck=0
EOF
```

## 使用场景

### 系统初始化批量部署

使用 ISO 源进行系统初始化：

```bash
# 安装常用软件包
yum groupinstall -y "Development Tools"
yum groupinstall -y "System Administration Tools"

# 安装基础服务
yum install -y \
    wget curl vim \
    net-tools \
    bash-completion \
    tree htop \
    lsof iotop

# 配置系统参数
sysctl -p
```

### 离线环境补丁安装

使用 ISO 源安装安全补丁：

```bash
# 查看可用更新
yum check-update

# 安装安全更新（仅从本地源）
yum update --disablerepo='*' --enablerepo='local-cdrom' --security

# 查看已安装补丁
rpm -qa --last | head -20
```

### 软件包依赖修复

修复系统依赖问题：

```bash
# 查看缺失依赖
yum deplist package-name

# 重建依赖数据库
rpm --rebuilddb

# 修复损坏的包
yum install -y --skip-broken package-name
```

## 自动化脚本

完整的 ISO 本地源配置脚本：

```bash
#!/bin/bash
# iso-local-repo-setup.sh

ISO_FILE="/data/iso/CentOS-7-x86_64-DVD-2009.iso"
MOUNT_POINT="/mnt/cdrom"
REPO_NAME="CentOS-Local.repo"

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

# 检查 ISO 文件
check_iso_file() {
    log_info "检查 ISO 文件..."
    
    if [ ! -f "$ISO_FILE" ]; then
        log_error "ISO 文件不存在: $ISO_FILE"
        exit 1
    fi
    
    # 检查文件完整性
    FILE_SIZE=$(stat -c%s "$ISO_FILE")
    if [ $FILE_SIZE -lt 4000000000 ]; then
        log_error "ISO 文件大小异常，可能不完整"
        exit 1
    fi
    
    log_info "ISO 文件检查完成"
}

# 创建挂载点
create_mount_point() {
    log_info "创建挂载点..."
    
    mkdir -p "$MOUNT_POINT"
    chmod 755 "$MOUNT_POINT"
    
    log_info "挂载点创建完成: $MOUNT_POINT"
}

# 挂载 ISO 文件
mount_iso_file() {
    log_info "挂载 ISO 文件..."
    
    # 检查是否已挂载
    if mount | grep -q "$MOUNT_POINT"; then
        log_info "ISO 已挂载"
        return 0
    fi
    
    # 挂载 ISO
    mount -o loop "$ISO_FILE" "$MOUNT_POINT" || {
        log_error "挂载失败"
        exit 1
    }
    
    log_info "ISO 文件挂载成功"
}

# 配置 YUM 源
configure_yum_repo() {
    log_info "配置 YUM 仓库..."
    
    # 备份原有配置
    if [ -d /etc/yum.repos.d.backup ]; then
        log_info "备份目录已存在"
    else
        cp -r /etc/yum.repos.d/ /etc/yum.repos.d.backup
    fi
    
    # 创建本地源配置
    cat > "/etc/yum.repos.d/$REPO_NAME" << EOF
[local-cdrom]
name=CentOS Local Repository
baseurl=file://${MOUNT_POINT}
enabled=1
gpgcheck=0
EOF
    
    log_info "YUM 仓库配置完成"
}

# 更新 YUM 缓存
update_yum_cache() {
    log_info "更新 YUM 缓存..."
    
    yum clean all || {
        log_error "清理缓存失败"
        exit 1
    }
    
    yum makecache || {
        log_error "生成缓存失败"
        exit 1
    }
    
    log_info "YUM 缓存更新完成"
}

# 配置自动挂载
configure_auto_mount() {
    log_info "配置开机自动挂载..."
    
    # 检查 fstab 是否已配置
    if grep -q "$ISO_FILE" /etc/fstab; then
        log_info "fstab 已配置自动挂载"
        return 0
    fi
    
    # 添加自动挂载配置
    echo "$ISO_FILE $MOUNT_POINT iso9660 loop,ro 0 0" >> /etc/fstab
    
    log_info "开机自动挂载配置完成"
}

# 验证配置
verify_configuration() {
    log_info "验证配置..."
    
    # 检查挂载
    mount | grep "$MOUNT_POINT"
    
    # 检查仓库
    yum repolist | grep local-cdrom
    
    # 查看可用包数量
    PACKAGE_COUNT=$(yum repolist | grep local-cdrom | awk '{print $2}')
    log_info "可用软件包数量: $PACKAGE_COUNT"
}

# 主执行流程
main() {
    log_info "开始配置 ISO 本地 YUM 源..."
    
    check_iso_file
    create_mount_point
    mount_iso_file
    configure_yum_repo
    update_yum_cache
    configure_auto_mount
    verify_configuration
    
    log_info "ISO 本地 YUM 源配置完成！"
}

# 执行主函数
main
```

## 最佳实践

### 性能优化

1. **使用 SSD 存储**
   ```bash
   # 将 ISO 文件放在 SSD 磁盘
   mv CentOS-7-x86_64-DVD-2009.iso /data-ssd/iso/
   
   # 配置 SSD 挂载点
   mount -o loop /data-ssd/iso/CentOS-7-x86_64-DVD-2009.iso /mnt/cdrom
   ```

2. **内存缓存优化**
   ```bash
   # 增加 YUM 缓存大小
   echo 'max_age=7d' >> /etc/yum.conf
   echo 'keepcache=1' >> /etc/yum.conf
   ```

3. **并发下载**
   ```bash
   # 安装并行下载插件
   yum install -y yum-plugin-fastestmirror
   
   # 配置并发数
   echo 'max_parallel_downloads=10' >> /etc/yum.conf
   ```

### 安全考虑

1. **访问权限控制**
   ```bash
   # 设置 ISO 文件权限
   chmod 600 /data/iso/CentOS-7-x86_64-DVD-2009.iso
   
   # 设置挂载点权限
   chmod 755 /mnt/cdrom
   chown root:root /mnt/cdrom
   ```

2. **GPG 签名验证**
   ```bash
   # 导入 GPG 密钥
   rpm --import /mnt/cdrom/RPM-GPG-KEY-CentOS-7
   
   # 启用签名检查
   sed -i 's/gpgcheck=0/gpgcheck=1/' /etc/yum.repos.d/CentOS-Local.repo
   ```

3. **审计日志**
   ```bash
   # 启用 YUM 操作日志
   echo 'history_record=1' >> /etc/yum.conf
   
   # 查看历史操作
   yum history list
   ```

### 维护建议

1. **定期更新 ISO**
   ```bash
   # 下载最新 ISO
   wget https://mirrors.aliyun.com/centos/7.9.2009/isos/x86_64/CentOS-7-x86_64-DVD-2009.iso
   
   # 验证 MD5
   md5sum -c CentOS-7-x86_64-DVD-2009.iso.md5
   
   # 替换旧 ISO
   umount /mnt/cdrom
   mv CentOS-7-x86_64-DVD-2009.iso /data/iso/
   mount -a
   ```

2. **备份配置**
   ```bash
   # 备份 YUM 配置
   tar -czf yum-config-backup.tar.gz /etc/yum.repos.d/
   
   # 备份 fstab
   cp /etc/fstab /etc/fstab.backup
   ```

3. **监控脚本**
   ```bash
   # 创建监控脚本
   cat > /usr/local/bin/monitor-iso-repo.sh << 'EOF'
   #!/bin/bash
   
   MOUNT_POINT="/mnt/cdrom"
   
   # 检查挂载状态
   if ! mount | grep -q "$MOUNT_POINT"; then
       echo "警告: ISO 未挂载"
       mount -a
   fi
   
   # 检查仓库状态
   if ! yum repolist | grep -q local-cdrom; then
       echo "警告: 本地源不可用"
       yum clean all
       yum makecache
   fi
   
   # 记录日志
   echo "$(date): ISO 源检查完成" >> /var/log/iso-repo-monitor.log
   EOF
   
   chmod +x /usr/local/bin/monitor-iso-repo.sh
   
   # 添加定时任务
   echo "*/10 * * * * /usr/local/bin/monitor-iso-repo.sh" >> /var/spool/cron/root
   ```

## 常见问题排查

### 问题1：挂载失败

**现象**: mount 命令提示失败

**解决方案**:
```bash
# 检查 loop 设备
ls -l /dev/loop*

# 创建 loop 设备
mknod /dev/loop0 b 7 0

# 检查文件系统
file CentOS-7-x86_64-DVD-2009.iso

# 使用其他挂载方式
mount -t iso9660 -o loop CentOS-7-x86_64-DVD-2009.iso /mnt/cdrom
```

### 问题2：YUM 仓库不可用

**现象**: yum repolist 不显示本地源

**解决方案**:
```bash
# 检查配置文件
ls -l /etc/yum.repos.d/

# 检查配置语法
yum-config-manager --verify local-cdrom

# 重新生成缓存
yum clean all
rm -rf /var/cache/yum/
yum makecache
```

### 问题3：开机不自动挂载

**现象**: 重启后 ISO 未挂载

**解决方案**:
```bash
# 检查 fstab 语法
mount -a -v

# 检查 fstab 条目
cat /etc/fstab | grep iso

# 测试手动挂载
mount -o loop /data/iso/CentOS-7-x86_64-DVD-2009.iso /mnt/cdrom

# 查看系统日志
journalctl -xe | grep mount
```

### 问题4：软件包安装失败

**现象**: yum install 提示依赖问题

**解决方案**:
```bash
# 查看依赖关系
yum deplist package-name

# 检查包是否存在
yum list available | grep package-name

# 使用跳过损坏包选项
yum install --skip-broken package-name

# 使用完整 ISO
# 切换到 Everything ISO，包含所有软件包
```

## 与其他方法对比

| 特性 | ISO 本地源 | 离线 RPM 包 | YUM 仓库同步 |
|------|-----------|------------|-------------|
| 准备难度 | 简单 | 中等 | 复杂 |
| 包数量 | 中等（~4000） | 自定义 | 完整（~10000+） |
| 更新频率 | ISO 发布周期 | 手动管理 | 实时同步 |
| 适用场景 | 系统初始化 | 特定软件部署 | 生产环境 |
| 磁盘占用 | 4.5GB | 自定义 | 50GB+ |

## 总结

ISO 本地 YUM 源是离线环境软件部署的快速解决方案。通过本文的详细指导，你掌握了：

1. **ISO 文件下载和上传** - 选择合适的镜像和版本
2. **挂载和配置流程** - 临时挂载和自动挂载设置
3. **多场景应用** - 系统初始化、补丁安装、依赖修复
4. **自动化脚本** - 提高效率，减少人工错误
5. **最佳实践和监控** - 确保长期稳定运行

掌握这些技能后，你可以在离线环境中快速部署和管理 CentOS 系统软件包。

**相关资源**:
- [CentOS 官方下载](https://www.centos.org/download/)
- [阿里云 CentOS 镜像](https://mirrors.aliyun.com/centos/)
- [YUM 配置指南](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/system_administrators_guide/ch-yum)

