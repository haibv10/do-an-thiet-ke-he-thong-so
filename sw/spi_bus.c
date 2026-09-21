#include "spi_bus.h"

#define SPI_BASE      0x70000000
#define SPI_DATA_REG  (*((volatile unsigned int *) SPI_BASE))
#define SPI_STAT_REG  (*((volatile unsigned int *) (SPI_BASE + 4)))
#define SPI_CTRL_REG  (*((volatile unsigned int *) (SPI_BASE + 8)))
#define SPI_BUSY      0x01

void spi_wait_idle(void) {
  while (SPI_STAT_REG & SPI_BUSY) {
  }
}

void spi_write(unsigned char value) {
  spi_wait_idle();
  SPI_DATA_REG = value;
}

// The control register moves cs_n and dc, so it must not change while a byte
// is still being shifted.
void spi_set_control(unsigned int bits) {
  spi_wait_idle();
  SPI_CTRL_REG = bits;
}
