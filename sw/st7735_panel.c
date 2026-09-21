#include "sys_delay.h"
#include "spi_bus.h"
#include "font_8x8.h"
#include "st7735_panel.h"

// D7 MY and D6 MX mirror the row and column order, D3 selects BGR over RGB
// subpixel order. Clearing MY and MX together turns the image through 180
// degrees, which is what puts the panel the right way up on this board; the
// bars come out red, green and blue in that order, so D3 stays set.
#define TFT_MADCTL    0x08

// The control register moves cs_n and dc, so it must not change while a byte
// is still being shifted.


static void tft_command(unsigned char value) {
  spi_set_control(SPI_RST_N);              // cs_n = 0, dc = 0
  spi_write(value);
}

static void tft_data(unsigned char value) {
  spi_set_control(SPI_RST_N | SPI_DC);     // cs_n = 0, dc = 1
  spi_write(value);
}

static void tft_deselect(void) {
  spi_set_control(SPI_RST_N | SPI_CS_N);
}

// The panel comes out of reset held low by the SPI peripheral, so firmware
// owns the release timing rather than racing the configuration load.
static void tft_reset(void) {
  spi_set_control(SPI_CS_N);               // rst_n = 0, panel in reset
  delay_loop(DELAY_MS(10));
  spi_set_control(SPI_CS_N | SPI_RST_N);   // release
  delay_loop(DELAY_MS(120));
}

void tft_init(void) {
  tft_reset();

  tft_command(0x01);                   // SWRESET
  delay_loop(DELAY_MS(120));

  tft_command(0x11);                   // SLPOUT
  delay_loop(DELAY_MS(120));           // datasheet 10.1.11 requires 120 ms

  tft_command(0x3a);                   // COLMOD
  tft_data(0x55);                      // 16-bit/pixel; 10.1.29 note 2 mandates 55h for writes

  tft_command(0x36);                   // MADCTL
  tft_data(TFT_MADCTL);

  tft_command(0x20);                   // INVOFF
  tft_command(0x13);                   // NORON
  tft_command(0x29);                   // DISPON
  delay_loop(DELAY_MS(120));

  tft_deselect();
}

// CASET and RASET take a 16-bit start and end, and the window is inclusive at
// both ends. RAMWR leaves the panel expecting pixel data.
static void tft_set_window(unsigned char x0, unsigned char y0,
                           unsigned char x1, unsigned char y1) {
  tft_command(0x2a);                   // CASET
  tft_data(0x00);
  tft_data(x0);
  tft_data(0x00);
  tft_data(x1);

  tft_command(0x2b);                   // RASET
  tft_data(0x00);
  tft_data(y0);
  tft_data(0x00);
  tft_data(y1);

  tft_command(0x2c);                   // RAMWR
}

void tft_fill_rect(unsigned char x0, unsigned char y0,
                          unsigned char x1, unsigned char y1,
                          unsigned short colour) {
  unsigned int columns = (unsigned int) (x1 - x0) + 1;
  unsigned int rows = (unsigned int) (y1 - y0) + 1;
  unsigned int row;
  unsigned int column;

  tft_set_window(x0, y0, x1, y1);

  // dc is raised once and left there: the whole burst is pixel data, and
  // moving it per byte would cost a register write per byte for nothing.
  spi_set_control(SPI_RST_N | SPI_DC);

  // Nested rather than one counter of columns * rows: the core is RV32I with
  // no multiply instruction, and -nostdlib leaves no __mulsi3 to call.
  for (row = 0; row < rows; row++) {
    for (column = 0; column < columns; column++) {
      spi_write((unsigned char) (colour >> 8));
      spi_write((unsigned char) colour);
    }
  }

  tft_deselect();
}

// One glyph occupies its own address window, so a redraw touches 64 pixels
// rather than a whole line. Both colours are written, which lets a character
// replace the one under it without clearing first.
// A scale of n repeats every glyph pixel n times across and n times down, so
// one font serves both sizes and the ROM holds one copy of it.
void tft_draw_glyph(unsigned char x, unsigned char y,
                           const unsigned char *glyph,
                           unsigned short fg, unsigned short bg,
                           unsigned int scale) {
  unsigned int row;
  unsigned int column;
  unsigned int down;
  unsigned int across;
  unsigned int span = FONT_SIZE * scale;
  unsigned char bits;
  unsigned short colour;

  tft_set_window(x, y, (unsigned char) (x + span - 1),
                 (unsigned char) (y + span - 1));
  spi_set_control(SPI_RST_N | SPI_DC);

  for (row = 0; row < FONT_SIZE; row++) {
    bits = glyph[row];
    for (down = 0; down < scale; down++) {
      for (column = 0; column < FONT_SIZE; column++) {
        colour = (bits & (0x80 >> column)) ? fg : bg;
        for (across = 0; across < scale; across++) {
          spi_write((unsigned char) (colour >> 8));
          spi_write((unsigned char) colour);
        }
      }
    }
  }

  tft_deselect();
}

void tft_draw_char(unsigned char x, unsigned char y, char value,
                          unsigned short fg, unsigned short bg,
                          unsigned int scale) {
  if (value < FONT_FIRST || value > FONT_LAST) value = ' ';
  tft_draw_glyph(x, y, &font8x8[(unsigned int) (value - FONT_FIRST) * FONT_SIZE],
                 fg, bg, scale);
}

void tft_draw_string(unsigned char x, unsigned char y, const char *text,
                            unsigned short fg, unsigned short bg,
                            unsigned int scale) {
  while (*text != '\0') {
    tft_draw_char(x, y, *text, fg, bg, scale);
    x = (unsigned char) (x + FONT_SIZE * scale);
    text++;
  }
}

// Two hex digits of a BCD byte are its two decimal digits.
// Both nibbles of a validated BCD byte are decimal digits, so the character
// follows from the value and no lookup table crosses into this file.
void tft_draw_bcd(unsigned char x, unsigned char y, unsigned char value,
                  unsigned short fg, unsigned short bg, unsigned int scale) {
  tft_draw_char(x, y, (char) ('0' + ((value >> 4) & 0x0f)), fg, bg, scale);
  tft_draw_char((unsigned char) (x + FONT_SIZE * scale), y,
                (char) ('0' + (value & 0x0f)), fg, bg, scale);
}

// Three vertical bars, not text. A bar shows byte order, MADCTL scan direction
// and column addressing at once: a swapped subpixel order comes back as the
// wrong colour, and a wrong scan direction as bars running the wrong way.
void tft_colour_bars(void) {
  unsigned char third = TFT_WIDTH / 3;

  tft_fill_rect(0, 0, third - 1, TFT_HEIGHT - 1, TFT_RED);
  tft_fill_rect(third, 0, (unsigned char) (2 * third - 1), TFT_HEIGHT - 1, TFT_GREEN);
  tft_fill_rect(2 * third, 0, TFT_WIDTH - 1, TFT_HEIGHT - 1, TFT_BLUE);
}
