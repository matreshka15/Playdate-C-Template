//
// main.c
// My Playdate Game
//

#include <stdio.h>
#include <stdlib.h>
#include "pd_api.h"

static int update(void* userdata);
const char* fontpath = "/System/Fonts/Asheville-Sans-14-Bold.pft";
LCDFont* font = NULL;

#ifdef _WINDLL
__declspec(dllexport)
#endif
int eventHandler(PlaydateAPI* pd, PDSystemEvent event, uint32_t arg)
{
	(void)arg; // arg is currently only used for event = kEventKeyPressed

	if (event == kEventInit)
	{
		const char* err;
		font = pd->graphics->loadFont(fontpath, &err);

		if (font == NULL)
			pd->system->error("%s:%i Couldn't load font %s: %s", __FILE__, __LINE__, fontpath, err);

		// Note: If you set an update callback in the kEventInit handler,
		// the system assumes the game is pure C and doesn't run any Lua code
		pd->system->setUpdateCallback(update, pd);
	}

	return 0;
}

#define TEXT_WIDTH 200
#define TEXT_HEIGHT 16

int x = (400 - TEXT_WIDTH) / 2;
int y = (240 - TEXT_HEIGHT) / 2;
int dx = 1;
int dy = 2;

static int update(void* userdata)
{
	PlaydateAPI* pd = userdata;

	// Clear screen
	pd->graphics->clear(kColorWhite);

	// Set font and draw text
	pd->graphics->setFont(font);
	const char* text = "My Playdate Game!";
	pd->graphics->drawText(text, strlen(text), kASCIIEncoding, x, y);

	// Update position
	x += dx;
	y += dy;

	// Bounce off edges
	if (x < 0 || x > LCD_COLUMNS - TEXT_WIDTH)
		dx = -dx;

	if (y < 0 || y > LCD_ROWS - TEXT_HEIGHT)
		dy = -dy;

	// Draw FPS counter
	pd->system->drawFPS(0, 0);

	return 1; // Return 1 to tell the system to draw the next frame
}
