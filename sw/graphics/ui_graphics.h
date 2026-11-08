#ifndef UI_GRAPHICS_H
#define UI_GRAPHICS_H
#include "ui_assets.h"
void ui_paint(unsigned int x, unsigned int y, unsigned int width, unsigned int height,
              void (*scene)(void), unsigned short background);
void ui_rect(int x, int y, int width, int height, unsigned short colour);
void ui_round_rect(int x, int y, int width, int height, unsigned short colour);
void ui_line(int x0, int y0, int x1, int y1, unsigned short colour);
void ui_text(int x, int baseline, const char *text, const struct ui_font *font,
             unsigned short colour);
void ui_icon(int x, int y, const struct ui_icon *icon, unsigned short colour);
#endif
