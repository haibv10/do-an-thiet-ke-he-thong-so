# Fix log

A running record of defects found in this repository and what was done about
each one. Every entry carries two pieces of evidence: proof the defect was real,
and proof it is gone. Commands are run from
`/home/haihbv/Desktop/work/fpga/thiet_ke_he_thong_so`.

Entries are newest first.

## Contents

- [2026-09-21 ROM depth](#2026-09-21-rom-depth)
  - [33. Firmware had outgrown the 4 KB instruction ROM](#33-firmware-had-outgrown-the-4-kb-instruction-rom)
- [2026-09-21 panel clock](#2026-09-21-panel-clock)
  - [32. The panel said nothing after bring-up](#32-the-panel-said-nothing-after-bring-up)
- [2026-09-21 DS3231](#2026-09-21-ds3231)
  - [30. Every delay was nine times its intended length](#30-every-delay-was-nine-times-its-intended-length)
  - [31. The clock could be read but never set](#31-the-clock-could-be-read-but-never-set)
- [2026-09-21 I2C master](#2026-09-21-i2c-master)
  - [28. The repeated START emitted a stop condition](#28-the-repeated-start-emitted-a-stop-condition)
  - [29. The bus had no way back from a slave](#29-the-bus-had-no-way-back-from-a-slave)
- [2026-09-21 tree layout](#2026-09-21-tree-layout)
  - [25. One source directory had its tests in three sim directories](#25-one-source-directory-had-its-tests-in-three-sim-directories)
  - [26. The LCD peripheral outlived the LCD](#26-the-lcd-peripheral-outlived-the-lcd)
  - [27. The design report listed testbenches that do not exist](#27-the-design-report-listed-testbenches-that-do-not-exist)
- [2026-09-21 LCD scope removal](#2026-09-21-lcd-scope-removal)
  - [24. Firmware still drove an LCD that is leaving the design](#24-firmware-still-drove-an-lcd-that-is-leaving-the-design)
- [2026-09-21 SPI and ST7735](#2026-09-21-spi-and-st7735)
  - [22. New RTL was left out of synthesis without failing a test](#22-new-rtl-was-left-out-of-synthesis-without-failing-a-test)
  - [23. The design had no SPI peripheral](#23-the-design-had-no-spi-peripheral)
- [2026-09-21 GPIO button scope removal](#2026-09-21-gpio-button-scope-removal)
  - [21. GPIO included an unused button input](#21-gpio-included-an-unused-button-input)
- [2026-09-21 FENCE](#2026-09-21-fence)
  - [20. FENCE decoded only as an accidental no-op](#20-fence-decoded-only-as-an-accidental-no-op)
- [2026-09-21 U/J load-use stall](#2026-09-21-uj-load-use-stall)
  - [19. Immediate fields were treated as source registers](#19-immediate-fields-were-treated-as-source-registers)
- [2026-09-21 UART FIFO board test](#2026-09-21-uart-fifo-board-test)
  - [18. Firmware wrote the status bit to the W1C control register](#18-firmware-wrote-the-status-bit-to-the-w1c-control-register)
- [2026-09-20 UART RX FIFO](#2026-09-20-uart-rx-fifo)
  - [17. UART RX silently overwrote an unread byte](#17-uart-rx-silently-overwrote-an-unread-byte)
- [2026-09-19 source layout](#2026-09-19-source-layout)
  - [16. RTL and testbench paths no longer described ownership](#16-rtl-and-testbench-paths-no-longer-described-ownership)
- [2026-09-19 review follow-up](#2026-09-19-review-follow-up)
  - [12. The coding style guide described a project that does not exist](#12-the-coding-style-guide-described-a-project-that-does-not-exist)
  - [13. Five modules had no unit test](#13-five-modules-had-no-unit-test)
  - [14. Three figures in `docs/images/` are from other projects](#14-three-figures-in-docsimages-are-from-other-projects)
  - [15. Nothing ran the tests](#15-nothing-ran-the-tests)
- [2026-09-19 asynchronous inputs](#2026-09-19-asynchronous-inputs)
  - [11. External inputs reached the clock domain unsynchronised](#11-external-inputs-reached-the-clock-domain-unsynchronised)
- [2026-09-19 review](#2026-09-19-review)
  - [1. The register file had no write-first bypass](#1-the-register-file-had-no-write-first-bypass)
  - [2. I2C never generated a STOP condition](#2-i2c-never-generated-a-stop-condition)
  - [3. `sda_out` had no reset value](#3-sda_out-had-no-reset-value)
  - [4. Two I2C testbenches passed on a transition that preceded the START](#4-two-i2c-testbenches-passed-on-a-transition-that-preceded-the-start)
  - [5. AUIPC was not implemented](#5-auipc-was-not-implemented)
  - [6. ROM was not readable over the data bus](#6-rom-was-not-readable-over-the-data-bus)
  - [7. `.data` and `.bss` were never initialised](#7-data-and-bss-were-never-initialised)
  - [8. The ROM image left words undefined past the end of the firmware](#8-the-rom-image-left-words-undefined-past-the-end-of-the-firmware)
  - [9. Documentation described the I2C defect incorrectly](#9-documentation-described-the-i2c-defect-incorrectly)
  - [10. The PCF8574 address was recorded as `0x21`](#10-the-pcf8574-address-was-recorded-as-0x21)

---

## 2026-09-21 ROM depth

### 33. Firmware had outgrown the 4 KB instruction ROM

**Scope.** An 8x8 ASCII font and the code that draws it overflowed the 4 KB
ROM by 296 bytes, paid for once by retiring a board test and once by moving the
build to `-Os`, which left 252 bytes. The device has room: 468 Kbit of BSRAM in
26 blocks, of which the design used 8.

**Changes.** Double the ROM to 8 KB. `mem_instruction_rom.v` takes 2048 words
and indexes on `a[12:2]`, `linker.ld` gives region 0 a length of 8K, and
`make_hex.py` pads to 2048 words. The testbenches that fill the array by hand
cover the new depth, and `mem_instruction_rom_tb` moves its wrap case from 4 KB
to 8 KB and adds one at 4 KB, which is now inside the ROM rather than a wrap.

**Defect found while doing it.** The zero-fill loop stopped synthesising:

```text
ERROR (EX3934) : Loop count limit of 2000 exceeded, condition is never false
                 (source/cpu/mem_instruction_rom.v:21)
Module 'mem_instruction_rom' remains a black box due to errors in its contents
```

GowinSynthesis refuses to unroll a loop of more than 2000 iterations, and 2048
crosses it. The loop only matters in simulation, where a fixture shorter than
the array would leave words at x; synthesis always gets a full-depth image from
`make_hex.py`. It is now bracketed by `translate_off`.

**Verification.** The suite passes 33/33 and the build has no violated
endpoints.

A build alone would not have proved the new depth. Synthesis noticed the upper
half of the current image is all zeros and did not spend memory on it: the
netlist wires `AD` from `a[11:2]` only and drives the pROM `RESET` input from
`a[12]`, forcing zeros above 4 KB. Correct, but the pROM count stays at 4 and
the depth is never exercised.

Building a deliberately oversized image settles it. With 5480 bytes of
firmware, reaching past 4 KB:

| | 4 KB ROM | 8 KB ROM, image under 4 KB | 8 KB ROM, image 5480 bytes |
|---|---|---|---|
| pROM blocks | 4 | 4 | 8 |
| BSRAM | 8/26 | 8/26 | 12/26 |
| Fmax | — | 30.371 MHz | 31.317 MHz |
| Violated endpoints | — | 0 | 0 |

The cost is the four extra blocks predicted, and timing closes with margin. The
concern that doubling the depth would push the critical path negative, which
runs from the ROM output into the load formatter, was unfounded. Raw log:
`logs/13-rom-8k/02-over-4k-probe.log`.

**Second defect, same shape.** The CI firmware job compared the image against
a hardcoded 1024 words, so it went red the moment the ROM grew:

```text
firmware.hex is 2048 words, expected 1024
```

Nothing local caught it. `tools/run_tests.sh` does not look at the image size,
and the depth already lived in three places that have to agree: the array in
the RTL, `ROM_WORDS` in `make_hex.py` and the region length in `linker.ld`.
The check was a hardcoded fourth copy. It now reads all three and fails if any
disagrees, which also catches the other direction, where the RTL grows and the
padding does not. This is the same defect as entry 22: a constant duplicated
into a place that nobody updates.

**Consequence.** `-Os` existed only to fit the font, so the build returns to
`-O1` and `DELAY_MS` returns to the 3000 iterations a millisecond that entry 30
measured. The disassembly confirms the five-instruction loop is back, which is
the nine clocks that figure rests on. Firmware is 4392 bytes, genuinely past
4 KB, so the shipped image is what exercises the new depth: pROM 8, BSRAM
12/26, Fmax 31.317 MHz, no violated endpoints, in
`logs/13-rom-8k/03-o1-clock-build.log`.

**Hardware.** The 4392 byte image boots and runs, which is the proof the probe
could only stand in for: code above `0x1000` lives in the half of the ROM that
did not exist before, and a board that reaches its main loop has fetched from
it. Raw log: `logs/13-rom-8k/06-board.log`.

```text
BOOT 5A5A5A5A 00000000
TFT INIT
TFT BARS
RTC OSF CLEAR
RTC 2026-09-21 15:40:12
```
## 2026-09-21 panel clock

### 32. The panel said nothing after bring-up

**Scope.** The ST7735 had been showing the same three colour bars since it
came up. They proved the link and then carried no information.

**Changes.** Add an 8x8 ASCII font for 32 through 126, taken from the console
font at `/usr/share/consolefonts/Uni2-VGA8.psf.gz`, whose first 128 entries
follow ASCII. A glyph is drawn into its own address window, so a redraw touches
64 pixels rather than a line, and both colours are written so a character
replaces the one under it without a clear.

Redraw when the seconds byte changes rather than on a timer. The loop polls
the part every 50 ms and compares; a timer cannot keep step, because the loop
spends time reading I2C and printing after the delay expires.

Three consequences had to be paid for. The font and the drawing code
overflowed the 4 KB ROM by 296 bytes, so the UART RX FIFO board test was
retired, freeing 728 bytes; it is the board half of a protocol that has
already run, `cpu_uart_fifo_tb` keeps the behaviour under test, and the result
stays in entry 18. That was still short, so the build moved from `-O1` to
`-Os`, which fits in 3844 bytes with 252 spare.

Moving to `-Os` invalidated the delay calibration recorded in entry 30. One
iteration of `delay_loop` costs its instructions plus two cycles for each taken
branch and one for each load-use stall: twelve for the six-instruction loop
`-Os` emits, nine for the five-instruction loop `-O1` emitted. Nine is what the
board measured, so the model is calibrated rather than assumed, and `DELAY_MS`
moves from 3000 to 2250 iterations a millisecond.

**Verification.** The suite passes 33/33 and the build has no violated
endpoints. On the board the panel shows the date and time, and a capture of
373 consecutive readings over five minutes contains no repeated and no skipped
second:

```text
RTC lines: 373
first: RTC 2026-09-21 15:07:54   last: RTC 2026-09-21 15:13:07
repeated seconds: 0
gaps other than 1 s: 1
    RTC 2026-09-21 15:08:03 -> RTC 2026-09-21 15:07:05 delta -58
```

The single exception is the `S` command setting the clock back to the build
timestamp. The earlier capture, before the redraw was tied to the seconds
byte, skipped one: `00:14:52` followed by `00:14:54`. Raw log:
`logs/11-i2c-master/13-board.log`.

**Known consequence.** Embedding `__DATE__` and `__TIME__` makes the image
different on every build, so `sw/firmware.hex` never reproduces and always
shows as modified after a build. The difference is confined to the timestamp
string and the immediates that load it.

---

## 2026-09-21 DS3231

### 30. Every delay was nine times its intended length

**Defect.** `delay_cycles` counted loop iterations, not clocks, and its name
invited the argument to be read as a cycle count. One volatile iteration costs
nine clocks, so every delay ran nine times longer than written: the ST7735
delays specified as 120 ms were 1.08 s each, and the main loop meant to print
once a second printed every nine.

**Evidence before.** `logs/11-i2c-master/04-board.log`, with the loop argument
at 27000000 and the intent of one second:

```text
RTC 2000-01-01 00:08:30
RTC 2000-01-01 00:08:39
RTC 2000-01-01 00:08:48
```

**Fix.** Rename the helper to `delay_loop`, take `iterations`, and give callers
`DELAY_MS`, built on the measured figure of 3000 iterations to the millisecond.

**Evidence after.** `logs/11-i2c-master/07-board.log`, one second apart and
rolling the minute correctly:

```text
RTC 2000-01-01 00:14:59
RTC 2000-01-01 00:15:00
RTC 2000-01-01 00:15:01
```

Boot drops from roughly 4.3 s of ST7735 delays to 0.5 s, still above every
minimum the datasheet states.

### 31. The clock could be read but never set

**Scope.** The DS3231 answered and its oscillator ran, but it counted from the
power-on default with the oscillator stop flag set, and nothing on the board
could give it a real time.

**Changes.** Add a write path to the driver, report the stop flag at boot, and
add a UART command that writes `__DATE__` and `__TIME__` into the seven
timekeeping registers. The compiler is the only time source this board has.

Clear the stop flag only after the time is written, with a read, mask and
write rather than a whole byte: bit 3 of that register enables the 32 kHz
output and the alarm flags sit beside it. The flag says the registers have not
been counting, so a known value in them is what makes it untrue.

Parse the timestamp without division or modulo, which on RV32I would pull in a
libcall that does not exist. `__DATE__` pads a day below the tenth with a space
rather than a zero. The day of week register is written as 1 and not derived,
because deriving it needs a modulo and nothing reads it.

**Verification.** The conversion was checked on the host before it reached the
board, covering a space-padded day and a two-digit month:

```text
date "Sep 21 2026" time "14:46:03"
  sec=03 min=46 hour=14 date=21 month=09 year=26
date "Jan  5 2027"   date=05    Dec=12 Oct=10
```

On the board the written time reads back field for field, in
`logs/11-i2c-master/10-board.log`:

```text
RTC SET Sep 21 2026 14:47:18
RTC 2026-09-21 14:47:18
RTC 2026-09-21 14:47:19
```

Firmware grows to 3404 bytes of the 4 KB ROM.

Clearing the flag was recorded here as inferred from the write path rather
than observed. It has since been observed: a reset in
`logs/13-rom-8k/06-board.log` reports `RTC OSF CLEAR`, and the clock reads the
real date rather than the power-on default, so the write reached the part and
survived a power cycle of the FPGA.

---

## 2026-09-21 I2C master

### 28. The repeated START emitted a stop condition

**Defect.** `PreStart` released SDA high and released SCL high in the same
tick. On an idle bus that is harmless, because SDA is already high. On a
chained frame SDA is held low by `AckDone`, so it rose while SCL was rising:
a slave reads that as a STOP, not as a repeated START. The path had never been
exercised, since the LCD only issued a START on its first frame and chained
the rest.

**Evidence before.** The first run of `i2c_master_tb`, against a slave model
that counts bus conditions:

```text
FATAL: libs/i2c/i2c_master_tb.sv:218: 1 STOP conditions before the read finished
```

**Fix.** Split the setup in two. `PreStart` raises SDA while SCL is still held
low, and a new `StartSetup` state then releases SCL. `Start` pulls SDA down
with SCL high, which is the START condition.

**Evidence after.** `i2c_master_tb` passes, with the slave counting two START
conditions and no STOP until the read ends.

### 29. The bus had no way back from a slave

**Scope.** The I2C block could only write. The DS3231 has no command that
returns a register: the pointer is set with a write, the bus is turned around
with a repeated START, and the device transmits until the master refuses a
byte.

**Changes.** Replace `i2c_write_frame.v` with `libs/i2c/i2c_master.v`, which
adds `rw`, `ack_out` and `data_out`. `rw` is latched when the frame begins, so
changing it mid-transfer cannot turn the data phase around while it runs. A
read releases SDA for the eight data bits and samples each one at the midpoint
of the SCL high time, where the slave holds it steady. The acknowledge bit is
driven by the master on a read and by the slave on a write.

Add `source/peripheral/i2c_mmio.v` at region `0x6`: one store launches one
frame, carrying the byte and the four flags that shape it. Framing stays in
software because which pointer to set and where a read turns around are
properties of the slave, not of the bus.

Add `libs/i2c/i2c_slave_model.sv`, a behavioural slave with address match, a
register pointer and auto-increment. It is deliberately not named after a part:
that shape is common to register-mapped I2C devices, and tying the master's
own tests to one device would misplace the scope.

**Verification.** The suite passes 33/33, including `cpu_i2c_tb`, which runs
the whole read sequence from a program in ROM against the slave model. The
build reaches 0 setup and 0 hold violated endpoints; logic rises from 3234 to
3256, registers from 1506 to 1598, and I/O ports from 10 to 12 as pins 31 and
32 come back.

On the board a DS3231 on pins 31 and 32 answers and the seven timekeeping
registers come back, with the seconds advancing between reads:

```text
RTC 2000-01-01 00:08:30
RTC 2000-01-01 00:08:39
RTC 2000-01-01 00:08:48
```

The date is the power-on default of a part whose time has never been set; what
the capture proves is that the address is acknowledged, the repeated START
turns the bus around, and the oscillator is running. Raw log:
`logs/11-i2c-master/04-board.log`.

---

## 2026-09-21 tree layout

### 25. One source directory had its tests in three sim directories

**Defect.** `sim/` divided the tests for `source/cpu/` by filename prefix
rather than by anything structural. A test for `source/cpu/core_alu.v` lived
in `sim/core/`, one for `source/cpu/mem_data_ram.v` in `sim/memory/`, and one
for `source/cpu/cpu_address_decoder.v` in `sim/cpu/`: three directories for
one source directory. The split could not be stated as a rule, so it could not
be checked.

**Fix.** Merge `sim/core/` and `sim/memory/` into `sim/cpu/`, so that `sim/`
holds one directory per `source/` directory and nothing else. `sim/cpu/` now
holds 22 files, the same cost `source/cpu/` already pays with 15; both rely on
the `core_`, `pipe_`, `mem_` and `cpu_` prefixes to group them.
`sim/support/` keeps the shared fixtures, which belong to no module.

A library keeps its unit testbench beside its RTL, as it did before. `libs/`
is meant to be liftable into another project, and a block that travels without
its tests arrives unverifiable.

**Verification.** No RTL and no testbench content changed. The suite passes
34/34 before and after the move.

### 26. The LCD peripheral outlived the LCD

**Scope.** Firmware stopped driving the HD44780 panel in entry 24, leaving the
RTL instantiated and synthesized with nothing to talk to. A DS3231 will take
region `0x6` over, and it needs register reads that a write-only frame engine
cannot perform.

**Changes.** Delete `pcf8574_lcd_mmio.v`, `i2c_pcf8574_lcd_write.v`,
`i2c_lcd_20x4_refresh.v` and their testbenches. Remove the I2C instance, its
clock enable, the `i2c_sda` and `i2c_scl` ports and the two pin constraints;
remove `we_i2c` and `rd_i2c` from the decoder, so region `0x6` reads zero as
unmapped until the DS3231 lands. Eight CPU testbenches drop the two `tri1`
nets they declared for those ports.

`libs/i2c/i2c_write_frame.v` and its testbench survive. The module is a plain
I2C write frame with START, eight data bits, ACK and optional STOP, chainable
through `start_frame` and `stop_frame`. It is the starting point for the
read-capable master, so deleting it would throw away a board-verified FSM.

**Verification.** The suite passes 31/31, which is 34 minus exactly the three
LCD testbenches. The build in `logs/10-tree-layout/01-build.log` reaches Fmax
30.299 MHz with 0 setup and 0 hold violated endpoints. Logic drops from 3372
to 3234, registers from 1632 to 1506 and I/O ports from 12 to 10, the last
being the two I2C pins; a peripheral that had really been removed had to show
up as a reduction.

### 27. The design report listed testbenches that do not exist

**Defect.** The verification table in `docs/design_report.md` named
`regfile_tb`, `gpio_tb`, `address_decoder_tb`, `dmem_tb`, `imem_tb`,
`forwarding_unit_tb`, `hazard_detection_unit_tb`, `clock_enable_divider_tb`,
`i2c_writeframe_tb`, `i2c_mmio_tb` and `lcd_display_tb`. None of those files
exist in this repository; they are names from the project this one was derived
from. The table also omitted every testbench added since, so it described
neither the tree nor the suite.

**Fix.** Rebuild the table from `tools/run_tests.sh`, which is the list the
suite actually runs, and correct the timing figures and the latch note beside
it.

**Verification.** Every row now names a file present in `sim/`, and the row
count matches the 31 testbenches `run_tests.sh` executes.

---

## 2026-09-21 LCD scope removal

### 24. Firmware still drove an LCD that is leaving the design

**Scope.** The 20x4 HD44780 LCD is being retired and a DS3231 will take its
place on the I2C bus. The shipped firmware no longer talks to it.

**Changes.** Remove `lcd_wait_ready`, `lcd_command`, `lcd_data`, `lcd_puts`,
`lcd_init`, `lcd_probe`, `lcd_find_address`, the `LCD_*` register defines and
`I2C_BASE` from `sw/main.c`. The main loop now prints `ALIVE` once a second and
toggles the LED instead of reporting the PCF8574 address. Firmware drops from
2412 to 2000 bytes of the 4 KB ROM.

The I2C RTL is untouched: `source/peripheral/pcf8574_lcd_mmio.v`, `libs/i2c/`,
region `0x6` and the four I2C testbenches all remain. `rules/git_flow.md`
keeps one subsystem per branch, and the DS3231 needs register reads that the
present write-only frame engine cannot do, so replacing it is its own branch
rather than a deletion here.

**Verification.** Simulation passes 34/34. On the board the banner, `TFT INIT`,
`TFT BARS` and the repeating `ALIVE` line all appear in
`logs/09-spi-st7735/04-board.log`.

---

## 2026-09-21 SPI and ST7735

### 22. New RTL was left out of synthesis without failing a test

**Defect.** `tools/run_tests.sh` collects CPU sources with a glob, but
`tools/build_gowin.tcl` names every file explicitly. A new module therefore
simulates and passes its testbenches while never reaching synthesis, and the
only symptom is the top module quietly becoming a black box.

**Evidence before.** The first FPGA build after adding the SPI peripheral,
with all 33 testbenches passing:

```text
ERROR (EX3937) : Instantiating unknown module 'spi_mmio'(".../source/cpu/cpu_top.v":294)
Module 'cpu_top' remains a black box due to errors in its contents(".../source/cpu/cpu_top.v":1)
GowinSynthesis finish
```

**Fix.** Add `source/peripheral/spi_mmio.v` and `libs/spi/spi_master.v` to
`tools/build_gowin.tcl`, and to `fpga_project.gprj` so the IDE flow matches.

**Evidence after.** `logs/09-spi-st7735/02-firmware-build.log` completes with
Fmax 30.880 MHz against the 27 MHz constraint, 0 setup and 0 hold violations,
and `logs/09-spi-st7735/03-program.log` reaches 100%.

### 23. The design had no SPI peripheral

**Scope.** Add a write-only SPI master at region `0x7` and drive an ST7735
128x160 TFT from firmware.

**Changes.** New `libs/spi/spi_master.v`, a mode 0 MSB-first shift engine with
no `miso` port, since the breakout brings only `SDA` to its header. New
`source/peripheral/spi_mmio.v` holding `cs_n`, `dc` and the panel reset as
software state, because one ST7735 command and its parameters form a single
chip select frame with `dc` changing partway through. `cpu_address_decoder`
gains region `0x7`; `cpu_top` gains five output pins bound to 25 through 29,
the only run of bank 2 header pins with no onboard component on them.

`sw/main.c` gains an ST7735 driver whose init sequence is limited to commands
the datasheet specifies: `SWRESET`, `SLPOUT`, `COLMOD` = `0x55` per 10.1.29
note 2, `MADCTL`, `INVOFF`, `NORON`, `DISPON`. Power control and frame rate
registers are left at their reset defaults. The fill loop is nested rather
than `columns * rows` because the core is RV32I with no multiply instruction
and `-nostdlib` leaves no `__mulsi3`.

**Verification.** Simulation passes 34/34, including `spi_master_tb`,
`spi_mmio_tb` and `cpu_spi_tb`, which boots a handwritten program and decodes
the byte stream off the pins with the state of `dc` recorded per byte. On the
board the panel shows three vertical bars in red, green and blue in that
order, which confirms RGB565 byte order, the `MADCTL 0xc8` subpixel order and
`CASET`/`RASET` addressing together.

---

## 2026-09-21 GPIO button scope removal

### 21. GPIO included an unused button input

**Scope.** The project no longer includes S1 as a software input. GPIO now
owns only the LED output register at `0x40000000`.

**Changes.** Remove `btn_in` from `cpu_top`, `gpio_mmio`, integration
testbenches and the FPGA constraint file. Offset `0x40000004` is now unmapped
and reads zero. The S1 pin constraint is removed; reset S2 remains on pin 3.

**Verification.** The full simulation suite passes 31/31. `gpio_mmio_tb`
covers reset, LED write/read and the removed offset. FPGA build completes
timing analysis and bitstream generation; SRAM programming reaches 100% with
`Finished.`.

---

## 2026-09-21 FENCE

### 20. FENCE decoded only as an accidental no-op

**Symptom.** Opcode `0001111` had no explicit decoder case. It therefore
looked like a no-op only because every unrecognised opcode fell through to the
default control values.

**Fix.** `core_control.v` now emits an explicit `Fence` signal for `funct3=000`.
The signal creates no datapath control because the core has one in-order memory
port, which already preserves all earlier accesses before later ones begin.

**Verification.** The full simulation suite passes 31/31. `core_control_tb`
checks the explicit decode. `cpu_fence_tb` performs store, FENCE, then load,
checks the loaded value and confirms that FENCE is decoded once.

**Status** — Fixed.

---

## 2026-09-21 U/J load-use stall

### 19. Immediate fields were treated as source registers

**Symptom.** `pipe_hazard.v` compared the preceding load destination against
`instr[19:15]` and `instr[24:20]` for every decoded instruction. Those fields
are immediate bits in LUI, AUIPC and JAL, so a matching bit pattern inserted a
load-use bubble even though the instruction did not read either register.

**Fix.** `core_control.v` now emits `UsesRs1` and `UsesRs2`. The hazard unit
compares an index only when the decoder says the instruction reads that source.
R-type, store and branch instructions use both sources; I-type, load and JALR
use `rs1`; LUI, AUIPC and JAL use neither.

**Verification.** The full simulation suite passes 30/30. `pipe_hazard_tb`
checks that unused instruction fields do
not stall. `cpu_hazard_tb` places LUI and AUIPC immediately after loads whose
destinations match their immediate bits, then confirms the program has exactly
one stall for its only true load-use dependency.

**Status** — Fixed.

---

## 2026-09-21 UART FIFO board test

### 18. Firmware wrote the status bit to the W1C control register

**Symptom.** The FIFO board protocol printed `RXFIFO CASE16`, `RXFIFO
CASE17`, then `RXFIFO FAIL` in both
`logs/03-uart-rx-fifo/11-board-protocol.log`
and `logs/03-uart-rx-fifo/15-board-test-firmware-protocol.log`.
The second failure followed a firmware rebuild, so the earlier explanation
that only a stale firmware image caused the first failure was not supported.
These captures report only an aggregate result; they do not identify which
case first failed.

**Cause.** `UART_STAT_REG` reports `rx_overrun` in bit 2 (`0x04`), but the
write-one-to-clear control at `UART_CTRL_REG` accepts bit 0 (`0x01`). The
firmware wrote `0x04` when draining the FIFO and after the 17-byte case, so
those writes could never clear the sticky overrun flag.

**Fix.** Use a separate `UART_CTRL_CLEAR_OVERRUN` value of `0x01`. Report
case 16 and case 17 results independently, and drain/clear the FIFO between
cases. The MMIO test now confirms that writing `0x04` leaves overrun set and
writing `0x01` clears it.

**Simulation.** `logs/03-uart-rx-fifo/16-w1c-fix-simulation.log`
records 30/30 PASS; the rebuilt firmware image is 1024 ROM words.

**Board verification.** `logs/03-uart-rx-fifo/17-w1c-fix-build.log`
records P&R, timing analysis and bitstream generation complete.
`logs/03-uart-rx-fifo/18-w1c-fix-program.log`
records SRAM programming at 100% with `Finished.`. The protocol capture in
`logs/03-uart-rx-fifo/19-w1c-fix-protocol.log`
records `CASE16 PASS`, `CASE17 PASS` and `RXFIFO PASS`.

**Status** — Fixed and board-verified. Case 16 proves ordered receipt of a
full FIFO without overrun. Case 17 proves that the FIFO retains its first 16
bytes, records the 17th-byte drop, and clears overrun through W1C.

---

## 2026-09-20 UART RX FIFO

### 17. UART RX silently overwrote an unread byte

**Symptom.** `uart_rx.v` stored only one received byte. A later valid frame
replaced it before firmware read offset `0x50000008`, with no indication that
data was lost. Historical board measurements recorded a mismatched 1024-byte
echo stream.

**Fix.** `uart_rx.v` now keeps sixteen bytes in a ring buffer. `uart_mmio.v`
reports non-empty state, queue level and a sticky overrun bit at `0x50000004`.
Reading `0x50000008` pops the oldest byte; writing one to `0x5000000c` bit zero
clears the overrun indication. A full FIFO drops the new byte and preserves the
queued sequence.

**Verification.** `logs/03-uart-rx-fifo/03-full-simulation.log`
records 30/30 PASS. The UART unit and MMIO tests cover FIFO order, full state,
drop-on-full, sticky overrun, W1C clear and pop behavior; `cpu_uart_fifo_tb`
covers two CPU loads popping queued bytes in order.

**Build.** `logs/03-uart-rx-fifo/04-fpga-build.log`
records P&R, timing analysis and bitstream generation complete at 30.210 MHz
against the 27 MHz constraint with 0 setup/hold violations. The FIFO build uses
3375/8640 logic cells, 1599/6693 registers and 6/26 BSRAM.

**Board boot.** `logs/03-uart-rx-fifo/05-program-board.log`
records SRAM programming at 100% with `Finished.`. The reset capture in
`logs/03-uart-rx-fifo/06-board-uart.log`
records `BOOT 5A5A5A5A 00000000` and `I2C 27` from the FIFO bitstream.

**Status** — Superseded by finding 18. The initial board workload exposed the
firmware W1C defect; the corrected board protocol now verifies FIFO ordering,
overrun handling and W1C clear.

---

## 2026-09-19 source layout

### 16. RTL and testbench paths no longer described ownership

**Symptom.** The flat `src/` and `tb/` tree mixed CPU core, pipeline, memory,
peripheral and reusable protocol code. After the physical trees were moved to
`source/` and `sim/`, the build graph still named the removed `src/` and `tb/`
paths, so the repository had no self-consistent source layout.

**Fix.** CPU files now live in `source/cpu/` and use `cpu_`, `core_`, `pipe_`
or `mem_` prefixes. SoC-specific MMIO adapters live in `source/peripheral/`,
common modules in `source/common/`, and reusable I2C/UART blocks live in
`libs/i2c/` and `libs/uart/` with their unit testbench beside them. CPU
integration tests live in `sim/cpu/`; the remaining non-library tests are
grouped by ownership under `sim/`.

`tools/run_tests.sh`, `tools/build_gowin.tcl` and `fpga_project.gprj` now use
the new paths and module names. README, design report, coding guide and firmware
image helper now describe the same tree.

**Simulation.** `logs/02-source-layout/01-refactor.log`
records 29/29 PASS. The only warning is the intentional short-image fixture in
`mem_instruction_rom_tb`; it proves that ROM words beyond the fixture are
zero-filled.

**Build and programming.** The refactored tree was built and programmed after the
simulation run. `logs/02-source-layout/02-fpga-build.log`
records P&R, timing analysis and bitstream generation complete with Fmax
28.912 MHz, 0 setup/hold violations, 3321/8640 logic cells, 1594/6693 registers
and 6/26 BSRAM. `logs/02-source-layout/03-program-board.log`
records SRAM programming at 100% with `Finished.`.

**Status** — Fixed. This is a behavior-preserving refactor. Programming was
verified, but no new UART/LCD capture was taken after the refactored bitstream
was loaded; the functional board evidence remains `logs/01-initial-bringup/05-board-uart.log`.

---

## 2026-09-19 review follow-up

The four gaps the review left open, closed together. Item 14 turned up something
worse than the gap it was meant to close.

### 12. The coding style guide described a project that does not exist

**Severity** — Low in effect, high in credibility. A rule nothing follows is
worse than no rule, because it stops being read.

**Symptom.** `rules/verilog_coding_style.md` mandated SystemVerilog-2017 with
`logic`, `always_ff`, `always_comb`, and ports suffixed `_i`/`_o`/`_ni`. Not one
of the 24 RTL files complied, and `tools/build_gowin.tcl` pins
`-verilog_std v2001`, so the build actively contradicted the guide.

**Fix.** The code is right and the guide was wrong, so the guide changed. The
policy is now stated with its reason: synthesizable RTL is Verilog-2001 because
that is GowinSynthesis's exercised path and the design sits near its timing
limit, and testbenches are SystemVerilog-2017 because nothing synthesizes them.
Sections 2, 6, 7, 8, 12, 13 and 44 were rewritten, the examples renamed to the
convention actually in use, and a table of deliberate deviations added so the
next reader knows which gaps are decisions rather than debt.

Section 44 gained an exception it always needed: `initial` with `$readmemh` is
how a block RAM gets its contents and is not a simulation-only construct.

**Status** — Fixed.

### 13. Five modules had no unit test

**Symptom.** `address_decoder`, `dmem`, `imem`, `pc_reg` and `uart_tx` were
exercised only through `cpu_top_tb`. The ROM window and the byte lanes, both
recent, had no test that named them.

**Fix.** Five testbenches, chosen to pin the behaviour that integration tests
cannot isolate:

- `address_decoder_tb` — each region selects one target, unmapped regions read
  zero, the byte mask reaches RAM unchanged, and a store into the ROM window
  reaches nothing
- `dmem_tb` — each byte lane independently, a halfword mask, a zero mask as a
  read, the 4 KB wrap, and that a read concurrent with a write returns the old
  word
- `imem_tb` — both ports reading independently and the same word at once, and
  that the array past the end of the image reads zero rather than `x`
- `pc_reg_tb` — advance, stall holding the address, and reset outranking stall
- `uart_tx_tb` — a captured 8N1 frame sampled at bit centres, and that a write
  arriving mid-frame is dropped rather than queued

Every module in `src/` now has its own testbench. The suite is 29 tests.

**Status** — Fixed.

### 14. Three figures in `docs/images/` are from other projects

**Severity** — High. One of them would misrepresent someone else's work as this
project's result.

**Symptom.** The review noted that all 15 files in `docs/images/` were
unreferenced. Opening them showed why that mattered: because nothing cited them,
nothing had ever checked what they contain.

- `demo.jpg` is an Avnet Zynq board driving a 16x2 LCD that reads
  **another person's name**. The project targets a Tang Nano 9K with a 20x4
  display
- `schematic_1.png` is a Vivado block design containing a Zynq UltraScale+
  processing system
- `pin_out.png` is a Quartus pin assignment table for a keypad lock on an Altera
  part

Three more are generic reference figures with no recorded source, one of them
labelled in Vietnamese. Three are genuine captures of superseded revisions of
this project.

**Fix.** `docs/images/README.md` is now an inventory that states, for every file,
which of the three groups it belongs to and why. Five figures were verified
against the current RTL and are now cited from the text:

| Figure | Checked against |
|---|---|
| `schematic_1frame_FSM.png` | The state list in `i2c_writeframe.v`, and the nine SCL pulses finding 2 restored |
| `FSM_i2c_writeframe.png` | The same state list; the drawing's `WaitACK` exit condition is noted as wrong in the caption |
| `FSM_lcd_write_cmd_data.png` | The state list in `lcd_write_cmd_data.v` |
| `schematic_lcd_i2c_pcf8574.png` | The P0-P7 mapping in the RTL comment, and the address straps |
| `waveform_lcd_write_cmd_data.png` | `4e dc d8 4c 48` recomputed by hand from `data = 0xd4` |

The backpack schematic independently confirms finding 10: A0, A1 and A2 sit on
pull-ups with the jumpers open, so `0x27` is the address the hardware was always
going to answer at.

`demo.jpg`, `schematic_1.png` and `pin_out.png` were deleted. Four generic I2C
reference figures remain, unused and uncited, because none of them has a
recorded source; `docs/images/README.md` says so rather than leaving a reader to
assume they are ours.

**Status** — Fixed.

### 15. Nothing ran the tests

**Symptom.** 29 self-checking testbenches and no automation. A commit that broke
one would be found by whoever next ran the suite by hand.

**Fix.** `.github/workflows/ci.yml`, on every push to a long-lived or topic
branch and every pull request into `main` or `develop`:

- **Simulation** installs Icarus Verilog and runs `tools/run_tests.sh`, which
  stops at the first failure, so a red job names the testbench that broke
- **Firmware** installs the RISC-V toolchain, builds, and checks the image fills
  the ROM exactly and that `_start` is at the reset vector. Both fail silently
  otherwise: an oversized image wraps inside `rom[a[11:2]]`, and a misplaced
  `_start` runs whatever is at address zero

The rebuild is deliberately **not** compared byte for byte with the committed
image. A different GCC release generates different code, and a red build on a
toolchain bump is noise; `firmware_boot_tb` in the simulation job already runs
the committed image on the SoC and checks what it prints.

**Status** — Fixed.

### Also corrected

The documentation claimed the suite runs on Icarus Verilog 11.0. It runs on
12.0.

---

## 2026-09-19 asynchronous inputs

One finding, in three places. Nothing here showed up as a failure in simulation
or on the board, which is the point: metastability is a probabilistic fault that
a directed test cannot provoke.

### 11. External inputs reached the clock domain unsynchronised

**Severity** — High. Intermittent, unreproducible misbehaviour.

**Symptom.** Three signals that have no relationship to the 27 MHz clock were
consumed directly.

`rst_n` comes off a mechanical button on pin 3 and drove the asynchronous reset
pin of every sequential block in the design:

```verilog
always @(posedge clk or negedge rst_n)   // in fifteen modules
```

Asserting that way is correct and deliberate. Releasing that way is not: the
rising edge lands wherever the button happens to bounce, so recovery and removal
cannot be met and nothing guarantees that all 1588 registers leave reset on the
same cycle. A pipeline that comes out of reset half in one state and half in
another produces exactly the kind of symptom that gets misdiagnosed as an RTL
bug.

At the time of this review, `btn_in` was also read combinationally through the
GPIO mux. That S1 input, its MMIO register and pin constraint were later
removed from project scope. `sda` was sampled for the ACK bit directly off the
pad, and the PCF8574 drives it on its own timing.

`uart_rx_in` was already synchronised with a two-stage chain, so the technique
was present in the design; it had just not been applied evenly.

**Fix.**

- add [`src/reset_sync.v`](../src/reset_sync.v): asynchronous assert, release
  gated through a two-stage chain, and route every module's `rst_n` through it
- synchronise `sda` in [`src/i2c_writeframe.v`](../src/i2c_writeframe.v) before
  the ACK sample, free running on `clk` rather than on the 1 MHz tick, since
  metastability settles in clock cycles

**Verification.** `tb/reset_sync_tb.sv` checks the asymmetry directly: the
output falls when the pin is dropped between clock edges, stays low across five
edges while the pin is held, does not move when the pin is released between
edges, and rises only after the chain has clocked twice. It then repeats the
whole cycle, so the chain is not one-shot.

```
reset_sync_tb: PASS
gpio_mmio_tb: PASS
```

Board behaviour is unchanged, as expected: this removes a failure mode rather
than a failure.

**Cost.** Six registers, and timing margin.

| Metric | Before | After |
|---|---|---|
| Actual Fmax | 31.762 MHz | 28.912 MHz |
| Margin over the 27 MHz oscillator | 18% | 7% |
| Setup / hold violated endpoints | 0 / 0 | 0 / 0 |
| Logic | 3343 / 8640 | 3321 / 8640 |
| Registers | 1588 / 6693 | 1594 / 6693 |

The binding path is not the reset. Place and route reports it as

```
ram/ram_3_ram_3_0_0_s/DO[7]  ->  reg_mem_wb/wb_read_data_28_s0/D
clk:[F] -> clk:[R]   relation 18.518 ns   slack 1.225 ns
```

which is the DMEM read: `dmem.v` reads on the falling edge and MEM/WB captures
on the next rising edge, so that path gets half a clock period rather than a
whole one. Nothing in this change touches it. The reset net itself sits on a
global long-wire resource (`rst_n_sync`, LW 1/8), so its fanout to 1594
registers costs no fabric routing; what moved is placement around the BSRAM.

Keeping the fix is still right — correctness before margin, and 28.912 MHz meets
the constraint with zero violations. But 7% is thin enough to record, and the
lever for recovering it is the half-cycle memory read, not the reset.

**Status** — Fixed.

---

## 2026-09-19 review

Ten findings from a full re-read of the tree after the repository restructure.
Items 1 through 3 are silicon defects, item 4 is a pair of tests that could not
fail, items 5 through 7 are missing functionality that blocked ordinary C, item
8 is simulation hygiene, and items 9 and 10 are documentation errors that came
from misreading the evidence.

### 1. The register file had no write-first bypass

**Severity** — High. Silent wrong answers in ordinary straight-line code.

**Symptom.** An instruction that read a register written three instructions
earlier got the stale value. The forwarding unit covers distances one and two
by reaching into EX/MEM and MEM/WB. At distance three the producer is in WB
exactly while the consumer is in ID, and neither path applies.

**Evidence before the fix.** A four-instruction program on the real `cpu_top`:

```
addi x1, x0, 4
addi x2, x0, 5
nop
add  x3, x1, x2

x1=4 x2=5 x3=5  (expected x3=9)
RESULT: distance-3 RAW FAILS
```

`x1` read back as zero, so the add produced `0 + 5`. The firmware worked around
this in `uart_hex()` by branching around the `A`-`F` arithmetic instead of using
a lookup table, which is why the UART used to print `0x27` as `2>`.

**Fix.** [`src/regfile.v`](../src/regfile.v) — return the pending write data
when the write port and a read port name the same register in the same cycle:

```verilog
wire bypass_rs1 = we && (rd != 5'd0) && (rd == rs1);
wire bypass_rs2 = we && (rd != 5'd0) && (rd == rs2);

assign rd1 = (rs1 == 5'd0) ? 32'd0 : (bypass_rs1 ? wd : x[rs1]);
assign rd2 = (rs2 == 5'd0) ? 32'd0 : (bypass_rs2 ? wd : x[rs2]);
```

**Verification.** Two new testbenches, both confirmed to fail against the old
`regfile.v` and pass against the new one.

`tb/regfile_tb.sv` covers the bypass itself, including the cases where it must
*not* fire — `x0`, a non-matching index, and write enable low:

```
against the old regfile: FATAL tb/regfile_tb.sv:61: bypass rd1=00000000 rd2=00000000 expected 12345678
against the new regfile: regfile_tb: PASS
```

`tb/cpu_hazard_tb.sv` runs RAW dependencies at distance one through four on the
full CPU, plus a distance-three dependency whose producer is a load, plus the
load-use interlock:

```
against the old regfile: FATAL tb/cpu_hazard_tb.sv:61: distance 3, write-first bypass: x7 = 1, expected 21
against the new regfile: cpu_hazard_tb: PASS
```

**Status** — Fixed.

### 2. I2C never generated a STOP condition

**Severity** — Medium. Off-spec bus behaviour that the PCF8574 happened to
tolerate.

**Symptom.** `stop_frame` produced no STOP. `PreStop` released SCL while SDA was
already high, so the edge that defines a STOP — SDA rising while SCL is high —
never occurred. What the bus saw instead was one extra SCL rising edge with no
falling edge after it.

**Evidence before the fix.** Logging every bus edge through a full frame with
`stop_frame` asserted:

```
>>> STOP  at t=105000 state=1      <- PreStart, before the START
>>> START at t=585000 state=2
t=10745000 state=12 scl=1 sda=1 sda_en=0
--- frame done ---
```

The only STOP in the trace preceded the START. Counting SCL rising edges across
a NACK frame gave ten where I2C defines nine:

```
NACK frame (no slave): scl rising edges = 10 (I2C requires 9), ack=0
```

**Fix.** [`src/i2c_writeframe.v`](../src/i2c_writeframe.v) — drive SDA low in
`AckDone`, while SCL is still low, so that releasing SCL in `PreStop` and then
SDA in `Stop` produces a real rising edge on a high clock.

**Verification.** The same bus probe after the fix:

```
>>> START at t=585000  state=2
>>> STOP  at t=11185000 state=13   <- Stop state, after the START
```

`tb/i2c_writeframe_tb.sv` now asserts one START, one STOP after it, exactly nine
SCL pulses in between, and both lines idle high afterwards, for the ACK frame
and the NACK frame:

```
i2c_writeframe_tb: PASS
```

**Status** — Fixed.

### 3. `sda_out` had no reset value

**Severity** — Medium. The bus was held low from power-up.

**Symptom.** The reset branch of the output logic set `sda_en`, `cnt_clr`, `ack`
and `scl_drive_low`, but not `sda_out`. Reset leaves `sda_en` at 1, and

```verilog
assign sda = sda_en ? (~sda_out ? 1'b0 : 1'bz) : 1'bz;
```

drives SDA low whenever `sda_out` is 0. Gowin powers registers up at zero, so
SDA was pulled low from configuration until the CPU issued its first I2C write —
the state machine sits in `WaitEn` until then. In simulation `sda_out` was `x`,
which is where the spurious transition in finding 2 came from.

**Fix.** Reset `sda_out` to 1 so the line starts released and the pull-up
defines the idle level.

**Verification.** `tb/i2c_writeframe_tb.sv` checks the line immediately after
reset, before any frame:

```
before the fix: FATAL tb/i2c_writeframe_tb.sv:135: SDA = x after reset, expected the line to be released
after the fix:  i2c_writeframe_tb: PASS
```

**Status** — Fixed.

### 4. Two I2C testbenches passed on a transition that preceded the START

**Severity** — High as a process defect. Both tests asserted `stop_count == 1`
and could not have caught finding 2.

**Symptom.** `tb/i2c_writeframe_tb.sv` and `tb/lcd_write_cmd_data_tb.sv` counted
a STOP on any SDA rising edge while SCL was high, with no requirement that a
START had happened first. The `x`-to-1 settle described in finding 3 satisfied
that at t=105 ns, so the assertion was met before the frame even began.

**Fix.** Gate STOP detection on `frame_active`, so only a transition inside an
open frame counts. `tb/i2c_writeframe_tb.sv` additionally counts complete SCL
pulses between the START and the STOP and checks the bus is idle afterwards.

**Verification.** With the gate in place and the RTL still unfixed, the LCD
testbench reported the real picture rather than a pass:

```
FATAL: tb/lcd_write_cmd_data_tb.sv:107: expected one START and one STOP, got 1 and 2
```

Both pass against the fixed RTL.

**Status** — Fixed.

### 5. AUIPC was not implemented

**Severity** — Medium. Opcode `0010111` decoded silently to a NOP.

**Symptom.** Every control signal defaulted to zero for that opcode and
`imm_gen` returned zero, so the instruction retired without writing its
destination. Any PC-relative address formation was impossible, which in turn is
what `la` needs for a position-independent reference.

**Fix.** A new `ALUSrcA` control bit selects the program counter instead of
`rs1` for the ALU's first operand:

- [`src/imm_gen.v`](../src/imm_gen.v) — AUIPC shares the U-type immediate with LUI
- [`src/control_unit.v`](../src/control_unit.v) — decode, with `ALUSrcA` set
- [`src/pipe_id_ex.v`](../src/pipe_id_ex.v) — carry `ALUSrcA` into EX
- [`src/cpu_top.v`](../src/cpu_top.v) — `alu_src_a = ex_ALUSrcA ? ex_pc : alu_mux_a`

**Verification.** `tb/cpu_auipc_tb.sv` checks AUIPC at three program counters
and a PC-relative load built from AUIPC plus `lw`. `tb/control_unit_tb.sv` and
`tb/imm_gen_tb.sv` gained decode checks. The real firmware then confirms it end
to end: the assembler expands every `la` in `sw/startup.s` to AUIPC.

```
00000000 <_start>:
   0:	20001117          	auipc	sp,0x20001
   c:	20000317          	auipc	t1,0x20000
  14:	20000397          	auipc	t2,0x20000
```

```
cpu_auipc_tb: PASS
```

The base instruction count goes from 36 of 40 to 37 of 40. FENCE, ECALL and
EBREAK remain unimplemented.

**Status** — Fixed.

### 6. ROM was not readable over the data bus

**Severity** — Medium. `.rodata` read back as zero.

**Symptom.** `address_decoder` had no case for region `0x0`, so a load from the
instruction ROM fell through to the default and returned zero. The linker places
`.rodata` and the load image of `.data` in ROM, so string literals and lookup
tables were unreachable. The firmware worked around it by sending characters one
`uart_putc` call at a time.

**Fix.** A second read port on the ROM, and a decoder case for it:

- [`src/imem.v`](../src/imem.v) — `a_data` / `rd_data`, read on the same falling edge as the fetch port
- [`src/address_decoder.v`](../src/address_decoder.v) — `4'h0: rd_out = rd_rom`, with no write enable, so a store into ROM is dropped
- [`src/cpu_top.v`](../src/cpu_top.v) — the data port is addressed from the MEM stage

**Verification.** `tb/cpu_auipc_tb.sv` loads a word and two individual bytes out
of the ROM window, reads the same constant through an AUIPC-relative address,
and confirms a store into region `0x0` leaves the image untouched.

```
cpu_auipc_tb: PASS
```

**Status** — Fixed.

### 7. `.data` and `.bss` were never initialised

**Severity** — Medium. Initialised globals held garbage, zero-initialised
globals held whatever the RAM powered up with.

**Symptom.** `sw/startup.s` set the stack pointer and jumped to `main`. The
linker script placed `.data` in RAM with a load address in ROM but nothing ever
performed the copy, and `.bss` was never cleared. Writing ordinary C with
globals was therefore unsafe.

**Fix.**

- [`sw/linker.ld`](../sw/linker.ld) — export `_data_lma`, `_data_start`,
  `_data_end`, `_bss_start`, `_bss_end` and `_stack_top`
- [`sw/startup.s`](../sw/startup.s) — copy `.data` from ROM to RAM, zero `.bss`,
  then call `main`
- [`tools/build_firmware.sh`](../tools/build_firmware.sh) — add
  `-msmall-data-limit=0`, so nothing lands in `.sdata`/`.sbss` and no
  `gp`-relative addressing is generated for a `gp` that is never set up

The copy loop reads through the ROM data window from finding 6, so this fix
depends on that one.

**Verification.** [`sw/main.c`](../sw/main.c) now prints a banner that is itself
the check: `data_marker` only reads back as `5A5A5A5A` if `.data` was copied out
of ROM, and `bss_marker` only reads back as zero if `.bss` was cleared. The hex
digits come from a `.rodata` table, so the banner also exercises finding 6, and
printing `0x27` correctly instead of `2>` exercises finding 1.

`tb/firmware_boot_tb.sv` runs the real `sw/firmware.hex` on the real SoC and
decodes the UART output bit by bit:

```
firmware_boot_tb: PASS (banner "BOOT 5A5A5A5A 00000000")
```

**Status** — Fixed.

### 8. The ROM image left words undefined past the end of the firmware

**Severity** — Low. Simulation hygiene.

**Symptom.** `sw/firmware.hex` held only as many words as the firmware needed,
172 of 1024, so `$readmemh` warned on every run and left the rest of the ROM at
`x`:

```
WARNING: src/imem.v:13: $readmemh(sw/firmware.hex): Not enough words in the file for the requested range [0:1023].
```

That mattered more once ROM became readable as data, because a stray load would
have returned `x` rather than zero.

**Fix.** [`tools/make_hex.py`](../tools/make_hex.py) pads the image to the full
1024-word ROM depth and now fails loudly if the firmware would overflow it,
which previously would have wrapped silently in `rom[a[11:2]]`.
[`src/imem.v`](../src/imem.v) also clears the array before `$readmemh`.

**Verification.** The suite runs clean:

```
$ bash tools/run_tests.sh 2>&1 | grep -c WARNING
0
```

**Status** — Fixed.

### 9. Documentation described the I2C defect incorrectly

**Severity** — Low, but misleading.

**Symptom.** `README.md` and `docs/design_report.md` both stated that "the NACK
path skips the ninth SCL pulse". Reading the state machine shows `WaitAck` to
`Ack1` to `Ack2` to `AckDone` runs unconditionally, so the ninth pulse is always
present. Measurement showed the opposite of the claim — an extra edge, not a
missing one:

```
NACK frame (no slave): scl rising edges = 10 (I2C requires 9), ack=0
```

**Fix.** The underlying defect is fixed under finding 2, so the limitation is
removed from both documents rather than reworded.

**Status** — Fixed.

### 10. The PCF8574 address was recorded as `0x21`

**Severity** — Low in the RTL, high in the documentation. Five documents stated
the wrong address as measured fact.

**Symptom.** `logs/01-initial-bringup/05-board-uart.log` captured `I2C 21` repeatedly, and that was
written up as "`0x21` is the real PCF8574 address on this backpack rather than
the more common `0x27`". A PCF8574 with A0, A1 and A2 left open answers at
`0x27`; `0x21` needs A0 strapped, which this backpack does not do.

**Cause.** The reading itself was corrupted by finding 1. This is the third
independent symptom of that defect, after `I2C 2>` and the directed distance-3
test. `I2C 2>` already carried the answer and was misread at the time: `'0' + 7`
is `'7'` and `'A' - 10 + 7` is `'>'`, so the low nibble was **7** all along and
the address was always `0x27`.

**Fix.** No RTL change. Corrected the claim in `README.md`,
`docs/design_report.md`, `docs/bringup.md`,
`docs/verification/rv32i_pipeline.md` and `docs/hardware/register_map.md`, and
recorded that an address must only be read off a build carrying finding 1's fix.

**Verification.** On the board, with the fixed bitstream:

```
I2C 27
I2C 27
I2C 27
```

**Status** — Fixed.

---

### Result of the pass

All 22 testbenches pass, including the four new ones:

```
$ bash tools/run_tests.sh
alu_tb: PASS
control_unit_tb: PASS
imm_gen_tb: PASS
regfile_tb: PASS
forwarding_unit_tb: PASS
hazard_detection_unit_tb: PASS
pipe_if_id_tb: PASS
pipe_id_ex_tb: PASS
pipe_ex_mem_tb: PASS
pipe_mem_wb_tb: PASS
uart_rx_tb: PASS
uart_mmio_tb: PASS
clock_enable_divider_tb: PASS
i2c_writeframe_tb: PASS
lcd_write_cmd_data_tb: PASS
i2c_mmio_tb: PASS
lcd_display_tb: PASS
cpu_top_tb: PASS
cpu_hazard_tb: PASS
cpu_auipc_tb: PASS
uart_hex_cpu_tb: PASS
firmware_boot_tb: PASS (banner "BOOT 5A5A5A5A 00000000")
```

Gowin V1.9.12.03 completes the flow for `GW1NR-LV9QN88PC6/I5` with no errors and
no registers inferred as latches. Full output in
`logs/01-initial-bringup/02-fpga-build.log`.

| Metric | Before this pass | After |
|---|---|---|
| Actual Fmax | 34.937 MHz | 31.762 MHz |
| Constraint | 27.000 MHz | 27.000 MHz |
| Deepest logic level | 12 | 15 |
| Setup / hold violated endpoints | 0 / 0 | 0 / 0 |
| Logic | 3167 / 8640 (37%) | 3343 / 8640 (39%) |
| Registers | 1587 / 6693 (24%) | 1588 / 6693 (24%) |
| Registers inferred as latch | 0 | 0 |
| BSRAM | 5 / 26 (20%) | 6 / 26 (24%) |

Timing margin fell from 29% to 18%. The register file bypass puts a mux in the
ID read path and is now on the critical path, which is also what pushed the
deepest logic level from 12 to 15. The design still meets the 27 MHz oscillator
with 4.76 MHz to spare.

The extra BSRAM block is the ROM's second read port. Gowin inferred a dual-port
memory rather than duplicating the 4 KB image, so the cost is one block, not two.

Board measurement has been repeated on the bitstream built from this tree.
Programming reports `User Code is: 0x000003D3` and `Finished.`, and the capture
in `logs/01-initial-bringup/05-board-uart.log` closes the loop on
four of the findings at once:

```
I2C 27
I2C 27
BOOT 5A5A5A5A 00000000
I2C 27
BOOT 5A5A5A5A 00000000
I2C 27
```

| Evidence in the capture | Finding it confirms |
|---|---|
| `5A5A5A5A` | 7 — `.data` was copied out of ROM |
| `00000000` | 7 — `.bss` was cleared |
| The digits themselves, from a `.rodata` table | 6 — the ROM data window answers loads |
| Every address in `startup.s`, formed with AUIPC | 5 |
| `27` rather than `2>` or `21` | 1 and 10 |

The 20x4 LCD shows `HELLO FPGA`.

---

### Still open

Carried forward, not addressed in this pass.

| Item | Impact |
|---|---|
| UART RX has no flow control | The 16-byte FIFO eventually fills if input remains faster than software service |
| ECALL and EBREAK are not implemented | 38 of the 40 RV32I base instructions |
