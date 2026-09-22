#include "i2c_bus.h"
#include "uart_io.h"
#include "ds3231_rtc.h"

// Fixed by the part: there are no address straps to scan.
#define DS3231_WRITE  0xd0
#define DS3231_READ   0xd1
#define DS3231_STATUS 0x0f
#define DS3231_OSF    0x80

// Days before the first of each month in a non-leap year.
static const unsigned short month_days[12] =
  {0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334};

// Year counts from 2000, where every year divisible by four is a leap year;
// 2100 is not, and is outside the range the two digit year can reach. The only
// division is by four, which is a shift, and the remainder by seven is taken
// by subtraction, since the core has neither instruction.
static unsigned int weekday_of(unsigned int year, unsigned int month,
                               unsigned int date) {
  unsigned int days;

  days = year * 365u + ((year + 3u) >> 2) + month_days[month - 1u] + (date - 1u);
  if ((year & 3u) == 0u && month > 2u) days += 1u;

  days += 6u;                        // 2000-01-01 was a Saturday
  while (days >= 7u) days -= 7u;

  return days + 1u;                  // 1 is Sunday through 7 is Saturday
}

// Division and modulo would pull in a libcall the core cannot satisfy, so the
// tens digit is counted off by subtraction. Correct across 0 to 99, which is
// the range every field here occupies.
static unsigned char bcd_of(unsigned int value) {
  unsigned int tens = 0;

  while (value >= 10u) {
    value -= 10u;
    tens++;
  }

  return (unsigned char) ((tens << 4) | value);
}

static int ds3231_read(unsigned char first, unsigned char *buffer,
                       unsigned int count) {
  unsigned int index;
  unsigned int flags;

  // Setting the pointer is a write; the read that follows turns the bus
  // around with a repeated START rather than releasing it.
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
    // A slave transmits until it is refused, so the last byte must be.
    if (index == count - 1) flags |= I2C_NACK | I2C_STOP;
    i2c_frame(flags);
    buffer[index] = i2c_last_byte();
  }

  return 1;
}

static int ds3231_write(unsigned char first, const unsigned char *buffer,
                        unsigned int count) {
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
    if (index == count - 1) flags |= I2C_STOP;
    if (!i2c_frame(flags)) {
      i2c_release();
      return 0;
    }
  }

  return 1;
}

// A BCD byte has two decimal digits, so neither nibble may exceed nine. A part
// that has never been set, or one written by firmware that got the conversion
// wrong, reads back values that fail this and would otherwise be drawn as if
// they were real.
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
  if (month == 2u) return (year & 3u) == 0u ? 29u : 28u;
  if (month == 4u || month == 6u || month == 9u || month == 11u) return 30u;
  return 31u;
}

int ds3231_time_is_valid(const unsigned char *time) {
  unsigned int year;
  unsigned int month;
  unsigned int date;

  if ((time[0] & 0x80) || !bcd_is_valid(time[0] & 0x7f) ||
      (time[0] & 0x7f) > 0x59) return 0;
  if ((time[1] & 0x80) || !bcd_is_valid(time[1] & 0x7f) ||
      (time[1] & 0x7f) > 0x59) return 0;
  if (time[2] & 0xc0 || !bcd_is_valid(time[2] & 0x3f) ||
      (time[2] & 0x3f) > 0x23) return 0;
  if (time[3] == 0 || time[3] > 7) return 0;
  if (time[5] & 0xe0 || !bcd_is_valid(time[5] & 0x1f) ||
      (time[5] & 0x1f) == 0 || (time[5] & 0x1f) > 0x12) return 0;
  if (time[4] & 0xc0 || !bcd_is_valid(time[4] & 0x3f) ||
      (time[4] & 0x3f) == 0) return 0;
  if (!bcd_is_valid(time[6])) return 0;

  year = bcd_to_uint(time[6]);
  month = bcd_to_uint(time[5] & 0x1f);
  date = bcd_to_uint(time[4] & 0x3f);
  if (date > days_in_month(year, month)) return 0;

  return 1;
}

// Reading from register 0 snapshots the time into a second bank inside the
// part, so the seven bytes cannot straddle a tick.
void ds3231_print(const unsigned char *time) {
  uart_puts("RTC 20");
  uart_bcd(time[6]);                 // year
  uart_putc('-');
  uart_bcd(time[5] & 0x1f);          // month, without the century bit
  uart_putc('-');
  uart_bcd(time[4] & 0x3f);          // date
  uart_putc(' ');
  uart_bcd(time[2] & 0x3f);          // hours, 24 hour mode
  uart_putc(':');
  uart_bcd(time[1] & 0x7f);          // minutes
  uart_putc(':');
  uart_bcd(time[0] & 0x7f);          // seconds
  uart_puts("\r\n");
}

// Sticky from the first time the part is powered, and cleared only by writing
// zero over it. Set means the oscillator stopped at some point, so whatever
// the timekeeping registers hold has not been counting since it was last set.
int ds3231_report_osf(void) {
  unsigned char status;

  if (!ds3231_read(DS3231_STATUS, &status, 1)) {
    uart_puts("RTC NACK\r\n");
    return 0;
  }

  uart_puts((status & DS3231_OSF) ? "RTC OSF SET\r\n" : "RTC OSF CLEAR\r\n");
  return (status & DS3231_OSF) == 0;
}

// The host knows what time it is and this board does not. Twelve digits,
// YYMMDDhhmmss, arrive behind the command byte and go straight into the
// registers. An earlier version used __DATE__ and __TIME__, which set the
// clock to the moment the compiler ran rather than the moment the command was
// given, and ran minutes slow by the time the image had been built, programmed
// and triggered.
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

  // year, month, date, hours, minutes, seconds
  for (index = 0; index < 6; index++) {
    field[index] = (unsigned int) (digits[index * 2] - '0') * 10u
                 + (unsigned int) (digits[index * 2 + 1] - '0');
  }

  if (field[1] < 1 || field[1] > 12 || field[2] < 1 ||
      field[2] > days_in_month(field[0], field[1]) ||
      field[3] > 23 || field[4] > 59 || field[5] > 59) {
    uart_puts("RTC SET RANGE\r\n");
    return 0;
  }

  time[0] = bcd_of(field[5]);
  time[1] = bcd_of(field[4]);
  time[2] = bcd_of(field[3]);                    // 24 hour: bit 6 clear
  time[3] = (unsigned char) weekday_of(field[0], field[1], field[2]);
  time[4] = bcd_of(field[2]);
  time[5] = bcd_of(field[1]);
  time[6] = bcd_of(field[0]);

  if (!ds3231_write(0x00, time, DS3231_TIME_BYTES)) {
    uart_puts("RTC SET FAIL\r\n");
    return 0;
  }

  // Read back rather than write a whole byte: bit 3 enables the 32 kHz output
  // and the alarm flags live here too. Clearing the stop flag is what marks
  // the registers as trustworthy again, so it happens only after a real time
  // has been written over them.
  if (!ds3231_read(DS3231_STATUS, &status, 1)) {
    uart_puts("RTC SET FAIL\r\n");
    return 0;
  }
  status &= (unsigned char) ~DS3231_OSF;
  if (!ds3231_write(DS3231_STATUS, &status, 1)) {
    uart_puts("RTC SET FAIL\r\n");
    return 0;
  }

  uart_puts("RTC SET OK\r\n");
  return 1;
}


// The seven timekeeping registers in one transaction. Reading from register
// zero snapshots them inside the part, so the bytes cannot straddle a tick.
int ds3231_read_time(unsigned char *time) {
  return ds3231_read(0x00, time, DS3231_TIME_BYTES);
}
