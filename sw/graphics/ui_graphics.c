#include "ui_graphics.h"
#include "st7735_panel.h"

// Four scanlines: compose each strip before transmitting it, without an
// intermediate erase on the TFT. A full-screen framebuffer would need 40 KiB.
static unsigned short pixels[TFT_WIDTH * 4];
static unsigned short *rows[4];
static int left, top, right, bottom;

static void pixel(int x, int y, unsigned short colour, unsigned int coverage) {
  unsigned short *destination;
  if (x < left || x >= right || y < top || y >= bottom || !coverage)
    return;
  destination = &rows[y - top][x - left];
  *destination = colour;
}

void ui_rect(int x, int y, int width, int height, unsigned short colour) {
  int end_x = x + width, end_y = y + height;
  if (x < left)
    x = left;
  if (y < top)
    y = top;
  if (end_x > right)
    end_x = right;
  if (end_y > bottom)
    end_y = bottom;
  for (; y < end_y; y++)
    for (int column = x; column < end_x; column++)
      rows[y - top][column - left] = colour;
}

void ui_round_rect(int x, int y, int width, int height, unsigned short colour) {
  static const unsigned char inset[5] = {3, 1, 1, 0, 0};
  if (y >= bottom || y + height <= top || x >= right || x + width <= left)
    return;
  for (int row = 0; row < height; row++) {
    int edge = row < height - 1 - row ? row : height - 1 - row;
    int margin = height < 10 ? (edge == 0 ? 1 : 0) : edge < 5 ? inset[edge] : 0;
    ui_rect(x + margin, y + row, width - margin - margin, 1, colour);
  }
}

void ui_line(int x0, int y0, int x1, int y1, unsigned short colour) {
  int dx = x1 > x0 ? x1 - x0 : x0 - x1;
  int dy = y1 > y0 ? y0 - y1 : y1 - y0;
  int sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
  int error = dx + dy;
  if ((y0 < top && y1 < top) || (y0 >= bottom && y1 >= bottom) || (x0 < left && x1 < left) ||
      (x0 >= right && x1 >= right))
    return;
  while (1) {
    int twice = error + error;
    pixel(x0, y0, colour, 3);
    if (x0 == x1 && y0 == y1)
      break;
    if (twice >= dy) {
      error += dy;
      x0 += sx;
    }
    if (twice <= dx) {
      error += dx;
      y0 += sy;
    }
  }
}

static void mask(int x, int y, unsigned int width, unsigned int height, const unsigned char *data,
                 unsigned short colour) {
  unsigned int bits = 0, value = 0;
  if (y >= bottom || y + (int)height <= top || x >= right || x + (int)width <= left)
    return;
  for (unsigned int row = 0; row < height; row++) {
    for (unsigned int column = 0; column < width; column++) {
      if (!bits) {
        value = *data++;
        bits = 8;
      }
      bits -= 1;
      pixel(x + (int)column, y + (int)row, colour, (value >> bits) & 1u);
    }
  }
}

void ui_text(int x, int baseline, const char *text, const struct ui_font *font,
             unsigned short colour) {
  for (; *text; text++) {
    const char *characters = font->characters;
    const struct ui_glyph *glyph = font->glyphs;
    while (*characters && *characters != *text) {
      characters++;
      glyph++;
    }
    if (!*characters)
      continue;
    mask(x - (glyph->advance >> 7), baseline + glyph->top, glyph->width, glyph->height,
         font->pixels + glyph->offset, colour);
    x += glyph->advance & 127u;
  }
}

void ui_icon(int x, int y, const struct ui_icon *icon, unsigned short colour) {
  mask(x, y, icon->width, icon->height, icon->pixels, colour);
}

void ui_paint(unsigned int x, unsigned int y, unsigned int width, unsigned int height,
              void (*scene)(void), unsigned short background) {
  unsigned int end_y = y + height;
  if (!width || !height || x + width > TFT_WIDTH || end_y > TFT_HEIGHT)
    return;
  left = (int)x;
  right = (int)(x + width);
  while (y < end_y) {
    unsigned int strip_height = end_y - y;
    unsigned short *next = pixels;
    if (strip_height > 4)
      strip_height = 4;
    top = (int)y;
    bottom = (int)(y + strip_height);
    for (unsigned int row = 0; row < strip_height; row++) {
      rows[row] = next;
      for (unsigned int column = 0; column < width; column++)
        *next++ = background;
    }
    scene();
    tft_blit(x, y, width, strip_height, pixels);
    y += strip_height;
  }
}
