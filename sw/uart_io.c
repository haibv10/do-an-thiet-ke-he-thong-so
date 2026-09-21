#include "uart_io.h"

#define UART_BASE     0x50000000
#define UART_TX_REG   (*((volatile unsigned int *) UART_BASE))
#define UART_STAT_REG (*((volatile unsigned int *) (UART_BASE + 4)))
#define UART_RX_REG   (*((volatile unsigned int *) (UART_BASE + 8)))
#define UART_TX_BUSY  0x01
#define UART_RX_VALID 0x02

// Lives in .rodata, so reading it exercises the ROM window at region 0x0, the
// same path startup.s uses to copy .data out of ROM.
static const char hex_digits[] = "0123456789ABCDEF";

// Long enough for twelve characters at 115200 baud with room to spare, short
// enough that a truncated line does not stop the caller.
#define UART_GETC_TIMEOUT 3000000U

void uart_putc(unsigned char value) {
  while (UART_STAT_REG & UART_TX_BUSY) {
  }
  UART_TX_REG = value;
}

void uart_puts(const char *text) {
  while (*text != '\0') {
    uart_putc((unsigned char) *text);
    text++;
  }
}

void uart_hex8(unsigned char value) {
  uart_putc(hex_digits[value >> 4]);
  uart_putc(hex_digits[value & 0x0f]);
}

void uart_hex32(unsigned int value) {
  uart_hex8((unsigned char) (value >> 24));
  uart_hex8((unsigned char) (value >> 16));
  uart_hex8((unsigned char) (value >> 8));
  uart_hex8((unsigned char) value);
}

void uart_bcd(unsigned char value) {
  uart_putc(hex_digits[(value >> 4) & 0x0f]);
  uart_putc(hex_digits[value & 0x0f]);
}

int uart_getc(unsigned char *value) {
  unsigned int timeout = UART_GETC_TIMEOUT;

  while (timeout != 0) {
    if (UART_STAT_REG & UART_RX_VALID) {
      *value = (unsigned char) UART_RX_REG;
      return 1;
    }
    timeout--;
  }

  return 0;
}

int uart_poll(unsigned char *value) {
  if (!(UART_STAT_REG & UART_RX_VALID)) return 0;
  *value = (unsigned char) UART_RX_REG;
  return 1;
}
