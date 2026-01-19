# 🎮 Playdate C 游戏模板

<div align="center">

[English](README.md) · [中文](README.zh-cn.md)

一个完整的、对初学者友好的 Playdate 纯 C 游戏开发模板！

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Playdate SDK](https://img.shields.io/badge/Playdate-SDK%202.0%2B-blue)](https://play.date/dev/)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.0%2B-00A4EF)](https://microsoft.com/powershell)
[![VS 2022](https://img.shields.io/badge/Visual%20Studio-2022-9146FF)](https://visualstudio.microsoft.com)

**🎯 无需 CMake。无需复杂配置。只需编码！**

</div>

## ✨ 为什么选择本模板？

这是一个**完整的、生产就绪的 Playdate 游戏开发模板**。无论你是完全初学者还是经验丰富的开发者，都能在几分钟内开始制作游戏：

- 🚀 **一键配置** - `.\setup.ps1` 自动配置所有内容
- 🔨 **零依赖构建** - 无需 CMake、无需 Make、无需复杂构建系统
- 💻 **VS Code 集成** - 按 F5 运行、F10 调试
- 📚 **初学者友好** - 清晰的示例、注释完善的代码
- 🎮 **完整演示** - 立即看到一个完全可运行的游戏
- 🛠️ **专业构建系统** - PowerShell 脚本让一切正常工作

完美适合初学者学习第一门语言，也适合有经验的开发者快速上手！🌟

## 🎯 快速开始（仅需 2 分钟！）

### 第 1️⃣ 步：运行安装向导

在该文件夹中打开 PowerShell 并运行：

```powershell
.\setup.ps1
```

这个友好的向导将自动：

- ✅ 检查系统是否有所需工具
- ✅ 自动检测 Visual Studio 2022 和 Playdate SDK
- ✅ 配置环境变量
- ✅ 编译并运行演示游戏
- ✅ 为 VS Code 设置调试配置

### 第 2️⃣ 步：查看你的游戏

演示游戏将在 Playdate 模拟器中启动。你会看到一个以 30 FPS 运行的弹跳文字动画！🎮

### 第 3️⃣ 步：开始编码

编辑 `src/main.c` 并运行：

```powershell
.\build.ps1 -Run
```

你的更改将在几秒内编译并运行！⚡

## 📋 系统要求

| 要求 | 版本 | 说明 |
|------|------|------|
| **操作系统** | Windows 10/11 | 64 位 |
| **Visual Studio** | 2022+ | Community（免费）、Professional 或 Enterprise |
| **C++ 工作负载** | 必需 | "Desktop development with C++" |
| **Playdate SDK** | 2.0+ | [下载](https://play.date/dev/) |
| **PowerShell** | 5.0+ | 通常已预装 |
| **VS Code** | 最新版 | 可选但推荐 💙 |

> **还没有？** 没问题！安装向导会指导你！😊

## 📁 项目结构

```
📦 Playdate-C-Template/
│
├── 🔧 setup.ps1                    # ⭐ 首先运行这个！
├── 🔨 build.ps1                    # 构建脚本
├── 🧪 test.ps1                     # 运行测试
│
├── 📖 README.md                    # 快速开始（英文）
├── 📖 README.zh-cn.md              # 快速开始（中文）
├── 📖 GETTING_STARTED.md           # 学习资源和示例
├── 📖 DEVELOPER_GUIDE.md           # 高级主题
│
├── 📦 setup-config.json            # 项目配置（自动生成）
├── 📄 CMakeLists.txt               # CMake 构建配置（可选）
├── 📄 Makefile                     # Unix/Linux 构建（可选）
│
├── 💻 src/
│   └── main.c                      # 你的游戏代码在这里！✏️
│
├── 🎨 .vscode/
│   ├── settings.json               # 编辑器设置
│   ├── tasks.json                  # VS Code 构建任务
│   ├── launch.json                 # 调试器配置
│   └── c_cpp_properties.json       # IntelliSense 设置
│
├── 📦 build/                       # 构建产物（自动生成）
├── 📊 logs/                        # 设置和构建日志
└── 🎮 *.pdx                        # 你的游戏包（自动生成）
```

**关键文件：**

- `setup.ps1` - 初始化环境（首先运行这个！）
- `build.ps1` - 编译你的游戏
- `src/main.c` - 你的实际游戏代码
- `GETTING_STARTED.md` - Playdate C API 教程

## 🎓 你的学习路径

按照这个路径，你将从零开始制作可工作的游戏！🚀

```
从这里开始
    ↓
[1] 运行：.\setup.ps1
    ↓
[2] 查看：演示游戏在模拟器中弹跳
    ↓
[3] 阅读：GETTING_STARTED.md（30 分钟）
    ↓
[4] 编辑：src/main.c（改变文字、添加颜色）
    ↓
[5] 构建：.\build.ps1 -Run
    ↓
[6] 学习：GETTING_STARTED.md 中的 Playdate API
    ↓
[7] 创作：你的超棒游戏！🎮
```

每一步通常需要 5-15 分钟。完成后你就会有一个工作的游戏！💪

## 💻 开发命令

### 快速参考

| 命令 | 功能 | 何时使用 |
|------|------|---------|
| `.\setup.ps1` | 完整设置向导 | 首次设置 |
| `.\setup.ps1 -Mode check` | 系统健康检查 | 故障排除 |
| `.\build.ps1 -Run` | 构建 + 在模拟器中运行 | 日常开发 ⭐ |
| `.\build.ps1` | 仅构建 | 测试构建 |
| `.\build.ps1 -Clean` | 删除构建文件 | 重新开始构建 |

### 在 VS Code 中（推荐！）

```
F5              → 在调试器中运行游戏 ▶️
Ctrl+Shift+B    → 构建项目 🔨
F10             → 单步跳过（调试）
F11             → 单步进入（调试）
Shift+F5        → 停止调试
```

> 💡 **提示：** VS Code 的调试器会自动在断点处停止。按 F9 在任意行设置断点！

## 🎨 演示中有什么？

模板附带一个工作的、弹跳的文字演示游戏。它展示了：

```c
// 主游戏循环（每秒运行 30 次）
static int update(void* userdata) {
    PlaydateAPI* pd = userdata;

    // 清空屏幕
    pd->graphics->clear(kColorWhite);

    // 绘制文字
    pd->graphics->setFont(font);
    pd->graphics->drawText(text, strlen(text), kASCIIEncoding, x, y);

    // 更新位置
    x += dx;
    y += dy;

    // 在边缘反弹
    if (x < 0 || x > 400) dx = -dx;
    if (y < 0 || y > 240) dy = -dy;

    return 1; // 继续运行
}
```

**试试这个：**

1. 用 `.\build.ps1 -Run` 运行演示
2. 在 `src/main.c` 中将 `"My Playdate Game!"` 改成你的名字
3. 保存并再次运行 - 你的名字立即弹跳起来！

完美的工作流学习方式！🎯

## 🔧 自定义你的项目

### 1. 更改项目名称

首次运行后，编辑 `setup-config.json`：

```json
{
    "projectName": "我的超棒游戏",
    "author": "你的名字",
    "description": "最好的 Playdate 游戏！",
    "bundleID": "com.yourname.myawesomegame"
}
```

然后重新构建：`.\build.ps1`

### 2. 添加更多 C 文件

在 `src/` 中创建新文件：

```
src/
├── main.c           （入口点）
├── player.c         （玩家逻辑）
├── player.h         （玩家头文件）
├── enemy.c          （敌人逻辑）
└── enemy.h          （敌人头文件）
```

它们会自动编译！无需更新构建脚本。✨

### 3. 添加游戏资源

在项目根目录创建这些文件夹：

```
images/              # 用于 .png/.bmp 图形
sounds/              # 用于 .mp3/.wav 音频
fonts/               # 用于自定义 .pft 字体
```

在代码中引用它们：

```c
LCDBitmap* sprite = pd->graphics->loadBitmap("images/player.png", &err);
```

## ⚠️ 故障排除

### "无法加载脚本"

**问题：** PowerShell 拒绝运行 `.ps1` 文件

**解决方案：**

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

然后再次运行 `.\setup.ps1`。

---

### "找不到 SDK" / "PLAYDATE_SDK_PATH 未设置"

**问题：** 设置向导找不到 Playdate SDK

**解决方案：**

1. **选项 A：** 从 [play.date/dev](https://play.date/dev/) 下载 SDK
2. **选项 B：** 再次运行 `.\setup.ps1` 并指定 SDK 路径
3. **选项 C：** 手动设置环境变量：

   ```powershell
   [Environment]::SetEnvironmentVariable("PLAYDATE_SDK_PATH", "C:\path\to\PlaydateSDK", "Machine")
   ```

---

### "cl 无法识别" / "找不到 vcvars64.bat"

**问题：** 未安装 Visual Studio 2022 或不在默认位置

**解决方案：**

1. 安装 [Visual Studio 2022 Community](https://visualstudio.microsoft.com/vs/community/)（免费！）
2. 安装期间选择"Desktop development with C++"
3. 重启你的终端并重试

---

### "构建失败" / 编译错误

**按顺序检查这些：**

1. ✅ 运行 `.\setup.ps1 -Mode check` - 验证所有工具
2. ✅ 检查 `logs/` 文件夹获取详细错误信息
3. ✅ 确保 `src/main.c` 已保存（编辑器中按 Ctrl+S）
4. ✅ 尝试 `.\build.ps1 -Clean` 然后 `.\build.ps1 -Run`

---

### VS Code 智能感知不工作

**问题：** VS Code 不显示自动完成或错误高亮

**解决方案：**

1. 从 VS Code 应用商店安装 **C/C++ Extension**（Microsoft）
2. 完全重启 VS Code
3. 再次运行 `.\setup.ps1` 重新配置
4. 如果存在，删除 `.vscode/.vs` 文件夹

---

### "无法打开包含文件 'pd_api.h'"

**问题：** 编译器找不到 Playdate SDK 头文件

**解决方案：**
验证 `PLAYDATE_SDK_PATH` 已设置：

```powershell
$env:PLAYDATE_SDK_PATH
```

应该输出类似：`C:\path\to\PlaydateSDK`

---

### 仍然卡住？🤔

1. 📖 查看 [GETTING_STARTED.md](GETTING_STARTED.md) 获取 API 示例
2. 📚 阅读 [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) 获取高级主题
3. 💬 访问 [Playdate 开发者论坛](https://devforum.play.date/)
4. 🆘 在 GitHub 中搜索类似问题

## 📚 文档

| 文档 | 用途 | 何时阅读 |
|------|------|---------|
| **[README.md](README.md)** | 快速开始指南（英文）| 首次使用 |
| **[README.zh-cn.md](README.zh-cn.md)** | 快速开始指南（中文）| 首次使用（你在这里！） |
| **[GETTING_STARTED.md](GETTING_STARTED.md)** | API 教程和示例 | 学习 Playdate C |
| **[DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md)** | 高级工作流 | 深入学习 |
| **[PUBLISHING_GUIDE.md](PUBLISHING_GUIDE.md)** | 分享你的游戏 | 发布前 |

### 快速链接

- 📖 **官方 SDK 文档：** [sdk.play.date](https://sdk.play.date/)
- 💬 **开发者论坛：** [devforum.play.date](https://devforum.play.date/)
- 🎮 **官方网站：** [play.date](https://play.date/)
- 📦 **SDK 下载：** [play.date/dev](https://play.date/dev/)

## ⭐ 为什么选择本模板？

| 功能 | 本模板 | 手动设置 |
|------|-------|---------|
| 设置时间 | 1 分钟 | 30+ 分钟 |
| 需要 CMake | ❌ 否 | ⚠️ 通常需要 |
| VS Code 集成 | ✅ 内置 | ❌ 手动配置 |
| 调试支持 | ✅ 开箱即用 | ❌ 复杂配置 |
| 初学者友好 | ✅ 是 | ❌ 复杂 |
| 新手文档 | ✅ 包含 | ❌ 无 |
| 演示游戏 | ✅ 包含 | ❌ 空项目 |

省去数小时的配置时间！直接开始创建！🚀

## 🤝 贡献和支持

### 分享本模板！💖

喜欢它？帮助其他人找到它：

- ⭐ 在 GitHub 上 Star
- 🔄 与学习 Playdate 的朋友分享
- 🐛 报告 Bug
- 💡 提出改进建议

### 做出了很棒的东西？

展示给我们看！🎮

- 📸 发布截图
- 🎬 分享游戏视频
- 💬 在论坛中告诉我们

---

## 📜 许可证

MIT 许可证 - 自由制作游戏！🎮

详见 [License.md](License.md)。

---

<div align="center">

### 🚀 准备好了？让我们开始吧

*有问题？* 访问 [开发者论坛](https://devforum.play.date/)

</div>
