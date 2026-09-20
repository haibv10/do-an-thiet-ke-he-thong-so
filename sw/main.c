#define GPIO_BASE     0x40000000
#define UART_BASE     0x50000000
#define I2C_BASE      0x60000000

#define LED_REG       (*((volatile unsigned int *) GPIO_BASE))
#define UART_TX_REG   (*((volatile unsigned int *) UART_BASE))
#define UART_STAT_REG (*((volatile unsigned int *) (UART_BASE + 4)))
#define UART_RX_REG   (*((volatile unsigned int *) (UART_BASE + 8)))
#define UART_CTRL_REG (*((volatile unsigned int *) (UART_BASE + 12)))
#define LCD_WRITE_REG (*((volatile unsigned int *) I2C_BASE))
#define LCD_STAT_REG  (*((volatile unsigned int *) (I2C_BASE + 4)))
#define LCD_ADDR_REG  (*((volatile unsigned int *) (I2C_BASE + 8)))

#define UART_TX_BUSY  0x01
#define UART_RX_VALID 0x02
#define UART_RX_OVERRUN 0x04
#define UART_RX_LEVEL_MASK 0xf8
#define UART_CTRL_CLEAR_OVERRUN 0x01
#define LCD_BUSY      0x01
#define LCD_ACK       0x02

#ifndef UART_FIFO_TEST_TIMEOUT
#define UART_FIFO_TEST_TIMEOUT 270000U
#endif

// Lives in .rodata, so reading it exercises the ROM window at region 0x0.
static const char hex_digits[] = "0123456789ABCDEF";

// Both markers have external linkage so the compiler must emit the objects and
// load them back, instead of folding the initialiser into an immediate.
unsigned int data_marker = 0x5a5a5a5a;  // .data, copied out of ROM by startup.s
unsigned int bss_marker;                // .bss, cleared by startup.s

static void delay_cycles(unsigned int cycles) {
  volatile unsigned int index;

  for (index = 0; index < cycles; index++) {
  }
}

static void uart_putc(unsigned char value) {
  while (UART_STAT_REG & UART_TX_BUSY) {
  }
  UART_TX_REG = value;
}

static void uart_puts(const char *text) {
  while (*text != '\0') {
    uart_putc((unsigned char) *text);
    text++;
  }
}

static void uart_hex8(unsigned char value) {
  uart_putc(hex_digits[value >> 4]);
  uart_putc(hex_digits[value & 0x0f]);
}

static void uart_hex32(unsigned int value) {
  uart_hex8((unsigned char) (value >> 24));
  uart_hex8((unsigned char) (value >> 16));
  uart_hex8((unsigned char) (value >> 8));
  uart_hex8((unsigned char) value);
}

static void uart_fifo_drain(void) {
  while (UART_STAT_REG & UART_RX_VALID) {
    (void) UART_RX_REG;
  }
  UART_CTRL_REG = UART_CTRL_CLEAR_OVERRUN;
}

static int uart_fifo_wait(unsigned int mask, unsigned int expected) {
  unsigned int timeout = UART_FIFO_TEST_TIMEOUT;

  while (timeout != 0) {
    if ((UART_STAT_REG & mask) == expected) return 1;
    timeout--;
  }

  return 0;
}

static int uart_fifo_check(const unsigned char *expected,
                           unsigned int count,
                           unsigned int expected_overrun) {
  unsigned int index;
  unsigned int status = UART_STAT_REG;

  if ((status & UART_RX_LEVEL_MASK) != (count << 3)) return 0;
  if (((status & UART_RX_OVERRUN) != 0) != expected_overrun) return 0;

  for (index = 0; index < count; index++) {
    if ((UART_STAT_REG & UART_RX_VALID) == 0) return 0;
    if ((unsigned char) UART_RX_REG != expected[index]) return 0;
  }

  if (UART_STAT_REG & UART_RX_VALID) return 0;

  if (expected_overrun) {
    UART_CTRL_REG = UART_CTRL_CLEAR_OVERRUN;
    if (UART_STAT_REG & UART_RX_OVERRUN) return 0;
  }

  return 1;
}

static void uart_fifo_test(void) {
  static const unsigned char case16[] = {
    0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
    0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f
  };
  static const unsigned char case17[] = {
    0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87,
    0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f, 0x90
  };
  int case16_passed;
  int case17_passed;

  uart_fifo_drain();

  uart_puts("RXFIFO CASE16\r\n");
  case16_passed = uart_fifo_wait(UART_RX_LEVEL_MASK, 16U << 3);
  if (case16_passed) case16_passed = uart_fifo_check(case16, 16, 0);
  uart_puts(case16_passed ? "RXFIFO CASE16 PASS\r\n" : "RXFIFO CASE16 FAIL\r\n");

  uart_fifo_drain();
  uart_puts("RXFIFO CASE17\r\n");
  case17_passed = uart_fifo_wait(UART_RX_OVERRUN, UART_RX_OVERRUN);
  if (case17_passed) case17_passed = uart_fifo_check(case17, 16, 1);
  uart_puts(case17_passed ? "RXFIFO CASE17 PASS\r\n" : "RXFIFO CASE17 FAIL\r\n");

  uart_puts(case16_passed && case17_passed ? "RXFIFO PASS\r\n" : "RXFIFO FAIL\r\n");
}

static void lcd_wait_ready(void) {
  while (LCD_STAT_REG & LCD_BUSY) {
  }
}

static void lcd_command(unsigned char value) {
  lcd_wait_ready();
  LCD_WRITE_REG = value;
}

static void lcd_data(unsigned char value) {
  lcd_wait_ready();
  LCD_WRITE_REG = 0x100 | value;
}

static void lcd_puts(const char *text) {
  while (*text != '\0') {
    lcd_data((unsigned char) *text);
    text++;
  }
}

static void lcd_init(void) {
  delay_cycles(1080000);
  lcd_command(0x02); // return home, 4-bit interface
  lcd_command(0x28); // 4-bit bus, two display lines, 5x8 font
  lcd_command(0x0C); // display on, cursor off, blink off
  lcd_command(0x06); // entry mode: increment, no shift
  lcd_command(0x01); // clear display
}

static int lcd_probe(unsigned char address) {
  LCD_ADDR_REG = address;
  lcd_command(0x00);
  lcd_wait_ready();
  return (LCD_STAT_REG & LCD_ACK) != 0;
}

static int lcd_find_address(void) {
  unsigned char address;

  // PCF8574 answers in 0x20-0x27, PCF8574A in 0x38-0x3f.
  for (address = 0x20; address <= 0x27; address++) {
    if (lcd_probe(address)) return address;
  }
  for (address = 0x38; address <= 0x3f; address++) {
    if (lcd_probe(address)) return address;
  }
  return -1;
}

int main(void) {
  int lcd_address;

  LED_REG = 0;

  // The banner doubles as a startup self-check: the two words only read back as
  // 5A5A5A5A and 00000000 if .data was copied and .bss cleared.
  uart_puts("BOOT ");
  uart_hex32(data_marker);
  uart_putc(' ');
  uart_hex32(bss_marker);
  uart_puts("\r\n");

  lcd_address = -1;
  delay_cycles(1080000);
  lcd_address = lcd_find_address();
  if (lcd_address >= 0) {
    lcd_init();
    lcd_command(0x80); // move the cursor to the start of line 1
    lcd_puts("HELLO FPGA");
  }

  while (1) {
    if (UART_STAT_REG & UART_RX_VALID) {
      if ((unsigned char) UART_RX_REG == 'T') uart_fifo_test();
    }

    uart_puts("I2C ");
    if (lcd_address >= 0) {
      uart_hex8((unsigned char) lcd_address);
    } else {
      uart_puts("NACK");
    }
    uart_puts("\r\n");
    delay_cycles(27000000);
  }
}
