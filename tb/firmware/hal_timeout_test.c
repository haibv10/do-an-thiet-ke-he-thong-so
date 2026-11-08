#define _GNU_SOURCE
#include <assert.h>
#include <stdio.h>
#include <sys/mman.h>
#include "i2c_bus.h"
#include "spi_bus.h"
#include "uart_io.h"

static volatile unsigned int *map_registers(unsigned long address) {
  void *mapped = mmap((void *)address, 4096, PROT_READ | PROT_WRITE,
                      MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED_NOREPLACE, -1, 0);
  assert(mapped != MAP_FAILED);
  return mapped;
}

int main(void) {
  volatile unsigned int *uart = map_registers(0x50000000ul);
  volatile unsigned int *i2c = map_registers(0x60000000ul);
  volatile unsigned int *spi = map_registers(0x70000000ul);
  uart[0] = i2c[0] = spi[0] = 0xdeadbeefu;
  uart[1] = i2c[1] = spi[1] = 1u;
  assert(!uart_putc('X'));
  assert(!uart_puts("timeout"));
  assert(!i2c_frame(0x123));
  assert(!spi_write(0x45));
  assert(spi_error());
  assert(uart[0] == 0xdeadbeefu && i2c[0] == 0xdeadbeefu && spi[0] == 0xdeadbeefu);
  assert(!spi_set_control(7));
  assert(spi[2] == 0);

  uart[1] = spi[1] = 0;
  i2c[1] = 2; // ACK, idle
  assert(uart_putc('Y') && uart[0] == 'Y');
  assert(uart_puts("OK") && uart[0] == 'K');
  assert(i2c_frame(0x321) && i2c[0] == 0x321);
  i2c[1] = 0; // NACK, idle
  assert(!i2c_frame(0x111) && i2c[0] == 0x111);
  assert(!spi_write(0x55)); // Timeout remains latched until explicit recovery.
  spi_clear_error();
  assert(!spi_error());
  assert(spi_write(0x55) && spi[0] == 0x55);
  assert(spi_set_control(7) && spi[2] == 7);
  puts("hal_timeout_test: PASS");
  return 0;
}
