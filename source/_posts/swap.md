---
title: 在没有 Swap 的服务器上创建 Swap
date: 2024-12-11 12:17:25
tags:
  - Mount
  - Linux
  - Swap
category: Linux
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在服务器上创建 Swap 文件是缓解内存不足的一种有效方法。本文介绍了如何在没有 Swap 分区的服务器上创建 Swap 文件，以提供额外的虚拟内存，从而保证系统的稳定性和性能。首先，我们检查系统是否已有 Swap 分区，然后通过创建和配置 Swap 文件来实现虚拟内存的扩展。最后，我们确保 Swap 文件在系统启动时自动启用。通过这些步骤，你可以在没有预配置 Swap 分区的服务器上创建 Swap 文件，确保系统在高负载情况下的稳定运行。

<!-- more -->

> 这里以16核、32GB内存、300GB数据盘的服务器进行举例。

#### 1. 检查当前系统是否有 Swap
首先，我们需要检查当前系统是否有 Swap 分区。执行以下命令：

```bash
swapon --show
```

如果没有输出，说明当前系统没有 Swap 分区。

#### 2. 创建 Swap 文件
为了在没有 Swap 分区的服务器上创建 Swap，我们可以使用文件来模拟 Swap。以下是创建 Swap 文件的详细步骤：

1. **创建 Swap 文件**：
   ```bash
   sudo dd if=/dev/zero of=/data/swapfile bs=1M count=20480
   ```
   解释：
   - `if=/dev/zero`：从零设备读取数据，用于创建文件。
   - `of=/data/swapfile`：指定目标文件名为 `/data/swapfile`，挂载在数据盘 `/data` 下。
   - `bs=1M`：设置块大小为1MB。
   - `count=20480`：指定文件大小为20GB（32GB内存 / 1.6 = 20GB）。

2. **更改 Swap 文件权限**：
   ```bash
   sudo chmod 600 /data/swapfile
   ```

3. **设置文件为Swap**：
   ```bash
   sudo mkswap /data/swapfile
   ```

4. **激活Swap文件**：
   ```bash
   sudo swapon /data/swapfile
   ```

#### 3. 配置开机自启
为了确保每次系统启动时自动启用 Swap 文件，我们需要在 `/etc/fstab` 文件中添加一行：

```bash
/data/swapfile   none    swap    sw    0   0
```

使用以下命令将其添加：

```bash
sudo nano /etc/fstab
```

在文件末尾添加上面的一行，并保存退出。

#### 4. 验证 Swap 文件创建成功
最后，我们可以验证 Swap 文件是否创建并成功启用：

```bash
swapon --show
```

如果输出中出现 `/data/swapfile`，则说明创建成功。

#### 5. 总结
通过本文中的步骤，你可以在没有 Swap 分区的服务器上创建一个Swap文件，从而有效缓解内存不足的情况。这种方法适用于内存充足但没有预配置Swap分区的服务器，确保系统稳定运行。
