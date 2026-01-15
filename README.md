# 🎮 Playdate C Game Template

> A friendly, beginner-friendly template for making Playdate games in C!

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Playdate SDK](https://img.shields.io/badge/Playdate-SDK-yellow)](https://play.date/dev/)

**No CMake needed!** Just run one script and you're ready to go! ✨

## ✨ What's This?

This is a **complete starter template** for making Playdate games in C. It includes:

- 🚀 **One-command setup** - Automatic environment configuration
- 🔨 **Simple build system** - No CMake or Make knowledge required
- 💻 **VS Code ready** - Press F5 to run your game!
- 📚 **Beginner-friendly docs** - Clear examples and explanations
- 🎮 **Working demo game** - See it running in seconds!

Perfect for both beginners and experienced developers! 🌟

## 🎯 Quick Start

### First Time? Run the Setup Wizard! 🧙‍♂️

```powershell
.\setup.ps1
```

This friendly wizard will:
- ✅ Check your computer for the right tools
- ✅ Set up environment variables
- ✅ Build and run the demo game
- ✅ Configure VS Code for you

**That's it!** You'll have a running game in minutes! 🎉

### Already Set Up? Let's Code! 💪

```powershell
# Build and run your game
.\build.ps1 -Run

# Just build
.\build.ps1

# Clean up
.\build.ps1 -Clean
```

Or use **VS Code**:
- Press `F5` to run your game
- Press `Ctrl+Shift+B` to build

## 📋 What You Need

- **Windows 10/11** 🪟
- **Visual Studio 2022** (Community is free!)
  - Include "Desktop development with C++"
- **Playdate SDK** - Download from [play.date/dev](https://play.date/dev/)
- **VS Code** (optional but recommended) 💙

**Don't have these yet?** No worries! The setup wizard will help you! 😊

## 📁 Project Structure

```
📦 MyPlaydateGame/
├── 🔧 setup.ps1          # Run this first! (Setup wizard)
├── 🔨 build.ps1          # Build your game
├── 📝 README.md          # You are here!
├── 📖 GETTING_STARTED.md # Your next stop!
├── 💻 src/
│   └── main.c            # Your game code lives here!
├── 🎨 .vscode/           # VS Code magic ✨
├── 📦 build/             # Build outputs (auto-generated)
└── 🎮 *.pdx              # Your game package!
```

## 🎓 Learning Path

New to Playdate development? Follow this path! 🛤️

1. 🏁 **Run `setup.ps1`** - Get everything installed
2. 🎮 **See the demo** - Watch it run in the simulator
3. ✏️ **Edit `src/main.c`** - Change the text, try stuff!
4. 📖 **Read `GETTING_STARTED.md`** - Learn the basics
5. 🚀 **Make your game!** - The world is your canvas!

## 🎨 What's in the Demo?

The template includes a simple bouncing text demo that shows:
- ✅ How to set up a game loop
- ✅ How to draw text on screen
- ✅ How to make things move
- ✅ How to display FPS

It's super simple so you can easily understand and modify it! 🌈

## 🛠️ Common Commands

```powershell
# Development workflow
.\build.ps1 -Run          # Build + Run (most common!)
.\build.ps1               # Just build
.\build.ps1 -Clean        # Clean everything

# In VS Code
F5                        # Run game
Ctrl+Shift+B              # Build
Ctrl+`                    # Open terminal
```

## 🎯 Making It Your Own

### 1. Rename Your Game

Edit these files:

**build.ps1** (line 13):
```powershell
$PROJECT_NAME = "MyAwesomeGame"
```

**CMakeLists.txt** (lines 27-28):
```cmake
set(PLAYDATE_GAME_NAME MyAwesomeGame)
set(PLAYDATE_GAME_DEVICE MyAwesomeGame_DEVICE)
```

### 2. Start Coding!

Open `src/main.c` and make it yours! 🎨

### 3. Add More Files

Create new `.c` and `.h` files in `src/`, they'll be automatically compiled! 🎉

## 🆘 Troubleshooting

### "Cannot run scripts"
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Cannot find SDK"
Make sure `PLAYDATE_SDK_PATH` environment variable is set. Run `setup.ps1` again!

### "cl is not recognized"
You need Visual Studio 2022 with C++ tools installed.

### VS Code IntelliSense not working
Restart VS Code after running `setup.ps1`.

**Still stuck?** Check [GETTING_STARTED.md](GETTING_STARTED.md) or visit the [Playdate Developer Forum](https://devforum.play.date/)!

## 📚 Documentation

- **[GETTING_STARTED.md](GETTING_STARTED.md)** - Learn Playdate C basics, APIs, and game development
- **[README.md](README.md)** - This file! Quick reference

That's it! We kept it simple. 😊

## 🌟 Features

- ✅ **Zero-dependency build** - No CMake or Make required!
- ✅ **Auto-detection** - Finds VS and SDK automatically
- ✅ **One-command setup** - `setup.ps1` does everything
- ✅ **VS Code integrated** - Keyboard shortcuts and debugging
- ✅ **Beginner-friendly** - Clear docs and working examples
- ✅ **Template ready** - Fork and start coding immediately!

## 🤝 Share This Template!

Love it? Share it! 💖

- Give it a ⭐ on GitHub
- Share with other Playdate devs
- Make something awesome and show us!

To use this template for a new game:
1. Fork or download this repository
2. Run `setup.ps1`
3. Start making your game!

## 📜 License

MIT License - Make awesome games! 🎮

See [License.md](License.md) for details.

## 🔗 Resources

- 📖 [Playdate SDK Docs](https://sdk.play.date/)
- 💬 [Developer Forum](https://devforum.play.date/)
- 🎮 [Official Playdate Site](https://play.date/)
- 📦 [SDK Examples](https://play.date/dev/)

---

<div align="center">

**Ready to make games?** 🚀

Run `.\setup.ps1` and let's go!

Made with 💛 for the Playdate community

</div>
