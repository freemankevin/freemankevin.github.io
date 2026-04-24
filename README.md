# FreemanKevin's Blog

[![首页预览](source/images/home.png)](https://www.freemankevin.uk)

个人技术博客，记录 DevOps、云原生、Linux 运维等技术笔记。

**访问地址：** https://www.freemankevin.uk

## 技术栈

- **博客框架：** [Hexo](https://hexo.io/) 8.x
- **主题：** [NexT](https://theme-next.js.org/) 8.x
- **搜索：** Algolia
- **部署：** GitHub Pages + GitHub Actions

## 本地运行

```shell
# 克隆项目
git clone https://github.com/freemankevin/freemankevin.github.io.git
cd freemankevin.github.io

# 安装依赖
npm install

# 启动本地服务
npm run server

# 或使用启动脚本
bash startup.sh
```

访问 http://localhost:4000 查看博客。

## 常用命令

```shell
npm run build   # 生成静态文件
npm run clean   # 清除缓存和静态文件
npm run deploy  # 部署到 GitHub Pages
```

## 文章分类

- **Linux** - 系统运维、网络配置、内核优化
- **Docker** - 容器化部署、镜像管理
- **Kubernetes** - 集群部署、服务治理
- **DevOps** - CI/CD、GitLab、Jenkins
- **Database** - PostgreSQL、MinIO 备份恢复

## 目录结构

```
.
├── source/
│   ├── _posts/       # 博客文章
│   └── images/       # 图片资源
├── themes/           # 主题配置
├── _config.yml       # Hexo 配置
├── _config.next.yml  # NexT 主题配置
└── package.json      # 依赖管理
```

## License

MIT