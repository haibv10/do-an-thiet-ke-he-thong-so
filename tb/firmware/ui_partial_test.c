#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "st7735_panel.h"
#include "ui_clock.h"
#include "spi_bus.h"
#include "mq5_sensor.h"

static unsigned short screen[160][128], saved[160][128];
static unsigned int control, command, parameter, byte_count, high, x0, x1, y0, y1, x, y;
static unsigned int transfers, pixels_written;

int spi_wait_idle(void) { return 1; }
int spi_set_control(unsigned int bits) {
  control = bits;
  return 1;
}
int spi_write(unsigned char value) {
  transfers++;
  if (control & SPI_CS_N)
    return 1;
  if (!(control & SPI_DC)) {
    command = value;
    parameter = 0;
    byte_count = 0;
    if (command == 0x2c) {
      x = x0;
      y = y0;
    }
    return 1;
  }
  if (command == 0x2a || command == 0x2b) {
    parameter = (parameter << 8) | value;
    if (++byte_count == 4) {
      if (command == 0x2a) {
        x0 = parameter >> 16;
        x1 = parameter & 0xffffu;
      } else {
        y0 = parameter >> 16;
        y1 = parameter & 0xffffu;
      }
      assert(x0 <= x1 && x1 < 128 && y0 <= y1 && y1 < 160);
    }
  } else if (command == 0x2c) {
    if ((byte_count++ & 1u) == 0)
      high = value;
    else {
      assert(x < 128 && y < 160);
      screen[y][x] = (unsigned short)((high << 8) | value);
      pixels_written++;
      if (++x > x1) {
        x = x0;
        if (++y > y1)
          y = y0;
      }
    }
  }
  return 1;
}
void delay_loop(unsigned int value) { (void)value; }

static void reset_counters(void) { transfers = pixels_written = 0; }
static void coherent(void) {
  memcpy(saved, screen, sizeof screen);
  ui_toggle_page();
  ui_toggle_page();
  assert(memcmp(saved, screen, sizeof screen) == 0);
}
static void snapshot(const char *directory, const char *name) {
  char path[512];
  assert(snprintf(path, sizeof path, "%s/%s.ppm", directory, name) < (int)sizeof path);
  FILE *file = fopen(path, "wb");
  assert(file);
  fprintf(file, "P6\n128 160\n255\n");
  for (unsigned int row = 0; row < 160; row++) {
    for (unsigned int col = 0; col < 128; col++) {
      unsigned int v = screen[row][col];
      fputc(((v >> 11) & 31u) * 255u / 31u, file);
      fputc(((v >> 5) & 63u) * 255u / 63u, file);
      fputc((v & 31u) * 255u / 31u, file);
    }
  }
  assert(fclose(file) == 0);
}

int main(int argc, char **argv) {
  unsigned char time[7] = {0x18, 0x23, 0x02, 2, 0x09, 0x11, 0x26};
  const char *directory = argc > 1 ? argv[1] : "build/tests";
  ui_draw_frame();
  assert(pixels_written == 128u * 160u); // Startup only.
  ui_show_time(time);
  ui_show_environment(27, 65);
  for (unsigned int i = 0; i < 65; i++)
    ui_show_gas(900, MQ5_LEVEL_CLEAN);
  coherent();
  snapshot(directory, "ui-dashboard");
  reset_counters();
  ui_show_time(time);
  ui_show_environment(27, 65);
  ui_show_gas(900, MQ5_LEVEL_CLEAN);
  assert(transfers == 0); // Identical data produces no SPI traffic.

  memcpy(saved, screen, sizeof screen);
  time[0] = 0x19;
  ui_show_time(time);
  assert(pixels_written == 19u * 15u);
  for (unsigned int row = 0; row < 160; row++)
    for (unsigned int col = 0; col < 128; col++)
      if (row < 32 || row >= 47 || col < 93 || col >= 112)
        assert(screen[row][col] == saved[row][col]);
  printf("ui_partial_test: seconds update %u pixels; identical values 0 SPI bytes\n",
         pixels_written);
  coherent();
  reset_counters();
  ui_show_environment(28, 65);
  assert(pixels_written == 29u * 25u);
  coherent();

  ui_show_gas(1800, MQ5_LEVEL_WARN);
  coherent();
  unsigned short warning = screen[155][9];
  ui_show_gas(2800, MQ5_LEVEL_DANGER);
  assert(screen[155][9] != warning); // Same footer text, different severity colour.
  coherent();
  snapshot(directory, "ui-danger");
  ui_show_gas(900, MQ5_LEVEL_CLEAN); // Four to three digits must leave no stale pixels.
  coherent();
  ui_show_environment_fault();
  ui_show_gas_fault();
  ui_show_unset();
  coherent();
  snapshot(directory, "ui-fault");
  for (unsigned int i = 0; i < 65; i++)
    ui_show_gas_fault();
  reset_counters();
  ui_show_environment_fault();
  ui_show_gas_fault();
  ui_show_unset();
  assert(transfers == 0);

  // Recovery, minute/hour/date rollover and history ring wrap.
  time[0] = 0x59;
  time[1] = 0x59;
  time[2] = 0x23;
  ui_show_time(time);
  ui_show_environment(99, 99);
  coherent();
  time[0] = time[1] = time[2] = 0;
  time[3] = 3;
  time[4] = 0x10;
  ui_show_time(time);
  ui_show_environment(0, 0);
  coherent();
  for (unsigned int i = 0; i < 90; i++)
    ui_show_gas(500u + (i % 20u) * 35u, MQ5_LEVEL_CLEAN);
  ui_toggle_page();
  coherent();
  snapshot(directory, "ui-history");
  reset_counters();
  time[0] = 1;
  ui_show_time(time);
  ui_show_environment(27, 65);
  assert(transfers == 0);              // Hidden clock/sensor values update state only.
  ui_show_gas(5000, MQ5_LEVEL_DANGER); // Axis scaling and min/max update.
  coherent();
  ui_show_gas(9999, MQ5_LEVEL_DANGER);
  coherent();
  ui_show_gas_fault();
  coherent();
  snapshot(directory, "ui-history-fault");
  ui_toggle_page();
  ui_show_time(time);
  ui_show_environment(27, 65);
  ui_show_gas(900, MQ5_LEVEL_CLEAN);
  coherent();
  puts("ui_partial_test: PASS (partial updates, page cache, faults, history and recovery)");
  return 0;
}
