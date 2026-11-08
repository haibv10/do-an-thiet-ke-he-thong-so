#include "gpio_led.h"
#include "uart_io.h"
#include "i2c_bus.h"
#include "spi_bus.h"
#include "ds3231_rtc.h"

static volatile unsigned int ram_probe[4];

static void demo_rtc(void) {
  unsigned char time[DS3231_TIME_BYTES];
  if (!ds3231_read_time(time)) {
    uart_puts("I2C NACK/TIMEOUT\r\n");
    return;
  }
  uart_puts("I2C ");
  ds3231_print(time);
}

static void demo_spi(void) {
  // ST7735 NOP: exercise the transmit path without drawing or reading the panel.
  spi_clear_error();
  if (spi_set_control(SPI_RST_N) && spi_write(0x00) && spi_wait_idle() &&
      spi_set_control(SPI_RST_N | SPI_CS_N))
    uart_puts("SPI TX OK\r\n");
  else
    uart_puts("SPI TIMEOUT\r\n");
}

int main(void) {
  unsigned int index;
  unsigned int led = 1;
  unsigned char command;
  for (index = 0; index < 4; index++)
    ram_probe[index] = 0x12340000u + index;
  for (index = 0; index < 4; index++) {
    if (ram_probe[index] != 0x12340000u + index) {
      uart_puts("RAM FAIL\r\n");
      while (1) {
      }
    }
  }
  uart_puts("RAM PASS\r\n");
  led_set(led);
  demo_rtc();
  demo_spi();
  uart_puts("MMIO DEMO READY: echo; r=RTC s=SPI l=LED\r\n");
  while (1) {
    if (!uart_poll(&command))
      continue;
    uart_putc(command);
    if (command == 'r')
      demo_rtc();
    else if (command == 's')
      demo_spi();
    else if (command == 'l') {
      led ^= 1u;
      led_set(led);
    }
  }
}
