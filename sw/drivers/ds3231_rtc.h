#ifndef DS3231_RTC_H
#define DS3231_RTC_H

#define DS3231_TIME_BYTES 7

int ds3231_read_time(unsigned char *time);

int ds3231_time_is_valid(const unsigned char *time);

void ds3231_print(const unsigned char *time);

int ds3231_report_osf(void);

int ds3231_set_from_uart(void);

#endif
