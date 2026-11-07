#include "sys_delay.h"
#include "gpio_led.h"
#include "uart_io.h"
#include "ds3231_rtc.h"
#include "st7735_panel.h"
#include "ui_clock.h"
#include "mq5_sensor.h"
#include "dht11_sensor.h"

unsigned int data_marker = 0x5a5a5a5a;
unsigned int bss_marker;

int main(void) {
  unsigned char time[DS3231_TIME_BYTES];
  unsigned char last_second = 0xff;
  unsigned int led = 0;
  unsigned int rtc_time_trusted;
  unsigned char command;
  unsigned int gas_tick = 0;
  unsigned int gas_mv;
  unsigned int dht_tick = 0;
  unsigned int dht_pending = 0;
  unsigned int dht_status;
  unsigned char humidity;
  unsigned char temperature;

  led_set(0);

  uart_puts("BOOT ");
  uart_hex32(data_marker);
  uart_putc(' ');
  uart_hex32(bss_marker);
  uart_puts("\r\n");

  tft_init();

  rtc_time_trusted = ds3231_report_osf();

  ui_draw_frame();

  while (1) {
    if (uart_poll(&command) && command == 'W') {

      if (ds3231_set_from_uart())
        rtc_time_trusted = 1;
    }

    if (++gas_tick >= 10u) {
      gas_tick = 0;
      if (mq5_read_mv(&gas_mv))
        ui_show_gas(gas_mv, mq5_level_of(gas_mv));
      else
        ui_show_gas_fault();
    }

    if (!dht_pending && ++dht_tick >= 40u) {
      dht_tick = 0;
      dht11_start();
      dht_pending = 1;
    }
    if (dht_pending) {
      dht_status = dht11_status();
      if (!(dht_status & DHT11_BUSY)) {
        if (dht11_read(&humidity, &temperature))
          ui_show_environment(temperature, humidity);
        else
          ui_show_environment_fault();
        dht_pending = 0;
      }
    }

    if (!ds3231_read_time(time)) {
      uart_puts("RTC NACK\r\n");
      delay_loop(DELAY_MS(1000));
      continue;
    }

    if (time[0] != last_second) {
      last_second = time[0];
      if (rtc_time_trusted && ds3231_time_is_valid(time)) {
        ds3231_print(time);
        ui_show_time(time);
      } else {
        uart_puts("RTC INVALID\r\n");
        ui_show_unset();
      }
      led = led ^ 1u;
      led_set(led);
    }

    delay_loop(DELAY_MS(50));
  }
}
