#ifndef SPI_BUS_H
#define SPI_BUS_H

#define SPI_CS_N 0x01
#define SPI_DC 0x02
#define SPI_RST_N 0x04

int spi_set_control(unsigned int bits);

int spi_wait_idle(void);
int spi_write(unsigned char value);

// A timeout latches the error; clear it before an explicit retry.
int spi_error(void);
void spi_clear_error(void);

#endif
