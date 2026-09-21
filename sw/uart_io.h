#ifndef UART_IO_H
#define UART_IO_H

void uart_putc(unsigned char value);
void uart_puts(const char *text);
void uart_hex8(unsigned char value);
void uart_hex32(unsigned int value);

// Two hex digits of a BCD byte are its two decimal digits, so this prints a
// packed field without converting it.
void uart_bcd(unsigned char value);

// Waits for one character rather than returning what is not there yet, with a
// bound so a truncated line cannot hang the caller. Returns zero on timeout.
int uart_getc(unsigned char *value);

// Non-blocking: returns zero when nothing has arrived, so a caller can check
// for a command without stalling its loop.
int uart_poll(unsigned char *value);

#endif
