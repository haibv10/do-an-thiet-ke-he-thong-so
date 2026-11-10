#include "sys_delay.h"
#include "spi_bus.h"
#include "st7735_panel.h"

#define TFT_MADCTL 0x08

static void tft_command(unsigned char value) {
  spi_set_control(SPI_RST_N);
  spi_write(value);
}

static void tft_data(unsigned char value) {
  spi_set_control(SPI_RST_N | SPI_DC);
  spi_write(value);
}

static void tft_deselect(void) { spi_set_control(SPI_RST_N | SPI_CS_N); }

static void tft_reset(void) {
  spi_set_control(SPI_CS_N);
  delay_loop(DELAY_MS(10));
  spi_set_control(SPI_CS_N | SPI_RST_N);
  delay_loop(DELAY_MS(120));
}

void tft_init(void) {
  tft_reset();

  tft_command(0x01);
  delay_loop(DELAY_MS(120));

  tft_command(0x11);
  delay_loop(DELAY_MS(120));

  tft_command(0x3a);
  tft_data(0x55);

  tft_command(0x36);
  tft_data(TFT_MADCTL);

  tft_command(0x20);
  tft_command(0x13);
  tft_command(0x29);
  delay_loop(DELAY_MS(120));

  tft_deselect();
}

static void tft_set_window(unsigned char x0, unsigned char y0, unsigned char x1, unsigned char y1) {
  tft_command(0x2a);
  tft_data(0x00);
  tft_data(x0);
  tft_data(0x00);
  tft_data(x1);

  tft_command(0x2b);
  tft_data(0x00);
  tft_data(y0);
  tft_data(0x00);
  tft_data(y1);

  tft_command(0x2c);
}

void tft_blit(unsigned int x, unsigned int y, unsigned int width, unsigned int height,
              const unsigned short *pixels) {
  if (!width || !height || x + width > TFT_WIDTH || y + height > TFT_HEIGHT)
    return;
  tft_set_window(x, y, x + width - 1u, y + height - 1u);
  spi_set_control(SPI_RST_N | SPI_DC);
  for (unsigned int row = 0; row < height; row++) {
    for (unsigned int column = 0; column < width; column++) {
      unsigned short colour = *pixels++;
      spi_write((unsigned char)(colour >> 8));
      spi_write((unsigned char)colour);
    }
  }
  tft_deselect();
}
