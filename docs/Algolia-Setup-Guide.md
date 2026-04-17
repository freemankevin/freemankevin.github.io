# Algolia 自动更新配置指南

本指南帮助你配置 Algolia 搜索索引自动更新功能。

## 前提条件

1. 已有 Algolia 账号和应用（Application ID: `O3AB73GDVU`）
2. 已创建索引（Index Name: `freemankevin`）
3. 已安装 `hexo-algolia` 插件（当前版本: 1.3.2）

## Algolia API Key 类型说明

Algolia 有两种 API Key：

| API Key 类型 | 用途 | 权限 | 使用场景 |
|-------------|------|------|---------|
| **Search-Only API Key** | 前端搜索 | 仅搜索权限 | 配置在 `_config.yml` 中，供网站前端使用 |
| **Admin API Key** | 管理索引 | 完全权限 | 仅用于更新索引，**必须保密** |

当前配置：
- Search-Only API Key: `b3f1048d604fe9a6c9648855741c1e6d`（已配置）
- Admin API Key: 需要从 Algolia Dashboard 获取并配置到 GitHub Secrets

## 方案一：GitHub Actions 自动更新（推荐）

### 步骤 1：获取 Admin API Key

1. 登录 [Algolia Dashboard](https://www.algolia.com/dashboard)
2. 进入应用 `O3AB73GDVU`
3. 点击 **Settings** → **API Keys**
4. 找到 **Admin API Key**（⚠️ 此 Key 有完全权限，必须保密）

### 步骤 2：配置 GitHub Secrets

1. 进入 GitHub 仓库：[freemankevin.github.io](https://github.com/freemankevin/freemankevin.github.io)
2. 点击 **Settings** → **Secrets and variables** → **Actions**
3. 点击 **New repository secret**
4. 配置：
   - Name: `ALGOLIA_ADMIN_API_KEY`
   - Value: 你的 Admin API Key
5. 点击 **Add secret**

### 步骤 3：启用 GitHub Actions

1. 推送 `.github/workflows/algolia-update.yml` 文件到仓库
2. GitHub Actions 会自动触发工作流
3. 每次 push 到 `main` 分支且修改 `source/_posts/**` 文件时自动更新索引

### 工作流触发条件

```yaml
on:
  push:
    branches:
      - main
    paths:
      - 'source/_posts/**'  # 文章文件变更
      - '_config.yml'       # 配置文件变更
  workflow_dispatch:        # 支持手动触发
```

### 手动触发更新

在 GitHub Actions 页面点击 **Run workflow** 按钮，手动触发索引更新。

## 方案二：本地手动更新

### 方法 1：使用环境变量

```bash
# Windows PowerShell
$env:HEXO_ALGOLIA_INDEXING_KEY="your-admin-api-key"
hexo clean
hexo generate
hexo algolia

# Linux/Mac
export HEXO_ALGOLIA_INDEXING_KEY="your-admin-api-key"
hexo clean
hexo generate
hexo algolia
```

### 方法 2：创建本地脚本

创建 `scripts/update-algolia.sh`（Linux/Mac）：

```bash
#!/bin/bash
echo "Updating Algolia index..."

# 提示输入 Admin API Key
read -sp "Enter Algolia Admin API Key: " ALGOLIA_KEY
echo ""

# 设置环境变量并更新
export HEXO_ALGOLIA_INDEXING_KEY="$ALGOLIA_KEY"
hexo clean
hexo generate
hexo algolia

echo "Algolia index updated successfully!"
```

创建 `scripts/update-algolia.ps1`（Windows）：

```powershell
Write-Host "Updating Algolia index..." -ForegroundColor Yellow

# 提示输入 Admin API Key
$ALGOLIA_KEY = Read-Host "Enter Algolia Admin API Key" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ALGOLIA_KEY)
$PlainKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

# 设置环境变量并更新
$env:HEXO_ALGOLIA_INDEXING_KEY = $PlainKey
hexo clean
hexo generate
hexo algolia

Write-Host "Algolia index updated successfully!" -ForegroundColor Green
```

### 运行脚本

```bash
# Linux/Mac
chmod +x scripts/update-algolia.sh
./scripts/update-algolia.sh

# Windows PowerShell
.\scripts\update-algolia.ps1
```

## 方案三：Algolia Crawler（官方爬虫）

### 配置 Algolia Crawler

1. 登录 [Algolia Crawler](https://crawler.algolia.com/)
2. 创建新爬虫项目
3. 配置爬虫规则：

```json
{
  "index_name": "freemankevin",
  "start_urls": ["https://freemankevin.uk/"],
  "sitemap_urls": ["https://freemankevin.uk/sitemap.xml"],
  "selectors": {
    "lvl0": "header h1",
    "lvl1": "article h2",
    "lvl2": "article h3",
    "lvl3": "article h4",
    "lvl4": "article h5",
    "text": "article p, article li"
  }
}
```

4. 设置调度频率：每日自动爬取

**优缺点对比：**
- ✅ 无需配置 GitHub Secrets
- ✅ 官方维护，稳定可靠
- ❌ 爬取频率有限（免费版每日一次）
- ❌ 无法实时更新新文章

## 配置验证

### 验证 GitHub Actions 是否工作

1. 推送新文章到仓库
2. 查看 GitHub Actions 运行日志
3. 应看到类似输出：

```
INFO  Start processing
INFO  Hexo is running at http://localhost:4000
INFO  13 files generated in 512 ms
INFO  [Algolia] Identified 13 pages to index.
INFO  [Algolia] Indexing chunk 1 of 1 (13 records)
INFO  [Algolia] Index updated successfully.
```

### 验证索引是否更新

1. 登录 Algolia Dashboard
2. 进入索引 `freemankevin`
3. 检查记录数量是否增加
4. 使用搜索测试功能验证新文章可搜索

### 验证网站搜索功能

1. 打开网站：https://freemankevin.uk
2. 使用搜索框输入关键词
3. 应能搜索到新发布的文章

## 故障排查

### 问题 1：GitHub Actions 报错 "API Key 无效"

**原因：** Admin API Key 配置错误或过期

**解决方案：**
1. 检查 GitHub Secret `ALGOLIA_ADMIN_API_KEY` 是否正确
2. 在 Algolia Dashboard 重新生成 Admin API Key
3. 更新 GitHub Secret

### 问题 2：索引更新但搜索不到内容

**原因：** 前端 Search-Only API Key 配置错误

**解决方案：**
1. 检查 `_config.yml` 中的 `apiKey` 是否为 Search-Only Key
2. 确认不是 Admin API Key（Admin Key 不应暴露在前端）

### 问题 3：hexo algolia 命令报错

**原因：** 环境变量未设置或插件版本不兼容

**解决方案：**
```bash
# 检查插件是否安装
npm list hexo-algolia

# 重新安装插件
npm uninstall hexo-algolia
npm install hexo-algolia --save

# 使用环境变量运行
export HEXO_ALGOLIA_INDEXING_KEY="your-key"
hexo algolia
```

### 问题 4：GitHub Actions 未触发

**原因：** 路径过滤规则不匹配

**解决方案：**
1. 确认修改了 `source/_posts/**` 文件
2. 或手动触发 workflow_dispatch

## 安全最佳实践

⚠️ **重要安全提醒：**

1. **永远不要**在 `_config.yml` 中配置 Admin API Key
2. **永远不要**将 Admin API Key 提交到 Git 仓库
3. **永远不要**在前端代码中使用 Admin API Key
4. Admin API Key **必须**只存储在 GitHub Secrets 或本地环境变量中
5. Search-Only API Key 可以公开（仅用于前端搜索）

## 参考资源

- [hexo-algolia 插件文档](https://github.com/oncletom/hexo-algolia)
- [Algolia API Keys 文档](https://www.algolia.com/doc/guides/security/api-keys/)
- [GitHub Actions Secrets 文档](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Algolia Crawler 文档](https://www.algolia.com/doc/tools/crawler/getting-started/overview/)

## 推荐配置总结

**生产环境推荐方案：**
- 使用 **GitHub Actions 自动更新**（方案一）
- Search-Only API Key 配置在 `_config.yml`
- Admin API Key 配置在 GitHub Secrets
- 每次 push 文章自动更新索引，实时生效

**开发环境推荐方案：**
- 使用 **本地手动更新**（方案二）
- 通过脚本临时输入 Admin API Key
- 避免 API Key 泄露风险