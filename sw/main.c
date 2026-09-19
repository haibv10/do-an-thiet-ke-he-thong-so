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
#define LCD_BUSY       0x01
#define LCD_ACK        0x02

static void delay_cycles(unsigned int cycles) {
  volatile unsigned int index;

  for (index = 0; index < cycles; index++) {
  }
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

static void uart_putc(unsigned char value) {
  while (UART_STAT_REG & UART_TX_BUSY) {
  }
  UART_TX_REG = value;
}

static void uart_hex(unsigned char value) {
  unsigned char high = value >> 4;
  unsigned char low = value & 0x0f;

  // The scanner only reports 0x20-0x27 and 0x38-0x3F.
  uart_putc('0' + high);
  uart_putc('0' + low);
}

static void lcd_init(void) {
  delay_cycles(1080000);
  lcd_command(0x02);
  lcd_command(0x28);
  lcd_command(0x0C);
  lcd_command(0x06);
  lcd_command(0x01);
}

static int lcd_probe(unsigned char address) {
  LCD_ADDR_REG = address;
  lcd_command(0x00);
  lcd_wait_ready();
  return (LCD_STAT_REG & LCD_ACK) != 0;
}

static int lcd_find_address(void) {
  unsigned char address;

  for (address = 0x20; address <= 0x27; address++) {
    if (lcd_probe(address)) return address;
  }
  for (address = 0x38; address <= 0x3f; address++) {
    if (lcd_probe(address)) return address;
  }
  return -1;
}

int main() {
  int lcd_address;

  LED_REG = 0;
  uart_putc('B'); uart_putc('O'); uart_putc('O'); uart_putc('T');
  uart_putc('\r'); uart_putc('\n');
  delay_cycles(1080000);
  lcd_address = lcd_find_address();
  if (lcd_address >= 0) {
    lcd_init();
    lcd_command(0x80);
    lcd_data('H'); lcd_data('E'); lcd_data('L'); lcd_data('L'); lcd_data('O');
    lcd_data(' '); lcd_data('F'); lcd_data('P'); lcd_data('G'); lcd_data('A');
  }

  while (1) {
    uart_putc('I'); uart_putc('2'); uart_putc('C'); uart_putc(' ');
    if (lcd_address >= 0) {
      uart_hex((unsigned char)lcd_address);
    } else {
      uart_putc('N'); uart_putc('A'); uart_putc('C'); uart_putc('K');
    }
    uart_putc('\r'); uart_putc('\n');
    delay_cycles(27000000);
  }
}
