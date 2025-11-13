---
title: Kubernetes v1.33 部署指南（使用 kubeadm）
date: 2025-11-13 17:47:25
keywords:
  - Kubernetes
  - ArgoCD
  - DevOps
  - GitOps
  - Helm
categories:
  - DevOps
  - Kubernetes
tags:
  - ArgoCD
  - Kubernetes
  - GitOps
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 本文档提供了在两台 Debian 13 虚拟机上部署 Kubernetes v1.33 集群的完整步骤。使用 kubeadm（官方推荐方式）部署，适合学习和测试 Kubernetes 核心功能。

<!-- more -->


## 🏗️ 部署架构

- VM 1：Control Plane (Master) - 运行 API Server、etcd、Scheduler、Controller Manager
- VM 2：Worker Node - 运行 Pods 和 Kubelet

---

## 🔧 前置要求

### 硬件资源

- 每台虚拟机至少 **2 CPU** 和 **2GB RAM**
- 推荐 **4 CPU** 和 **4GB RAM** 以获得更好的性能

### 网络配置

- 所有机器相互可通信（检查防火墙规则）
- Kubernetes 所需的开放端口已配置或防火墙已关闭
- 记录每台 VM 的 IP 地址（本指南使用 `192.168.199.135` 作为 Master 节点示例）

### 系统检查清单

执行以下检查确保系统就绪：

```bash
# 1. 验证 MAC 地址唯一性
ip link | grep link/ether

# 2. 验证 product_uuid 唯一性
cat /sys/class/dmi/id/product_uuid

# 3. 确认 Swap 已禁用
free | grep Swap
```

---

## 📦 安装步骤

### 步骤 1：配置 APT 源（两台 VM）

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

### 步骤 2：禁用 Swap（两台 VM）

Kubelet 无法在启用 Swap 的系统上运行：

```bash
# 立即禁用
sudo swapoff -a

# 永久禁用（编辑 fstab 文件）
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 验证（应输出 0）
free | grep Swap | awk '{print $2}'
```

### 步骤 3：安装并配置容器运行时（两台 VM）

使用 Containerd 作为容器运行时：

```bash
# 1. 加载必需的内核模块
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# 2. 配置内核参数
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# 3. 安装 Containerd
sudo apt update
sudo apt install -y containerd

# 4. 初始化配置文件
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

# 5. 启用 systemd cgroup 驱动（kubeadm 默认使用）
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# 6. 配置国内镜像源（加速 pause 镜像下载）
sudo sed -i 's|registry.k8s.io/pause:3\.[0-9]\+|registry.aliyuncs.com/google_containers/pause:3.10|g' /etc/containerd/config.toml

# 7. 启动并启用 Containerd 服务
sudo systemctl restart containerd
sudo systemctl enable containerd

# 8. 验证安装
sudo ctr version
```

### 步骤 4：安装 Kubeadm、Kubelet、Kubectl（两台 VM）

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

### 步骤 5：初始化 Control Plane（仅 VM 1 - Master 节点）

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

### 步骤 6：配置 Kubectl（仅 VM 1）

```bash
# 为当前用户配置 kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 验证 Control Plane（节点状态应为 NotReady，等待网络插件）
kubectl get nodes
```

### 步骤 7：Worker Node 加入集群（仅 VM 2）

在 VM 2 上执行步骤 5 中保存的 `kubeadm join` 命令：

```bash
sudo kubeadm join 192.168.199.135:6443 --token <YOUR_TOKEN> \
  --discovery-token-ca-cert-hash sha256:<YOUR_HASH>
```

**说明：** `<YOUR_TOKEN>` 和 `<YOUR_HASH>` 来自步骤 5 的输出。

### 步骤 8：部署网络插件 - Flannel（VM 1 或任意有 kubectl 访问的节点）

Kubernetes 需要网络插件实现 Pod 间通信。我们使用 Flannel：

```bash
# 部署 Flannel CNI
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# 等待 1-2 分钟，然后验证
kubectl get pods -n kube-system | grep flannel

# 验证所有系统 Pod 运行正常
kubectl get pods -n kube-system
```

### 步骤 8.1：预加载 Flannel 镜像（两台 VM - 可选但推荐）

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

### 步骤 9：修复 CNI 插件路径（两台 VM）

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

