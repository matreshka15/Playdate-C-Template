# Playdate C Template Developer Guide

> Comprehensive guide for developers working with this template

---

## 📖 Table of Contents

1. [Overview](#overview)
2. [Project Structure](#project-structure)
3. [Quick Start](#quick-start)
4. [Configuration](#configuration)
5. [Development Workflow](#development-workflow)
6. [Building and Testing](#building-and-testing)
7. [Debugging](#debugging)
8. [Advanced Topics](#advanced-topics)
9. [Troubleshooting](#troubleshooting)
10. [Best Practices](#best-practices)

---

## Overview

This template provides a complete foundation for developing Playdate games using C. It includes:

- **Automated setup** - One-command environment configuration
- **Flexible build system** - No CMake/Make knowledge required
- **VS Code integration** - Full IDE support with debugging
- **Beginner-friendly** - Well-documented and easy to extend

### Supported Platforms

- **Windows**: 10/11 (Primary development platform)
- **Visual Studio**: 2022 Community/Professional/Enterprise
- **Playdate SDK**: 2.0+

---

## Project Structure

```
MyPlaydateGame/
├── 📄 setup.ps1              # Setup wizard (run this first!)
├── 📄 build.ps1              # Build script
├── 📄 setup-config.json      # Configuration file
├── 📄 CMakeLists.txt         # CMake configuration (optional)
├── 📄 Makefile               # Make build file (optional)
├── 📄 README.md              # Quick start guide
├── 📄 GETTING_STARTED.md     # Learning resources
├── 📄 TEST_REPORT.md         # Test documentation
├── 📄 LICENSE.md             # MIT License
├── 📁 src/                   # Source code directory
│   └── 📄 main.c             # Main game file
├── 📁 .vscode/               # VS Code configuration
│   ├── 📄 settings.json      # Editor settings
│   ├── 📄 tasks.json         # Build tasks
│   ├── 📄 launch.json        # Debug configuration
│   └── 📄 c_cpp_properties.json # C/C++ IntelliSense
├── 📁 build/                 # Build output (auto-generated)
├── 📁 logs/                  # Log files (auto-generated)
└── 📄 *.pdx                  # Game package (generated)
```

---

## Quick Start

### 1. First-Time Setup

```powershell
# Run the setup wizard
.\setup.ps1

# Follow the on-screen instructions
```

The wizard will:
- ✅ Check for required tools (VS 2022, Playdate SDK)
- ✅ Configure environment variables
- ✅ Build and test the demo game
- ✅ Set up VS Code

### 2. Development Cycle

```powershell
# Make changes to src/main.c

# Build and run your game
.\build.ps1 -Run

# Or use VS Code
F5  # Run in debugger
Ctrl+Shift+B  # Build only
```

---

## Configuration

### setup-config.json

The configuration file controls various aspects of your project:

```json
{
    "projectName": "MyPlaydateGame",
    "author": "Your Name",
    "description": "Your game description",
    "bundleID": "com.example.myplaydategame",
    "version": "1.0.0",
    "buildNumber": "1",
    "sdkPath": "${env:PLAYDATE_SDK_PATH}",
    "features": {
        "enableLogging": true,
        "enableDebugMode": false
    }
}
```

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `projectName` | Name of your game | "MyPlaydateGame" |
| `author` | Game author name | "Developer" |
| `description` | Game description | "My Playdate Game" |
| `bundleID` | Unique bundle identifier | com.example.* |
| `version` | Game version | "1.0.0" |
| `buildNumber` | Build number | "1" |
| `enableLogging` | Enable runtime logging | true |
| `enableDebugMode` | Enable debug features | false |

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `PLAYDATE_SDK_PATH` | Path to Playdate SDK | Yes |

---

## Development Workflow

### Adding New Source Files

1. Create `.c` or `.h` files in the `src/` directory
2. They will be automatically detected and compiled
3. Include files using standard C includes

Example:
```c
// src/game.c
#include "main.h"
#include <pd_api.h>

void game_init(PlaydateAPI* pd) {
    // Your initialization code
}
```

### Modifying the Build

To customize the build process, edit `build.ps1`:

```powershell
# Change project name
param(
    [string]$Name = "YourGameName"
)

# Modify compiler flags
$compilerFlags = "/c /nologo /W3 /Z7 /Od /MD"
```

### Game Metadata

Edit the pdxinfo section in `build.ps1` to customize your game's metadata:

```powershell
$pdxinfo = @"
name=YourGameName
author=Your Name
description=Your game description
bundleID=com.example.yourgame
version=1.0.0
buildNumber=1
"@
```

---

## Building and Testing

### Build Commands

```powershell
# Build only
.\build.ps1

# Build and run in simulator
.\build.ps1 -Run

# Clean build artifacts
.\build.ps1 -Clean

# Clean and build
.\build.ps1 -Clean -Run

# Specify SDK path
.\build.ps1 -SDKPath "C:\Path\To\SDK"

# Specify project name
.\build.ps1 -Name "MyGame"
```

### Build Output

After a successful build:
- **PDX file**: `.\MyPlaydateGame.pdx`
- **DLL file**: `.\build\pdex.dll`
- **Object files**: `.\build\*.obj`

### Running on Hardware

1. Build your game: `.\build.ps1`
2. Package the PDX file
3. Transfer to Playdate device via USB
4. The game will appear in "DEVELOPMENT" section

---

## Debugging

### VS Code Debugging

1. Open the project in VS Code
2. Set breakpoints in your source code
3. Press F5 to start debugging
4. Use the debugging toolbar to:
   - Continue (F5)
   - Step Over (F10)
   - Step Into (F11)
   - Step Out (Shift+F11)
   - Restart (Ctrl+Shift+F5)
   - Stop (Shift+F5)

### Console Logging

Enable logging in `setup-config.json`:
```json
"features": {
    "enableLogging": true
}
```

Use logging in your code:
```c
pd->system->logToConsole("Player position: %d, %d", x, y);
```

### Common Debug Techniques

1. **Draw debug info**:
   ```c
   pd->system->drawFPS(0, 0);
   pd->graphics->drawText("Debug info", strlen("Debug info"), kASCIIEncoding, 10, 10);
   ```

2. **Conditional compilation**:
   ```c
   #ifdef _DEBUG
   // Debug-only code
   #endif
   ```

---

## Advanced Topics

### Using CMake

For advanced build management, use CMake:

```powershell
# Configure
cmake -B build -S .

# Build
cmake --build build --config Release
```

### Cross-Compilation

To build for the actual Playdate device:

```powershell
# Set toolchain
$env:TOOLCHAIN="armgcc"

# Configure CMake
cmake -B build-arm -S . -DCMAKE_TOOLCHAIN_FILE=$env:PLAYDATE_SDK_PATH/C_API/buildsupport/armgcc.cmake

# Build
cmake --build build-arm
```

### Custom Build Steps

Add custom build steps in `build.ps1`:

```powershell
# After compilation, before linking
Write-Info "Running custom build step..."

# Example: Generate resources
& "tools\resource_generator.exe" "resources" "build\resources.bin"
```

### Plugin System

Create a plugin architecture for your game:

```
src/
├── main.c
├── plugins/
│   ├── audio/
│   │   ├── audio.h
│   │   └── audio.c
│   └── input/
│       ├── input.h
│       └── input.c
```

---

## Troubleshooting

### "Cannot find SDK"

```powershell
# Solution 1: Set environment variable
$env:PLAYDATE_SDK_PATH = "C:\Path\To\SDK"

# Solution 2: Run setup wizard
.\setup.ps1

# Solution 3: Specify on command line
.\build.ps1 -SDKPath "C:\Path\To\SDK"
```

### "cl is not recognized"

1. Ensure Visual Studio 2022 is installed
2. Run from "Developer Command Prompt" or use:
   ```powershell
   & "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\Launch-VsDevShell.ps1"
   ```

### Build Fails with "Cannot open include file"

Check that `PLAYDATE_SDK_PATH` points to a valid SDK installation containing `C_API` directory.

### PDX Packaging Fails

Ensure `pdc.exe` is in the SDK's `bin` directory:
```
$SDK_PATH\bin\pdc.exe
```

### VS Code IntelliSense Not Working

1. Restart VS Code after running setup
2. Check `C_Cpp.default.configurationProvider` setting
3. Verify `c_cpp_properties.json` is valid

---

## Best Practices

### Code Organization

1. **Single responsibility**: Each file handles one aspect
2. **Modular design**: Separate game systems into modules
3. **Clear naming**: Descriptive variable and function names
4. **Comments**: Document complex logic

### Performance

1. **Profile early**: Use `pd->system->drawFPS()` to monitor
2. **Optimize sprites**: Use sprite sheets and caching
3. **Minimize allocations**: Pre-allocate memory when possible
4. **Use hardware**: Leverage Playdate's hardware features

### Version Control

1. **Ignore build artifacts**:
   ```
   build/
   *.pdx
   *.pdx.zip
   ```
2. **Commit config template**: Keep `setup-config.json` tracked
3. **Use branches**: Feature branches for new features

### Testing

1. **Test on simulator**: Quick iteration
2. **Test on hardware**: Verify performance
3. **Test edge cases**: Memory limits, input handling
4. **Automate tests**: Use the test scripts

---

## API Reference

### Key Playdate APIs

| API | Description |
|-----|-------------|
| `pd->system` | System operations, timing, logging |
| `pd->graphics` | Drawing, fonts, sprites |
| `pd->audio` | Sound effects and music |
| `pd->input` | Button and crank input |
| `pd->file` | File I/O operations |
| `pd->sprite` | Sprite system |
| `pd->ui` | UI elements |

### Common Functions

```c
// Game loop
pd->system->setUpdateCallback(update, userdata)

// Drawing
pd->graphics->clear(kColorWhite)
pd->graphics->drawText(text, length, encoding, x, y)
pd->graphics->setFont(font)
pd->system->drawFPS(x, y)

// Input
pd->input->getButtonState(buttons, pushed, released)

// Timing
pd->system->getCurrentTimeMilliseconds()
pd->system->sleepMS(milliseconds)
```

---

## Resources

### Official Documentation
- [Playdate SDK Documentation](https://sdk.play.date/)
- [C API Reference](https://sdk.play.date/2.0.0/C/)
- [Developer Forum](https://devforum.play.date/)

### Community
- [Discord Server](https://discord.gg/playdate)
- [Reddit Community](https://reddit.com/r/playdate)

### Examples
- SDK examples: `$PLAYDATE_SDK/C_API/Examples/`
- Template source: This repository

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `.\test.ps1`
5. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

## License

This template is licensed under the MIT License.

See [LICENSE.md](LICENSE.md) for details.

---

**Document Version**: 1.0.0  
**Last Updated**: 2024-01-19  
**Maintained By**: Playdate Community
