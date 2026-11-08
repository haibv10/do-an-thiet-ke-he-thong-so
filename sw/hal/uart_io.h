#ifndef UART_IO_H
#define UART_IO_H

// Output functions return 1 on success, 0 on polling timeout.
int uart_putc(unsigned char value);
int uart_puts(const char *text);
int uart_hex8(unsigned char value);
int uart_hex32(unsigned int value);

int uart_bcd(unsigned char value);

int uart_getc(unsigned char *value);

int uart_poll(unsigned char *value);

#endif
