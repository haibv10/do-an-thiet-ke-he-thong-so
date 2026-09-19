# MMIO register map

The address decoder compares only `addr[31:28]` to select a device, which keeps
decoding cheap — no 32-bit comparators. Inside each peripheral the low address
bits act as a register offset.

| `addr[31:28]` | Base | Device | Module |
|---|---|---|---|
| `0x2` | `0x20000000` | Data memory, 4 KB | `dmem.v` |
| `0x4` | `0x40000000` | GPIO | `gpio.v` |
| `0x5` | `0x50000000` | UART | `uart_mmio.v` |
| `0x6` | `0x60000000` | I2C | `i2c_mmio.v` |

Region `0x0` is **not** in the decoder. The fetch stage reads `imem.v` directly,
so any `lw` aimed at ROM returns `0`. This is why `.rodata` is unreachable from
firmware — see [Known limitations](#known-limitations).

---

## GPIO — `0x40000000`

Decoded on `a[7:0]`.

| Offset | Access | Bits | Function |
|---|---|---|---|
| `0x00` | Write | `[0]` | LED output |
| `0x00` | Read | `[0]` | Reads back the value last written |
| `0x04` | Read | `[0]` | State of button S1 |

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
| `0x04` | Read | `[1]` | `rx_valid` — an unread byte is waiting |
| `0x08` | Read | `[7:0]` | Received byte; the read clears `rx_valid` |

Correct usage:

```c
while (UART_STAT_REG & UART_TX_BUSY) { }   /* wait for idle */
UART_TX_REG = value;                       /* then write */
```

A write while `tx_busy` is 1 is dropped silently — there is no error flag.

---

## I2C — `0x60000000`

The frame FSM lives in the CPU 27 MHz clock domain and advances on a 1 MHz tick
produced by `clock_enable_divider`.

Decoded on **`a[3:2]` only**, so the registers alias every 16 bytes:
`0x60000010` also hits the register at offset `0x00`.

| Offset | Access | Bits | Function |
|---|---|---|---|
| `0x00` | Write | `[7:0]` | Byte to send to the PCF8574 |
| `0x00` | Write | `[8]` | `cmd_data` — `0` selects an LCD command, `1` display data |
| `0x04` | Read | `[0]` | `busy` — a transaction is in flight |
| `0x04` | Read | `[1]` | `ack` — ACK result of the transaction that just finished |
| `0x08` | Write | `[6:0]` | 7-bit slave address, defaults to `0x27` |

Both write registers are **only sampled while `busy` is 0**. Writing during a
transaction is dropped silently, so wait first:

```c
lcd_wait_ready();          /* wait for busy = 0 FIRST */
LCD_ADDR_REG = address;    /* only then set the address */
lcd_command(0x00);
```

---

## Known limitations

**ROM is not readable over the data bus.** The decoder has no region `0x0`, so
string literals and lookup tables in `.rodata` all read back as `0`. The current
firmware generates characters inline instead of using string literals. Evidence:
`logs/07-fault-rodata-null.log`.

**`startup.s` does not initialise `.data` or `.bss`.** The linker script places
both in RAM but nothing copies `.data` from its load address and nothing zeroes
`.bss`. The current firmware uses no globals, so this has not yet surfaced.

**AUIPC is missing.** Opcode `0010111` is absent from the decoder and decodes
silently to a NOP. This is the third independent reason globals and strings are
unusable.

**UART RX has no FIFO.** The receiver holds exactly one byte; a new byte
overwrites the previous one if firmware has not read it. There is no overrun
flag.

**Hex formatting is incomplete.** `uart_hex()` in `sw/main.c` avoids the `A`–`F`
branch because the pipeline mis-executes it, so nibbles above `9` print as
punctuation. Evidence: `logs/08-fault-hex-branch.log`.
