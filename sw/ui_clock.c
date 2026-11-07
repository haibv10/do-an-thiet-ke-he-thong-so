#include "st7735_panel.h"
#include "ui_clock.h"
#include "mq5_sensor.h"

// RGB565, five bits of red and blue and six of green. One hue at three
// brightnesses over a neutral bar. Blue was tried first and reads badly: it is
// the channel the eye is least sensitive to and the dimmest subpixel on the
// panel, so small blue text on black washes out.
#define TFT_BAR       0x18e3   // charcoal, the bar behind the title
#define TFT_BRIGHT    0xfd80   // amber, the hours and minutes
#define TFT_MID       0xc400   // amber at two thirds, the seconds and the date
#define TFT_DIM       0x7280   // amber at a third, the separators

#define HEADER_HEIGHT 20
#define FOOTER_TOP    152

// need no code of their own beyond the table.
static const unsigned char icon_clock[8] = {
  0x3c, 0x42, 0x89, 0x89, 0x8e, 0x81, 0x42, 0x3c
};
static const unsigned char icon_calendar[8] = {
  0x42, 0xff, 0x81, 0xa9, 0x81, 0xa9, 0x81, 0xff
};

// Drawn once: the bar, the rule under it and the matching foot. Nothing in
// them changes with the time, so they stay out of the per-second redraw.
void ui_draw_frame(void) {
  tft_fill_rect(0, 0, TFT_WIDTH - 1, TFT_HEIGHT - 1, TFT_BLACK);
  tft_fill_rect(0, 0, TFT_WIDTH - 1, HEADER_HEIGHT - 1, TFT_BAR);
  tft_fill_rect(0, HEADER_HEIGHT, TFT_WIDTH - 1, HEADER_HEIGHT, TFT_MID);
  tft_fill_rect(0, FOOTER_TOP, TFT_WIDTH - 1, TFT_HEIGHT - 1, TFT_BAR);

  // Icon, a gap, then twelve glyphs: 112 pixels with eight either side.
  tft_draw_glyph(8, 6, icon_clock, TFT_MID, TFT_BAR, 1);
  tft_draw_string(24, 6, "TANG NANO 9K", TFT_MID, TFT_BAR, 1);
  tft_draw_string(1, 108, "T", TFT_DIM, TFT_BLACK, 1);
  tft_draw_string(32, 108, "C", TFT_DIM, TFT_BLACK, 1);
  tft_draw_string(64, 108, "RH", TFT_DIM, TFT_BLACK, 1);
  tft_draw_char(104, 108, '%', TFT_DIM, TFT_BLACK, 1);
  tft_draw_string(1, 120, "MQ5", TFT_DIM, TFT_BLACK, 1);
  tft_draw_string(88, 120, "mV", TFT_DIM, TFT_BLACK, 1);
}

// Two lines and nothing else. The weekday was drawn here for a while and came
// out as a second way of saying what the date already says, so it went; the
// register behind it is still written correctly, it is simply not shown.
//
// The time carries the screen at double size, where eight glyphs of sixteen
// pixels fill the width exactly. The date sits under it at single size.
// Drawn in place of the time when the registers do not hold valid BCD. Showing
// the digits anyway would present a fault as a reading.
void ui_show_unset(void) {
  tft_draw_string(0, 66, "--:--:--", TFT_DIM, TFT_BLACK, 2);
  tft_draw_string(24, 98, " NOT SET  ", TFT_MID, TFT_BLACK, 1);
}

void ui_show_time(const unsigned char *time) {
  // Hours and minutes carry the reading; the seconds step back a shade so the
  // eye settles on the part that matters.
  tft_draw_bcd(0, 66, time[2] & 0x3f, TFT_BRIGHT, TFT_BLACK, 2);
  tft_draw_char(32, 66, ':', TFT_MID, TFT_BLACK, 2);
  tft_draw_bcd(48, 66, time[1] & 0x7f, TFT_BRIGHT, TFT_BLACK, 2);
  tft_draw_char(80, 66, ':', TFT_MID, TFT_BLACK, 2);
  tft_draw_bcd(96, 66, time[0] & 0x7f, TFT_MID, TFT_BLACK, 2);

  // Icon, a gap, then ten glyphs of date: 96 pixels with sixteen either side.
  tft_draw_glyph(16, 98, icon_calendar, TFT_DIM, TFT_BLACK, 1);
  tft_draw_string(32, 98, "20", TFT_MID, TFT_BLACK, 1);
  tft_draw_bcd(48, 98, time[6], TFT_MID, TFT_BLACK, 1);
  tft_draw_char(64, 98, '-', TFT_DIM, TFT_BLACK, 1);
  tft_draw_bcd(72, 98, time[5] & 0x1f, TFT_MID, TFT_BLACK, 1);
  tft_draw_char(88, 98, '-', TFT_DIM, TFT_BLACK, 1);
  tft_draw_bcd(96, 98, time[4] & 0x3f, TFT_MID, TFT_BLACK, 1);
}

static void draw_decimal2(unsigned char x, unsigned char y, unsigned int value,
                          unsigned short colour) {
  unsigned int tens = 0;
  if (value > 99u) value = 99u;
  while (value >= 10u) { value -= 10u; tens++; }
  tft_draw_char(x, y, (char) ('0' + tens), colour, TFT_BLACK, 1);
  tft_draw_char((unsigned char) (x + 8u), y, (char) ('0' + value),
                colour, TFT_BLACK, 1);
}

static void draw_decimal4(unsigned char x, unsigned char y, unsigned int value,
                          unsigned short colour) {
  static const unsigned short place[3] = {1000, 100, 10};
  unsigned int index;
  unsigned int digit;
  if (value > 9999u) value = 9999u;
  for (index = 0; index < 3u; index++) {
    digit = 0;
    while (value >= place[index]) { value -= place[index]; digit++; }
    tft_draw_char(x, y, (char) ('0' + digit), colour, TFT_BLACK, 1);
    x = (unsigned char) (x + 8u);
  }
  tft_draw_char(x, y, (char) ('0' + value), colour, TFT_BLACK, 1);
}

void ui_show_environment(unsigned char temperature, unsigned char humidity) {
  draw_decimal2(16, 108, temperature, TFT_BRIGHT);
  draw_decimal2(80, 108, humidity, TFT_BRIGHT);
}

void ui_show_environment_fault(void) {
  tft_draw_string(16, 108, "--", TFT_DIM, TFT_BLACK, 1);
  tft_draw_string(80, 108, "--", TFT_DIM, TFT_BLACK, 1);
}

void ui_show_gas(unsigned int mv, unsigned int level) {
  unsigned short colour = TFT_GREEN;
  const char *text = "CLEAN ";
  unsigned int length = mv >> 5;
  if (level == MQ5_LEVEL_WARN) { colour = TFT_BRIGHT; text = "WARN  "; }
  else if (level == MQ5_LEVEL_DANGER) { colour = TFT_RED; text = "DANGER"; }
  if (length > 126u) length = 126u;
  draw_decimal4(40, 120, mv, colour);
  tft_draw_string(1, 132, text, colour, TFT_BLACK, 1);
  if (length > 0u) tft_fill_rect(1, 142, (unsigned char) length, 148, colour);
  if (length < 126u)
    tft_fill_rect((unsigned char) (length + 1u), 142, 126, 148, TFT_BLACK);
}

void ui_show_gas_fault(void) {
  tft_draw_string(40, 120, "----", TFT_DIM, TFT_BLACK, 1);
  tft_draw_string(1, 132, "NO ADC", TFT_DIM, TFT_BLACK, 1);
  tft_fill_rect(1, 142, 126, 148, TFT_BLACK);
}
