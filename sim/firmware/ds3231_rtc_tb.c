#include <stdio.h>
#include <stdlib.h>

#include "ds3231_rtc.h"

// The validation path is pure C. These stubs satisfy the rest of the driver
// without making a host test depend on the UART or the I2C hardware model.
int i2c_frame(unsigned int value) {
  (void) value;
  return 1;
}

void i2c_release(void) {
}

unsigned char i2c_last_byte(void) {
  return 0;
}

void uart_putc(unsigned char value) {
  (void) value;
}

void uart_puts(const char *text) {
  (void) text;
}

void uart_bcd(unsigned char value) {
  (void) value;
}

int uart_getc(unsigned char *value) {
  (void) value;
  return 0;
}

static void expect_valid(const unsigned char *time, const char *label) {
  if (!ds3231_time_is_valid(time)) {
    fprintf(stderr, "%s rejected\n", label);
    exit(1);
  }
}

static void expect_invalid(const unsigned char *time, const char *label) {
  if (ds3231_time_is_valid(time)) {
    fprintf(stderr, "%s accepted\n", label);
    exit(1);
  }
}

int main(void) {
  const unsigned char valid[] = {0x59, 0x59, 0x23, 0x7, 0x29, 0x02, 0x24};
  const unsigned char leap_day[] = {0x00, 0x00, 0x00, 0x4, 0x29, 0x02, 0x24};
  const unsigned char bad_second[] = {0x69, 0x00, 0x00, 0x1, 0x01, 0x01, 0x24};
  const unsigned char twelve_hour[] = {0x00, 0x00, 0x71, 0x1, 0x01, 0x01, 0x24};
  const unsigned char february_30[] = {0x00, 0x00, 0x00, 0x5, 0x30, 0x02, 0x24};
  const unsigned char nonleap_february_29[] = {0x00, 0x00, 0x00, 0x3, 0x29, 0x02, 0x23};
  const unsigned char bad_weekday[] = {0x00, 0x00, 0x00, 0x0, 0x01, 0x01, 0x24};

  expect_valid(valid, "valid end-of-day time");
  expect_valid(leap_day, "2024 leap day");
  expect_invalid(bad_second, "69 seconds");
  expect_invalid(twelve_hour, "12-hour mode");
  expect_invalid(february_30, "30 February");
  expect_invalid(nonleap_february_29, "2023 leap day");
  expect_invalid(bad_weekday, "weekday zero");

  puts("ds3231_rtc_tb: PASS");
  return 0;
}
