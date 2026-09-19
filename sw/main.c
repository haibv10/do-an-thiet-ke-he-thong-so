#define GPIO_BASE     0x40000000
#define UART_BASE     0x50000000
#define I2C_BASE      0x60000000

#define LED_REG       (*((volatile unsigned int *) GPIO_BASE))
#define UART_TX_REG   (*((volatile unsigned int *) UART_BASE))
#define UART_STAT_REG (*((volatile unsigned int *) (UART_BASE + 4)))
#define UART_RX_REG   (*((volatile unsigned int *) (UART_BASE + 8)))
#define LCD_WRITE_REG (*((volatile unsigned int *) I2C_BASE))
#define LCD_STAT_REG  (*((volatile unsigned int *) (I2C_BASE + 4)))
#define LCD_ADDR_REG  (*((volatile unsigned int *) (I2C_BASE + 8)))

#define UART_TX_BUSY  0x01
#define UART_RX_VALID 0x02
#define LCD_BUSY      0x01
#define LCD_ACK       0x02

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

  delay_cycles(1080000);
  lcd_address = lcd_find_address();
  if (lcd_address >= 0) {
    lcd_init();
    lcd_command(0x80); // move the cursor to the start of line 1
    lcd_puts("HELLO FPGA");
  }

  while (1) {
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
