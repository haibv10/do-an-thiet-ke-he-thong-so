#ifndef ST7735_PANEL_H
#define ST7735_PANEL_H

#define TFT_WIDTH 128
#define TFT_HEIGHT 160

void tft_init(void);
void tft_blit(unsigned int x, unsigned int y, unsigned int width, unsigned int height,
              const unsigned short *pixels);

#endif
