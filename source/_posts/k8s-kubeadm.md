---
title: Kubernetes v1.33 生产级部署完整指南（kubeadm）
date: 2025-11-13 17:47:25
keywords:
  - Kubernetes
  - kubeadm
  - DevOps
  - Containerd
  - Flannel
categories:
  - DevOps
  - Kubernetes
tags:
  - Kubernetes
  - Containerd
  - Production
---

Kubernetes v1.33 是云原生应用编排的核心平台。本文档提供生产级 Kubernetes 集群部署方案，涵盖架构设计、环境准备、组件安装、网络配置、安全加固、性能优化和故障排查等全流程内容，适用于学习和生产环境。

<!-- more -->

## Kubernetes 架构概述

### Control Plane 组件

| 组件 | 功能 | 生产要求 |
|------|------|----------|
| kube-apiserver | 集群 API 入口，认证授权 | 3+ 副本，负载均衡 |
| etcd | 分布式键值存储，保存集群状态 | 3+ 节点，定期备份 |
| kube-scheduler | Pod 调度决策 | 多副本，Leader选举 |
| kube-controller-manager | 控制器管理（Deployment、Node等） | 多副本，Leader选举 |
| cloud-controller-manager | 云平台集成控制器 | 可选，云环境必需 |

### Worker Node 组件

| 组件 | 功能 | 配置要点 |
|------|------|----------|
| kubelet | 节点代理，与 API Server 通信 | 配置资源预留 |
| kube-proxy | 服务代理，实现 Service | iptables/IPVS 模式 |
| Container Runtime | 容器运行时（containerd/Docker） | systemd cgroup 驱动 |

### 网络模型

Kubernetes 网络需满足四个要求：
1. 所有 Pod 不使用 NAT 即可相互通信
2. 所有 Node 不使用 NAT 即可与所有 Pod 通信
3. Pod 看到的自身 IP 与其他 Pod 看到的 IP 相同
4. Service 的 ClusterIP 可在集群内访问


## 🏗️ 部署架构

### 单控制平面架构（测试环境）
```
┌─────────────────────────────────────────┐
│  Control Plane (192.168.199.135)        │
│  ├─ kube-apiserver (6443)               │
│  ├─ etcd (2379-2380)                    │
│  ├─ kube-scheduler                      │
│  ├─ kube-controller-manager             │
│  └─ kubelet                             │
└─────────────────────────────────────────┘
           │
           │ Pod Network (10.244.0.0/16)
           │
┌─────────────────────────────────────────┐
│  Worker Node (192.168.199.136)          │
│  ├─ kubelet                             │
│  ├─ kube-proxy                          │
│  └─ Pods (业务应用)                      │
└─────────────────────────────────────────┘
```

### 高可用架构（生产环境）

```
┌────────────────────────────────────────────────────┐
│         Load Balancer (HAProxy/Nginx)              │
│                 VIP: 192.168.1.100                 │
└────────────────────────────────────────────────────┘
        │                    │                    │
        ▼                    ▼                    ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Master 1     │  │ Master 2     │  │ Master 3     │
│ API Server   │  │ API Server   │  │ API Server   │
│ etcd         │  │ etcd         │  │ etcd         │
└──────────────┘  └──────────────┘  └──────────────┘
        │                    │                    │
        └────────────────────┴────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Worker 1     │  │ Worker 2     │  │ Worker 3     │
└──────────────┘  └──────────────┘  └──────────────┘
```

**高可用要点：**
- etcd 集群：3 或 5 节点，奇数配置
- API Server：多副本 + 负载均衡
- 控制器：内置 Leader 选举机制
- 网络：跨节点 Pod 通信，Service 贠载均衡

---

## 🔧 前置要求

### 硬件资源配置

| 环境 | CPU | 内存 | 存储 | 说明 |
|------|-----|------|------|------|
| 测试环境 | 2核 | 2GB | 20GB | 最小配置，仅用于学习 |
| 开发环境 | 4核 | 4GB | 50GB | 推荐配置，支持轻量应用 |
| 生产环境 | 8核+ | 16GB+ | 100GB+ | SSD存储，独立etcd |
| 大规模集群 | 16核+ | 32GB+ | 200GB+ | 高IO性能，专用磁盘 |

**生产环境补充建议：**
- Master节点：CPU预留1核，内存预留2GB给系统进程
- Worker节点：根据应用负载动态调整
- etcd数据：独立SSD磁盘，避免IO竞争
- 网络带宽：至少1Gbps，生产推荐10Gbps

### 网络配置要求

#### 必需开放的端口

**Control Plane节点：**

| 端口 | 协议 | 服务 | 说明 |
|------|------|------|------|
| 6443 | TCP | API Server | Kubernetes API入口 |
| 2379-2380 | TCP | etcd | etcd服务端口 |
| 10250 | TCP | Kubelet | 节点状态和日志 |
| 10251 | TCP | Scheduler | 调度器端口 |
| 10252 | TCP | Controller | 控制器端口 |
| 10257 | TCP | kube-controller-manager | 安全端口 |
| 10259 | TCP | kube-scheduler | 安全端口 |

**Worker节点：**

| 端口 | 协议 | 服务 | 说明 |
|------|------|------|------|
| 10250 | TCP | Kubelet | 节点通信 |
| 10256 | TCP | kube-proxy | 代理健康检查 |
| 30000-32767 | TCP | NodePort | 服务暴露端口 |

#### 网络插件端口

| 网络插件 | 端口 | 说明 |
|---------|------|------|
| Flannel | 8285/8472 | VXLAN通信 |
| Calico | 179/4789 | BGP/VXLAN |
| Cilium | 4240/8472 | 健康检查/VXLAN |

### 系统检查清单

执行以下检查确保系统就绪：

```bash
# 1. 验证 MAC 地址唯一性
ip link | grep link/ether

# 2. 验证 product_uuid 唯一性
cat /sys/class/dmi/id/product_uuid

# 3. 确认 Swap 已禁用
free | grep Swap

# 4. 验证时间同步
timedatectl status
systemctl status systemd-timesyncd

# 5. 检查内核版本（建议 5.4+）
uname -r

# 6. 检查系统资源
df -h
free -g
lscpu
```

---

## 📦 安装步骤

### 配置 APT 源（两台 VM）

使用清华 TUNA 镜像加速软件包下载：

```bash
nano /etc/apt/sources.list
```

替换为以下内容：

```
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie main contrib non-free-firmware
deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie main contrib non-free-firmware

deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-updates main contrib non-free-firmware
deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-updates main contrib non-free-firmware

deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-backports main contrib non-free-firmware
deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-backports main contrib non-free-firmware

deb https://mirrors.tuna.tsinghua.edu.cn/debian-security/ trixie-security main contrib non-free-firmware
deb-src https://mirrors.tuna.tsinghua.edu.cn/debian-security/ trixie-security main contrib non-free-firmware
```

### 禁用 Swap（两台 VM）

Kubelet 无法在启用 Swap 的系统上运行：

```bash
# 立即禁用
sudo swapoff -a

# 永久禁用（编辑 fstab 文件）
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 验证（应输出 0）
free | grep Swap | awk '{print $2}'
```

### 安装并配置容器运行时（两台 VM）

使用 Containerd 作为容器运行时（Kubernetes 1.24+ 推荐）：

```bash
# 1. 加载必需的内核模块
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# 2. 配置内核参数（生产级调优）
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
# Kubernetes 必需参数
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1

# 性能优化参数
net.core.somaxconn                  = 65535
net.ipv4.tcp_max_syn_backlog        = 8192
net.core.netdev_max_backlog         = 5000
vm.swappiness                       = 10
vm.max_map_count                    = 262144
fs.file-max                         = 655350
EOF

sudo sysctl --system

# 3. 安装 Containerd
sudo apt update
sudo apt install -y containerd

# 4. 创建生产级配置文件
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

# 5. 关键配置优化（生产必需）
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# 配置镜像加速（国内环境）
sudo sed -i 's|registry.k8s.io/pause:3\.[0-9]\+|registry.aliyuncs.com/google_containers/pause:3.10|g' /etc/containerd/config.toml

# 6. 启动并验证服务
sudo systemctl enable --now containerd
sudo systemctl status containerd
sudo ctr version

# 7. 验证配置
sudo ctr config dump | grep -A5 "plugins"
```

**Containerd 生产级配置详解：**

```toml
# /etc/containerd/config.toml 关键片段
[plugins."io.containerd.grpc.v1.cri"]
  enable_tls_streaming = false
  
  [plugins."io.containerd.grpc.v1.cri".containerd]
    snapshotter = "overlayfs"
    default_runtime_name = "runc"
    
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
      runtime_type = "io.containerd.runc.v2"
      
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
        SystemdCgroup = true  # Kubernetes 必需
        
  [plugins."io.containerd.grpc.v1.cri".registry]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
        endpoint = ["https://registry.aliyuncs.com"]
```

### 安装 Kubeadm、Kubelet、Kubectl（两台 VM）

添加 Kubernetes 官方仓库并安装 v1.33 版本：

```bash
# 1. 安装必需的工具
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

# 2. 添加 Kubernetes 官方 GPG 密钥
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# 3. 添加 Kubernetes v1.33 APT 仓库
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# 4. 刷新缓存
sudo apt-get update

# 5. 安装指定版本
sudo apt-get install -y kubelet=1.33.* kubeadm=1.33.* kubectl=1.33.*

# 6. 防止自动升级
sudo apt-mark hold kubelet kubeadm kubectl

# 7. 验证安装
kubeadm version
```

### 初始化 Control Plane（仅 VM 1 - Master 节点）

**前置条件：** 记录 Master 节点的 IP 地址（本例为 `192.168.199.135`）

```bash
# 初始化集群
sudo kubeadm init \
  --apiserver-advertise-address=192.168.199.135 \
  --pod-network-cidr=10.244.0.0/16 \
  --kubernetes-version v1.33.6 \
  --image-repository registry.aliyuncs.com/google_containers
```

**重要：** 初始化完成后，终端会输出：

- kubectl 配置命令
- **`kubeadm join` 命令**（必须保存供 Worker 节点使用）

### 配置 Kubectl（仅 VM 1）

```bash
# 为当前用户配置 kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 验证 Control Plane（节点状态应为 NotReady，等待网络插件）
kubectl get nodes
```

### Worker Node 加入集群（仅 VM 2）

在 VM 2 上执行步骤 5 中保存的 `kubeadm join` 命令：

```bash
sudo kubeadm join 192.168.199.135:6443 --token <YOUR_TOKEN> \
  --discovery-token-ca-cert-hash sha256:<YOUR_HASH>
```

**说明：** `<YOUR_TOKEN>` 和 `<YOUR_HASH>` 来自步骤 5 的输出。

### 部署网络插件 - Flannel（VM 1 或任意有 kubectl 访问的节点）

Kubernetes 需要网络插件实现 Pod 间通信。我们使用 Flannel：

```bash
# 部署 Flannel CNI
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# 等待 1-2 分钟，然后验证
kubectl get pods -n kube-system | grep flannel

# 验证所有系统 Pod 运行正常
kubectl get pods -n kube-system
```

### 预加载 Flannel 镜像（两台 VM - 可选但推荐）

如果网络不稳定或镜像下载缓慢，可提前在两台 VM 上加载 Flannel 镜像：

**方案一：直接拉取镜像**

```bash
# 1. 使用 ctr 直接拉取镜像到 containerd
sudo ctr image pull ghcr.io/flannel-io/flannel:v0.27.4
sudo ctr image pull ghcr.io/flannel-io/flannel-cni-plugin:v1.8.0-flannel1
```

**方案二：本地打包后导入**

如果镜像源不可达，可在能访问外网的机器上下载后导入：

```bash
# 在能访问外网的机器上执行
# 1. 拉取镜像
docker pull ghcr.io/flannel-io/flannel:v0.27.4
docker pull ghcr.io/flannel-io/flannel-cni-plugin:v1.8.0-flannel1

# 2. 打包成 tar 文件
docker save -o flannel_images.tar \
  ghcr.io/flannel-io/flannel:v0.27.4 \
  ghcr.io/flannel-io/flannel-cni-plugin:v1.8.0-flannel1

# 将 flannel_images.tar 文件复制到两台 VM，然后执行：

# 3. 在每台 VM 上导入镜像
# 导入到 k8s.io 命名空间
sudo ctr --namespace k8s.io image import flannel_images.tar

# 4. 验证镜像
sudo ctr images list | grep flannel
sudo ctr --namespace k8s.io images list | grep flannel
```

### 修复 CNI 插件路径（两台 VM）

如果 CoreDNS Pod 仍无法启动，执行以下修复：

```bash
# 1. 创建 CNI 标准目录
sudo mkdir -p /usr/lib/cni

# 2. 创建 Flannel 插件的符号链接
cd /usr/lib/cni/
for plugin in /opt/cni/bin/*; do
  sudo ln -sf "$plugin" "$(basename $plugin)"
done

# 3. 验证符号链接
ls -lh /usr/lib/cni/

# 4. 重启 Kubelet
sudo systemctl restart kubelet

# 5. 验证 Pod 状态
kubectl get pods -n kube-system
```

---

## ✅ 集群验证

### 最终验证（VM 1）

```bash
# 1. 检查所有节点状态（应全为 Ready）
kubectl get nodes

# 2. 检查所有系统 Pod（应全为 Running）
kubectl get pods -n kube-system

# 3. 查看集群信息
kubectl cluster-info

# 4. 运行测试 Pod
kubectl run test-pod --image=nginx --port=80
kubectl get pods
kubectl delete pod test-pod
```

### 常见验证命令

```bash
# 查看节点详细信息
kubectl describe node <NODE_NAME>

# 查看集群资源
kubectl top nodes

# 查看系统事件
kubectl get events -n kube-system

# 检查 API 服务器状态
kubectl get cs  # 已弃用，但可用于诊断
```

---

## 🐛 故障排除

### 问题：节点处于 NotReady 状态

**原因：** 网络插件未部署或未就绪

**解决方案：**

```bash
# 检查 Flannel Pod 状态
kubectl get pods -n kube-system | grep flannel

# 查看 Pod 日志
kubectl logs -n kube-system <FLANNEL_POD_NAME>
```

### 问题：CoreDNS Pod 处于 Pending 状态

**原因：** CNI 插件路径配置不正确

**解决方案：** 执行步骤 9 的修复步骤

### 问题：kubeadm join 失败

**原因：** Token 过期（默认 24 小时有效）

**解决方案：**

```bash
# 在 Master 节点生成新 Token
kubeadm token create --print-join-command
```

### 获取调试日志

```bash
# 查看 Kubelet 日志
sudo journalctl -u kubelet -f

# 查看 containerd 日志
sudo journalctl -u containerd -f

# 查看 kubeadm 日志
sudo cat /var/log/pods/kube-system_*/kubeadm-*/log
```

---

## 📌 常用命令参考

```bash
# 集群管理
kubectl get nodes                          # 列出所有节点
kubectl get pods -A                        # 列出所有 Pod
kubectl get svc -A                         # 列出所有服务
kubectl get events -n kube-system         # 查看系统事件

# 节点管理
kubectl cordon <NODE_NAME>                # 禁止 Pod 调度到该节点
kubectl uncordon <NODE_NAME>              # 允许 Pod 调度到该节点
kubectl drain <NODE_NAME>                 # 驱逐节点上的所有 Pod

# 日志查看
kubectl logs -n kube-system <POD_NAME>   # 查看 Pod 日志
kubectl describe pod <POD_NAME>           # 查看 Pod 详细信息

# 集群信息
kubectl cluster-info                      # 查看集群信息
kubectl api-resources                     # 查看所有 API 资源
```

---

## 📚 参考资源

- [Kubernetes 官方文档](https://kubernetes.io/docs/)
- [kubeadm 官方指南](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [Flannel 官方文档](https://github.com/flannel-io/flannel)
- [Containerd 官方文档](https://containerd.io/)

---

## 🚀 生产环境优化配置

### Kubelet 资源预留

编辑 `/var/lib/kubelet/config.yaml`（或通过 kubeadm 配置）：

```yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
systemReserved:
  cpu: "500m"
  memory: "1Gi"
  ephemeral-storage: "10Gi"
kubeReserved:
  cpu: "500m"
  memory: "1Gi"
  ephemeral-storage: "10Gi"
evictionHard:
  memory.available: "500Mi"
  nodefs.available: "10%"
  nodefs.inodesFree: "5%"
  imagefs.available: "10%"
maxPods: 110
imageGCHighThresholdPercent: 85
imageGCLowThresholdPercent: 80
```

**应用配置：**
```bash
sudo systemctl restart kubelet
kubectl describe node | grep -A5 "Allocated resources"
```

### API Server 性能调优

高并发场景配置（添加到 kubeadm init 参数）：

```bash
sudo kubeadm init \
  --apiserver-advertise-address=192.168.199.135 \
  --pod-network-cidr=10.244.0.0/16 \
  --kubernetes-version v1.33.6 \
  --image-repository registry.aliyuncs.com/google_containers \
  --apiserver-extra-args=--max-requests-inflight=800 \
  --apiserver-extra-args=--max-mutating-requests-inflight=400 \
  --apiserver-extra-args=--default-not-ready-toleration-seconds=300 \
  --apiserver-extra-args=--default-unreachable-toleration-seconds=300
```

### etcd 性能优化

编辑 `/etc/kubernetes/manifests/etcd.yaml`：

```yaml
spec:
  containers:
  - command:
    - etcd
    - --snapshot-count=10000  # 提高快照频率
    - --heartbeat-interval=200  # 心跳间隔（毫秒）
    - --election-timeout=2000  # 选举超时（毫秒）
    - --quota-backend-bytes=8589934592  # 8GB 存储限制
    - --auto-compaction-retention=1h  # 自动压缩
```

---

## 🔒 安全加固配置

### RBAC 最小权限原则

创建命名空间管理员角色：

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: namespace-admin
rules:
- apiGroups: ["", "apps", "extensions"]
  resources: ["*"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: production
  name: namespace-admin-binding
subjects:
- kind: User
  name: dev-user
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: namespace-admin
  apiGroup: rbac.authorization.k8s.io
```

### Pod 安全策略（PSP）

使用 Pod Security Standards：

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest
```

### 网络策略（Network Policy）

限制命名空间间通信：

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-same-namespace
  namespace: production
spec:
  podSelector: {}
  ingress:
  - from:
    - podSelector: {}
  egress:
  - to:
    - podSelector: {}
```

### 集群证书轮换

证书有效期检查与更新：

```bash
# 检查证书有效期
kubeadm certs check-expiration

# 更新证书（自动续期1年）
kubeadm certs renew all

# 重启控制平面组件
sudo kill -s SIGHUP $(pidof kube-apiserver)
sudo kill -s SIGHUP $(pidof kube-controller-manager)
sudo kill -s SIGHUP $(pidof kube-scheduler)

# 更新客户端证书
cp /etc/kubernetes/admin.conf ~/.kube/config
```

---

## 📊 监控与运维

### 集群健康检查脚本

```bash
cat << 'EOF' > k8s-health-check.sh
#!/bin/bash
echo "=== Kubernetes Cluster Health Check ==="
echo ""

echo "1. Node Status:"
kubectl get nodes -o wide
echo ""

echo "2. System Pods Status:"
kubectl get pods -n kube-system
echo ""

echo "3. Resource Usage:"
kubectl top nodes
kubectl top pods -A --sort-by=memory | head -n 10
echo ""

echo "4. Certificate Expiration:"
kubeadm certs check-expiration
echo ""

echo "5. Component Health:"
kubectl get componentstatuses
echo ""

echo "6. Recent Events:"
kubectl get events -A --sort-by='.lastTimestamp' | tail -n 20
echo ""

echo "7. Cluster Info:"
kubectl cluster-info
EOF
chmod +x k8s-health-check.sh
./k8s-health-check.sh
```

### etcd 备份与恢复

**备份脚本：**
```bash
cat << 'EOF' > etcd-backup.sh
#!/bin/bash
BACKUP_DIR="/backup/etcd"
DATE=$(date +%Y%m%d-%H%M%S)

ETCDCTL_API=3 etcdctl snapshot save ${BACKUP_DIR}/etcd-snapshot-${DATE}.db \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# 保留最近7天的备份
find ${BACKUP_DIR} -name "*.db" -mtime +7 -delete
EOF
chmod +x etcd-backup.sh
```

**恢复流程：**
```bash
# 1. 停止所有控制平面组件
sudo systemctl stop kubelet
sudo crictl stopp $(sudo crictl pods -q)
sudo crictl rmp $(sudo crictl pods -q)

# 2. 恢复 etcd 数据
ETCDCTL_API=3 etcdctl snapshot restore /backup/etcd/etcd-snapshot.db \
  --data-dir=/var/lib/etcd-restore

# 3. 更新 etcd manifest
sudo mv /var/lib/etcd /var/lib/etcd-old
sudo mv /var/lib/etcd-restore/member /var/lib/etcd
sudo systemctl start kubelet
```

### 日志收集配置

配置 Fluent Bit：
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: kube-system
data:
  fluent-bit.conf: |
    [SERVICE]
      Flush         1
      Log_Level     info
      Parsers_File  parsers.conf
    
    [INPUT]
      Name              tail
      Path              /var/log/containers/*.log
      Parser            cri
      Tag               kube.*
      Mem_Buf_Limit     10MB
    
    [FILTER]
      Name                kubernetes
      Match               kube.*
      Kube_URL            https://kubernetes.default.svc:443
      Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
    
    [OUTPUT]
      Name            forward
      Match           *
      Host            fluentd-server
      Port            24224
```

---

## 💡 最佳实践建议

### 镜像管理
- 使用私有仓库（Harbor、Nexus）
- 镜像扫描（Trivy、Clair）
- 版本锁定（避免使用 latest）
- 预加载关键镜像到节点

### 资源管理
- 设置合理的 requests/limits
- 使用 LimitRange 和 ResourceQuota
- 配置 Horizontal Pod Autoscaler (HPA)
- 启用 Vertical Pod Autoscaler (VPA)

### 网络配置
- 选择合适的 CNI 插件
- 配置网络策略隔离
- 使用 Service Mesh（Istio）进行流量管理
- 监控网络性能指标

### 存储管理
- 使用动态存储 provisioning
- 配置 StorageClass 多级别存储
- 定期备份 PVC 数据
- 监控存储使用情况

### 高可用配置
- 多 Master 节点（至少3个）
- etcd 集群独立部署（大规模场景）
- 配置 Pod 反亲和性
- 使用 PodDisruptionBudget (PDB)

