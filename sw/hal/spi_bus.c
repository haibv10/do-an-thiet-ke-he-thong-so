#include "spi_bus.h"
#include "mmio_poll.h"

#define SPI_BASE 0x70000000
#define SPI_DATA_REG (*((volatile unsigned int *)SPI_BASE))
#define SPI_STAT_REG (*((volatile unsigned int *)(SPI_BASE + 4)))
#define SPI_CTRL_REG (*((volatile unsigned int *)(SPI_BASE + 8)))
#define SPI_BUSY 0x01

static unsigned int failed;

int spi_error(void) { return failed != 0u; }

int spi_wait_idle(void) {
  if (failed)
    return 0;
  if (!mmio_wait_clear(&SPI_STAT_REG, SPI_BUSY)) {
    failed = 1u;
    return 0;
  }
  return 1;
}

int spi_write(unsigned char value) {
  if (!spi_wait_idle())
    return 0;
  SPI_DATA_REG = value;
  return 1;
}

int spi_set_control(unsigned int bits) {
  if (!spi_wait_idle())
    return 0;
  SPI_CTRL_REG = bits;
  return 1;
}
