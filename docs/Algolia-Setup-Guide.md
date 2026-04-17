# Algolia 自动更新配置指南

本指南帮助你配置 Algolia 搜索索引自动更新功能。

## 前提条件

1. 已有 Algolia 账号和应用（Application ID: `O3AB73GDVU`）
2. 已创建索引（Index Name: `freemankevin`）
3. 已安装 `hexo-algolia` 插件（当前版本: 1.3.2）

## Algolia API Key 类型说明

Algolia 有三种主要 API Key：

| API Key 类型 | 用途 | 权限 | 使用场景 | 安全等级 |
|-------------|------|------|---------|---------|
| **Search-Only API Key** | 前端搜索 | 仅搜索权限 | 配置在 `_config.yml` 中，供网站前端使用 | ✅ **最安全**（可公开） |
| **Write API Key** | 更新索引 | 仅写入权限 | GitHub Secrets 或本地环境变量 | ✅ **安全**（泄露风险低） |
| **Admin API Key** | 管理索引 | 完全权限 | ⚠️ **不推荐**用于自动化 | ⚠️ **高风险**（谨慎使用） |

当前配置：
- Search-Only API Key: `b3f1048d604fe9a6c9648855741c1e6d`（已配置）
- Write API Key: 需要创建（推荐）
- Admin API Key: 可用但不推荐（风险高）

## 方案一：GitHub Actions 自动更新（推荐）

### 步骤 1：创建 Write API Key（推荐）

⚠️ **最佳实践：使用 Write API Key 而非 Admin API Key**

**为什么使用 Write API Key？**
- ✅ 仅限写入权限，无法删除索引或修改敏感配置
- ✅ 泄露后影响范围小（仅限单个索引）
- ✅ 符合最小权限原则
- ❌ Admin API Key 有完全权限，泄露后风险极大

**创建步骤：**

1. 登录 [Algolia Dashboard](https://www.algolia.com/dashboard)
2. 进入应用 `O3AB73GDVU`
3. 点击 **Settings** → **API Keys**
4. 点击 **Create API Key**
5. 配置权限：

```json
{
  "description": "Hexo Algolia Indexing Key",
  "acl": [
    "addObject",      // 添加记录（必需）
    "deleteObject",   // 删除记录（必需，更新时需要）
    "listIndexes",    // 查看索引列表（必需）
    "editSettings"    // 修改索引设置（可选）
  ],
  "indexes": ["freemankevin"],  // 仅限此索引（提高安全性）
  "validity": 0,                // 永久有效
  "maxQueriesPerIPPerHour": 0,  // 无限制
  "maxHitsPerQuery": 0          // 无限制
}
```

6. 点击 **Create** 生成新的 Write API Key
7. ⚠️ 立即复制并保存（关闭窗口后无法再次查看）

**权限说明：**

| ACL 权限 | 作用 | 必需性 |
|---------|------|--------|
| `addObject` | 添加新记录到索引 | ✅ **必需** |
| `deleteObject` | 删除旧记录（更新时清理） | ✅ **必需** |
| `listIndexes` | 查看索引状态 | ✅ **必需** |
| `editSettings` | 修改索引配置（可选） | ⚠️ 可选 |
| `deleteIndex` | 删除整个索引 | ❌ **禁止**（Admin 才有） |
| `settings` | 查看配置 | ⚠️ 可选 |

### 步骤 2：配置 GitHub Secrets

1. 进入 GitHub 仓库：[freemankevin.github.io](https://github.com/freemankevin/freemankevin.github.io)
2. 点击 **Settings** → **Secrets and variables** → **Actions**
3. 点击 **New repository secret**
4. 配置：
   - Name: `ALGOLIA_WRITE_API_KEY`（推荐）
   - Value: 你创建的 Write API Key
5. 点击 **Add secret**

**可选：配置 Admin API Key（高风险）**

如果无法创建 Write API Key，可使用 Admin API Key：
1. Name: `ALGOLIA_ADMIN_API_KEY`
2. Value: Admin API Key（从 Dashboard 获取）

⚠️ **安全警告：**
- Admin API Key 有完全权限，包括删除索引
- 泄露后可被恶意删除整个索引
- 仅在无法创建 Write Key 时使用

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
$env:HEXO_ALGOLIA_INDEXING_KEY="your-write-api-key"
hexo clean
hexo generate
hexo algolia

# Linux/Mac
export HEXO_ALGOLIA_INDEXING_KEY="your-write-api-key"
hexo clean
hexo generate
hexo algolia
```

### 方法 2：创建本地脚本

创建 `scripts/update-algolia.sh`（Linux/Mac）：

```bash
#!/bin/bash
echo "Updating Algolia index..."

# 提示输入 Write API Key（推荐）
read -sp "Enter Algolia Write API Key: " ALGOLIA_KEY
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

# 提示输入 Write API Key
$ALGOLIA_KEY = Read-Host "Enter Algolia Write API Key" -AsSecureString
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

### ⚠️ 本地更新注意事项

**安全建议：**
- ✅ 优先使用 Write API Key（推荐）
- ⚠️ 仅在必要时使用 Admin API Key
- ❌ 不要将 Key 写入脚本文件
- ❌ 不要在 shell history 中保存 Key（使用 `read -sp`）

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

**原因：** Write API Key 或 Admin API Key 配置错误或过期

**解决方案：**
1. 检查 GitHub Secret 名称：
   - ✅ 应使用 `ALGOLIA_WRITE_API_KEY`（推荐）
   - ⚠️ 或使用 `ALGOLIA_ADMIN_API_KEY`（备用）
2. 在 Algolia Dashboard 检查 Key 是否有效
3. 重新生成 API Key 并更新 GitHub Secret
4. 验证 Key 的 ACL 权限是否正确：
   - 必须包含：`addObject`, `deleteObject`, `listIndexes`

### 问题 2：索引更新但搜索不到内容

**原因：** 前端 Search-Only API Key 配置错误

**解决方案：**
1. 检查 `_config.yml` 中的 `apiKey` 是否为 Search-Only Key
2. 确认不是 Write Key 或 Admin Key（这两种 Key 不应暴露在前端）
3. 验证前端主题配置是否正确引用 API Key

### 问题 3：hexo algolia 命令报错 "Permission denied"

**原因：** API Key 权限不足

**解决方案：**
```bash
# 检查 API Key 权限
# Write Key 必须包含以下 ACL：
# - addObject
# - deleteObject
# - listIndexes

# 重新创建具有正确权限的 Write Key
# 在 Algolia Dashboard -> Settings -> API Keys -> Create API Key
```

### 问题 4：GitHub Actions 未触发

**原因：** 路径过滤规则不匹配

**解决方案：**
1. 确认修改了 `source/_posts/**` 文件
2. 或手动触发 workflow_dispatch
3. 检查工作流文件路径：`.github/workflows/algolia-update.yml`

### 问题 5：Write API Key 创建后无法查看

**原因：** Algolia 安全机制，Key 创建后仅显示一次

**解决方案：**
1. ⚠️ 创建 Key 后立即复制并保存
2. 如果忘记，删除该 Key 并重新创建
3. 建议保存到安全位置（如密码管理器）

### 问题 6：索引更新速度慢

**原因：** 文章数量多或网络延迟

**解决方案：**
1. 调整 `chunkSize` 参数（默认 5000）：
```yaml
algolia:
  chunkSize: 10000  # 增大分块大小
```
2. 检查网络连接质量
3. 使用 Algolia Dashboard 监控 API 响应时间

## 安全最佳实践

⚠️ **重要安全提醒：**

### API Key 使用原则

1. **优先使用 Write API Key**
   - ✅ 仅限写入权限，最小权限原则
   - ✅ 泄露后影响范围有限（仅限单个索引）
   - ✅ 无法删除整个索引或修改关键配置

2. **避免使用 Admin API Key**
   - ❌ 完全权限，包括删除索引
   - ❌ 泄露后可被恶意删除所有数据
   - ❌ 仅在无法创建 Write Key 时备用

3. **前端仅用 Search-Only Key**
   - ✅ Search-Only Key 可以公开
   - ✅ 仅搜索权限，无写入能力
   - ✅ 即使泄露也无法修改数据

### 配置安全原则

1. **永远不要**在 `_config.yml` 中配置 Write 或 Admin API Key
2. **永远不要**将 Write 或 Admin API Key 提交到 Git 仓库
3. **永远不要**在前端代码中使用 Write 或 Admin API Key
4. Write API Key **必须**只存储在 GitHub Secrets 或本地环境变量中
5. Search-Only API Key 可以公开（仅用于前端搜索）

### API Key 泄露风险评估

| Key 类型 | 泄露后果 | 恢复难度 |
|---------|---------|---------|
| **Search-Only Key** | 无影响（仅搜索权限） | 无需恢复 |
| **Write Key** | 紧急删除索引数据 | 重建索引（1小时） |
| **Admin Key** | 恶意删除整个索引、修改配置 | 完全重建（数小时）+安全审计 |

### 泄露应急处理

如果 API Key 泄露：

**Write Key 泄露：**
1. 立即在 Algolia Dashboard 删除该 Key
2. 重新创建新的 Write Key
3. 更新 GitHub Secrets
4. 检查索引数据是否被篡改

**Admin Key 泄露：**
1. ⚠️ 立即删除该 Key（最高优先级）
2. 检查所有索引是否被删除或篡改
3. 备份并恢复索引数据
4. 重新创建所有 API Key
5. 安全审计所有操作日志
6. 更新所有 GitHub Secrets

## 参考资源

- [hexo-algolia 插件文档](https://github.com/oncletom/hexo-algolia)
- [Algolia API Keys 文档](https://www.algolia.com/doc/guides/security/api-keys/)
- [GitHub Actions Secrets 文档](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Algolia Crawler 文档](https://www.algolia.com/doc/tools/crawler/getting-started/overview/)

## 推荐配置总结

**生产环境推荐方案：**
- 使用 **GitHub Actions 自动更新**（方案一）
- Search-Only API Key 配置在 `_config.yml`（前端搜索）
- **Write API Key** 配置在 GitHub Secrets（自动更新）
- ⚠️ 仅在无法创建 Write Key 时使用 Admin API Key（备用）
- 每次 push 文章自动更新索引，实时生效

**开发环境推荐方案：**
- 使用 **本地手动更新**（方案二）
- 通过脚本临时输入 Write API Key
- 避免 API Key 泄露风险
- ⚠️ 不要使用 Admin Key（风险高）

**API Key 配置矩阵：**

| 环境 | Search-Only Key | Write Key | Admin Key |
|------|----------------|-----------|-----------|
| **前端网站** | ✅ `_config.yml` | ❌ 禁止 | ❌ 禁止 |
| **GitHub Actions** | ❌ 无需 | ✅ **推荐** GitHub Secrets | ⚠️ 备用 GitHub Secrets |
| **本地脚本** | ❌ 无需 | ✅ **推荐** 环境变量 | ⚠️ 备用环境变量 |

**权限分配最佳实践：**

```
┌─────────────────────────────────────┐
│        Algolia API Key 层级          │
└─────────────────────────────────────┘
           │
           ├─ Admin Key（完全权限）
           │  ⚠️ 仅管理员使用
           │  ❌ 不用于自动化
           │
           ├─ Write Key（写入权限）
           │  ✅ 自动化推荐
           │  ✅ GitHub Actions
           │  ✅ 本地脚本
           │
           └─ Search-Only Key（搜索权限）
              ✅ 前端公开
              ✅ _config.yml
              ✅ 可泄露无风险
```