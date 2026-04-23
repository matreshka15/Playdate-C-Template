# 🎮 Playdate C 游戏模板

<div align="center">

[English](README.md) · [中文](README.zh-cn.md) · ⚡ [3 分钟极速入门](QUICKSTART.md)

**零配置的 Playdate 纯 C 游戏起步模板（Windows）。**
**不用 CMake，不用 Make，只要 `setup.ps1` → `build.ps1 -Run` 两条命令。**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Playdate SDK](https://img.shields.io/badge/Playdate-SDK%202.0%2B-blue)](https://play.date/dev/)
[![Windows](https://img.shields.io/badge/Windows-10%2F11-00A4EF)](#-系统要求)

</div>

---

## 🚀 三条命令，立刻跑起来

在项目根目录打开 PowerShell：

```powershell
# 1. 自动安装 & 检查环境（仅首次）
.\setup.ps1

# 2. 构建并在模拟器里运行
.\build.ps1 -Run

# 3. 在 VS Code 里直接按 F5 —— 以后就这么用。
```

第一条命令会**自动做完所有事**：找 SDK、找 Visual Studio、设置
`PLAYDATE_SDK_PATH`、写 [setup-config.json](setup-config.json)，最后还会问你
"要不要现在就构建 Demo？"—— 按回车就看到游戏跑起来了。

> **完全零基础？** → [QUICKSTART.md](QUICKSTART.md) 带你 3 分钟改完第一行代码。

---

## 📋 系统要求

| 工具 | 版本 | 为什么需要 |
|------|------|-----------|
| Windows 10/11 | 64 位 | 构建产物为 MSVC x64 |
| [Playdate SDK](https://play.date/dev/) | 2.0+ | 提供 `pd_api.h`、`pdc.exe`、模拟器 |
| [Visual Studio](https://visualstudio.microsoft.com/vs/community/) | 2017 / 2019 / 2022 | 提供 C 编译器（`cl.exe`）|
| → C++ 工作负载 | 必需 | 安装时**必须勾选** "Desktop development with C++" |
| PowerShell | 5.0+（系统自带）| 跑构建脚本 |
| [VS Code](https://code.visualstudio.com/) | 可选 | 一键 F5 构建+调试 |

**缺什么？** `.\setup.ps1` 会告诉你缺哪个，并给出下载链接。随时可以重跑。

---

## 📁 项目结构

```
📦 Playdate-C-Template/
│
├── 🔧 setup.ps1            ← 首次运行（向导）
├── 🔨 build.ps1            ← 构建 / 运行 / 清理
├── 🧪 test.ps1             ← 自测模板本身
│
├── 💻 src/
│   └── main.c              ← 你的游戏代码写这里
│
├── 📦 setup-config.json    ← 项目名/作者/路径（向导自动写入）
├── 📄 CMakeLists.txt       ← 可选的 CMake 路径（不用也行）
│
├── 🎨 .vscode/             ← F5 = 构建+运行+调试，任务已接好
│
└── 📖 docs/
    ├── GETTING_STARTED.md  ← API 教程
    ├── DEVELOPER_GUIDE.md  ← 构建系统原理
    ├── PUBLISHING_GUIDE.md ← 发布上架
    └── CONTRIBUTING.md
```

**新增 `.c` / `.h` 文件直接扔进 `src/` 即可，构建脚本会自动发现。无需改任何配置。**

---

## 💻 日常命令

| 命令 | 用途 |
|------|-----|
| `.\build.ps1 -Run` | 构建 + 启动模拟器（⭐ 最常用）|
| `.\build.ps1` | 仅构建 |
| `.\build.ps1 -Clean` | 清掉 `build/` 和 `*.pdx` |
| `.\build.ps1 -Config Release` | Release 优化构建（无调试信息）|
| `.\build.ps1 -Target Device` | 交叉编译真机版本（需 ARM toolchain + CMake）|
| `.\setup.ps1 -Mode check` | 环境坏了时用它诊断 |

**VS Code** 里：

| 按键 | 效果 |
|------|-----|
| `F5` | 构建 + 启动 + 附加调试器 |
| `Ctrl+Shift+B` | 仅构建 |
| `F9` | 下/取消断点 |
| `F10` / `F11` | 单步跳过 / 单步进入 |

---

## 🔧 改项目名 / 自定义

编辑 [setup-config.json](setup-config.json)：

```json
{
  "projectName": "我的超棒游戏",
  "author":      "你的名字",
  "description": "最好玩的 Playdate 游戏！",
  "bundleID":    "com.yourname.myawesomegame"
}
```

然后 `.\build.ps1`。脚本会用这些字段生成 `pdxinfo`，并同步更新
`.vscode/settings.json`，保证 F5 仍然能正确找到 `.pdx` 包。

---

## ⚠️ 故障排除

| 现象 | 解决 |
|------|-----|
| `无法加载脚本` | `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned` |
| 找不到 SDK | 重跑 `.\setup.ps1`；或手动 `$env:PLAYDATE_SDK_PATH = "..."` |
| `cl 不是命令` | 装 VS 2022 并**勾选** "Desktop development with C++" |
| `无法打开 pd_api.h` | `PLAYDATE_SDK_PATH` 失效 → 重跑 `.\setup.ps1` |
| F5 报 `xx.pdx 不存在` | 改了项目名但没重建 → 跑 `.\build.ps1` |
| 其他奇怪问题 | 跑 `.\setup.ps1 -Mode check`，它会诊断整条工具链 |

详细日志在 `logs/` 目录。

---

## 📚 文档导航

| 文档 | 何时看 |
|------|-------|
| [QUICKSTART.md](QUICKSTART.md) | 最初 5 分钟 |
| [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md) | 学 Playdate C API |
| [docs/DEVELOPER_GUIDE.md](docs/DEVELOPER_GUIDE.md) | 了解构建系统内部 |
| [docs/PUBLISHING_GUIDE.md](docs/PUBLISHING_GUIDE.md) | 准备发布 |
| [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) | 提 Issue / PR |

**外部资源：** [官方 SDK 文档](https://sdk.play.date/) · [开发者论坛](https://devforum.play.date/) · [play.date/dev](https://play.date/dev/)

---

## 📜 许可证

[MIT](License.md) —— 自由地做游戏。🎮

<div align="center">

**准备好了？** 打开 PowerShell，运行 `.\setup.ps1`。

</div>


