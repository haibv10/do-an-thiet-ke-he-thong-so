#define GPIO_BASE     0x40000000
#define UART_BASE     0x50000000
#define I2C_BASE      0x60000000
#define SPI_BASE      0x70000000

#define LED_REG       (*((volatile unsigned int *) GPIO_BASE))
#define UART_TX_REG   (*((volatile unsigned int *) UART_BASE))
#define UART_STAT_REG (*((volatile unsigned int *) (UART_BASE + 4)))
#define UART_RX_REG   (*((volatile unsigned int *) (UART_BASE + 8)))
#define I2C_FRAME_REG (*((volatile unsigned int *) I2C_BASE))
#define I2C_STAT_REG  (*((volatile unsigned int *) (I2C_BASE + 4)))
#define I2C_DATA_REG  (*((volatile unsigned int *) (I2C_BASE + 8)))
#define SPI_DATA_REG  (*((volatile unsigned int *) SPI_BASE))
#define SPI_STAT_REG  (*((volatile unsigned int *) (SPI_BASE + 4)))
#define SPI_CTRL_REG  (*((volatile unsigned int *) (SPI_BASE + 8)))

#define UART_TX_BUSY  0x01
#define UART_RX_VALID 0x02
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

// Long enough for twelve characters at 115200 baud with room to spare, short
// enough that a truncated line does not stop the clock.
#define UART_SET_TIMEOUT 3000000U

#define SPI_BUSY      0x01
#define SPI_CS_N      0x01
#define SPI_DC        0x02
#define SPI_RST_N     0x04

#define TFT_WIDTH     128
#define TFT_HEIGHT    160

// D7 MY and D6 MX mirror the row and column order, D3 selects BGR over RGB
// subpixel order. Clearing MY and MX together turns the image through 180
// degrees, which is what puts the panel the right way up on this board; the
// bars come out red, green and blue in that order, so D3 stays set. Setting
// D5 MV as well would give landscape, but the panel is then 160 by 128 and the
// layout coordinates have to move with it.
#define TFT_MADCTL    0x08

#define TFT_RED       0xf800
#define TFT_GREEN     0x07e0
#define TFT_BLUE      0x001f
#define TFT_WHITE     0xffff
#define TFT_BLACK     0x0000

// RGB565, five bits of red and blue and six of green. One hue at three
// brightnesses, over a neutral bar. Blue was tried first and reads badly: it
// is the channel the eye is least sensitive to and the dimmest subpixel on the
// panel, so small blue text on black washes out. Amber is what instrument
// panels use for the same reason.
#define TFT_BAR       0x18e3   // charcoal, the bar behind the title
#define TFT_BRIGHT    0xfd80   // amber, the hours and minutes
#define TFT_MID       0xc400   // amber at two thirds, the seconds and the date
#define TFT_DIM       0x7280   // amber at a third, the weekday

#define HEADER_HEIGHT 20
#define FOOTER_TOP    152

#define FONT_FIRST    0x20
#define FONT_LAST     0x7e
#define FONT_SIZE     8

// Lives in .rodata, so reading it exercises the ROM window at region 0x0.
static const char hex_digits[] = "0123456789ABCDEF";


// 8x8 glyphs for ASCII 32 through 126, lifted from the console font at
// /usr/share/consolefonts/Uni2-VGA8.psf.gz, whose first 128 entries follow
// ASCII. Each byte is one row, most significant bit leftmost.
static const unsigned char font8x8[] = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  /*   */
  0x18, 0x3c, 0x3c, 0x18, 0x18, 0x00, 0x18, 0x00,  /* ! */
  0x66, 0x66, 0x24, 0x00, 0x00, 0x00, 0x00, 0x00,  /* \" */
  0x6c, 0x6c, 0xfe, 0x6c, 0xfe, 0x6c, 0x6c, 0x00,  /* # */
  0x18, 0x3e, 0x60, 0x3c, 0x06, 0x7c, 0x18, 0x00,  /* $ */
  0x00, 0xc6, 0xcc, 0x18, 0x30, 0x66, 0xc6, 0x00,  /* % */
  0x38, 0x6c, 0x38, 0x76, 0xdc, 0xcc, 0x76, 0x00,  /* & */
  0x18, 0x18, 0x30, 0x00, 0x00, 0x00, 0x00, 0x00,  /* ' */
  0x0c, 0x18, 0x30, 0x30, 0x30, 0x18, 0x0c, 0x00,  /* ( */
  0x30, 0x18, 0x0c, 0x0c, 0x0c, 0x18, 0x30, 0x00,  /* ) */
  0x00, 0x66, 0x3c, 0xff, 0x3c, 0x66, 0x00, 0x00,  /* * */
  0x00, 0x18, 0x18, 0x7e, 0x18, 0x18, 0x00, 0x00,  /* + */
  0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x30,  /* , */
  0x00, 0x00, 0x00, 0x7e, 0x00, 0x00, 0x00, 0x00,  /* - */
  0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x00,  /* . */
  0x06, 0x0c, 0x18, 0x30, 0x60, 0xc0, 0x80, 0x00,  /* / */
  0x38, 0x6c, 0xc6, 0xd6, 0xc6, 0x6c, 0x38, 0x00,  /* 0 */
  0x18, 0x38, 0x18, 0x18, 0x18, 0x18, 0x7e, 0x00,  /* 1 */
  0x7c, 0xc6, 0x06, 0x1c, 0x30, 0x66, 0xfe, 0x00,  /* 2 */
  0x7c, 0xc6, 0x06, 0x3c, 0x06, 0xc6, 0x7c, 0x00,  /* 3 */
  0x1c, 0x3c, 0x6c, 0xcc, 0xfe, 0x0c, 0x1e, 0x00,  /* 4 */
  0xfe, 0xc0, 0xc0, 0xfc, 0x06, 0xc6, 0x7c, 0x00,  /* 5 */
  0x38, 0x60, 0xc0, 0xfc, 0xc6, 0xc6, 0x7c, 0x00,  /* 6 */
  0xfe, 0xc6, 0x0c, 0x18, 0x30, 0x30, 0x30, 0x00,  /* 7 */
  0x7c, 0xc6, 0xc6, 0x7c, 0xc6, 0xc6, 0x7c, 0x00,  /* 8 */
  0x7c, 0xc6, 0xc6, 0x7e, 0x06, 0x0c, 0x78, 0x00,  /* 9 */
  0x00, 0x18, 0x18, 0x00, 0x00, 0x18, 0x18, 0x00,  /* : */
  0x00, 0x18, 0x18, 0x00, 0x00, 0x18, 0x18, 0x30,  /* ; */
  0x06, 0x0c, 0x18, 0x30, 0x18, 0x0c, 0x06, 0x00,  /* < */
  0x00, 0x00, 0x7e, 0x00, 0x00, 0x7e, 0x00, 0x00,  /* = */
  0x60, 0x30, 0x18, 0x0c, 0x18, 0x30, 0x60, 0x00,  /* > */
  0x7c, 0xc6, 0x0c, 0x18, 0x18, 0x00, 0x18, 0x00,  /* ? */
  0x7c, 0xc6, 0xde, 0xde, 0xde, 0xc0, 0x78, 0x00,  /* @ */
  0x38, 0x6c, 0xc6, 0xfe, 0xc6, 0xc6, 0xc6, 0x00,  /* A */
  0xfc, 0x66, 0x66, 0x7c, 0x66, 0x66, 0xfc, 0x00,  /* B */
  0x3c, 0x66, 0xc0, 0xc0, 0xc0, 0x66, 0x3c, 0x00,  /* C */
  0xf8, 0x6c, 0x66, 0x66, 0x66, 0x6c, 0xf8, 0x00,  /* D */
  0xfe, 0x62, 0x68, 0x78, 0x68, 0x62, 0xfe, 0x00,  /* E */
  0xfe, 0x62, 0x68, 0x78, 0x68, 0x60, 0xf0, 0x00,  /* F */
  0x3c, 0x66, 0xc0, 0xc0, 0xce, 0x66, 0x3a, 0x00,  /* G */
  0xc6, 0xc6, 0xc6, 0xfe, 0xc6, 0xc6, 0xc6, 0x00,  /* H */
  0x3c, 0x18, 0x18, 0x18, 0x18, 0x18, 0x3c, 0x00,  /* I */
  0x1e, 0x0c, 0x0c, 0x0c, 0xcc, 0xcc, 0x78, 0x00,  /* J */
  0xe6, 0x66, 0x6c, 0x78, 0x6c, 0x66, 0xe6, 0x00,  /* K */
  0xf0, 0x60, 0x60, 0x60, 0x62, 0x66, 0xfe, 0x00,  /* L */
  0xc6, 0xee, 0xfe, 0xfe, 0xd6, 0xc6, 0xc6, 0x00,  /* M */
  0xc6, 0xe6, 0xf6, 0xde, 0xce, 0xc6, 0xc6, 0x00,  /* N */
  0x7c, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x7c, 0x00,  /* O */
  0xfc, 0x66, 0x66, 0x7c, 0x60, 0x60, 0xf0, 0x00,  /* P */
  0x7c, 0xc6, 0xc6, 0xc6, 0xc6, 0xce, 0x7c, 0x0e,  /* Q */
  0xfc, 0x66, 0x66, 0x7c, 0x6c, 0x66, 0xe6, 0x00,  /* R */
  0x3c, 0x66, 0x30, 0x18, 0x0c, 0x66, 0x3c, 0x00,  /* S */
  0x7e, 0x7e, 0x5a, 0x18, 0x18, 0x18, 0x3c, 0x00,  /* T */
  0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x7c, 0x00,  /* U */
  0xc6, 0xc6, 0xc6, 0xc6, 0xc6, 0x6c, 0x38, 0x00,  /* V */
  0xc6, 0xc6, 0xc6, 0xd6, 0xd6, 0xfe, 0x6c, 0x00,  /* W */
  0xc6, 0xc6, 0x6c, 0x38, 0x6c, 0xc6, 0xc6, 0x00,  /* X */
  0x66, 0x66, 0x66, 0x3c, 0x18, 0x18, 0x3c, 0x00,  /* Y */
  0xfe, 0xc6, 0x8c, 0x18, 0x32, 0x66, 0xfe, 0x00,  /* Z */
  0x3c, 0x30, 0x30, 0x30, 0x30, 0x30, 0x3c, 0x00,  /* [ */
  0xc0, 0x60, 0x30, 0x18, 0x0c, 0x06, 0x02, 0x00,  /* \\ */
  0x3c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x3c, 0x00,  /* ] */
  0x10, 0x38, 0x6c, 0xc6, 0x00, 0x00, 0x00, 0x00,  /* ^ */
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff,  /* _ */
  0x30, 0x18, 0x0c, 0x00, 0x00, 0x00, 0x00, 0x00,  /* ` */
  0x00, 0x00, 0x78, 0x0c, 0x7c, 0xcc, 0x76, 0x00,  /* a */
  0xe0, 0x60, 0x7c, 0x66, 0x66, 0x66, 0xdc, 0x00,  /* b */
  0x00, 0x00, 0x7c, 0xc6, 0xc0, 0xc6, 0x7c, 0x00,  /* c */
  0x1c, 0x0c, 0x7c, 0xcc, 0xcc, 0xcc, 0x76, 0x00,  /* d */
  0x00, 0x00, 0x7c, 0xc6, 0xfe, 0xc0, 0x7c, 0x00,  /* e */
  0x3c, 0x66, 0x60, 0xf8, 0x60, 0x60, 0xf0, 0x00,  /* f */
  0x00, 0x00, 0x76, 0xcc, 0xcc, 0x7c, 0x0c, 0xf8,  /* g */
  0xe0, 0x60, 0x6c, 0x76, 0x66, 0x66, 0xe6, 0x00,  /* h */
  0x18, 0x00, 0x38, 0x18, 0x18, 0x18, 0x3c, 0x00,  /* i */
  0x06, 0x00, 0x06, 0x06, 0x06, 0x66, 0x66, 0x3c,  /* j */
  0xe0, 0x60, 0x66, 0x6c, 0x78, 0x6c, 0xe6, 0x00,  /* k */
  0x38, 0x18, 0x18, 0x18, 0x18, 0x18, 0x3c, 0x00,  /* l */
  0x00, 0x00, 0xec, 0xfe, 0xd6, 0xd6, 0xd6, 0x00,  /* m */
  0x00, 0x00, 0xdc, 0x66, 0x66, 0x66, 0x66, 0x00,  /* n */
  0x00, 0x00, 0x7c, 0xc6, 0xc6, 0xc6, 0x7c, 0x00,  /* o */
  0x00, 0x00, 0xdc, 0x66, 0x66, 0x7c, 0x60, 0xf0,  /* p */
  0x00, 0x00, 0x76, 0xcc, 0xcc, 0x7c, 0x0c, 0x1e,  /* q */
  0x00, 0x00, 0xdc, 0x76, 0x60, 0x60, 0xf0, 0x00,  /* r */
  0x00, 0x00, 0x7e, 0xc0, 0x7c, 0x06, 0xfc, 0x00,  /* s */
  0x30, 0x30, 0xfc, 0x30, 0x30, 0x36, 0x1c, 0x00,  /* t */
  0x00, 0x00, 0xcc, 0xcc, 0xcc, 0xcc, 0x76, 0x00,  /* u */
  0x00, 0x00, 0xc6, 0xc6, 0xc6, 0x6c, 0x38, 0x00,  /* v */
  0x00, 0x00, 0xc6, 0xd6, 0xd6, 0xfe, 0x6c, 0x00,  /* w */
  0x00, 0x00, 0xc6, 0x6c, 0x38, 0x6c, 0xc6, 0x00,  /* x */
  0x00, 0x00, 0xc6, 0xc6, 0xc6, 0x7e, 0x06, 0xfc,  /* y */
  0x00, 0x00, 0x7e, 0x4c, 0x18, 0x32, 0x7e, 0x00,  /* z */
  0x0e, 0x18, 0x18, 0x70, 0x18, 0x18, 0x0e, 0x00,  /* { */
  0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x00,  /* | */
  0x70, 0x18, 0x18, 0x0e, 0x18, 0x18, 0x70, 0x00,  /* } */
  0x76, 0xdc, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  /* ~ */
};

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

// delay_loop counts iterations, not clocks. One iteration costs its five
// instructions plus two cycles for the taken branch and one for each load-use
// stall, which is nine, and nine is what the board measured as the gap between
// RTC lines. Changing optimisation level changes this number: the
// six-instruction loop -Os emits costs twelve.
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

// Eight by eight like the font, so they go through the same drawing path and
// need no code of their own beyond the table.
static const unsigned char icon_clock[8] = {
  0x3c, 0x42, 0x89, 0x89, 0x8e, 0x81, 0x42, 0x3c
};
static const unsigned char icon_calendar[8] = {
  0x42, 0xff, 0x81, 0xa9, 0x81, 0xa9, 0x81, 0xff
};

// One glyph occupies its own address window, so a redraw touches 64 pixels
// rather than a whole line. Both colours are written, which lets a character
// replace the one under it without clearing first.
// A scale of n repeats every glyph pixel n times across and n times down, so
// one font serves both sizes and the ROM holds one copy of it.
static void tft_draw_glyph(unsigned char x, unsigned char y,
                           const unsigned char *glyph,
                           unsigned short fg, unsigned short bg,
                           unsigned int scale) {
  unsigned int row;
  unsigned int column;
  unsigned int down;
  unsigned int across;
  unsigned int span = FONT_SIZE * scale;
  unsigned char bits;
  unsigned short colour;

  tft_set_window(x, y, (unsigned char) (x + span - 1),
                 (unsigned char) (y + span - 1));
  tft_control(SPI_RST_N | SPI_DC);

  for (row = 0; row < FONT_SIZE; row++) {
    bits = glyph[row];
    for (down = 0; down < scale; down++) {
      for (column = 0; column < FONT_SIZE; column++) {
        colour = (bits & (0x80 >> column)) ? fg : bg;
        for (across = 0; across < scale; across++) {
          spi_write((unsigned char) (colour >> 8));
          spi_write((unsigned char) colour);
        }
      }
    }
  }

  tft_deselect();
}

static void tft_draw_char(unsigned char x, unsigned char y, char value,
                          unsigned short fg, unsigned short bg,
                          unsigned int scale) {
  if (value < FONT_FIRST || value > FONT_LAST) value = ' ';
  tft_draw_glyph(x, y, &font8x8[(unsigned int) (value - FONT_FIRST) * FONT_SIZE],
                 fg, bg, scale);
}

static void tft_draw_string(unsigned char x, unsigned char y, const char *text,
                            unsigned short fg, unsigned short bg,
                            unsigned int scale) {
  while (*text != '\0') {
    tft_draw_char(x, y, *text, fg, bg, scale);
    x = (unsigned char) (x + FONT_SIZE * scale);
    text++;
  }
}

// Two hex digits of a BCD byte are its two decimal digits.
static void tft_draw_bcd(unsigned char x, unsigned char y, unsigned char value,
                         unsigned short fg, unsigned short bg,
                         unsigned int scale) {
  tft_draw_char(x, y, hex_digits[(value >> 4) & 0x0f], fg, bg, scale);
  tft_draw_char((unsigned char) (x + FONT_SIZE * scale), y,
                hex_digits[value & 0x0f], fg, bg, scale);
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

// Days before the first of each month in a non-leap year.
static const unsigned short month_days[12] =
  {0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334};

// Year counts from 2000, where every year divisible by four is a leap year;
// 2100 is not, and is outside the range the two digit year can reach. The only
// division is by four, which is a shift, and the remainder by seven is taken
// by subtraction, since the core has neither instruction.
static unsigned int weekday_of(unsigned int year, unsigned int month,
                               unsigned int date) {
  unsigned int days;

  days = year * 365u + ((year + 3u) >> 2) + month_days[month - 1u] + (date - 1u);
  if ((year & 3u) == 0u && month > 2u) days += 1u;

  days += 6u;                        // 2000-01-01 was a Saturday
  while (days >= 7u) days -= 7u;

  return days + 1u;                  // 1 is Sunday through 7 is Saturday
}

// Division and modulo would pull in a libcall the core cannot satisfy, so the
// tens digit is counted off by subtraction. Correct across 0 to 99, which is
// the range every field here occupies.
static unsigned char bcd_of(unsigned int value) {
  unsigned int tens = 0;

  while (value >= 10u) {
    value -= 10u;
    tens++;
  }

  return (unsigned char) ((tens << 4) | value);
}

// The registers hold BCD, so printing a byte as two hex digits already reads
// as the decimal value and needs no conversion.
static void uart_bcd(unsigned char value) {
  uart_putc(hex_digits[(value >> 4) & 0x0f]);
  uart_putc(hex_digits[value & 0x0f]);
}

static int ds3231_write(unsigned char first, const unsigned char *buffer,
                        unsigned int count) {
  unsigned int index;
  unsigned int flags;

  if (!i2c_frame(I2C_START | DS3231_WRITE)) {
    i2c_release();
    return 0;
  }
  if (!i2c_frame(first)) {
    i2c_release();
    return 0;
  }

  for (index = 0; index < count; index++) {
    flags = buffer[index];
    if (index == count - 1) flags |= I2C_STOP;
    if (!i2c_frame(flags)) {
      i2c_release();
      return 0;
    }
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

// Waits for one character rather than returning what is not there yet. The
// caller has already seen the command byte, so the rest of the line is on its
// way; the bound exists so a truncated line cannot hang the clock.
static int uart_getc(unsigned char *value) {
  unsigned int timeout = UART_SET_TIMEOUT;

  while (timeout != 0) {
    if (UART_STAT_REG & UART_RX_VALID) {
      *value = (unsigned char) UART_RX_REG;
      return 1;
    }
    timeout--;
  }

  return 0;
}

// The host knows what time it is and this board does not. Twelve digits,
// YYMMDDhhmmss, arrive behind the command byte and go straight into the
// registers. An earlier version used __DATE__ and __TIME__, which set the
// clock to the moment the compiler ran rather than the moment the command was
// given, and ran minutes slow by the time the image had been built, programmed
// and triggered.
static void ds3231_set_from_uart(void) {
  unsigned char digits[12];
  unsigned char time[DS3231_TIME_BYTES];
  unsigned char status;
  unsigned int index;
  unsigned int field[6];

  for (index = 0; index < 12; index++) {
    if (!uart_getc(&digits[index])) {
      uart_puts("RTC SET SHORT\r\n");
      return;
    }
    if (digits[index] < '0' || digits[index] > '9') {
      uart_puts("RTC SET BAD\r\n");
      return;
    }
  }

  // year, month, date, hours, minutes, seconds
  for (index = 0; index < 6; index++) {
    field[index] = (unsigned int) (digits[index * 2] - '0') * 10u
                 + (unsigned int) (digits[index * 2 + 1] - '0');
  }

  if (field[1] < 1 || field[1] > 12 || field[2] < 1 || field[2] > 31 ||
      field[3] > 23 || field[4] > 59 || field[5] > 59) {
    uart_puts("RTC SET RANGE\r\n");
    return;
  }

  time[0] = bcd_of(field[5]);
  time[1] = bcd_of(field[4]);
  time[2] = bcd_of(field[3]);                    // 24 hour: bit 6 clear
  time[3] = (unsigned char) weekday_of(field[0], field[1], field[2]);
  time[4] = bcd_of(field[2]);
  time[5] = bcd_of(field[1]);
  time[6] = bcd_of(field[0]);

  if (!ds3231_write(0x00, time, DS3231_TIME_BYTES)) {
    uart_puts("RTC SET FAIL\r\n");
    return;
  }

  // Read back rather than write a whole byte: bit 3 enables the 32 kHz output
  // and the alarm flags live here too. Clearing the stop flag is what marks
  // the registers as trustworthy again, so it happens only after a real time
  // has been written over them.
  if (!ds3231_read(DS3231_STATUS, &status, 1)) {
    uart_puts("RTC SET FAIL\r\n");
    return;
  }
  status &= (unsigned char) ~DS3231_OSF;
  if (!ds3231_write(DS3231_STATUS, &status, 1)) {
    uart_puts("RTC SET FAIL\r\n");
    return;
  }

  uart_puts("RTC SET OK\r\n");
}

// A BCD byte has two decimal digits, so neither nibble may exceed nine. A part
// that has never been set, or one written by firmware that got the conversion
// wrong, reads back values that fail this and would otherwise be drawn as if
// they were real.
static int bcd_is_valid(unsigned char value) {
  return ((value & 0x0f) <= 9) && (((value >> 4) & 0x0f) <= 9);
}

static int ds3231_time_is_valid(const unsigned char *time) {
  if (!bcd_is_valid(time[0] & 0x7f)) return 0;   // seconds
  if (!bcd_is_valid(time[1] & 0x7f)) return 0;   // minutes
  if (!bcd_is_valid(time[2] & 0x3f)) return 0;   // hours
  if (!bcd_is_valid(time[4] & 0x3f)) return 0;   // date
  if (!bcd_is_valid(time[5] & 0x1f)) return 0;   // month
  if (!bcd_is_valid(time[6])) return 0;          // year

  // A month or a date of zero is the other way the registers say they have
  // never been given a real time.
  if ((time[5] & 0x1f) == 0 || (time[4] & 0x3f) == 0) return 0;

  return 1;
}

// Reading from register 0 snapshots the time into a second bank inside the
// part, so the seven bytes cannot straddle a tick.
static void ds3231_print(const unsigned char *time) {
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

// Drawn once: the bar, the rule under it and the matching foot. Nothing in
// them changes with the time, so they stay out of the per-second redraw.
static void tft_draw_frame(void) {
  tft_fill_rect(0, 0, TFT_WIDTH - 1, TFT_HEIGHT - 1, TFT_BLACK);
  tft_fill_rect(0, 0, TFT_WIDTH - 1, HEADER_HEIGHT - 1, TFT_BAR);
  tft_fill_rect(0, HEADER_HEIGHT, TFT_WIDTH - 1, HEADER_HEIGHT, TFT_MID);
  tft_fill_rect(0, FOOTER_TOP, TFT_WIDTH - 1, TFT_HEIGHT - 1, TFT_BAR);

  // Icon, a gap, then twelve glyphs: 112 pixels with eight either side.
  tft_draw_glyph(8, 6, icon_clock, TFT_MID, TFT_BAR, 1);
  tft_draw_string(24, 6, "TANG NANO 9K", TFT_MID, TFT_BAR, 1);
}

// Two lines and nothing else. The weekday was drawn here for a while and came
// out as a second way of saying what the date already says, so it went; the
// register behind it is still written correctly, it is simply not shown.
//
// The time carries the screen at double size, where eight glyphs of sixteen
// pixels fill the width exactly. The date sits under it at single size.
// Drawn in place of the time when the registers do not hold valid BCD. Showing
// the digits anyway would present a fault as a reading.
static void tft_show_unset(void) {
  tft_draw_string(0, 66, "--:--:--", TFT_DIM, TFT_BLACK, 2);
  tft_draw_string(24, 98, " NOT SET  ", TFT_MID, TFT_BLACK, 1);
}

static void tft_show_time(const unsigned char *time) {
  // Hours and minutes carry the reading; the seconds step back a shade so the
  // eye settles on the part that matters.
  tft_draw_bcd(0, 66, time[2] & 0x3f, TFT_BRIGHT, TFT_BLACK, 2);
  tft_draw_char(32, 66, ':', TFT_MID, TFT_BLACK, 2);
  tft_draw_bcd(48, 66, time[1] & 0x7f, TFT_BRIGHT, TFT_BLACK, 2);
  tft_draw_char(80, 66, ':', TFT_MID, TFT_BLACK, 2);
  tft_draw_bcd(96, 66, time[0] & 0x7f, TFT_MID, TFT_BLACK, 2);

  // Icon, a gap, then ten glyphs of date: 96 pixels with sixteen either side.
  tft_draw_glyph(16, 98, icon_calendar, TFT_DIM, TFT_BLACK, 1);
  tft_draw_string(32, 98, "20", TFT_MID, TFT_BLACK, 1);
  tft_draw_bcd(48, 98, time[6], TFT_MID, TFT_BLACK, 1);
  tft_draw_char(64, 98, '-', TFT_DIM, TFT_BLACK, 1);
  tft_draw_bcd(72, 98, time[5] & 0x1f, TFT_MID, TFT_BLACK, 1);
  tft_draw_char(88, 98, '-', TFT_DIM, TFT_BLACK, 1);
  tft_draw_bcd(96, 98, time[4] & 0x3f, TFT_MID, TFT_BLACK, 1);
}

int main(void) {
  unsigned char time[DS3231_TIME_BYTES];
  unsigned char last_second = 0xff;
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

  // The bars stay up long enough to be read, then the panel becomes the clock.
  delay_loop(DELAY_MS(1000));
  tft_draw_frame();

  while (1) {
    if (UART_STAT_REG & UART_RX_VALID) {
      if ((unsigned char) UART_RX_REG == 'W') ds3231_set_from_uart();
    }

    if (!ds3231_read(0x00, time, DS3231_TIME_BYTES)) {
      uart_puts("RTC NACK\r\n");
      delay_loop(DELAY_MS(1000));
      continue;
    }

    // Redrawn when the seconds byte changes, not on a timer. A timer drifts
    // against the clock and eventually skips a second, which an earlier
    // capture showed as 00:14:52 followed by 00:14:54.
    if (time[0] != last_second) {
      last_second = time[0];
      if (ds3231_time_is_valid(time)) {
        ds3231_print(time);
        tft_show_time(time);
      } else {
        uart_puts("RTC INVALID\r\n");
        tft_show_unset();
      }
      led = led ^ 1u;
      LED_REG = led;
    }

    delay_loop(DELAY_MS(50));
  }
}
