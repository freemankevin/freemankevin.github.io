<p align="center">
  <a href="https://freemankevin.uk">
    <img src="https://raw.githubusercontent.com/FreemanKevin/freemankevin.github.io/gh-pages/images/avatar.jpg" width="220" alt="Kevin's Notes">
  </a>
</p>

<p align="center">
  <strong>
    A personal tech blog focusing on DevOps, MLOps, and AIOps practices, built with
    <a href="https://hexo.io">Hexo</a>
  </strong>
</p>

<p align="center">
  <a href="https://hexo.io"><img
    src="https://img.shields.io/badge/Hexo-5.0+-0E83CD?style=flat-square&logo=hexo"
    alt="Hexo"
  /></a>
  <a href="https://nodejs.org"><img
    src="https://img.shields.io/badge/Node.js-14.0+-339933?style=flat-square&logo=node.js"
    alt="Node.js"
  /></a>
  <a href="https://hub.docker.com/r/freelabspace/freemankevin"><img
    src="https://img.shields.io/docker/pulls/freelabspace/freemankevin?style=flat-square&logo=docker"
    alt="Docker Pulls"
  /></a>
  <a href="https://github.com/FreemanKevin/FreemanKevin.github.io/stargazers"><img
    src="https://img.shields.io/github/stars/FreemanKevin/FreemanKevin.github.io?style=flat-square&logo=github"
    alt="GitHub Stars"
  /></a>
  <a href="LICENSE"><img
    src="https://img.shields.io/github/license/FreemanKevin/FreemanKevin.github.io?style=flat-square"
    alt="License"
  /></a>
</p>

<p align="center">
  🌟 <a href="https://freemankevin.uk">Visit Site</a> |
  📖 <a href="https://freemankevin.uk/archives/">Archives</a> |
  📊 <a href="https://freemankevin.uk/categories/">Categories</a> |
  🔖 <a href="https://freemankevin.uk/tags/">Tags</a> |
  📰 <a href="https://freemankevin.uk/atom.xml">RSS</a>
</p>

<p align="center">
  <a href="https://freemankevin.uk">
    <img src="https://raw.githubusercontent.com/FreemanKevin/freemankevin.github.io/gh-pages/images/screenshot.png" width="700" />
  </a>
</p>

<p align="center">
  <em>
    Visit the blog –
    <a href="https://freemankevin.uk">freemankevin.uk</a>
  </em>
</p>

## 🛠 Tech Stack

- **Framework**: [Hexo](https://hexo.io)
- **Theme**: [NexT.Gemini](https://theme-next.js.org)
- **Hosting**: GitHub Pages
- **Search**: Algolia
- **Container**: [Docker](https://hub.docker.com/r/freelabspace/freemankevin)

## Quick Start
```shell
# clone project
git clone https://github.com/FreemanKevin/FreemanKevin.github.io.git
cd FreemanKevin.github.io

# run project
git clone https://github.com/next-theme/hexo-theme-next themes/next
rm -rf node_modules && npm install --force
hexo cl && hexo g && hexo s

# git push
hexo cl && hexo g && hexo d

# algolia push
hexo cl && hexo g && hexo algolia 

# git commit
git add .
git commit -m "update files"
git push
```

## 🗂 Content Categories

- DevOps Practices
- Machine Learning Operations
- CI/CD Pipelines
- Security
- Cloud Native

## 🐳 Docker Usage

Quick start with Docker:
```bash
docker run -d -p 80:80 freelabspace/freemankevin:latest
```

Or use Docker Compose:
```yaml
version: '3'
services:
  blog:
    image: freelabspace/freemankevin:latest
    ports:
      - "80:80"
    restart: unless-stopped
```

## 📄 License

This blog is licensed under [MIT License](LICENSE). 