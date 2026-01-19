# 🎮 Playdate C Game Template

<div align="center">

[English](README.md) · [中文](README.zh-cn.md)

A complete, beginner-friendly template for making Playdate games in pure C!

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Playdate SDK](https://img.shields.io/badge/Playdate-SDK%202.0%2B-blue)](https://play.date/dev/)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.0%2B-00A4EF)](https://microsoft.com/powershell)
[![VS 2022](https://img.shields.io/badge/Visual%20Studio-2022-9146FF)](https://visualstudio.microsoft.com)

**🎯 No CMake. No headaches. Just code!**

</div>

## ✨ Why This Template?

This is a **complete, production-ready starter template** for Playdate game development in C. Whether you're a complete beginner or an experienced developer, you'll be building games in minutes:

- 🚀 **One-Command Setup** - `.\setup.ps1` configures everything automatically
- 🔨 **Zero Dependencies** - No CMake, no Make, no complex build systems
- 💻 **VS Code Integration** - Press F5 to run, F10 to debug
- 📚 **Beginner-Friendly** - Clear examples, well-commented code
- 🎮 **Working Demo** - See a fully functional game immediately
- 🛠️ **Professional Build System** - PowerShell scripts that just work

Perfect for beginners learning their first language AND experienced developers looking for a quick setup! 🌟

## 🎯 Quick Start (2 Minutes!)

### Step 1️⃣: Run Setup

Open PowerShell in this folder and run:

```powershell
.\setup.ps1
```

This wizard will automatically:

- ✅ Check your system for required tools
- ✅ Detect Visual Studio 2022 and Playdate SDK
- ✅ Configure environment variables
- ✅ Build and run the demo game
- ✅ Set up VS Code for debugging

### Step 2️⃣: See Your Game

The demo game will launch in the Playdate Simulator. You'll see a bouncing text animation running at 30 FPS! 🎮

### Step 3️⃣: Start Coding

Edit `src/main.c` and run:

```powershell
.\build.ps1 -Run
```

Your changes will compile and run in seconds! ⚡

## 📋 System Requirements

| Requirement | Version | Notes |
|-----------|---------|-------|
| **OS** | Windows 10/11 | 64-bit |
| **Visual Studio** | 2022+ | Community (free), Professional, or Enterprise |
| **C++ Workload** | Required | "Desktop development with C++" |
| **Playdate SDK** | 2.0+ | [Download](https://play.date/dev/) |
| **PowerShell** | 5.0+ | Usually pre-installed |
| **VS Code** | Latest | Optional but recommended 💙 |

> **Don't have these yet?** No problem! The setup wizard will guide you through installation! 😊

## 📁 Project Structure

```
📦 Playdate-C-Template/
│
├── 🔧 setup.ps1                    # ⭐ Run this first!
├── 🔨 build.ps1                    # Build script
├── 🧪 test.ps1                     # Run tests
│
├── 📖 README.md                    # Quick start (you are here!)
├── 📖 docs/GETTING_STARTED.md      # Learning resources & examples
├── 📖 docs/DEVELOPER_GUIDE.md      # Advanced topics
│
├── 📦 setup-config.json            # Project configuration (auto-created)
├── 📄 CMakeLists.txt               # Alternative CMake build (optional)
├── 📄 Makefile                     # Unix/Linux build (optional)
│
├── 💻 src/
│   └── main.c                      # Your game code here! ✏️
│
├── 🎨 .vscode/
│   ├── settings.json               # Editor settings
│   ├── tasks.json                  # VS Code build tasks
│   ├── launch.json                 # Debugger configuration
│   └── c_cpp_properties.json       # IntelliSense setup
│
├── 📦 build/                       # Build artifacts (auto-generated)
├── 📊 logs/                        # Setup & build logs
└── 🎮 *.pdx                        # Your game package (auto-generated)
```

**Key Files:**

- `setup.ps1` - Initialize environment (run this first!)
- `build.ps1` - Compile your game
- `src/main.c` - Your actual game code
- `docs/GETTING_STARTED.md` - Playdate C API tutorial

## 🎓 Your Learning Path

Following this path will get you from zero to working game! 🚀

```
START HERE
    ↓
[1] Run: .\setup.ps1
    ↓
[2] See: Demo game bouncing in simulator
    ↓
[3] Read: docs/GETTING_STARTED.md (30 minutes)
    ↓
[4] Edit: src/main.c (change text, add colors)
    ↓
[5] Build: .\build.ps1 -Run
    ↓
[6] Learn: Playdate APIs in docs/GETTING_STARTED.md
    ↓
[7] Make: Your awesome game! 🎮
```

Each step typically takes 5-15 minutes. You'll have a working game by the end! 💪

## 🎨 What's in the Demo?

The template comes with a working, bouncing text demo game. It demonstrates:

```c
// Main game loop (runs 30 times per second)
static int update(void* userdata) {
    PlaydateAPI* pd = userdata;

    // Clear screen
    pd->graphics->clear(kColorWhite);

    // Draw text
    pd->graphics->setFont(font);
    pd->graphics->drawText(text, strlen(text), kASCIIEncoding, x, y);

    // Update position
    x += dx;
    y += dy;

    // Bounce off edges
    if (x < 0 || x > 400) dx = -dx;
    if (y < 0 || y > 240) dy = -dy;

    return 1; // Keep running
}
```

**Try this:**

1. Run the demo with `.\build.ps1 -Run`
2. Change `"My Playdate Game!"` to your name in `src/main.c`
3. Save and run again - your name bounces instantly!

Perfect way to learn the workflow! 🎯

## � Development Commands

### Quick Reference

| Command | What it does | When to use |
|---------|-----------|-----------|
| `.\setup.ps1` | Full setup wizard | First time setup |
| `.\setup.ps1 -Mode check` | System health check | Troubleshooting |
| `.\build.ps1 -Run` | Build + run in simulator | Daily development ⭐ |
| `.\build.ps1` | Build only | Testing without running |
| `.\build.ps1 -Clean` | Delete build artifacts | Before fresh build |

### In VS Code (Recommended!)

```
F5              → Run game in debugger ▶️
Ctrl+Shift+B    → Build project 🔨
F10             → Step over (debugging)
F11             → Step into (debugging)
Shift+F5        → Stop debugging
```

> 💡 **Tip:** VS Code's debugger automatically stops at breakpoints. Press F9 on any line to set a breakpoint!

## 🔧 Customizing Your Project

### 1. Change Project Name

After first run, edit `setup-config.json`:

```json
{
    "projectName": "MyAwesomeGame",
    "author": "Your Name",
    "description": "The best Playdate game ever!",
    "bundleID": "com.yourname.myawesomegame"
}
```

Then rebuild: `.\build.ps1`

### 2. Add More C Files

Create new files in `src/`:

```
src/
├── main.c           (entry point)
├── player.c         (player logic)
├── player.h         (player header)
├── enemy.c          (enemy logic)
└── enemy.h          (enemy header)
```

They'll be automatically compiled! No need to update build scripts. ✨

### 3. Add Game Assets

Create these folders in the project root:

```
images/              # For .png/.bmp graphics
sounds/              # For .mp3/.wav audio
fonts/               # For custom .pft fonts
```

Reference them in code:

```c
LCDBitmap* sprite = pd->graphics->loadBitmap("images/player.png", &err);
```

## ⚠️ Troubleshooting

### "Scripts cannot be loaded"

**Problem:** PowerShell won't run `.ps1` files

**Solution:**

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Then run `.\setup.ps1` again.

---

### "Cannot find SDK" / "PLAYDATE_SDK_PATH not set"

**Problem:** Setup wizard can't locate Playdate SDK

**Solutions:**

1. **Option A:** Download SDK from [play.date/dev](https://play.date/dev/)
2. **Option B:** Run `.\setup.ps1` again and specify the SDK path
3. **Option C:** Set environment variable manually:

   ```powershell
   [Environment]::SetEnvironmentVariable("PLAYDATE_SDK_PATH", "C:\path\to\PlaydateSDK", "Machine")
   ```

---

### "cl is not recognized" / "vcvars64.bat not found"

**Problem:** Visual Studio 2022 not installed or not in default location

**Solutions:**

1. Install [Visual Studio 2022 Community](https://visualstudio.microsoft.com/vs/community/) (free!)
2. During install, select "Desktop development with C++"
3. Restart your terminal and try again

---

### "Build failed" / Compilation errors

**Check these in order:**

1. ✅ Run `.\setup.ps1 -Mode check` - verify all tools
2. ✅ Check `logs/` folder for detailed error messages
3. ✅ Make sure `src/main.c` is saved (Ctrl+S in editor)
4. ✅ Try `.\build.ps1 -Clean` then `.\build.ps1 -Run`

---

### VS Code IntelliSense not working

**Problem:** VS Code doesn't show autocomplete or error highlighting

**Solutions:**

1. Install the **C/C++ Extension** (Microsoft) from VS Code marketplace
2. Restart VS Code completely
3. Run `.\setup.ps1` again to reconfigure
4. Delete `.vscode/.vs` folder if it exists

---

### "Cannot open include file 'pd_api.h'"

**Problem:** Compiler can't find the Playdate SDK headers

**Solution:**
Verify `PLAYDATE_SDK_PATH` is set:

```powershell
$env:PLAYDATE_SDK_PATH
```

Should output something like: `C:\path\to\PlaydateSDK`

---

### Still stuck? 🤔

1. 📖 Check [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md) for API examples
2. 📚 Read [docs/DEVELOPER_GUIDE.md](docs/DEVELOPER_GUIDE.md) for advanced topics
3. 💬 Visit [Playdate Developer Forum](https://devforum.play.date/)
4. 🆘 Search GitHub issues for similar problems

## 📚 Documentation

| Document | Purpose | Read When |
|----------|---------|-----------|
| **[README.md](README.md)** | Quick start guide | First time (you are here!) |
| **[docs/GETTING_STARTED.md](docs/GETTING_STARTED.md)** | API tutorial & examples | Learning Playdate C |
| **[docs/DEVELOPER_GUIDE.md](docs/DEVELOPER_GUIDE.md)** | Advanced workflows | Going deeper |
| **[docs/PUBLISHING_GUIDE.md](docs/PUBLISHING_GUIDE.md)** | Share your game | Before publishing |

### Quick Links

- 📖 **Official SDK Docs:** [sdk.play.date](https://sdk.play.date/)
- 💬 **Developer Forum:** [devforum.play.date](https://devforum.play.date/)
- 🎮 **Official Site:** [play.date](https://play.date/)
- 📦 **SDK Downloads:** [play.date/dev](https://play.date/dev/)

## ⭐ Why Choose This Template?

| Feature | This Template | Manual Setup |
|---------|---------------|--------------|
| Setup time | 1 minute | 30+ minutes |
| CMake required | ❌ No | ⚠️ Often yes |
| VS Code integration | ✅ Built-in | ❌ Manual config |
| Debugging | ✅ Ready to go | ❌ Complex setup |
| Beginner friendly | ✅ Yes | ❌ Complicated |
| Newbie docs | ✅ Included | ❌ None |
| Demo game | ✅ Included | ❌ Empty project |

Save yourself hours of configuration! Get straight to creating! 🚀

## 🤝 Contributing & Support

### Share This Template! 💖

Love it? Help others find it:

- ⭐ Star on GitHub
- 🔄 Share with friends learning Playdate
- 🐛 Report issues
- 💡 Suggest improvements

### Made Something Awesome?

Show us what you built! 🎮

- 📸 Post screenshots
- 🎬 Share gameplay videos
- 💬 Tell us on the forum

---

## 📜 License

MIT License - Make games freely! 🎮

See [License.md](License.md) for details.

---

<div align="center">

### 🚀 Ready? Let's Go

*Questions?* Visit the [Developer Forum](https://devforum.play.date/)

</div>
