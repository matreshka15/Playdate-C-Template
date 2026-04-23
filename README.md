# 🎮 Playdate C Game Template

<div align="center">

[English](README.md) · [中文](README.zh-cn.md) · ⚡ [3-Minute Quickstart](QUICKSTART.md)

**A zero-config, pure-C starter for Playdate games on Windows.**
**No CMake. No Make. Just `setup.ps1` → `build.ps1 -Run`.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Playdate SDK](https://img.shields.io/badge/Playdate-SDK%202.0%2B-blue)](https://play.date/dev/)
[![Windows](https://img.shields.io/badge/Windows-10%2F11-00A4EF)](#-requirements)

</div>

---

## 🚀 Get Running in 3 Commands

Open PowerShell in this folder:

```powershell
# 1. Install & verify everything (first time only)
.\setup.ps1

# 2. Build + launch in the simulator
.\build.ps1 -Run

# 3. In VS Code — press F5.   That's the whole workflow.
```

The first command does everything: finds your SDK + Visual Studio, sets
`PLAYDATE_SDK_PATH`, writes [setup-config.json](setup-config.json), and offers
to build the demo for you on the spot.

> **Brand-new to this?** → [QUICKSTART.md](QUICKSTART.md) walks through your first
> code change in 3 minutes.

---

## 📋 Requirements

| Tool | Version | Why you need it |
|------|---------|-----------------|
| Windows 10/11 | 64-bit | The build targets MSVC x64 |
| [Playdate SDK](https://play.date/dev/) | 2.0+ | Provides `pd_api.h`, `pdc.exe`, the simulator |
| [Visual Studio](https://visualstudio.microsoft.com/vs/community/) | 2017 / 2019 / 2022 | Contains the C compiler (`cl.exe`) |
| → VS C++ workload | required | Tick **"Desktop development with C++"** during install |
| PowerShell | 5.0+ (built-in) | Runs the build scripts |
| [VS Code](https://code.visualstudio.com/) | optional | One-click F5 build + debug |

**Missing something?** `.\setup.ps1` will tell you exactly what and link you to
the download page. It is safe to re-run at any time.

---

## 📁 What's in the box

```
📦 Playdate-C-Template/
│
├── 🔧 setup.ps1            ← run first (wizard)
├── 🔨 build.ps1            ← build / run / clean
├── 🧪 test.ps1             ← smoke-test the template itself
│
├── 💻 src/
│   └── main.c              ← your game code lives here
│
├── 📦 setup-config.json    ← project name / author / paths (auto-written)
├── 📄 CMakeLists.txt       ← optional CMake path (not required)
│
├── 🎨 .vscode/             ← F5 = build+run+debug, tasks pre-wired
│
└── 📖 docs/
    ├── GETTING_STARTED.md  ← API tutorial
    ├── DEVELOPER_GUIDE.md  ← build internals
    ├── PUBLISHING_GUIDE.md ← ship to the Playdate catalog
    └── CONTRIBUTING.md
```

**Add your own `.c` / `.h` files to `src/` — the build auto-discovers them.
No build-script edits required.**

---

## 💻 Daily commands

| Command | Does |
|---------|------|
| `.\build.ps1 -Run` | build + launch simulator (⭐ most-used) |
| `.\build.ps1` | build only |
| `.\build.ps1 -Clean` | wipe `build/` and `*.pdx` |
| `.\build.ps1 -Config Release` | optimized, no debug symbols |
| `.\build.ps1 -Target Device` | cross-compile for real hardware (needs ARM toolchain + CMake) |
| `.\setup.ps1 -Mode check` | diagnose a broken environment |

In **VS Code**:

| Key | Action |
|-----|--------|
| `F5` | Build + launch + attach debugger |
| `Ctrl+Shift+B` | Build only |
| `F9` | Toggle breakpoint |
| `F10` / `F11` | Step over / into |

---

## 🔧 Rename / customize the project

Edit [setup-config.json](setup-config.json):

```json
{
  "projectName": "MyAwesomeGame",
  "author":      "Your Name",
  "description": "The best Playdate game ever!",
  "bundleID":    "com.yourname.myawesomegame"
}
```

Then rebuild: `.\build.ps1`. The script regenerates `pdxinfo` from these
fields and `.vscode/settings.json` is kept in sync so `F5` still works.

---

## ⚠️ Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Scripts cannot be loaded` | `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned` |
| `Cannot find SDK` | Re-run `.\setup.ps1`, or set `$env:PLAYDATE_SDK_PATH` manually |
| `cl is not recognized` | Install VS 2022 + **"Desktop development with C++"** workload |
| `Cannot open include file 'pd_api.h'` | `PLAYDATE_SDK_PATH` is stale → re-run `.\setup.ps1` |
| F5 error: `MyPlaydateGame.pdx not found` | You renamed the project but didn't rebuild → run `.\build.ps1` |
| Anything else | Run `.\setup.ps1 -Mode check` — it diagnoses the whole toolchain |

Detailed logs land in `logs/`.

---

## 📚 Docs

| Doc | Read when |
|-----|-----------|
| [QUICKSTART.md](QUICKSTART.md) | First 5 minutes |
| [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md) | Learning the Playdate C API |
| [docs/DEVELOPER_GUIDE.md](docs/DEVELOPER_GUIDE.md) | Build internals, advanced workflows |
| [docs/PUBLISHING_GUIDE.md](docs/PUBLISHING_GUIDE.md) | Before you ship |
| [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) | Sending PRs / issues |

**External:** [Official SDK docs](https://sdk.play.date/) · [Dev forum](https://devforum.play.date/) · [play.date/dev](https://play.date/dev/)

---

## 📜 License

[MIT](License.md) — make games freely. 🎮

<div align="center">

**Ready?** Open PowerShell and run `.\setup.ps1`.

</div>
