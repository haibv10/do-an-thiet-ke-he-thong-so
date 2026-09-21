#ifndef DS3231_RTC_H
#define DS3231_RTC_H

#define DS3231_TIME_BYTES 7

// Seven registers from zero: seconds, minutes, hours, weekday, date, month and
// year, all packed BCD. Returns zero if the part did not answer.
int ds3231_read_time(unsigned char *time);

// Zero unless the fields form a valid 24-hour calendar date in the supported
// 2000 through 2099 range. Trust also requires the oscillator-stop flag to be
// clear, which is reported separately at boot.
int ds3231_time_is_valid(const unsigned char *time);

void ds3231_print(const unsigned char *time);

// Reports the oscillator stop flag, which is set from the first time the part
// is powered and stays set until a real time is written over the registers.
// Returns one only when the timekeeping registers can be trusted.
int ds3231_report_osf(void);

// Takes twelve digits, YYMMDDhhmmss, from the serial link, since the board has
// no other idea what time it is. Clears the stop flag once they are written.
// Returns one only after the registers and stop flag are both written.
int ds3231_set_from_uart(void);

#endif
