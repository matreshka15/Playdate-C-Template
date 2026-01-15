# 🎓 Getting Started with Playdate C Development

Welcome! This guide will teach you everything you need to know to make Playdate games in C! 🎮

> **New to programming?** Don't worry! We'll take it step by step. 🌈

## 📖 Table of Contents

- [Your First Steps](#your-first-steps)
- [Understanding the Code](#understanding-the-code)
- [Drawing Graphics](#drawing-graphics)
- [Handling Input](#handling-input)
- [Playing Sounds](#playing-sounds)
- [Common Patterns](#common-patterns)
- [Tips & Tricks](#tips--tricks)
- [Next Steps](#next-steps)

---

## 🏁 Your First Steps

### 1. Look at the Demo Code

Open `src/main.c`. You'll see:

```c
int eventHandler(PlaydateAPI* pd, PDSystemEvent event, uint32_t arg)
```

This is the **entry point** - where your game starts! 🚪

### 2. The Game Loop

```c
static int update(void* userdata) {
    PlaydateAPI* pd = userdata;
    
    // Clear screen
    pd->graphics->clear(kColorWhite);
    
    // Your game logic here!
    
    return 1;  // Keep running!
}
```

This function runs **30 times per second**! That's how games work! ⚡

### 3. Make a Change!

Try this: In `src/main.c`, find the text "My Playdate Game!" and change it to your name!

```c
const char* text = "Hello [Your Name]!";
```

Now build and run:
```powershell
.\build.ps1 -Run
```

See? You're already making changes! 🎨

---

## 🎨 Drawing Graphics

### Drawing Text

```c
// 1. Load a font
const char* err;
LCDFont* font = pd->graphics->loadFont(
    "/System/Fonts/Asheville-Sans-14-Bold.pft", &err);

// 2. Set the font
pd->graphics->setFont(font);

// 3. Draw text!
pd->graphics->drawText("Hello!", 6, kASCIIEncoding, x, y);
```

### Drawing Shapes

```c
// Clear to white or black
pd->graphics->clear(kColorWhite);

// Draw a rectangle
pd->graphics->drawRect(x, y, width, height, kColorBlack);

// Fill a rectangle
pd->graphics->fillRect(x, y, width, height, kColorBlack);

// Draw a circle
pd->graphics->drawEllipse(x, y, width, height, 
                          lineWidth, 0, 360, kColorBlack);

// Draw a line
pd->graphics->drawLine(x1, y1, x2, y2, width, kColorBlack);
```

### Loading Images

```c
// Load an image
const char* err;
LCDBitmap* image = pd->graphics->loadBitmap("images/player.png", &err);

if (image == NULL) {
    pd->system->error("Failed to load image: %s", err);
}

// Draw it!
pd->graphics->drawBitmap(image, x, y, kBitmapUnflipped);
```

**Pro tip:** Put your images in a folder called `images/` in your project! 📁

---

## 🎮 Handling Input

### Button Presses

```c
PDButtons current, pushed, released;
pd->system->getButtonState(&current, &pushed, &released);

// Check if A button is held down
if (current & kButtonA) {
    // A button is being pressed!
}

// Check if A button was just pressed
if (pushed & kButtonA) {
    // A button was JUST pressed this frame!
}

// Check if A button was just released
if (released & kButtonA) {
    // A button was JUST released!
}
```

**All buttons:**
- `kButtonLeft`, `kButtonRight`, `kButtonUp`, `kButtonDown`
- `kButtonA`, `kButtonB`

### The Crank! 🎡

The crank is Playdate's special feature!

```c
// Get crank angle (0-360 degrees)
float angle = pd->system->getCrankAngle();

// Get how much it changed
float change = pd->system->getCrankChange();

// Check if crank is docked (not being used)
int docked = pd->system->isCrankDocked();

// Example: Rotate something with the crank
rotation += pd->system->getCrankChange();
```

### Accelerometer

```c
float x, y, z;
pd->system->getAccelerometer(&x, &y, &z);

// x, y, z are between -1.0 and 1.0
// Tilt the Playdate to get different values!
```

---

## 🔊 Playing Sounds

### Sound Effects

```c
// Load a sound
FilePlayer* sfxPlayer = pd->sound->fileplayer->newPlayer();
pd->sound->fileplayer->loadIntoPlayer(sfxPlayer, "sounds/jump.wav");

// Play it!
pd->sound->fileplayer->play(sfxPlayer, 1);  // Play once
```

### Background Music

```c
// Load music
FilePlayer* music = pd->sound->fileplayer->newPlayer();
pd->sound->fileplayer->loadIntoPlayer(music, "sounds/bgm.mp3");

// Loop forever!
pd->sound->fileplayer->play(music, 0);  // 0 = loop forever

// Stop it
pd->sound->fileplayer->stop(music);
```

**Tip:** Put your sounds in a `sounds/` folder! 🎵

---

## 🎯 Common Patterns

### Making Things Move

```c
// At the top of your file
static int x = 100;
static int y = 100;
static int speedX = 2;
static int speedY = 2;

// In your update() function
static int update(void* userdata) {
    PlaydateAPI* pd = userdata;
    
    // Move the object
    x += speedX;
    y += speedY;
    
    // Bounce off edges!
    if (x < 0 || x > 400) speedX = -speedX;
    if (y < 0 || y > 240) speedY = -speedY;
    
    // Draw it
    pd->graphics->fillRect(x, y, 20, 20, kColorBlack);
    
    return 1;
}
```

### Simple Collision Detection

```c
int checkCollision(int x1, int y1, int w1, int h1,
                   int x2, int y2, int w2, int h2) {
    return x1 < x2 + w2 &&
           x1 + w1 > x2 &&
           y1 < y2 + h2 &&
           y1 + h1 > y2;
}

// Use it like this:
if (checkCollision(playerX, playerY, 20, 20,
                   enemyX, enemyY, 30, 30)) {
    // They touched!
}
```

### Game States

```c
typedef enum {
    STATE_MENU,
    STATE_PLAYING,
    STATE_GAME_OVER
} GameState;

static GameState currentState = STATE_MENU;

static int update(void* userdata) {
    PlaydateAPI* pd = userdata;
    
    switch (currentState) {
        case STATE_MENU:
            drawMenu(pd);
            if (/* player presses A */) {
                currentState = STATE_PLAYING;
            }
            break;
            
        case STATE_PLAYING:
            updateGame(pd);
            drawGame(pd);
            break;
            
        case STATE_GAME_OVER:
            drawGameOver(pd);
            break;
    }
    
    return 1;
}
```

### Simple Timer

```c
static float timer = 0;

static int update(void* userdata) {
    PlaydateAPI* pd = userdata;
    
    // Add time (assuming 30 FPS)
    timer += 1.0f / 30.0f;
    
    if (timer >= 2.0f) {  // 2 seconds passed!
        // Do something
        timer = 0;  // Reset timer
    }
    
    return 1;
}
```

---

## 💡 Tips & Tricks

### Debugging

```c
// Print to console (see it in the simulator)
pd->system->logToConsole("Player X: %d, Y: %d", playerX, playerY);

// Show errors (this will pause the simulator)
pd->system->error("Something went wrong!");

// Show FPS counter
pd->system->drawFPS(0, 0);
```

### Performance Tips

✅ **DO:**
- Use static variables for things you keep around
- Reuse memory instead of allocating every frame
- Draw only what changed (sprites help with this!)

❌ **DON'T:**
- Call `malloc()` or `free()` every frame
- Load images in the update loop
- Do heavy calculations if you don't need to

### Organizing Your Code

As your game grows, split it into files:

```c
// player.h
typedef struct {
    int x, y;
    int speed;
} Player;

void player_init(Player* p);
void player_update(Player* p, PlaydateAPI* pd);
void player_draw(Player* p, PlaydateAPI* pd);

// player.c
#include "player.h"

void player_init(Player* p) {
    p->x = 200;
    p->y = 120;
    p->speed = 2;
}
// ... etc
```

---

## 🚀 Next Steps

### Learn More

1. **Explore SDK Examples** - Check `%PLAYDATE_SDK_PATH%\C_API\Examples\`
2. **Read the API Docs** - Open `Inside Playdate with C.html` in your SDK folder
3. **Join the Community** - Visit [devforum.play.date](https://devforum.play.date/)

### Game Ideas for Practice

- 🎯 **Pong** - Classic! Learn collision and scoring
- 🐍 **Snake** - Practice arrays and collision
- 🚀 **Flappy Bird** - Learn gravity and scrolling
- 🎲 **Dice Roller** - Use the accelerometer!
- 🎨 **Drawing App** - Try using the crank

### Useful Snippets

Check the SDK's example folder for:
- `Hello World` - Minimal example
- `Sprite Collisions` - Learn the sprite system
- `JSON` - Save and load data
- `Life` - Conway's Game of Life

---

## 🎮 The Playdate Coordinate System

```
    0,0 ──────────────────► X (400)
     │
     │
     │
     │
     │
     ▼
     Y (240)
```

Screen is **400 pixels wide** and **240 pixels tall**! 📺

---

## ❓ Common Questions

**Q: How do I make my game faster?**
A: Use the sprite system! It's optimized for you. Check the Sprite Collisions example.

**Q: How do I save high scores?**
A: Use the JSON or file APIs. Check the JSON example in the SDK.

**Q: Can I use C++?**
A: Technically yes, but the SDK is C-based. Stick with C for best compatibility!

**Q: How do I test on a real Playdate?**
A: Build your game, then use the Simulator's "Device" menu to upload to your Playdate!

---

## 🌟 You're Ready!

You now know enough to make a game! 🎉

**Start small** - Make a simple game first. Then make it better!

**Have fun** - That's what game dev is all about! 😊

**Share your work** - The Playdate community is friendly and helpful!

---

<div align="center">

**Need help?** 💬

[Playdate Forum](https://devforum.play.date/) • [SDK Docs](https://sdk.play.date/) • [This Template's README](README.md)

Happy coding! 🚀✨

</div>
