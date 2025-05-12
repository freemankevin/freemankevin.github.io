---
title: 如何在 Docker 环境中部署 VLLM
date: 2025-05-12 17:14:25
tags:
    - Docker
    - VLLM
    - OPenAI
    - LLM
category: Development 
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 本指南将详细介绍如何在 Windows 和 Linux 系统上使用 Docker 部署 vLLM 大模型服务，并提供跨平台测试方案。

<!-- more -->

## 系统要求

### 硬件要求
- NVIDIA GPU (建议 RTX 3060 或更高)
- 显存要求:
  - Qwen/Qwen3-0.6B: 至少 8GB （本地测试）
  - Qwen/QwQ-32B: 至少 64GB（生产使用）
- 内存: 16GB 或更高

### 软件要求
- 操作系统:
  - Windows 10/11 (专业版/企业版)
  - Linux (Ubuntu 20.04+/CentOS 7+)
- Docker Engine 20.10+
- NVIDIA 驱动 535+
- NVIDIA Container Toolkit

## 准备工作

### 1. 安装必要组件

**Windows 环境:**

```powershell
# 安装 WSL2 (Windows 子系统)
wsl --install

# 安装 Docker Desktop
# 从 https://www.docker.com/products/docker-desktop 下载安装

# 安装 NVIDIA 驱动和 CUDA
# 从 https://developer.nvidia.com/cuda-downloads 下载
```

**Linux 环境:**

```bash
# 安装 Docker
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io

# 安装 NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
   && curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add - \
   && curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt-get update
sudo apt-get install -y nvidia-docker2
sudo systemctl restart docker
```

### 2. 验证环境

```bash
# 验证 Docker 安装
docker --version

# 验证 NVIDIA 支持
docker run --rm --gpus all nvidia/cuda:11.0.3-base-ubuntu20.04 nvidia-smi
```

## Docker 部署

### 1. 创建 docker-compose.yml 文件

```yaml
# version: '3.8'

services:
  vllm:
    image: vllm/vllm-openai:latest
    runtime: nvidia
    container_name: vllm
    restart: unless-stopped 
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              capabilities: [gpu]
              count: all
    volumes:
      - $HOME/.cache/huggingface:/root/.cache/huggingface
    ports:
      - "28000:8000"
    environment:
      - HF_HOME=/root/.cache/huggingface
      - PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
    command:
      - --model
      - Qwen/Qwen3-0.6B # 或 Qwen/QwQ-32B
      - --gpu-memory-utilization
      - "0.8"
      - --trust-remote-code
      - --max-num-seqs
      - "256"
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8000/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
```

**Windows 用户注意**:
- 将 `$HOME/.cache/huggingface` 替换为 `C:/Users/Devops/.cache/huggingface`
- 确保路径使用正斜杠 `/` 而非反斜杠 `\`

### 2. 启动服务

```bash
# 下载 vLLM 镜像
docker pull vllm/vllm-openai:latest

# 启动服务
docker-compose up -d
```

### 3. 验证服务

```bash
# 检查容器状态
docker ps

# 查看日志
docker logs vllm

# 健康检查
curl http://localhost:28000/health
```

## 模型下载与管理

### 1. 手动下载模型 (可选)

```bash
# 安装 huggingface_hub
pip install huggingface_hub

# 下载模型 (可在宿主机执行)
huggingface-cli download Qwen/Qwen3-0.6B 

# 模型默认存放在用户家目录下，比如:
# C:/Users/Devops/.cache/huggingface/hub/models--Qwen--Qwen3-0.6B
```

### 2. 使用 vLLM 自动下载

vLLM 会在首次启动时自动下载模型，但建议提前下载以避免超时。

## 服务测试

### 1. 使用 curl 测试

```bash
curl http://localhost:28000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
      "model": "Qwen/Qwen3-0.6B",
      "prompt": "你好，介绍一下你自己",
      "max_tokens": 100
  }'
```

### 2. 使用 HTML 测试界面

创建 `vllm-test.html` 文件：

```html
<!DOCTYPE html>
<html>
<body>
  <h2>vLLM 测试界面</h2>
  <textarea id="input" rows="4" cols="50" placeholder="输入提示词..."></textarea><br>
  <button onclick="generate()">生成</button>
  <pre id="output"></pre>

  <script>
    async function generate() {
      const input = document.getElementById("input").value;
      try {
        const response = await fetch("http://localhost:28000/v1/completions", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            model: "Qwen/Qwen3-0.6B",
            prompt: input,
            max_tokens: 100
          })
        });
        const result = await response.json();
        document.getElementById("output").textContent = result.choices[0].text;
      } catch (error) {
        document.getElementById("output").textContent = "错误: " + error.message;
      }
    }
  </script>
</body>
</html>
```

## 跨平台测试方案

### Windows 环境测试

1. **浏览器安全限制**:
   - Chrome/Firefox 默认阻止跨域请求
   - 解决方案:
     - 使用 `file:///` 协议直接打开 HTML 文件
     - 或使用以下命令启动 Chrome 禁用安全限制:
       ```powershell
       chrome.exe --user-data-dir="C:/Temp" --disable-web-security
       ```

2. **替代方案**:
   - 使用 Postman 或 Insomnia 测试 API
   - 使用 Python 脚本测试:
     ```python
     from openai import OpenAI
     
     client = OpenAI(base_url="http://localhost:28000/v1", api_key="token-abc123")
     
     completion = client.completions.create(
         model="Qwen/Qwen3-0.6B",
         prompt="你好，介绍一下你自己",
         max_tokens=100
     )
     print(completion.choices[0].text)
     ```

### Linux 环境测试

1. **浏览器测试**:
   - 可直接使用 Firefox 打开 HTML 文件
   - 或部署简单 HTTP 服务器:
     ```bash
     python3 -m http.server 8000
     ```
     然后访问 `http://localhost:8000/vllm-test.html`

2. **命令行测试**:
   ```bash
   # 使用 httpie 工具
   http POST http://localhost:28000/v1/completions \
     model="Qwen/Qwen3-0.6B" \
     prompt="你好" \
     max_tokens:=50
   ```

## 常见问题解决

### 1. 模型下载失败

**症状**: 容器日志显示下载超时或失败

**解决方案**:
- 手动下载模型到缓存目录
- 设置 HTTP 代理:
  ```yaml
  environment:
    - HF_HUB_ENABLE_HF_TRANSFER=1
    - http_proxy=http://your-proxy:port
    - https_proxy=http://your-proxy:port
  ```

### 2. GPU 内存不足

**症状**: CUDA out of memory 错误

**解决方案**:
- 降低 `--gpu-memory-utilization` 值 (如 0.5)
- 使用更小模型 (如 Qwen3-0.6B 替代 QwQ-32B)
- 添加 `--enforce-eager` 参数减少内存占用

### 3. 跨域问题 (CORS)

**症状**: HTML 测试界面无法访问 API

**解决方案**:
- 启动 vLLM 时添加 CORS 参数:
  ```yaml
  command:
    - --model
    - Qwen/Qwen3-0.6B
    - --cors-allow-origins "*"
  ```
- 或使用 Nginx 反向代理配置 CORS

### 4. Windows 路径问题

**症状**: 卷挂载失败

**解决方案**:
- 使用绝对路径并确保 Docker Desktop 已启用 "Shared Drives"
- 示例:
  ```yaml
  volumes:
    - C:/Users/Devops/.cache/huggingface:/root/.cache/huggingface
  ```

## 性能优化建议

1. **量化**:
   ```yaml
   command:
     - --model
     - Qwen/Qwen3-0.6B
     - --quantization
     - awq  # 或 gptq
   ```

2. **批处理优化**:
   ```yaml
   command:
     - --max-num-batched-tokens
     - "4096"
   ```

3. **并行推理**:
   ```yaml
   command:
     - --tensor-parallel-size
     - "2"  # 使用2个GPU
   ```