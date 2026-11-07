// Boot and the loop that keeps the panel showing what the clock holds. Every
// layer below is in a file of its own: the buses in i2c_bus and spi_bus, the
// devices on them in ds3231_rtc and st7735_panel, and the screen in ui_clock.
#include "sys_delay.h"
#include "gpio_led.h"
#include "uart_io.h"
#include "ds3231_rtc.h"
#include "st7735_panel.h"
#include "ui_clock.h"
#include "mq5_sensor.h"
#include "dht11_sensor.h"

// load them back, instead of folding the initialiser into an immediate.
unsigned int data_marker = 0x5a5a5a5a;  // .data, copied out of ROM by startup.s
unsigned int bss_marker;                // .bss, cleared by startup.s

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

  // The banner doubles as a startup self-check: the two words only read back as
  // 5A5A5A5A and 00000000 if .data was copied and .bss cleared.
  uart_puts("BOOT ");
  uart_hex32(data_marker);
  uart_putc(' ');
  uart_hex32(bss_marker);
  uart_puts("\r\n");

  uart_puts("TFT INIT\r\n");
  tft_init();
  tft_colour_bars();
  uart_puts("TFT BARS\r\n");

  rtc_time_trusted = ds3231_report_osf();

  // The bars stay up long enough to be read, then the panel becomes the clock.
  delay_loop(DELAY_MS(1000));
  ui_draw_frame();

  while (1) {
    if (uart_poll(&command) && command == 'W') {
      // A rejected command never touched the clock, so it must not make a
      // time that was already trusted disappear from the panel.
      if (ds3231_set_from_uart()) rtc_time_trusted = 1;
    }

    if (++gas_tick >= 10u) {
      gas_tick = 0;
      if (mq5_read_mv(&gas_mv)) ui_show_gas(gas_mv, mq5_level_of(gas_mv));
      else ui_show_gas_fault();
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
        else ui_show_environment_fault();
        dht_pending = 0;
      }
    }

    if (!ds3231_read_time(time)) {
      uart_puts("RTC NACK\r\n");
      delay_loop(DELAY_MS(1000));
      continue;
    }

    // Redrawn when the seconds byte changes, not on a timer. A timer drifts
    // against the clock and eventually skips a second, which an earlier
    // capture showed as 00:14:52 followed by 00:14:54.
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
