# Playdate Game Publishing Guide

This guide walks you through preparing and sharing your Playdate game.

## ✅ Checklist

- Build a release `.pdx` package
- Test in the Playdate Simulator
- Test on real hardware (optional but recommended)
- Write a short description and screenshots
- Choose a license and include `License.md`

## 🚀 Build a Release

```powershell
# Clean and build
.\build.ps1 -Clean
.\build.ps1

# The package will be created as: <ProjectName>.pdx
```

## 🧪 Test Your Game

1. Open the `.pdx` in the Playdate Simulator
2. Verify FPS and performance
3. Check audio, input, and save functionality
4. Try edge cases and long sessions

## 🔌 Test on Device

1. Connect your Playdate via USB
2. Open the Simulator and use `Device → Upload to Playdate`
3. The game appears in the Playdate's Development section

## 📦 Share Your Game

- Zip the `.pdx` folder for distribution
- Include a `README` with instructions
- Optional: Upload to itch.io or GitHub Releases

## 📝 Metadata Tips

- Keep your `bundleID` unique (e.g., `com.yourname.yourgame`)
- Update version and build numbers
- Include author and description

## 🔧 Troubleshooting

- If the device upload fails, restart the Simulator and Playdate
- Ensure Playdate firmware is up to date
- Rebuild after clearing with `.\build.ps1 -Clean`

## 📚 Resources

- [Playdate SDK Docs](https://sdk.play.date/)
- [Developer Forum](https://devforum.play.date/)

Good luck and happy publishing! 🎉