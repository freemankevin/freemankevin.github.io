---
title: Harbor 多架构镜像管理完整指南
date: 2025-08-13 10:40:00
tags:
  - Docker
  - Harbor
  - Manifest
  - Multi-Architecture
# comments: true
category: Docker
---

在现代容器化环境中，多架构支持变得越来越重要。随着 ARM64 架构在服务器和边缘设备中的普及，我们需要构建和管理支持多种 CPU 架构的容器镜像。本文将详细介绍如何在 Harbor 私有镜像仓库中管理多架构镜像，包括配置、推送和创建 manifest 列表的完整流程。

<!-- more -->

## 环境说明

- **Harbor 版本**: 自建 Harbor 私有仓库
- **部署方式**: HTTPS 模式，使用自签名证书，443 端口
- **Docker 版本**: 支持 manifest 功能的版本
- **目标架构**: AMD64 和 ARM64

## 问题背景

在实际项目中，我们遇到了以下挑战：

1. 需要将单架构镜像转换为多架构镜像
2. Harbor 使用自签名 HTTPS 证书，需要正确配置 Docker 客户端
3. Docker manifest 功能需要特定的配置和操作流程
4. 需要批量处理多个版本的镜像

## 解决方案

### 1. Harbor 证书配置

#### 问题现象
```bash
Get "http://110.1.20.3/v2/": dial tcp 110.1.20.3:80: connect: connection refused
```

这个错误表明 Docker 客户端尝试使用 HTTP 协议连接 Harbor，但 Harbor 实际运行在 HTTPS 模式。

#### 解决步骤

**Step 1: 配置客户端证书**
```bash
# 创建证书目录
mkdir -p /etc/docker/certs.d/110.1.20.3/

# 复制 Harbor CA 证书和服务器证书
\cp -rvf /data/opt/installharbor/certs/{ca.crt,harbor.crt} /etc/docker/certs.d/110.1.20.3/

# 设置正确的文件权限
cd /etc/docker/certs.d/110.1.20.3/
chmod 644 ca.crt harbor.crt
```

**Step 2: 配置 Docker daemon**

编辑 `/etc/docker/daemon.json`：
```json
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "http://docker.1panel.live",
    "https://docker.agsv.top",
    "https://docker.agsvpt.work",
    "https://dockerpull.com",
    "https://dockerproxy.cn"
  ],
  "debug": false,
  "insecure-registries": [
    "110.1.20.3"
  ],
  "ip-forward": true,
  "ipv6": false,
  "live-restore": true,
  "log-driver": "json-file",
  "log-level": "warn",
  "log-opts": {
    "max-size": "100m",
    "max-file": "2"
  },
  "selinux-enabled": false,
  "experimental": true,
  "storage-driver": "overlay2",
  "data-root": "/data/docker_dir",
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    }
  },
  "exec-opts": ["native.cgroupdriver=systemd"]
}
```

**关键配置说明：**
- `"experimental": true` - 启用 manifest 功能
- `"insecure-registries": ["110.1.20.3"]` - 信任自签名证书

**Step 3: 重启服务**
```bash
# 重启 Docker
systemctl daemon-reload 
systemctl restart docker

# 重启 Harbor（同台机器部署需要）
cd /data/opt/installharbor/
bash install.sh
```

### 2. 常见证书问题解决

#### 问题1：证书文件扩展名错误
```
missing key ca.key for client certificate ca.cert. CA certificates must use the extension .crt
```

**解决方法：**
- Docker 要求 CA 证书必须使用 `.crt` 扩展名
- 客户端证书目录不应包含私钥文件（`.key` 文件）

**正确的证书目录结构：**
```
/etc/docker/certs.d/110.1.20.3/
├── ca.crt          # CA 证书（必需）
└── harbor.crt      # Harbor 服务器证书（可选）
```

#### 问题2：Docker daemon 配置错误
```
json: cannot unmarshal string into Go struct field Config.experimental of type bool
```

**解决方法：**
```json
// 错误写法
"experimental": "enabled"

// 正确写法
"experimental": true
```

### 3. 多架构镜像管理脚本

创建自动化脚本 `pushImages.sh` 来批量处理镜像：

```bash
#!/bin/bash
# ===================================
# 批量处理：打 tag + 推送 + 创建多架构 manifest
# 支持 HTTPS Harbor 自签名证书
# ===================================
set -e

# Harbor 配置
HARBOR_HOST="110.1.20.3"
REPO_PREFIX="${HARBOR_HOST}/library"
VERSIONS=("3.11.3" "3.10.1" "3.9.2" "3.8.5")
ARCHES=("amd64" "arm64")

# 是否删除旧标签（可选）
DELETE_OLD_TAGS=false

echo "🚀 开始处理镜像标签与多架构清单..."
echo "📡 Harbor 地址: https://${HARBOR_HOST}"

# 检查登录状态
if ! docker login https://${HARBOR_HOST} 2>/dev/null; then
  echo "⚠️  Docker 未登录到 Harbor，请先登录："
  echo "   docker login https://${HARBOR_HOST}"
  exit 1
fi

# 1. 先为所有镜像打新标签并推送
for version in "${VERSIONS[@]}"; do
  for arch in "${ARCHES[@]}"; do
    OLD_TAG="${REPO_PREFIX}/java-gdal-local-${arch}:${version}"
    NEW_TAG="${REPO_PREFIX}/java-gdal-local:${version}-${arch}"
    
    if docker inspect "$OLD_TAG" &> /dev/null; then
      echo "🏷️  打标签: $OLD_TAG -> $NEW_TAG"
      docker tag "$OLD_TAG" "$NEW_TAG"
      
      echo "📤 推送: $NEW_TAG"
      docker push "$NEW_TAG"
      
      if [ "$DELETE_OLD_TAGS" = true ]; then
        echo "🗑️  删除旧标签: $OLD_TAG"
        docker rmi "$OLD_TAG" || true
      fi
    else
      echo "⚠️  镜像不存在，跳过: $OLD_TAG"
    fi
  done
done

# 2. 为每个版本创建多架构 manifest
echo ""
echo "🔧 开始创建多架构 manifest..."

for version in "${VERSIONS[@]}"; do
  MANIFEST_TAG="${REPO_PREFIX}/java-gdal-local:${version}"
  TAG_AMD64="${REPO_PREFIX}/java-gdal-local:${version}-amd64"
  TAG_ARM64="${REPO_PREFIX}/java-gdal-local:${version}-arm64"
  
  echo "📦 创建多架构镜像清单: $MANIFEST_TAG"
  
  # 删除可能存在的旧 manifest
  docker manifest rm "$MANIFEST_TAG" 2>/dev/null || true
  
  # 创建 manifest
  docker manifest create "$MANIFEST_TAG" \
    --amend "$TAG_AMD64" \
    --amend "$TAG_ARM64"
  
  # 添加平台信息（关键步骤）
  docker manifest annotate "$MANIFEST_TAG" "$TAG_AMD64" --os linux --arch amd64
  docker manifest annotate "$MANIFEST_TAG" "$TAG_ARM64" --os linux --arch arm64
  
  # 推送 manifest
  echo "📤 推送多架构镜像: $MANIFEST_TAG"
  docker manifest push "$MANIFEST_TAG"
  
  echo "✅ 完成: $MANIFEST_TAG"
done

echo ""
echo "🎉 所有操作完成！"
echo ""
echo "你现在可以通过以下方式拉取："
for version in "${VERSIONS[@]}"; do
  echo "   docker pull ${HARBOR_HOST}/library/java-gdal-local:${version}"
done
```

### 4. 手动操作流程

如果需要手动创建多架构镜像，可以按以下步骤：

**Step 1: 登录 Harbor**
```bash
docker login 110.1.20.3
# 或者
docker login -u admin -p Harbor12345@Gmail.com 110.1.20.3
```

**Step 2: 推送单架构镜像**
```bash
# 为现有镜像打新标签
docker tag 110.1.20.3/library/java-gdal-local-amd64:3.8.5 \
           110.1.20.3/library/java-gdal-local:3.8.5-amd64

docker tag 110.1.20.3/library/java-gdal-local-arm64:3.8.5 \
           110.1.20.3/library/java-gdal-local:3.8.5-arm64

# 推送镜像
docker push 110.1.20.3/library/java-gdal-local:3.8.5-amd64
docker push 110.1.20.3/library/java-gdal-local:3.8.5-arm64
```

**Step 3: 创建多架构 manifest**
```bash
# 创建 manifest
docker manifest create 110.1.20.3/library/java-gdal-local:3.8.5 \
  --amend 110.1.20.3/library/java-gdal-local:3.8.5-amd64 \
  --amend 110.1.20.3/library/java-gdal-local:3.8.5-arm64

# 添加平台信息（重要！）
docker manifest annotate 110.1.20.3/library/java-gdal-local:3.8.5 \
  110.1.20.3/library/java-gdal-local:3.8.5-amd64 --os linux --arch amd64

docker manifest annotate 110.1.20.3/library/java-gdal-local:3.8.5 \
  110.1.20.3/library/java-gdal-local:3.8.5-arm64 --os linux --arch arm64

# 推送 manifest（注意：使用 manifest push，不是普通 push）
docker manifest push 110.1.20.3/library/java-gdal-local:3.8.5
```

**Step 4: 验证结果**
```bash
# 查看 manifest 信息
docker manifest inspect 110.1.20.3/library/java-gdal-local:3.8.5

# 测试拉取（会根据当前平台自动选择架构）
docker pull 110.1.20.3/library/java-gdal-local:3.8.5
```

### 5. 故障排除

#### 常见错误及解决方法

**1. 证书相关错误**
```
x509: certificate signed by unknown authority
```
**解决：** 确保正确配置了 CA 证书或使用 `insecure-registries`

**2. Manifest 推送错误**
```
tag does not exist: 110.1.20.3/library/java-gdal-local:3.8.5
```
**解决：** 使用 `docker manifest push` 而不是 `docker push`

**3. 实验性功能未启用**
```
docker manifest is only supported when experimental cli features are enabled
```
**解决：** 在 `daemon.json` 中设置 `"experimental": true`

#### 检查清单

- [ ] Docker daemon 配置了 `"experimental": true`
- [ ] 证书文件使用正确的扩展名（`.crt`）
- [ ] 证书目录不包含私钥文件
- [ ] 已正确登录 Harbor
- [ ] 单架构镜像已成功推送
- [ ] 使用 `docker manifest push` 推送 manifest

## 完整配置脚本

将所有配置步骤整合成一个脚本：

```bash
#!/bin/bash
# Harbor 多架构镜像配置脚本

echo "🔧 配置 Harbor 多架构镜像支持..."

# 1. 配置客户端证书
echo "📜 配置客户端证书..."
mkdir -p /etc/docker/certs.d/110.1.20.3/
\cp -rvf /data/opt/installharbor/certs/{ca.crt,harbor.crt} /etc/docker/certs.d/110.1.20.3/
cd /etc/docker/certs.d/110.1.20.3/
chmod 644 ca.crt harbor.crt

# 2. 重启 Docker
echo "🔄 重启 Docker 服务..."
systemctl daemon-reload 
systemctl restart docker

# 3. 重启 Harbor（同台机器上需要）
echo "🔄 重启 Harbor..."
cd /data/opt/installharbor/
bash install.sh

# 4. 等待服务启动
echo "⏳ 等待服务启动..."
sleep 30

# 5. 测试配置
echo "🧪 测试配置..."
docker login 110.1.20.3

# 6. 创建测试 manifest
echo "📦 创建测试 manifest..."
docker manifest create 110.1.20.3/library/java-gdal-local:3.8.5 \
  110.1.20.3/library/java-gdal-local:3.8.5-amd64 \
  110.1.20.3/library/java-gdal-local:3.8.5-arm64

docker manifest annotate 110.1.20.3/library/java-gdal-local:3.8.5 \
  110.1.20.3/library/java-gdal-local:3.8.5-amd64 --os linux --arch amd64

docker manifest annotate 110.1.20.3/library/java-gdal-local:3.8.5 \
  110.1.20.3/library/java-gdal-local:3.8.5-arm64 --os linux --arch arm64

docker manifest push 110.1.20.3/library/java-gdal-local:3.8.5

# 7. 验证结果
echo "✅ 验证结果..."
docker manifest inspect 110.1.20.3/library/java-gdal-local:3.8.5

echo "🎉 配置完成！"
```

## 总结

通过本文的配置和脚本，我们成功解决了在自建 Harbor 中管理多架构镜像的问题。关键要点包括：

1. **正确配置 HTTPS 证书**：使用正确的文件名和权限
2. **启用实验性功能**：Docker manifest 需要实验性功能支持
3. **理解 manifest 操作**：区分 `docker push` 和 `docker manifest push`
4. **自动化流程**：使用脚本批量处理多个版本和架构

这套方案可以帮助团队高效地管理多架构容器镜像，支持在不同 CPU 架构的环境中无缝部署应用。

## 参考资源

- [Docker Multi-platform images](https://docs.docker.com/build/building/multi-platform/)
- [Docker manifest command](https://docs.docker.com/engine/reference/commandline/manifest/)
- [Harbor Documentation](https://goharbor.io/docs/)