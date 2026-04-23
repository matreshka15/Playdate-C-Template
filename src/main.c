//
// main.c  -  你的第一个 Playdate 游戏 / Your first Playdate game
// ============================================================
//
// 这是游戏的入口文件。保存它，然后运行：
// This is the entry file of your game. Save it, then run:
//
//     .\build.ps1 -Run
//
// 屏幕规格 / Screen specs:
//   LCD_COLUMNS = 400  (宽度 / width)
//   LCD_ROWS    = 240  (高度 / height)
//   1-bit 黑白像素 / 1-bit black & white pixels
//   30 FPS 默认帧率 / default frame rate
//
// 想修改弹跳文字？去看下面的 update() 函数。
// Want to change the bouncing text? Jump to update() below.
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "pd_api.h"   // 所有 Playdate API 都通过这个头文件 / Everything Playdate lives here

// ---- 前向声明 / forward declaration ----
static int update(void* userdata);

// 字体文件路径（来自 SDK 自带的系统字体）
// Path to a built-in SDK font.
const char* fontpath = "/System/Fonts/Asheville-Sans-14-Bold.pft";
LCDFont*    font     = NULL;

// ============================================================
//  eventHandler - SDK 唯一的必需入口 / the one required entry point
//  SDK 会在不同时机调用它（启动 / 暂停 / 终止 …）
//  Called by the SDK at various lifecycle events (init / pause / terminate ...)
// ============================================================
#ifdef _WINDLL
__declspec(dllexport)   // Windows 模拟器构建必需 / required for simulator build
#endif
int eventHandler(PlaydateAPI* pd, PDSystemEvent event, uint32_t arg)
{
    (void)arg; // 当前仅 kEventKeyPressed 使用 arg / only used for key events

    if (event == kEventInit)
    {
        // 加载字体；失败时在模拟器控制台报错
        // Load the font; report in the simulator console if it fails.
        const char* err;
        font = pd->graphics->loadFont(fontpath, &err);
        if (font == NULL)
            pd->system->error("%s:%i Couldn't load font %s: %s",
                              __FILE__, __LINE__, fontpath, err);

        // 告诉 SDK：这是一个纯 C 游戏，每帧调用 update()
        // Tells the SDK this is a pure-C game; update() will run every frame.
        pd->system->setUpdateCallback(update, pd);
    }

    return 0;
}

// ---- 演示用的弹跳文字状态 / demo state for the bouncing text ----
#define TEXT_WIDTH  200
#define TEXT_HEIGHT 16

static int x  = (400 - TEXT_WIDTH)  / 2;  // 初始 x / initial x
static int y  = (240 - TEXT_HEIGHT) / 2;  // 初始 y / initial y
static int dx = 1;                        // 每帧水平移动像素 / px per frame
static int dy = 2;                        // 每帧垂直移动像素 / px per frame

// ============================================================
//  update - 主循环 / main game loop
//  每秒调用 ~30 次。返回 1 = 画下一帧，0 = 停止。
//  Runs ~30 times per second. Return 1 to keep drawing, 0 to stop.
// ============================================================
static int update(void* userdata)
{
    PlaydateAPI* pd = userdata;

    // 1) 清屏为白色 / Clear the screen to white
    pd->graphics->clear(kColorWhite);

    // 2) 画文字 / Draw the text
    //    想改？把下面字符串改成你的名字，保存，再运行 .\build.ps1 -Run
    //    Tip: change the string, save, re-run  .\build.ps1 -Run
    pd->graphics->setFont(font);
    const char* text = "My Playdate Game!";
    pd->graphics->drawText(text, strlen(text), kASCIIEncoding, x, y);

    // 3) 更新位置 / Move the text
    x += dx;
    y += dy;

    // 4) 碰到边缘就反弹 / Bounce at the edges
    if (x < 0 || x > LCD_COLUMNS - TEXT_WIDTH)  dx = -dx;
    if (y < 0 || y > LCD_ROWS    - TEXT_HEIGHT) dy = -dy;

    // 5) 左上角显示 FPS / Draw FPS counter (top-left)
    pd->system->drawFPS(0, 0);

    return 1; // 继续绘制下一帧 / keep the loop running
}
