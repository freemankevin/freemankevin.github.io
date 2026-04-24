---
title: Windows Tiny10 恢复中文语言包与微软拼音输入法完整指南
date: 2026-04-24 10:17:18
tags:
    - Windows
    - Tiny10
    - 中文支持
    - 输入法
category: Windows
---

Tiny10 是 Windows 10 的精简版本，移除了大量预装组件以减小系统体积。然而，这也导致了中文语言包、输入法和字体等组件的缺失，使得中文显示乱码，影响日常使用。本文将详细介绍如何在 Tiny10 系统中恢复中文支持，包括语言包安装、输入法配置和字体修复。

<!-- more -->

**适用版本与环境说明：**
- 操作系统: Windows Tiny10（基于 Windows 10 LTSC 精简）
- 更新日期: 2026-04-24
- 需要管理员权限

{% note warning %}
Tiny10 移除了部分系统功能，某些 PowerShell 命令可能不可用。如果遇到命令执行失败，请尝试使用 DISM 替代方案。
{% endnote %}

---

## 问题背景

在 Tiny10 系统中，由于精简了语言包和输入法组件，会出现以下问题：

1. **中文乱码**：命令行、编辑器中的中文显示为乱码
2. **无中文输入法**：无法输入中文
3. **系统区域设置缺失**：无法切换到中文环境

---

## 方案一：命令行修复（推荐）

### 1. 安装中文语言包

**方法一：使用 PowerShell（推荐）**

以管理员身份运行 PowerShell：

```powershell
# 添加中文语言到语言列表
$LanguageList = Get-WinUserLanguageList
$LanguageList.Add("zh-CN")
Set-WinUserLanguageList $LanguageList -Force

# 安装语言功能（字体、OCR等）
Install-Language -Language zh-CN
```

**方法二：使用 DISM（备用）**

如果上述命令不可用（Tiny10 可能移除了该功能），使用 DISM：

```powershell
# 查看可用语言包
DISM /Online /Get-Capabilities

# 安装中文语言包和字体
DISM /Online /Add-Capability /CapabilityName:Language.Basic~~~zh-CN~0.0.1.0
DISM /Online /Add-Capability /CapabilityName:Language.Fonts.Hans~~~und-HANS~0.0.1.0
DISM /Online /Add-Capability /CapabilityName:Language.Handwriting~~~zh-CN~0.0.1.0
DISM /Online /Add-Capability /CapabilityName:Language.OCR~~~zh-CN~0.0.1.0
DISM /Online /Add-Capability /CapabilityName:Language.TextToSpeech~~~zh-CN~0.0.1.0
```

---

### 2. 恢复微软拼音输入法

```powershell
# 确保语言包已安装
DISM /Online /Add-Capability /CapabilityName:Language.TextToSpeech~~~zh-CN~0.0.1.0

# 添加微软拼音输入法
$langList = Get-WinUserLanguageList
$langList[0].InputMethodTips.Clear()
$langList[0].InputMethodTips.Add('0804:00000804')  # 微软拼音
Set-WinUserLanguageList $langList -Force
```

---

### 3. 修复字体（解决乱码问题）

如果中文仍然显示乱码，可能是缺少中文字体。

**方法一：从正常 Windows 系统复制字体**

从正常的 Windows 10 系统复制以下字体文件到 Tiny10：

```
源路径: C:\Windows\Fonts\
目标路径: C:\Windows\Fonts\

需要复制的字体:
- msyh.ttc (微软雅黑)
- msyhbd.ttc (微软雅黑 Bold)
- simhei.ttf (黑体)
- simsun.ttc (宋体)
```

**方法二：安装开源字体**

```powershell
# 下载 Noto Sans CJK SC 字体
Invoke-WebRequest -Uri "https://github.com/googlefonts/noto-cjk/raw/main/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf" -OutFile "$env:TEMP\NotoSans.otf"

# 安装字体
Copy-Item "$env:TEMP\NotoSans.otf" "C:\Windows\Fonts\"
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" -Name "Noto Sans CJK SC (TrueType)" -Value "NotoSans.otf" -PropertyType String
```

---

### 4. 设置系统区域

```powershell
# 设置系统区域为中文
Set-WinSystemLocale -SystemLocale zh-CN
Set-WinUILanguageOverride -Language zh-CN
Set-Culture -CultureInfo zh-CN

# 设置非 Unicode 程序的语言
Set-WinSystemLocale zh-CN
```

{% note info %}
设置完成后需要重启系统才能生效。
{% endnote %}

---

## 方案二：离线包安装（无网络环境）

如果系统无法联网，可以使用离线安装方式。

### 1. 准备离线包

从正常 Windows 10 系统复制语言包文件：

```
源路径: C:\Windows\servicing\LCU\
或者从微软官方下载 Language Pack ISO
```

### 2. 使用 DISM 离线安装

```powershell
# 假设语言包存放在 D:\LanguagePack 目录
DISM /Online /Add-Package /PackagePath:"D:\LanguagePack\Microsoft-Windows-LanguageFeatures-Basic-zh-cn-Package.cab"
DISM /Online /Add-Package /PackagePath:"D:\LanguagePack\Microsoft-Windows-LanguageFeatures-Fonts-Hans-Package.cab"
```

---

## 方案三：GUI 方式（备选）

如果命令行方式遇到问题，可以尝试图形界面操作：

1. 打开 **Settings → Time & Language → Language**
2. 点击 **Add a language**
3. 选择 **中文（简体，中国）**
4. 点击 **Options** → **Download language pack**
5. 重启系统

---

## 验证安装

重启系统后，执行以下命令验证：

```powershell
# 检查已安装的语言包
Get-WinUserLanguageList

# 检查系统语言
Get-WinSystemLocale

# 测试中文显示
echo 测试中文显示

# 设置命令行为 UTF-8 编码
chcp 65001
```

---

## 备选方案：便携版输入法

如果以上方法都无法恢复微软拼音输入法，可以考虑使用第三方便携版输入法：

### 小小输入法（绿色版）

- 官网: https://yong.dgod.net/
- 特点: 无需安装，不依赖系统组件
- 支持拼音、五笔等多种输入方式

### 使用方法

1. 下载便携版压缩包
2. 解压到任意目录
3. 运行主程序即可使用

---

## 常见问题

### Q1: DISM 命令执行失败？

检查 Windows Update 服务是否正常运行：

```powershell
# 启动 Windows Update 服务
net start wuauserv

# 或者设置为自动启动
sc config wuauserv start= auto
net start wuauserv
```

### Q2: 字体安装后仍然乱码？

1. 检查控制面板 → 区域 → 管理 → 更改系统区域设置
2. 勾选 "Beta 版: 使用 Unicode UTF-8 提供全球语言支持"
3. 重启系统

### Q3: 输入法切换快捷键无效？

```powershell
# 检查输入法设置
Get-WinUserLanguageList | Select-Object InputMethodTips

# 手动添加输入法切换热键
# 设置 → 时间和语言 → 语言 → 拼写、键入和键盘设置 → 高级键盘设置 → 语言栏选项
```

---

## 总结

Tiny10 作为精简版系统，虽然体积小、运行快，但也牺牲了一些实用性组件。通过本文介绍的方法，可以恢复中文语言支持，解决中文乱码问题，并重新获得中文输入能力。建议优先使用命令行方式（方案一），如遇网络问题则使用离线安装（方案二），最后可考虑便携版输入法作为备选方案。