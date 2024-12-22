---
title: GitHub 推送代码失败的解决方案
date: 2024-12-11 12:17:25
tags:
    - GitHub
    - Git
    - Proxy
category: GitHub
---


### 问题描述

在使用 Git 推送代码到 GitHub 时，**推送经常失败**，但带宽测试显示网络正常，上传和下载速度都没问题。经过排查发现，**Git 默认不会通过本地代理**，即使代理设置为全局模式也无效。这导致 GitHub 的访问不稳定。

------

### 解决方案

通过设置 Git 的代理，可以解决推送问题。



#### 1. 修改全局 Git 配置

执行以下命令编辑 Git 的全局配置文件：

```bash
git config --global --edit
```

添加如下内容，将 `127.0.0.1:7890` 替换为你的代理地址和端口：

```bash
[http]
proxy = http://127.0.0.1:7890

[https]
proxy = https://127.0.0.1:7890
```

#### 2. 验证代理配置

使用以下命令检查配置是否生效：

```bash
git config --global --get https.proxy
```

若返回代理地址（如 `https://127.0.0.1:7890`），说明设置成功。