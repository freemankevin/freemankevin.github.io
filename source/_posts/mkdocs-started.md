---
title: 如何使用 MkDocs 创建和部署博客站点
date: 2024-12-25 09:00:00
tags:
  - MkDocs
  - GitHub Pages
  - GitHub
# comments: true
category: MkDocs
---

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;本指南将帮助你从头开始创建一个使用 MkDocs 的博客站点，并将其托管在 GitHub Pages 上。我们将涵盖以下内容：首先，我们会介绍如何安装 MkDocs，然后创建一个新的 MkDocs 项目。接下来，我们会配置和编辑内容，之后将站点部署到 GitHub Pages。我们还将介绍如何配置自定义域名，最后会添加 `.gitignore` 文件来忽略不必要的文件。



<!-- more -->

## 安装 MkDocs

首先，你需要确保已经安装了 MkDocs。你可以使用 `pip` 来安装 MkDocs：

```shell
pip install mkdocs
```

## 创建 MkDocs 项目

使用 MkDocs 的命令行工具创建一个新的项目：



```shell
mkdocs new my-blog
cd my-blog
```

这将创建一个名为 `my-blog` 的目录，其中包含一个基本的 MkDocs 配置文件和一些示例内容。

## 配置和编辑内容

### 启动开发服务器

启动 MkDocs 的开发服务器，这样你可以在本地查看你的站点：

```shell
mkdocs serve
```



运行此命令后，打开浏览器并访问 `http://127.0.0.1:8000/`，你应该能够看到 MkDocs 生成的默认页面。

### 编辑内容

项目目录中有一个 `docs` 文件夹，里面包含一个 `index.md` 文件。你可以编辑这个文件来修改主页内容，并添加更多的 Markdown 文件来创建其他页面。

### 配置站点

项目目录中有一个名为 `mkdocs.yml` 的文件，这是 MkDocs 的配置文件。你可以编辑这个文件来配置站点的各种设置，例如站点名称、主题、导航等。

示例 `mkdocs.yml` 配置文件：



```YAML
site_name: My Blog
nav:
  - Home: index.md
  - About: about.md
theme: readthedocs
```

## 部署到 GitHub Pages

当你对内容和配置满意后，可以将站点部署到 GitHub Pages。

### 推送代码到 GitHub

首先，初始化一个新的 Git 仓库并推送到 GitHub：



```shell
git init
git remote add origin https://github.com/<your-username>/<your-repo>.git
git add .
git commit -m "Initial commit"
git push -u origin main
```

### 部署到 GitHub Pages

使用 `mkdocs gh-deploy` 命令来部署站点：

```shell
mkdocs gh-deploy
```



## 配置自定义域名

如果你已经购买了自定义域名，可以按照以下步骤配置：

### 配置域名 DNS

在你的域名注册服务商的管理面板中，添加一个 CNAME 记录，指向你的 GitHub Pages URL。

示例：



```shell
Type: CNAME
Name: www
Value: <your-github-username>.github.io
```

如果你想使用裸域名（例如 `yourdomain.com`），你需要配置 A 记录指向 GitHub 的 IP 地址：



```shell
Type: A
Name: @
Value: 185.199.108.153
Value: 185.199.109.153
Value: 185.199.110.153
Value: 185.199.111.153
```

### 创建 CNAME 文件

在 `docs` 目录下创建一个名为 `CNAME` 的文件，并添加你的域名：

```sh
echo "yourdomain.com" > docs/CNAME
```



然后重新构建并部署：



```shell
mkdocs build
mkdocs gh-deploy
```

## 添加 `.gitignore` 文件

为了避免将不必要的文件推送到仓库中，创建一个 `.gitignore` 文件并添加以下内容：

plaintext

```.gitignore
# 忽略操作系统生成的文件
# macOS
.DS_Store

# Windows
Thumbs.db
ehthumbs.db
Desktop.ini

# VS Code 设置文件
.vscode/

# Python
*.pyc
*.pyo
*.pyd
__pycache__/
*.env
*.venv
env/
venv/
ENV/
env.bak/
venv.bak/

# MkDocs 构建输出
site/

# MkDocs 配置文件备份
mkdocs.yml.bak

# 忽略日志文件和数据库
*.log
*.sql
*.sqlite

# 忽略挂载目录
mnt/
media/
```

将 `.gitignore` 文件添加到 Git 仓库并提交：



```sh
git add .gitignore
git commit -m "Add .gitignore file"
git push origin main
```

通过以上步骤，你就可以创建并部署一个使用 MkDocs 的博客站点，并配置自定义域名和忽略不必要的文件。