#define GPIO_BASE     0x40000000
#define UART_BASE     0x50000000
#define I2C_BASE      0x60000000
#define SPI_BASE      0x70000000

#define LED_REG       (*((volatile unsigned int *) GPIO_BASE))
#define UART_TX_REG   (*((volatile unsigned int *) UART_BASE))
#define UART_STAT_REG (*((volatile unsigned int *) (UART_BASE + 4)))
#define UART_RX_REG   (*((volatile unsigned int *) (UART_BASE + 8)))
#define UART_CTRL_REG (*((volatile unsigned int *) (UART_BASE + 12)))
#define I2C_FRAME_REG (*((volatile unsigned int *) I2C_BASE))
#define I2C_STAT_REG  (*((volatile unsigned int *) (I2C_BASE + 4)))
#define I2C_DATA_REG  (*((volatile unsigned int *) (I2C_BASE + 8)))
#define SPI_DATA_REG  (*((volatile unsigned int *) SPI_BASE))
#define SPI_STAT_REG  (*((volatile unsigned int *) (SPI_BASE + 4)))
#define SPI_CTRL_REG  (*((volatile unsigned int *) (SPI_BASE + 8)))

#define UART_TX_BUSY  0x01
#define UART_RX_VALID 0x02
#define UART_RX_OVERRUN 0x04
#define UART_RX_LEVEL_MASK 0xf8
#define UART_CTRL_CLEAR_OVERRUN 0x01
#define I2C_BUSY      0x01
#define I2C_ACK       0x02
#define I2C_START     0x100
#define I2C_STOP      0x200
#define I2C_READ      0x400
#define I2C_NACK      0x800

// Fixed by the part: there are no address straps to scan.
#define DS3231_WRITE  0xd0
#define DS3231_READ   0xd1
#define DS3231_TIME_BYTES 7
#define DS3231_STATUS 0x0f
#define DS3231_OSF    0x80

#define SPI_BUSY      0x01
#define SPI_CS_N      0x01
#define SPI_DC        0x02
#define SPI_RST_N     0x04

#define TFT_WIDTH     128
#define TFT_HEIGHT    160

// D7 MY and D6 MX set the scan direction, D3 selects BGR over RGB subpixel
// order. Panels sold on identical breakouts differ in subpixel order, so if
// the first colour bar comes up blue instead of red, clear D3 to make this
// 0xc0. Nothing else in the driver changes.
#define TFT_MADCTL    0xc8

#define TFT_RED       0xf800
#define TFT_GREEN     0x07e0
#define TFT_BLUE      0x001f

#ifndef UART_FIFO_TEST_TIMEOUT
#define UART_FIFO_TEST_TIMEOUT 270000U
#endif

// Lives in .rodata, so reading it exercises the ROM window at region 0x0.
static const char hex_digits[] = "0123456789ABCDEF";

// Both markers have external linkage so the compiler must emit the objects and
// load them back, instead of folding the initialiser into an immediate.
unsigned int data_marker = 0x5a5a5a5a;  // .data, copied out of ROM by startup.s
unsigned int bss_marker;                // .bss, cleared by startup.s

// The counter is volatile so the loop survives optimisation, which also fixes
// its cost at nine clocks an iteration. Callers pass DELAY_MS rather than a
// raw count.
static void delay_loop(unsigned int iterations) {
  volatile unsigned int index;

  for (index = 0; index < iterations; index++) {
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

// delay_cycles counts loop iterations, not clocks. One volatile iteration
// measures nine clocks on the board, taken from the nine seconds between
// consecutive RTC lines when the loop argument was 27000000.
#define DELAY_MS(ms) ((ms) * 3000U)

static void spi_wait_idle(void) {
  while (SPI_STAT_REG & SPI_BUSY) {
  }
}

static void spi_write(unsigned char value) {
  spi_wait_idle();
  SPI_DATA_REG = value;
}

// The control register moves cs_n and dc, so it must not change while a byte
// is still being shifted.
static void tft_control(unsigned int bits) {
  spi_wait_idle();
  SPI_CTRL_REG = bits;
}

static void tft_command(unsigned char value) {
  tft_control(SPI_RST_N);              // cs_n = 0, dc = 0
  spi_write(value);
}

static void tft_data(unsigned char value) {
  tft_control(SPI_RST_N | SPI_DC);     // cs_n = 0, dc = 1
  spi_write(value);
}

static void tft_deselect(void) {
  tft_control(SPI_RST_N | SPI_CS_N);
}

// The panel comes out of reset held low by the SPI peripheral, so firmware
// owns the release timing rather than racing the configuration load.
static void tft_reset(void) {
  tft_control(SPI_CS_N);               // rst_n = 0, panel in reset
  delay_loop(DELAY_MS(10));
  tft_control(SPI_CS_N | SPI_RST_N);   // release
  delay_loop(DELAY_MS(120));
}

static void tft_init(void) {
  tft_reset();

  tft_command(0x01);                   // SWRESET
  delay_loop(DELAY_MS(120));

  tft_command(0x11);                   // SLPOUT
  delay_loop(DELAY_MS(120));           // datasheet 10.1.11 requires 120 ms

  tft_command(0x3a);                   // COLMOD
  tft_data(0x55);                      // 16-bit/pixel; 10.1.29 note 2 mandates 55h for writes

  tft_command(0x36);                   // MADCTL
  tft_data(TFT_MADCTL);

  tft_command(0x20);                   // INVOFF
  tft_command(0x13);                   // NORON
  tft_command(0x29);                   // DISPON
  delay_loop(DELAY_MS(120));

  tft_deselect();
}

// CASET and RASET take a 16-bit start and end, and the window is inclusive at
// both ends. RAMWR leaves the panel expecting pixel data.
static void tft_set_window(unsigned char x0, unsigned char y0,
                           unsigned char x1, unsigned char y1) {
  tft_command(0x2a);                   // CASET
  tft_data(0x00);
  tft_data(x0);
  tft_data(0x00);
  tft_data(x1);

  tft_command(0x2b);                   // RASET
  tft_data(0x00);
  tft_data(y0);
  tft_data(0x00);
  tft_data(y1);

  tft_command(0x2c);                   // RAMWR
}

static void tft_fill_rect(unsigned char x0, unsigned char y0,
                          unsigned char x1, unsigned char y1,
                          unsigned short colour) {
  unsigned int columns = (unsigned int) (x1 - x0) + 1;
  unsigned int rows = (unsigned int) (y1 - y0) + 1;
  unsigned int row;
  unsigned int column;

  tft_set_window(x0, y0, x1, y1);

  // dc is raised once and left there: the whole burst is pixel data, and
  // moving it per byte would cost a register write per byte for nothing.
  tft_control(SPI_RST_N | SPI_DC);

  // Nested rather than one counter of columns * rows: the core is RV32I with
  // no multiply instruction, and -nostdlib leaves no __mulsi3 to call.
  for (row = 0; row < rows; row++) {
    for (column = 0; column < columns; column++) {
      spi_write((unsigned char) (colour >> 8));
      spi_write((unsigned char) colour);
    }
  }

  tft_deselect();
}

// Three vertical bars, not text. A bar shows byte order, MADCTL scan direction
// and column addressing at once: a swapped subpixel order comes back as the
// wrong colour, and a wrong scan direction as bars running the wrong way.
static void tft_colour_bars(void) {
  unsigned char third = TFT_WIDTH / 3;

  tft_fill_rect(0, 0, third - 1, TFT_HEIGHT - 1, TFT_RED);
  tft_fill_rect(third, 0, (unsigned char) (2 * third - 1), TFT_HEIGHT - 1, TFT_GREEN);
  tft_fill_rect(2 * third, 0, TFT_WIDTH - 1, TFT_HEIGHT - 1, TFT_BLUE);
}

static void i2c_wait(void) {
  while (I2C_STAT_REG & I2C_BUSY) {
  }
}

// One store carries one frame. The acknowledge belongs to the frame that just
// finished, so it is only meaningful once busy has fallen again.
static int i2c_frame(unsigned int value) {
  i2c_wait();
  I2C_FRAME_REG = value;
  i2c_wait();
  return (I2C_STAT_REG & I2C_ACK) != 0;
}

// The peripheral has no stop-only operation, so releasing the bus after a
// refused frame costs one throwaway byte. A slave that did not acknowledge is
// not listening to it.
static void i2c_release(void) {
  i2c_frame(I2C_STOP | 0x00);
}

static int ds3231_read(unsigned char first, unsigned char *buffer,
                       unsigned int count) {
  unsigned int index;
  unsigned int flags;

  // Setting the pointer is a write; the read that follows turns the bus
  // around with a repeated START rather than releasing it.
  if (!i2c_frame(I2C_START | DS3231_WRITE)) {
    i2c_release();
    return 0;
  }
  if (!i2c_frame(first)) {
    i2c_release();
    return 0;
  }
  if (!i2c_frame(I2C_START | DS3231_READ)) {
    i2c_release();
    return 0;
  }

  for (index = 0; index < count; index++) {
    flags = I2C_READ;
    // A slave transmits until it is refused, so the last byte must be.
    if (index == count - 1) flags |= I2C_NACK | I2C_STOP;
    i2c_frame(flags);
    buffer[index] = (unsigned char) I2C_DATA_REG;
  }

  return 1;
}

// Sticky from the first time the part is powered, and cleared only by writing
// zero over it. Set means the oscillator stopped at some point, so whatever
// the timekeeping registers hold has not been counting since it was last set.
static void ds3231_report_osf(void) {
  unsigned char status;

  if (!ds3231_read(DS3231_STATUS, &status, 1)) {
    uart_puts("RTC NACK\r\n");
    return;
  }

  uart_puts((status & DS3231_OSF) ? "RTC OSF SET\r\n" : "RTC OSF CLEAR\r\n");
}

// The registers hold BCD, so printing a byte as two hex digits already reads
// as the decimal value and needs no conversion.
static void uart_bcd(unsigned char value) {
  uart_putc(hex_digits[(value >> 4) & 0x0f]);
  uart_putc(hex_digits[value & 0x0f]);
}

// Reading from register 0 snapshots the time into a second bank inside the
// part, so the seven bytes cannot straddle a tick.
static void ds3231_report(void) {
  unsigned char time[DS3231_TIME_BYTES];

  if (!ds3231_read(0x00, time, DS3231_TIME_BYTES)) {
    uart_puts("RTC NACK\r\n");
    return;
  }

  uart_puts("RTC 20");
  uart_bcd(time[6]);                 // year
  uart_putc('-');
  uart_bcd(time[5] & 0x1f);          // month, without the century bit
  uart_putc('-');
  uart_bcd(time[4] & 0x3f);          // date
  uart_putc(' ');
  uart_bcd(time[2] & 0x3f);          // hours, 24 hour mode
  uart_putc(':');
  uart_bcd(time[1] & 0x7f);          // minutes
  uart_putc(':');
  uart_bcd(time[0] & 0x7f);          // seconds
  uart_puts("\r\n");
}

int main(void) {
  unsigned int led = 0;

  LED_REG = 0;

  // The banner doubles as a startup self-check: the two words only read back as
  // 5A5A5A5A and 00000000 if .data was copied and .bss cleared.
  uart_puts("BOOT ");
  uart_hex32(data_marker);
  uart_putc(' ');
  uart_hex32(bss_marker);
  uart_puts("\r\n");

  uart_puts("TFT INIT\r\n");
  tft_init();
  tft_colour_bars();
  uart_puts("TFT BARS\r\n");

  ds3231_report_osf();

  while (1) {
    if (UART_STAT_REG & UART_RX_VALID) {
      if ((unsigned char) UART_RX_REG == 'T') uart_fifo_test();
    }

    // The line is also the liveness signal: a CPU that hung prints nothing,
    // and the LED says the same without a terminal.
    ds3231_report();
    led = led ^ 1u;
    LED_REG = led;
    delay_loop(DELAY_MS(1000));
  }
}
