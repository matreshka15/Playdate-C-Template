# ⚡ 3 分钟极速入门 · 3-Minute Quickstart

> **没装 Playdate SDK / Visual Studio？** 先看 [README 的"系统要求"](README.zh-cn.md#-系统要求)。
> 都装好了？继续看下面三步。

---

## 🎬 三步搞定 · Three Steps

### 1️⃣  在项目根目录打开 PowerShell，运行：

```powershell
.\setup.ps1
```

向导会自动：找工具 → 写配置 → 设环境变量 → **问你要不要直接跑 Demo**。
点回车就能看到屏幕上的弹跳文字。✨

### 2️⃣  改一行代码试试

打开 [src/main.c](src/main.c)，找到这行：

```c
const char* text = "My Playdate Game!";
```

把它改成：

```c
const char* text = "Hello, <你的名字>!";
```

按 `Ctrl+S` 保存。

### 3️⃣  重新构建并运行

```powershell
.\build.ps1 -Run
```

或者在 VS Code 里直接按 **F5**。你会看到自己的名字在屏幕上弹跳 🎮

---

## 🧭 我下一步该干啥？

| 想做的事 | 怎么做 |
|---------|-------|
| 改变弹跳速度 | 编辑 [src/main.c](src/main.c) 里的 `dx`、`dy` |
| 改项目名 | 编辑 [setup-config.json](setup-config.json) 的 `projectName`，再 `.\build.ps1` |
| 加新 `.c` 文件 | 扔进 `src/` 目录就行，自动被编译 |
| 学 Playdate C API | 看 [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md) |
| 构建真机版本 | 装 ARM toolchain + CMake，然后 `.\build.ps1 -Target Device` |
| 出错了 | 看 [README 的"故障排除"](README.zh-cn.md#️-故障排除) 或跑 `.\setup.ps1 -Mode check` |

---

## 💡 常用 VS Code 快捷键

| 键 | 效果 |
|----|------|
| `F5` | 构建并启动模拟器（带调试器）|
| `Ctrl+Shift+B` | 仅构建 |
| `F9` | 在光标所在行下/取消断点 |
| `F10` / `F11` | 单步跳过 / 单步进入 |

---

<div align="center">

**卡住了？** 先试试：`.\setup.ps1 -Mode check`

跑通了就去 [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md) 继续学习 🚀

</div>
