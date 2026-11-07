#ifndef UART_IO_H
#define UART_IO_H

void uart_putc(unsigned char value);
void uart_puts(const char *text);
void uart_hex8(unsigned char value);
void uart_hex32(unsigned int value);

void uart_bcd(unsigned char value);

int uart_getc(unsigned char *value);

int uart_poll(unsigned char *value);

#endif
