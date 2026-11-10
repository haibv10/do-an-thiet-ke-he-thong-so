#include "ui_clock.h"
#include "ui_graphics.h"
#include "st7735_panel.h"
#include "mq5_sensor.h"
#include "bcd.h"

#define BG 0x0863u
#define PANEL 0x1106u
#define EDGE 0x2189u
#define WHITE 0xf7bfu
#define MUTED 0xb5f9u
#define MINT 0x56f8u
#define BLUE 0x6e3fu
#define ORANGE 0xfd8eu
#define YELLOW 0xff28u
#define RED 0xfb6fu
#define EMPTY 0xffffu
#define SAMPLES 60u

// Validity: 0 waiting, 1 valid, 2 invalid, 3 bus failure (RTC only).
static unsigned char rtc_valid, env_valid, gas_valid, page;
static unsigned char clock_data[7], temperature, humidity;
static unsigned short gas_mv, gas_level;
static unsigned short samples[SAMPLES];
static unsigned int head, count, minimum, maximum;
static unsigned char graph_y[SAMPLES], spark_y[16];
static unsigned int footer;
static unsigned short footer_ink;

static void scene(void);
static void paint(unsigned int x, unsigned int y, unsigned int w, unsigned int h) {
  ui_paint(x, y, w, h, scene, BG);
}

static unsigned short level_colour(void) {
  if (gas_valid != 1)
    return MUTED;
  return gas_level == MQ5_LEVEL_DANGER ? RED : gas_level == MQ5_LEVEL_WARN ? YELLOW : MINT;
}

static void label(int x, int y, const char *text, const struct ui_font *font,
                  unsigned short colour) {
  ui_text(x, y + font->cap_height, text, font, colour);
}

static void decimal(char *text, unsigned int value) {
  static const unsigned short places[5] = {10000, 1000, 100, 10, 1};
  unsigned int started = 0;
  for (unsigned int index = 0; index < 5; index++) {
    unsigned int digit = 0;
    while (value >= places[index]) {
      value -= places[index];
      digit++;
    }
    if (digit || started || index == 4) {
      *text++ = (char)('0' + digit);
      started = 1;
    }
  }
  *text = 0;
}

static void pair(int x, int baseline, unsigned char value, const struct ui_font *font,
                 unsigned short colour, int step) {
  char first[2] = {(char)('0' + (value >> 4)), 0};
  char second[2] = {(char)('0' + (value & 15u)), 0};
  if (value == 0xff)
    first[0] = second[0] = '-';
  ui_text(x, baseline, first, font, colour);
  ui_text(x + step, baseline, second, font, colour);
}


static unsigned int footer_state(void) {
  if (gas_valid == 2)
    return 1;
  if (env_valid == 2)
    return 2;
  if (rtc_valid == 3)
    return 3;
  if (rtc_valid == 2)
    return 4;
  if (gas_valid == 1 && gas_level >= MQ5_LEVEL_WARN)
    return 5;
  if (rtc_valid == 1 && env_valid == 1 && gas_valid == 1)
    return 6;
  return 0;
}

static unsigned short footer_colour(void) {
  if (footer == 1 || footer == 2 || footer == 3)
    return RED;
  if (footer == 4)
    return ORANGE;
  if (footer == 5)
    return level_colour();
  return footer == 6 ? MINT : MUTED;
}

static void update_footer(void) {
  unsigned int next = footer_state();
  unsigned int previous = footer;
  footer = next;
  unsigned short ink = footer_colour();
  if (previous == next && footer_ink == ink)
    return;
  footer_ink = ink;
  if (!page) {
    paint(113, 9, 7, 7);
    paint(8, 153, 112, 7);
  }
}

static unsigned short sample(unsigned int index) {
  unsigned int position;
  if (index < SAMPLES - count)
    return EMPTY;
  position = head + index;
  if (position >= SAMPLES)
    position -= SAMPLES;
  return samples[position];
}

static unsigned int record(unsigned short value) {
  unsigned int shift = 11, changed = 0;
  samples[head++] = value;
  if (head == SAMPLES)
    head = 0;
  if (count < SAMPLES)
    count++;
  minimum = EMPTY;
  maximum = 0;
  for (unsigned int index = 0; index < SAMPLES; index++) {
    unsigned short reading = sample(index);
    if (reading == EMPTY)
      continue;
    if (reading < minimum)
      minimum = reading;
    if (reading > maximum)
      maximum = reading;
  }
  if (maximum >= 2048u)
    shift++;
  if (maximum >= 4096u)
    shift++;
  if (maximum >= 8192u)
    shift++;
  // Power-of-two graph scale avoids software multiply/divide on RV32I.
  for (unsigned int index = 0; index < SAMPLES; index++) {
    unsigned int reading = sample(index);
    unsigned char y =
        reading == EMPTY
            ? 255
            : (unsigned char)(116u - (((reading << 5) + (reading << 3) + (reading << 1)) >> shift));
    if (graph_y[index] != y)
      changed |= 1;
    graph_y[index] = y;
    if (index >= 44u) {
      y = reading == EMPTY
              ? 255
              : (unsigned char)(146u -
                                (((reading << 3) + (reading << 2) + (reading << 1)) >> shift));
      if (spark_y[index - 44u] != y)
        changed |= 2;
      spark_y[index - 44u] = y;
    }
  }
  return changed;
}

static void plot(unsigned int small) {
  unsigned int total = small ? 16 : SAMPLES;
  const unsigned char *ys = small ? spark_y : graph_y;
  int x = small ? 76 : 27, previous_x = x, previous_y = -1;
  unsigned int fraction = 0;
  for (unsigned int index = 0; index < total; index++) {
    if (ys[index] != 255) {
      if (previous_y >= 0) {
        if (!small)
          ui_rect(previous_x + 1, ys[index], x - previous_x, 117 - ys[index], 0x1166u);
        ui_line(previous_x, previous_y, x, ys[index], level_colour());
      }
      previous_x = x;
      previous_y = ys[index];
    } else
      previous_y = -1;
    fraction += small ? 43u : 92u;
    while (fraction >= (total - 1u)) {
      x++;
      fraction -= total - 1u;
    }
  }
  if (ys[total - 1u] != 255)
    ui_rect(previous_x - 1, previous_y - 1, 3, 3, WHITE);
}

static void date(void) {
  static const char weekdays[7][4] = {"SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"};
  static const char months[12][4] = {"JAN", "FEB", "MAR", "APR", "MAY", "JUN",
                                     "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"};
  char text[18];
  unsigned int day = clock_data[3], month = (clock_data[5] >> 4) * 10u + (clock_data[5] & 15u);
  if (rtc_valid != 1) {
    label(9, 53,
          rtc_valid == 3   ? "RTC OFFLINE"
          : rtc_valid == 2 ? "RTC NOT SET"
                           : "WAITING FOR RTC",
          &ui_body, MUTED);
    return;
  }
  if (day < 1u || day > 7u || month < 1u || month > 12u)
    return;
  // Fixed-size names keep the date in one bounded display region.
  for (unsigned int i = 0; i < 3; i++)
    text[i] = weekdays[day - 1u][i];
  text[3] = ',';
  text[4] = ' ';
  text[5] = '0' + (clock_data[4] >> 4);
  text[6] = '0' + (clock_data[4] & 15u);
  text[7] = ' ';
  for (unsigned int i = 0; i < 3; i++)
    text[8u + i] = months[month - 1u][i];
  text[11] = ' ';
  text[12] = '2';
  text[13] = '0';
  text[14] = '0' + (clock_data[6] >> 4);
  text[15] = '0' + (clock_data[6] & 15u);
  text[16] = 0;
  label(9, 53, text, &ui_body, MUTED);
}

static void gas_value(int x, int y) {
  char text[6];
  unsigned int length = 0;
  if (gas_valid == 1)
    decimal(text, gas_mv);
  else {
    text[0] = text[1] = text[2] = '-';
    text[3] = 0;
  }
  while (text[length])
    length++;
  label(x, y, text, &ui_value, WHITE);
  label(x + (int)(length << 3) + (int)(length << 1) + 4, y + 10, "mV", &ui_body, MUTED);
}

static void dashboard(void) {
  static const char *const footers[] = {
      "WAITING FOR SENSORS", "ADC OFFLINE",         "DHT11 OFFLINE",     "RTC OFFLINE",
      "RTC NEEDS SET",       "GAS ABOVE THRESHOLD", "ALL SENSORS ONLINE"};
  unsigned char invalid = rtc_valid == 1 ? 0 : 0xff;
  unsigned short colour = level_colour();
  const char *status = gas_valid != 1                  ? "NO ADC"
                       : gas_level == MQ5_LEVEL_DANGER ? "DANGER"
                       : gas_level == MQ5_LEVEL_WARN   ? "WARN"
                                                       : "CLEAN";
  ui_icon(8, 7, &ui_wind, MINT);
  label(25, 10, "ENV MONITOR", &ui_title, MUTED);
  ui_round_rect(114, 10, 5, 5, footer_colour());
  pair(18, 45, invalid ? invalid : clock_data[2], &ui_clock, WHITE, 16);
  ui_text(50, 45, ":", &ui_clock, MUTED);
  pair(57, 45, invalid ? invalid : clock_data[1], &ui_clock, WHITE, 16);
  ui_text(89, 45, ":", &ui_seconds, MUTED);
  pair(93, 45, invalid ? invalid : clock_data[0], &ui_seconds, MUTED, 9);
  date();
  ui_round_rect(8, 67, 54, 45, PANEL);
  ui_round_rect(66, 67, 54, 45, PANEL);
  ui_icon(12, 72, &ui_thermometer, ORANGE);
  ui_icon(70, 72, &ui_droplets, BLUE);
  label(28, 75, "TEMP", &ui_label, MUTED);
  label(86, 75, "HUMID", &ui_label, MUTED);
  pair(13, 104, env_valid == 1 ? to_bcd(temperature) : 0xff, &ui_sensor, WHITE, 13);
  pair(71, 104, env_valid == 1 ? to_bcd(humidity) : 0xff, &ui_sensor, WHITE, 13);
  ui_rect(41, 94, 3, 1, ORANGE);
  ui_rect(41, 96, 3, 1, ORANGE);
  ui_rect(41, 94, 1, 3, ORANGE);
  ui_rect(43, 94, 1, 3, ORANGE);
  label(44, 98, "C", &ui_body, ORANGE);
  label(102, 98, "%", &ui_body, BLUE);
  label(9, 119, "GAS / MQ-5", &ui_label, MUTED);
  ui_round_rect(77, 116, 43, 12, gas_valid == 1 ? colour : PANEL);
  label(gas_valid != 1                  ? 84
        : gas_level == MQ5_LEVEL_DANGER ? 85
        : gas_level == MQ5_LEVEL_WARN   ? 90
                                        : 87,
        119, status, &ui_label, gas_valid == 1 ? BG : MUTED);
  gas_value(9, 132);
  plot(1);
  ui_rect(8, 151, 112, 1, EDGE);
  ui_rect(9, 155, 3, 3, footer_colour());
  label(15, 154, footers[footer], &ui_tiny, footer_colour());
}

static void history(void) {
  char text[6];
  unsigned int scale = maximum >= 8192u ? 4u : maximum >= 4096u ? 3u : maximum >= 2048u ? 2u : 1u;
  unsigned int tick = 512u << (scale - 1u);
  ui_icon(8, 7, &ui_activity, MINT);
  label(25, 10, "GAS HISTORY", &ui_title, MUTED);
  label(8, 28, "LAST 60 SAMPLES", &ui_body, MUTED);
  gas_value(8, 43);
  label(93, 51, gas_valid == 1 ? "LIVE" : "NO ADC", &ui_label, level_colour());
  for (unsigned int index = 1; index <= 3; index++) {
    int y = 116 - (int)(index * 10u) - (int)(index >> 1);
    for (int x = 27; x < 119; x += 4)
      ui_rect(x, y, 2, 1, EDGE);
    decimal(text, tick);
    label(7, y - 2, text, &ui_tiny, MUTED);
    tick += 512u << (scale - 1u);
  }
  plot(0);
  ui_round_rect(8, 125, 54, 24, PANEL);
  ui_round_rect(66, 125, 54, 24, PANEL);
  label(13, 130, "MIN", &ui_label, MUTED);
  label(71, 130, "MAX", &ui_label, MUTED);
  if (minimum == EMPTY) {
    text[0] = text[1] = text[2] = '-';
    text[3] = 0;
  } else
    decimal(text, minimum);
  label(13, 138, text, &ui_body, WHITE);
  if (minimum != EMPTY)
    decimal(text, maximum);
  label(71, 138, text, &ui_body, WHITE);
  label(39, 138, "mV", &ui_body, MUTED);
  label(97, 138, "mV", &ui_body, MUTED);
  ui_rect(58, 154, 3, 3, EDGE);
  ui_rect(65, 154, 3, 3, MINT);
}

static void scene(void) {
  if (page)
    history();
  else
    dashboard();
}

void ui_draw_frame(void) {
  rtc_valid = env_valid = gas_valid = page = 0;
  gas_mv = gas_level = head = count = maximum = footer = 0;
  minimum = EMPTY;
  footer_ink = MUTED;
  for (unsigned int i = 0; i < SAMPLES; i++) {
    samples[i] = EMPTY;
    graph_y[i] = 255;
  }
  for (unsigned int i = 0; i < 16; i++)
    spark_y[i] = 255;
  paint(0, 0, TFT_WIDTH, TFT_HEIGHT);
}

void ui_toggle_page(void) {
  page ^= 1u;
  paint(0, 0, TFT_WIDTH, TFT_HEIGHT);
}

void ui_show_time(const unsigned char *time) {
  unsigned int first = rtc_valid != 1;
  unsigned int changed_date = first;
  unsigned char previous[7];
  for (unsigned int i = 0; i < 7; i++) {
    previous[i] = clock_data[i];
    clock_data[i] = time[i];
  }
  rtc_valid = 1;
  if (!page) {
    if (first || previous[2] != time[2])
      paint(17, 24, 33, 23);
    if (first || previous[1] != time[1])
      paint(57, 24, 32, 23);
    if (first || previous[0] != time[0])
      paint(93, 32, 19, 15);
    for (unsigned int i = 3; i < 7; i++)
      if (previous[i] != time[i])
        changed_date = 1;
    if (changed_date)
      paint(8, 52, 112, 10);
  }
  update_footer();
}

static void rtc_fault(unsigned char state) {
  unsigned char previous = rtc_valid;
  rtc_valid = state;
  if (previous != state && !page) {
    paint(17, 24, 95, 23);
    paint(8, 52, 112, 10);
  }
  update_footer();
}
void ui_show_unset(void) { rtc_fault(2); }
void ui_show_rtc_fault(void) { rtc_fault(3); }

void ui_show_environment(unsigned char next_temperature, unsigned char next_humidity) {
  unsigned int temp_changed = env_valid != 1 || temperature != next_temperature;
  unsigned int humid_changed = env_valid != 1 || humidity != next_humidity;
  temperature = next_temperature;
  humidity = next_humidity;
  env_valid = 1;
  if (!page) {
    if (temp_changed)
      paint(12, 86, 29, 25);
    if (humid_changed)
      paint(70, 86, 29, 25);
  }
  update_footer();
}

void ui_show_environment_fault(void) {
  unsigned int changed = env_valid != 2;
  env_valid = 2;
  if (changed && !page) {
    paint(12, 86, 29, 25);
    paint(70, 86, 29, 25);
  }
  update_footer();
}

static void gas(unsigned short value, unsigned int valid, unsigned int level) {
  unsigned int value_changed = gas_valid != valid || gas_mv != value;
  unsigned int status_changed = gas_valid != valid || gas_level != level;
  unsigned int old_min = minimum, old_max = maximum;
  unsigned int changes = record(valid == 1 ? value : EMPTY);
  gas_valid = valid;
  gas_mv = value;
  gas_level = level;
  if (page) {
    if (value_changed)
      paint(8, 42, 65, 21);
    if (status_changed)
      paint(91, 50, 29, 9);
    if ((changes & 1u) || status_changed)
      paint(7, 69, 114, 49);
    if (minimum != old_min || maximum != old_max)
      paint(8, 137, 112, 11);
  } else {
    if (value_changed)
      paint(8, 130, 64, 19);
    if (status_changed)
      paint(77, 116, 43, 12);
    if ((changes & 2u) || status_changed)
      paint(75, 130, 46, 19);
  }
  update_footer();
}
void ui_show_gas(unsigned int mv, unsigned int level) {
  if (mv > 9999u)
    mv = 9999u;
  gas((unsigned short)mv, 1, level);
}
void ui_show_gas_fault(void) { gas(0, 2, 0); }
