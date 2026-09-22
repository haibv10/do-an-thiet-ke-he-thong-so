#ifndef SPI_BUS_H
#define SPI_BUS_H

// Control lines the peripheral holds for software rather than sequencing: one
// command and its parameters form a single chip select frame with dc changing
// partway through, which the hardware cannot infer from the byte stream.
#define SPI_CS_N      0x01
#define SPI_DC        0x02
#define SPI_RST_N     0x04

void spi_set_control(unsigned int bits);

void spi_wait_idle(void);
void spi_write(unsigned char value);

#endif
