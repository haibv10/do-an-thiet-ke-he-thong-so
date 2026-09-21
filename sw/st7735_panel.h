#ifndef ST7735_PANEL_H
#define ST7735_PANEL_H

#define TFT_WIDTH     128
#define TFT_HEIGHT    160

#define TFT_RED       0xf800
#define TFT_GREEN     0x07e0
#define TFT_BLUE      0x001f
#define TFT_WHITE     0xffff
#define TFT_BLACK     0x0000

// The link is write only: the breakout brings only SDA out to its header, so
// nothing can be read back and every delay below comes from the datasheet.
void tft_init(void);

// Proves byte order and addressing before anything is asked of the layout.
void tft_colour_bars(void);

void tft_fill_rect(unsigned char x0, unsigned char y0,
                   unsigned char x1, unsigned char y1, unsigned short colour);

// A scale of n repeats every glyph pixel n times across and n times down, so
// one font serves every size and the ROM holds one copy of it.
void tft_draw_glyph(unsigned char x, unsigned char y,
                    const unsigned char *glyph,
                    unsigned short fg, unsigned short bg, unsigned int scale);
void tft_draw_char(unsigned char x, unsigned char y, char value,
                   unsigned short fg, unsigned short bg, unsigned int scale);
void tft_draw_string(unsigned char x, unsigned char y, const char *text,
                     unsigned short fg, unsigned short bg, unsigned int scale);
void tft_draw_bcd(unsigned char x, unsigned char y, unsigned char value,
                  unsigned short fg, unsigned short bg, unsigned int scale);

#endif
