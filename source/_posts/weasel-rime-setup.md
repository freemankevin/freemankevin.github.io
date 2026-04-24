---
title: Windows 小狼毫输入法（Rime）安装配置指南
date: 2026-04-24 10:36:58
tags:
    - Windows
    - Rime
    - 输入法
    - 小狼毫
category: Windows
---

小狼毫（Weasel）是 Rime 输入法在 Windows 平台上的实现。Rime 是一款开源、高度可定制的输入法引擎，支持多种输入方案（拼音、双拼、五笔等），深受技术用户喜爱。本文将介绍小狼毫的安装、基础配置和进阶用法。

<!-- more -->

**适用版本与环境说明：**
- 操作系统: Windows 10/11
- 输入法版本: 小狼毫 (Weasel) 0.15+
- 更新日期: 2026-04-24

{% note info %}
Rime 是跨平台的输入法引擎：
- Windows: 小狼毫 (Weasel)
- macOS: 鼠须管 (Squirrel)
- Linux: 中州韵 (ibus-rime / fcitx5-rime)
{% endnote %}

---

## 安装步骤

### 方式一：官方下载

访问 Rime 官网下载安装包：

```
https://rime.im/download/
```

下载后双击安装程序，按提示完成安装。

### 方式二：包管理器安装（推荐）

使用 Windows 包管理器安装：

```powershell
# 使用 winget
winget install RIME.Weasel

# 或使用 scoop
scoop install weasel
```

{% note warning %}
安装完成后需要重启系统或注销后重新登录，输入法才能正常加载。
{% endnote %}

---

## 基础配置

### 配置文件位置

小狼毫的用户配置文件位于：

```
%APPDATA%\Rime\
```

主要的配置文件：

| 文件名 | 说明 |
|--------|------|
| `default.custom.yaml` | 全局配置（候选词数量、输入方案等） |
| `weasel.custom.yaml` | 外观配置（配色、字体、布局） |
| `user.yaml` | 用户信息 |

### 最小化配置

#### 创建 `default.custom.yaml`

```yaml
patch:
  # 候选词数量
  "menu/page_size": 5
  
  # 配色方案
  style/color_scheme: clean_white
  
  # 输入方案列表
  schema_list:
    - schema: luna_pinyin_simp  # 简体拼音
```

#### 创建 `weasel.custom.yaml`

```yaml
patch:
  # 配色方案
  "style/color_scheme": minimal_white
  "style/horizontal": true  # 横向候选栏
  "style/font_face": "Segoe UI, Microsoft YaHei"
  "style/font_point": 12
  "style/layout/border": 0
  "style/layout/margin_x": 12
  "style/layout/margin_y": 12
  "style/layout/spacing": 10
  
  # 自定义配色：简约白
  "preset_color_schemes/minimal_white":
    name: "简约白 / Minimal White"
    author: "Custom"
    back_color: 0xFFFFFF
    border_color: 0xE0E0E0
    text_color: 0x424242
    hilited_text_color: 0x000000
    hilited_back_color: 0xF5F5F5
    candidate_text_color: 0x606060
    hilited_candidate_text_color: 0x000000
    hilited_candidate_back_color: 0xEEEEEE
```

### 部署配置

修改配置文件后，需要重新部署才能生效：

1. 右键点击任务栏小狼毫图标
2. 选择 **重新部署**
3. 等待部署完成（几秒钟）

---

## 快速上手

### 常用快捷键

| 快捷键 | 功能 |
|--------|------|
| `Ctrl + ~` | 切换输入方案 |
| `Ctrl + Shift + 1` | 中英文切换 |
| `Ctrl + Shift + F` | 繁简转换 |
| `Shift` | 临时英文模式 |
| `Ctrl + .` | 切换中西文标点 |

### 切换输入方案

安装后默认使用明月拼音，可通过以下方式切换：

1. 按 `Ctrl + ~` 打开方案选单
2. 输入方案编号选择
3. 或右键托盘图标 → 输入方案设定

---

## 进阶配置

### 同步配置到 GitHub

使用 Git 管理配置文件，实现多设备同步：

```powershell
cd $env:APPDATA\Rime

# 初始化 Git 仓库
git init
git add .
git commit -m "Init Rime config"

# 关联远程仓库
git remote add origin https://github.com/your-username/rime-config.git
git branch -M main
git push -u origin main
```

在其他设备上恢复配置：

```powershell
cd $env:APPDATA\Rime
git clone https://github.com/your-username/rime-config.git .
```

### 词库扩展

#### 使用雾凇拼音词库

雾凇拼音是一个高质量的简体拼音词库：

```powershell
# 克隆词库
cd $env:TEMP
git clone https://github.com/iDvel/rime-ice.git

# 复制配置文件到 Rime 目录
Copy-Item -Recurse -Force "$env:TEMP\rime-ice\*" "$env:APPDATA\Rime\"
```

复制后重新部署即可生效。

#### 自定义词库

在用户目录创建 `custom_phrase.txt`：

```
# 编码<Tab>词组
rime    小狼毫
github  GitHub
```

在 `luna_pinyin.custom.yaml` 中引入：

```yaml
patch:
  "translator/dictionary": luna_pinyin
  "translator/prism": luna_pinyin_simp
  "translator/custom_phrase": "custom_phrase.txt"
```

### 添加更多输入方案

内置输入方案：

| 方案 | 说明 |
|------|------|
| `luna_pinyin` | 明月拼音（繁体） |
| `luna_pinyin_simp` | 明月拼音（简体） |
| `double_pinyin` | 自然码双拼 |
| `double_pinyin_flypy` | 小鹤双拼 |
| `wubi_pinyin` | 五笔拼音混输 |
| `terra_pinyin` | 地球拼音 |

在 `default.custom.yaml` 中添加：

```yaml
patch:
  schema_list:
    - schema: luna_pinyin_simp
    - schema: double_pinyin_flypy
    - schema: wubi_pinyin
```

---

## 常见问题

### Q1: 输入法候选框不显示？

检查小狼毫服务是否运行：

```powershell
# 重启服务
net stop WeaselService
net start WeaselService
```

或在任务管理器中重启 `WeaselServer.exe`。

### Q2: 配置修改后无效？

1. 确保文件编码为 UTF-8
2. 检查 YAML 格式是否正确（注意缩进）
3. 重新部署配置

### Q3: 如何设置默认英文模式？

在 `default.custom.yaml` 中添加：

```yaml
patch:
  "switches/@0/reset": 1  # 0 为中文，1 为英文
```

### Q4: 如何关闭模糊音？

在 `luna_pinyin.custom.yaml` 中设置：

```yaml
patch:
  "speller/algebra":
    - erase/^xx$/  # 移除模糊音配置
```

### Q5: 如何备份用户词频？

用户词频存储在以下文件：

```
%APPDATA%\Rime\luna_pinyin.userdb\
```

使用 Git 同步或定期备份此目录。

---

## 配色方案参考

### 简约白

```yaml
"preset_color_schemes/minimal_white":
  name: "简约白"
  back_color: 0xFFFFFF
  border_color: 0xE0E0E0
  text_color: 0x424242
  hilited_candidate_text_color: 0x000000
  hilited_candidate_back_color: 0xEEEEEE
  candidate_text_color: 0x606060
```

### 深色模式

```yaml
"preset_color_schemes/minimal_dark":
  name: "简约黑"
  back_color: 0x2B2B2B
  border_color: 0x3C3C3C
  text_color: 0xD4D4D4
  hilited_candidate_text_color: 0xFFFFFF
  hilited_candidate_back_color: 0x3C3C3C
  candidate_text_color: 0x808080
```

### 跟随系统

在 `weasel.custom.yaml` 中设置：

```yaml
patch:
  "style/color_scheme_dark": minimal_dark  # 深色模式配色
  "style/color_scheme": minimal_white        # 浅色模式配色
```

---

## 总结

小狼毫作为 Rime 在 Windows 平台的实现，提供了高度可定制的输入体验。通过配置文件可以精细控制候选词数量、外观样式、输入方案等。配合 Git 同步，可以轻松在多台设备间共享配置和词库。对于追求效率和个性化的用户来说，小狼毫是一个值得尝试的选择。