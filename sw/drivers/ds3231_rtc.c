#include "i2c_bus.h"
#include "uart_io.h"
#include "ds3231_rtc.h"
#include "bcd.h"

#define DS3231_WRITE 0xd0
#define DS3231_READ 0xd1
#define DS3231_STATUS 0x0f
#define DS3231_OSF 0x80

static const unsigned short month_days[12] = {0,   31,  59,  90,  120, 151,
                                              181, 212, 243, 273, 304, 334};

static unsigned int weekday_of(unsigned int year, unsigned int month, unsigned int date) {
  unsigned int days;

  days = year * 365u + ((year + 3u) >> 2) + month_days[month - 1u] + (date - 1u);
  if ((year & 3u) == 0u && month > 2u)
    days += 1u;

  days += 6u;
  while (days >= 7u)
    days -= 7u;

  return days + 1u;
}


static int ds3231_read(unsigned char first, unsigned char *buffer, unsigned int count) {
  unsigned int index;
  unsigned int flags;

  if (!i2c_frame(I2C_START | DS3231_WRITE)) {
    i2c_release();
    return 0;
  }
  if (!i2c_frame(first)) {
    i2c_release();
    return 0;
  }
  if (!i2c_frame(I2C_START | DS3231_READ)) {
    i2c_release();
    return 0;
  }

  for (index = 0; index < count; index++) {
    flags = I2C_READ;

    if (index == count - 1)
      flags |= I2C_NACK | I2C_STOP;
    i2c_frame(flags);
    buffer[index] = i2c_last_byte();
  }

  return 1;
}

static int ds3231_write(unsigned char first, const unsigned char *buffer, unsigned int count) {
  unsigned int index;
  unsigned int flags;

  if (!i2c_frame(I2C_START | DS3231_WRITE)) {
    i2c_release();
    return 0;
  }
  if (!i2c_frame(first)) {
    i2c_release();
    return 0;
  }

  for (index = 0; index < count; index++) {
    flags = buffer[index];
    if (index == count - 1)
      flags |= I2C_STOP;
    if (!i2c_frame(flags)) {
      i2c_release();
      return 0;
    }
  }

  return 1;
}

static int bcd_is_valid(unsigned char value) {
  return ((value & 0x0f) <= 9) && (((value >> 4) & 0x0f) <= 9);
}

static unsigned int bcd_to_uint(unsigned char value) {
  unsigned int result = value & 0x0f;
  unsigned int tens = value >> 4;

  while (tens != 0) {
    result += 10u;
    tens--;
  }

  return result;
}

static unsigned int days_in_month(unsigned int year, unsigned int month) {
  if (month == 2u)
    return (year & 3u) == 0u ? 29u : 28u;
  if (month == 4u || month == 6u || month == 9u || month == 11u)
    return 30u;
  return 31u;
}

int ds3231_time_is_valid(const unsigned char *time) {
  unsigned int year;
  unsigned int month;
  unsigned int date;

  if ((time[0] & 0x80) || !bcd_is_valid(time[0] & 0x7f) || (time[0] & 0x7f) > 0x59)
    return 0;
  if ((time[1] & 0x80) || !bcd_is_valid(time[1] & 0x7f) || (time[1] & 0x7f) > 0x59)
    return 0;
  if (time[2] & 0xc0 || !bcd_is_valid(time[2] & 0x3f) || (time[2] & 0x3f) > 0x23)
    return 0;
  if (time[3] == 0 || time[3] > 7)
    return 0;
  if (time[5] & 0xe0 || !bcd_is_valid(time[5] & 0x1f) || (time[5] & 0x1f) == 0 ||
      (time[5] & 0x1f) > 0x12)
    return 0;
  if (time[4] & 0xc0 || !bcd_is_valid(time[4] & 0x3f) || (time[4] & 0x3f) == 0)
    return 0;
  if (!bcd_is_valid(time[6]))
    return 0;

  year = bcd_to_uint(time[6]);
  month = bcd_to_uint(time[5] & 0x1f);
  date = bcd_to_uint(time[4] & 0x3f);
  if (date > days_in_month(year, month))
    return 0;

  return 1;
}

void ds3231_print(const unsigned char *time) {
  uart_puts("RTC 20");
  uart_hex8(time[6]);
  uart_putc('-');
  uart_hex8(time[5] & 0x1f);
  uart_putc('-');
  uart_hex8(time[4] & 0x3f);
  uart_putc(' ');
  uart_hex8(time[2] & 0x3f);
  uart_putc(':');
  uart_hex8(time[1] & 0x7f);
  uart_putc(':');
  uart_hex8(time[0] & 0x7f);
  uart_puts("\r\n");
}

int ds3231_report_osf(void) {
  unsigned char status;

  if (!ds3231_read(DS3231_STATUS, &status, 1)) {
    uart_puts("RTC NACK\r\n");
    return 0;
  }

  uart_puts((status & DS3231_OSF) ? "RTC OSF SET\r\n" : "RTC OSF CLEAR\r\n");
  return (status & DS3231_OSF) == 0;
}

int ds3231_set_from_uart(void) {
  unsigned char digits[12];
  unsigned char time[DS3231_TIME_BYTES];
  unsigned char status;
  unsigned int index;
  unsigned int field[6];

  for (index = 0; index < 12; index++) {
    if (!uart_getc(&digits[index])) {
      uart_puts("RTC SET SHORT\r\n");
      return 0;
    }
    if (digits[index] < '0' || digits[index] > '9') {
      uart_puts("RTC SET BAD\r\n");
      return 0;
    }
  }

  for (index = 0; index < 6; index++) {
    field[index] =
        (unsigned int)(digits[index * 2] - '0') * 10u + (unsigned int)(digits[index * 2 + 1] - '0');
  }

  if (field[1] < 1 || field[1] > 12 || field[2] < 1 ||
      field[2] > days_in_month(field[0], field[1]) || field[3] > 23 || field[4] > 59 ||
      field[5] > 59) {
    uart_puts("RTC SET RANGE\r\n");
    return 0;
  }

  time[0] = to_bcd(field[5]);
  time[1] = to_bcd(field[4]);
  time[2] = to_bcd(field[3]);
  time[3] = (unsigned char)weekday_of(field[0], field[1], field[2]);
  time[4] = to_bcd(field[2]);
  time[5] = to_bcd(field[1]);
  time[6] = to_bcd(field[0]);

  if (!ds3231_write(0x00, time, DS3231_TIME_BYTES)) {
    uart_puts("RTC SET FAIL\r\n");
    return 0;
  }

  if (!ds3231_read(DS3231_STATUS, &status, 1)) {
    uart_puts("RTC SET FAIL\r\n");
    return 0;
  }
  status &= (unsigned char)~DS3231_OSF;
  if (!ds3231_write(DS3231_STATUS, &status, 1)) {
    uart_puts("RTC SET FAIL\r\n");
    return 0;
  }

  uart_puts("RTC SET OK\r\n");
  return 1;
}

int ds3231_read_time(unsigned char *time) { return ds3231_read(0x00, time, DS3231_TIME_BYTES); }
