# Fix log

A running record of defects found in this repository and what was done about
each one. Every entry carries two pieces of evidence: proof the defect was real,
and proof it is gone. Commands are run from
`/home/haihbv/Desktop/work/fpga/thiet_ke_he_thong_so`.

Entries are newest first.

## Contents

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

**Simulation.** [`logs/09-source-layout-refactor.log`](../logs/09-source-layout-refactor.log)
records 29/29 PASS. The only warning is the intentional short-image fixture in
`mem_instruction_rom_tb`; it proves that ROM words beyond the fixture are
zero-filled.

**Build and programming.** The refactored tree was built and programmed after the
simulation run. [`logs/10-source-layout-fpga-build.log`](../logs/10-source-layout-fpga-build.log)
records P&R, timing analysis and bitstream generation complete with Fmax
28.912 MHz, 0 setup/hold violations, 3321/8640 logic cells, 1594/6693 registers
and 6/26 BSRAM. [`logs/11-source-layout-program-board.log`](../logs/11-source-layout-program-board.log)
records SRAM programming at 100% with `Finished.`.

**Status** — Fixed. This is a behavior-preserving refactor. Programming was
verified, but no new UART/LCD capture was taken after the refactored bitstream
was loaded; the functional board evidence remains `logs/05-board-uart.log`.

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

`btn_in`, also a mechanical button, was read combinationally straight into the
GPIO read mux, so a press landing near a clock edge could hand the CPU a
metastable bit. `sda` was sampled for the ACK bit directly off the pad, and the
PCF8574 drives it on its own timing.

`uart_rx_in` was already synchronised with a two-stage chain, so the technique
was present in the design; it had just not been applied evenly.

**Fix.**

- add [`src/reset_sync.v`](../src/reset_sync.v): asynchronous assert, release
  gated through a two-stage chain, and route every module's `rst_n` through it
- synchronise `btn_in` in [`src/gpio.v`](../src/gpio.v) before software can read
  it, resetting the chain high because the button is active low with a pull-up
- synchronise `sda` in [`src/i2c_writeframe.v`](../src/i2c_writeframe.v) before
  the ACK sample, free running on `clk` rather than on the 1 MHz tick, since
  metastability settles in clock cycles

**Verification.** `tb/reset_sync_tb.sv` checks the asymmetry directly: the
output falls when the pin is dropped between clock edges, stays low across five
edges while the pin is held, does not move when the pin is released between
edges, and rises only after the chain has clocked twice. It then repeats the
whole cycle, so the chain is not one-shot.

`tb/gpio_tb.sv` is new and covers the button path end to end, including that a
pin change is invisible after one clock edge and visible after two.

```
reset_sync_tb: PASS
gpio_tb: PASS
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

### Still open from this pass

**No debounce.** Synchronising stops a metastable bit reaching the CPU; it does
not stop a bouncing contact producing several clean transitions. For `rst_n`
that is harmless, since each bounce simply re-asserts reset and the final
release is still clean. For `btn_in` software sees the bounces and would have to
filter them. Left deliberately: debouncing is a policy choice about how long a
press must be held, and belongs with whatever eventually uses the button.

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

**Symptom.** `logs/05-board-uart.log` captured `I2C 21` repeatedly, and that was
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
[../logs/02-fpga-build.log](../logs/02-fpga-build.log).

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
in [../logs/05-board-uart.log](../logs/05-board-uart.log) closes the loop on
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
| UART RX holds a single byte, with no FIFO and no overrun flag | A byte arriving before software reads the previous one is lost |
| FENCE, ECALL and EBREAK are not implemented | 37 of the 40 RV32I base instructions |
| U-type and J-type instructions can trigger a spurious load-use stall | `instr[19:15]` is immediate data for these formats but is still fed to the hazard unit as `rs1`. Costs one cycle, never wrong |
