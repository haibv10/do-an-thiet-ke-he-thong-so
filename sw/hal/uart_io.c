#include "uart_io.h"
#include "mmio_poll.h"

#define UART_BASE 0x50000000
#define UART_TX_REG (*((volatile unsigned int *)UART_BASE))
#define UART_STAT_REG (*((volatile unsigned int *)(UART_BASE + 4)))
#define UART_RX_REG (*((volatile unsigned int *)(UART_BASE + 8)))
#define UART_TX_BUSY 0x01
#define UART_RX_VALID 0x02

static const char hex_digits[] = "0123456789ABCDEF";

#define UART_GETC_TIMEOUT 3000000U

int uart_putc(unsigned char value) {
  if (!mmio_wait_clear(&UART_STAT_REG, UART_TX_BUSY))
    return 0;
  UART_TX_REG = value;
  return 1;
}

int uart_puts(const char *text) {
  while (*text != '\0') {
    if (!uart_putc((unsigned char)*text))
      return 0;
    text++;
  }
  return 1;
}

int uart_hex8(unsigned char value) {
  return uart_putc(hex_digits[value >> 4]) && uart_putc(hex_digits[value & 0x0f]);
}

int uart_hex32(unsigned int value) {
  return uart_hex8((unsigned char)(value >> 24)) && uart_hex8((unsigned char)(value >> 16)) &&
         uart_hex8((unsigned char)(value >> 8)) && uart_hex8((unsigned char)value);
}

int uart_bcd(unsigned char value) {
  return uart_putc(hex_digits[(value >> 4) & 0x0f]) && uart_putc(hex_digits[value & 0x0f]);
}

int uart_getc(unsigned char *value) {
  unsigned int timeout = UART_GETC_TIMEOUT;

  while (timeout != 0) {
    if (UART_STAT_REG & UART_RX_VALID) {
      *value = (unsigned char)UART_RX_REG;
      return 1;
    }
    timeout--;
  }

  return 0;
}

int uart_poll(unsigned char *value) {
  if (!(UART_STAT_REG & UART_RX_VALID))
    return 0;
  *value = (unsigned char)UART_RX_REG;
  return 1;
}
