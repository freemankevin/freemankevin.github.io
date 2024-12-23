---
title: 使用镜像ISO 文件制做本地Yum 源
date: 2024-12-20 12:17:25
tags:
    - Yum
    - Linux
    - CentOS
category: Linux
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;本文介绍了如何在 CentOS 7 环境中使用镜像 ISO 文件制作本地 YUM 源。通过详细步骤指导，用户可以下载并挂载 CentOS 7.9 的 ISO 文件，创建 YUM 仓库配置文件，清理 YUM 缓存，并测试新的 YUM 仓库配置。文章还介绍了如何设置开机自动挂载 ISO 文件，以确保每次启动时本地 YUM 源都可用。通过这些步骤，用户可以在本地环境中使用 YUM 安装、更新或删除软件包。

<!-- more -->

> 这里以Centos7 环境为例，其他系统也是类似。

阿里云ISO 镜像下载地址：https://mirrors.aliyun.com/centos/7.9.2009/isos/x86_64/

要将CentOS 7.9的ISO映像文件挂载到CentOS 7.4系统上，并配置为本地YUM源，你可以按照以下步骤操作：

1. **上传ISO文件**:
   将CentOS 7.9的ISO文件上传到你的CentOS 7.4服务器上。假设ISO文件位于`/path/to/CentOS-7.9.iso`。

2. **创建挂载点**:
   创建一个目录来作为ISO文件的挂载点。

   ```sh
   sudo mkdir /mnt/cdrom
   ```

3. **挂载ISO文件**:
   使用`mount`命令将ISO文件挂载到刚创建的挂载点。

   ```sh
   sudo mount -o loop /path/to/CentOS-7.9.iso /mnt/cdrom
   ```

   `loop`选项用于将文件作为块设备挂载。

4. **创建YUM仓库配置文件**:
   在`/etc/yum.repos.d/`目录下创建一个新的`.repo`文件。

   ```sh
   sudo vi /etc/yum.repos.d/CentOS-Base.repo
   ```

   在该文件中添加以下内容：

   ```shell
   [local-cdrom]
   name=CentOS-7.9 Local Repository
   baseurl=file:///mnt/cdrom
   enabled=1
   gpgcheck=0 # 跳过检查
   gpgkey=file:///mnt/cdrom/RPM-GPG-KEY-CentOS-7
   ```

   按`ESC`，然后输入`:wq`保存并退出vi编辑器。

5. **清理YUM缓存**:
   清理YUM缓存，确保YUM识别新的仓库。

   ```shell
   sudo yum clean all
   sudo yum makecache
   ```

6. **测试新的YUM仓库**:
   使用YUM repolist命令检查仓库列表，确保本地仓库已经被添加。

   ```sh
   sudo yum repolist
   ```

7. **设置开机自动挂载**:
   如果你希望每次开机自动挂载ISO文件，可以编辑`/etc/fstab`文件。

   ```sh
   sudo vi /etc/fstab
   ```

   在文件末尾添加以下行：

   ```
   /path/to/CentOS-7.9.iso /mnt/cdrom iso9660 loop,ro 0 0
   ```

   再次按`ESC`，然后输入`:wq`保存并退出vi编辑器。

现在你可以使用本地YUM源来安装、更新或删除软件包了。例如：

```sh
sudo yum install <package-name>
```

确保在执行这些步骤之前，你有足够的权限，以防需要root权限执行某些命令。此外，ISO文件的路径应该是静态的；如果ISO文件移动到其他位置，你需要更新`/etc/fstab`和`/etc/yum.repos.d/CentOS-Base.repo`文件中的路径。

