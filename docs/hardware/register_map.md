# MMIO register map

The address decoder compares only `addr[31:28]` to select a device, which keeps
decoding cheap — no 32-bit comparators. Inside each peripheral the low address
bits act as a register offset.

| `addr[31:28]` | Base | Device | Module |
|---|---|---|---|
| `0x0` | `0x00000000` | Instruction ROM, 4 KB, read only | `mem_instruction_rom.v` |
| `0x2` | `0x20000000` | Data memory, 4 KB | `mem_data_ram.v` |
| `0x4` | `0x40000000` | GPIO | `gpio_mmio.v` |
| `0x5` | `0x50000000` | UART | `uart_mmio.v` |
| `0x7` | `0x70000000` | SPI/TFT | `spi_mmio.v` |

Region `0x0` answers loads through a second read port on `mem_instruction_rom.v`. It has no
write enable, so a store aimed at ROM is dropped rather than faulting. The
window is what makes `.rodata` and the load image of `.data` reachable from
firmware; `startup.s` uses it to copy `.data` into RAM at boot.

---

## GPIO — `0x40000000`

Decoded on `a[7:0]`.

| Offset | Access | Bits | Function |
|---|---|---|---|
| `0x00` | Write | `[0]` | LED output |
| `0x00` | Read | `[0]` | Reads back the value last written |

The onboard LED on the Tang Nano 9K is **active low**: writing `1` turns it off.
The register still holds exactly what was written, so this is a board convention
rather than a data-path fault.

---

## UART — `0x50000000`

8N1 framing at 115200 baud. At 27 MHz that gives `CLKS_PER_BIT = 234`
(27 000 000 / 115 200 ≈ 234.4, an error of +0.16%).

Decoded on `a[7:0]`.

| Offset | Access | Bits | Function |
|---|---|---|---|
| `0x00` | Write | `[7:0]` | Byte to transmit; only takes effect while `tx_busy` is 0 |
| `0x04` | Read | `[0]` | `tx_busy` — transmitter active |
| `0x04` | Read | `[1]` | `rx_valid` — RX FIFO is not empty |
| `0x04` | Read | `[2]` | `rx_overrun` — sticky when a received byte was dropped because the FIFO was full |
| `0x04` | Read | `[7:3]` | `rx_level` — number of queued bytes, from 0 through 16 |
| `0x08` | Read | `[7:0]` | Oldest received byte; the read pops one byte when the FIFO is not empty |
| `0x0c` | Write | `[0]` | Write one to clear `rx_overrun`; all other bits are ignored |

Correct usage:

```c
while (UART_STAT_REG & UART_TX_BUSY) { }   /* wait for idle */
UART_TX_REG = value;                       /* then write */
```

A write while `tx_busy` is 1 is dropped silently — there is no error flag.

The RX FIFO holds 16 bytes. When full, a new byte is dropped without changing
the queued order and sets `rx_overrun`. Reading `0x08` while empty returns zero
and does not change the FIFO.

---

## SPI — `0x70000000`

SPI mode 0, MSB first, 8 bits per transfer. `CLK_DIV` defaults to 2, so at
27 MHz `sck` runs at 27 000 000 / (2 x 2) = 6.75 MHz, inside the ST7735 write
cycle limit with margin for jumper wiring.

Decoded on `a[7:0]`.

| Offset | Access | Bits | Function |
|---|---|---|---|
| `0x00` | Write | `[7:0]` | Byte to shift out; only takes effect while `busy` is 0 |
| `0x04` | Read | `[0]` | `busy` — a byte is being shifted |
| `0x08` | Write | `[0]` | `cs_n` — chip select, driven straight to the pin, so 0 selects the panel |
| `0x08` | Write | `[1]` | `dc` — 0 selects an ST7735 command, 1 a parameter or pixel data |
| `0x08` | Write | `[2]` | `rst_n` — panel hardware reset, driven straight to the pin |
| `0x08` | Read | `[2:0]` | Reads back `{rst_n, dc, cs_n}` |

The link is write-only. The breakout brings only `SDA` out to its header, so
there is no `miso` port and no receive register; the ST7735 status commands
cannot be read back.

`cs_n`, `dc` and `rst_n` are software state, not sequenced by the shift engine.
One ST7735 command and its parameters form a single chip select frame with `dc`
changing partway through, which the hardware cannot infer from the byte stream.
A control write is accepted at any time, including during a transfer.

Out of reset the panel is deselected (`cs_n` = 1) and **held in reset**
(`rst_n` = 0). Firmware must release it explicitly before the panel answers
anything:

```c
SPI_CTRL_REG = SPI_CS_N | SPI_RST_N;   /* release reset, stay deselected */
/* wait out the ST7735 reset time, then */
SPI_CTRL_REG = SPI_RST_N;              /* cs_n = 0, dc = 0: select, command */
while (SPI_STAT_REG & SPI_BUSY) { }
SPI_DATA_REG = 0x11;                   /* SLPOUT */
```

`busy` stays set for one half period after the last bit, so `cs_n` or `dc`
moved as soon as it clears cannot change while `sck` is still high.

A write to `0x00` while `busy` is 1 is dropped silently — there is no error
flag, exactly as on the UART transmitter.

---

## Known limitations

**UART RX has a finite FIFO.** The receiver holds 16 bytes and reports a
sticky overrun flag, but has no hardware flow control. A stream that remains
faster than software can consume will eventually fill the FIFO and lose bytes.

**The SPI link is write-only.** Nothing can be read back from the panel, so
firmware cannot poll the ST7735 for readiness and must rely on the delays the
datasheet specifies.

**Peripheral registers alias.** Each peripheral decodes only its low address
bits — `a[7:0]` for GPIO, UART and SPI — so `0x40000100` hits the
same LED register as `0x40000000`. Address the documented offsets only.

Defects that have been fixed, including the three that used to make `.rodata`,
globals and hex formatting unusable, are recorded with their evidence in
[../fix_log.md](../fix_log.md).
