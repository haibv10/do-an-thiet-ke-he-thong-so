# Design report: RV32I SoC on a Tang Nano 9K FPGA

**Course:** Digital system design
**Device:** Gowin GW1NR-LV9QN88PC6/I5 (Tang Nano 9K), 27 MHz clock
**Languages:** Verilog-2001 (RTL), SystemVerilog (testbenches), C (firmware)

---

## Results at a glance

| Metric | Result |
|---|---|
| Simulation | 18 / 18 testbenches pass |
| Fmax after place and route | 34.937 MHz against a 27 MHz constraint |
| Timing violations | 0 setup, 0 hold |
| Logic utilisation | 3167 / 8640 (37%) |
| Hardware | 20x4 LCD displays `HELLO FPGA`; UART reports the PCF8574 at `0x21` |

---

## 1. Overview

This project builds a complete **system-on-chip**, not just a CPU core. At its
centre is a self-designed 32-bit RISC-V RV32I processor with a five-stage
pipeline. Around it sit instruction memory, data memory and physical
peripherals, all connected to the CPU through a **memory-mapped I/O** bus.

The result behaves like a simple microcontroller: a program written in C is
compiled to RISC-V machine code, loaded into on-chip ROM, and executed to drive
an LED, read a button, talk to a laptop over UART and write to an LCD over I2C.

The design is validated in three independent layers — RTL simulation,
post-synthesis timing analysis, and direct measurement on the board. Every
figure in this report is a measured result.

---

## 2. System architecture

The CPU has no instruction dedicated to peripherals. It knows only two memory
operations: `lw` to read and `sw` to write. The block that turns those two
instructions into hardware control is the **address decoder** — it watches the
top four bits of the address, routes the write strobe to the right device, and
multiplexes read data back.

```text
   ┌──────────────┐          ┌────────────────────────────────┐
   │    IMEM      │  instr   │   RV32I CPU — 5-stage pipeline  │
   │  ROM 4 KB    │ ───────► │      IF · ID · EX · MEM · WB    │
   │ firmware.hex │          └────────────────┬───────────────┘
   └──────────────┘                           │
                                              │ addr · wdata · we_mask
                                              ▼
                              ┌───────────────────────────────┐
                              │        ADDRESS DECODER        │
                              │     selects on addr[31:28]    │
                              └──┬────────┬────────┬───────┬──┘
                                0x2      0x4      0x5     0x6
                                 ▼        ▼        ▼       ▼
                            ┌────────┐┌──────┐┌──────┐┌────────┐
                            │  DMEM  ││ GPIO ││ UART ││  I2C   │
                            │ RAM 4K ││      ││ 8N1  ││ 1 MHz  │
                            │ stack  ││      ││115200││  tick  │
                            └────────┘└──┬───┘└──┬───┘└───┬────┘
                                         │       │        │
                                         ▼       ▼        ▼
                                 ┌───────────┐┌────────┐┌──────────┐
                                 │ LED pin10 ││ TX  34 ││ SDA   31 │
                                 │ btn pin 4 ││ RX  33 ││ SCL   32 │
                                 └───────────┘│→ laptop││→ PCF8574 │
                                              └────────┘└──────────┘
```

### Address map

Only the top four bits partition the space, which makes decoding very cheap in
logic — no 32-bit comparator is needed. Inside each peripheral the low address
bits select a register.

| `addr[31:28]` | Region | Device | Role |
|---|---|---|---|
| `0x0` | `0x00000000` | IMEM (ROM) | Holds machine code, fetched directly by the IF stage |
| `0x2` | `0x20000000` | DMEM (RAM) | Globals and stack |
| `0x4` | `0x40000000` | GPIO | LED output, button input |
| `0x5` | `0x50000000` | UART | Serial link to the laptop |
| `0x6` | `0x60000000` | I2C | 20x4 LCD through a PCF8574 backpack |

Thanks to this scheme, the C statement `*(volatile int *)0x50000000 = 'A';`
executes as an ordinary memory write, but the decoder recognises region `0x5`
and triggers the UART, pushing the character out of a physical pin as an 8N1
frame.

Region `0x0` is deliberately absent from the decoder. The fetch stage reads ROM
directly, so ROM is not reachable over the data bus — a limitation with real
consequences, discussed in section 8.

---

## 3. The CPU core and its five-stage pipeline

The CPU splits instruction execution into five consecutive stages. Between each
pair sits a **pipeline register** that holds data for exactly one clock cycle.
As a result, five different instructions are in flight at any moment.

```text
        ┌─────────────── stall: freeze PC and IF/ID for one cycle ──────┐
        │                                                              │
        ▼                                                              │
   ┌─────────┐ ║ ┌─────────┐ ║ ┌─────────┐ ║ ┌─────────┐ ║ ┌─────────┐ │
   │   IF    │ ║ │   ID    │ ║ │   EX    │ ║ │   MEM   │ ║ │   WB    │ │
   │ PC→IMEM │ ║ │ decode  │ ║ │  ALU    │ ║ │ RAM or  │ ║ │ write   │ │
   │ fetch   │ ║ │ regfile │ ║ │ compare │ ║ │ MMIO,   │ ║ │ back to │ │
   │         │ ║ │ imm_gen │ ║ │ branch  │ ║ │ byte    │ ║ │ regfile │ │
   │         │ ║ │         │ ║ │ target  │ ║ │ align   │ ║ │         │ │
   └─────────┘ ║ └─────────┘ ║ └─────────┘ ║ └─────────┘ ║ └─────────┘ │
             IF/ID        ID/EX     ▲   EX/MEM      MEM/WB             │
                                    │                                  │
                                    │        hazard_detection_unit ─────┘
                                    │
                                    ├──◄── forwarding from MEM
                                    └──◄── forwarding from WB

   ║ = pipeline register (holds data for one cycle)
```

### Implemented instruction set

36 of the 40 RV32I base instructions are implemented.

| Group | Opcode | Instructions |
|---|---|---|
| Register arithmetic | `0110011` | ADD SUB AND OR XOR SLL SRL SRA SLT SLTU |
| Immediate arithmetic | `0010011` | ADDI ANDI ORI XORI SLLI SRLI SRAI SLTI SLTIU |
| Upper immediate | `0110111` | LUI |
| Loads | `0000011` | LB LBU LH LHU LW |
| Stores | `0100011` | SB SH SW |
| Branches | `1100011` | BEQ BNE BLT BGE BLTU BGEU |
| Calls | `1101111` | JAL |
| Returns and indirect jumps | `1100111` | JALR |

**AUIPC, FENCE, ECALL and EBREAK are not implemented.** There is no illegal
instruction trap either, so an unimplemented opcode decodes silently to a NOP.
The consequences of the missing AUIPC are covered in section 8.

Sub-word loads and stores are handled by a dedicated **byte-alignment** circuit
in the MEM stage. On a write it replicates the data across all 32 bits and
generates a 4-bit write mask from the low two address bits; on a read it shifts
the result right and then either sign-extends or zero-fills depending on whether
the instruction is `LB` or `LBU`.

---

## 4. Three pipeline hazards

Running five instructions in parallel creates three situations a naive pipeline
would get wrong. This is the hardest part of the design and the most heavily
verified.

### A. Data hazard — solved by forwarding, zero cycles lost

```text
  cycle:             1     2     3     4     5     6
  add x1, x2, x3    IF    ID    EX   MEM    WB
  sub x4, x1, x5          IF    ID    EX   MEM    WB
                                      ▲
                                      └── taken straight from MEM, no wait for WB
```

When an instruction needs the result of the one immediately before it, that
result is still inside the pipeline and has not reached the register file. The
forwarding unit continuously compares the destination registers in MEM and WB
against the source registers EX needs; on a match it steers a multiplexer so the
ALU takes the value directly. MEM has priority over WB because its data is newer.

### B. Load-use hazard — needs a bubble, one cycle lost

```text
  cycle:             1     2     3     4     5     6     7
  lw  x1, 0(x2)     IF    ID    EX   MEM    WB
  add x3, x1, x4          IF    ID    ··     EX   MEM    WB
                                      ▲
                                      └── bubble: data only exists after MEM
```

This is the one case forwarding cannot rescue. With `lw`, the data only exists
after the MEM stage, while the next instruction needs it in EX — one cycle
earlier. The hazard detection unit recognises this from the `MemRead` signal
plus a register match, then freezes the PC and the IF/ID register for one cycle
while clearing the control bits in ID/EX to create an empty instruction.

### C. Control hazard — needs a flush, two cycles lost

```text
  cycle:             1     2     3     4     5
  beq x1, x2, dest  IF    ID    EX
                                 ▲ condition only known here
  wrongly fetched 1       IF    kill
  wrongly fetched 2             kill
  instruction at dest                  IF    ID   ...
```

The branch condition is evaluated in EX, by which time the pipeline has already
fetched two instructions along the not-taken path. When a branch is actually
taken, both IF/ID and ID/EX are cleared and the PC is steered to the target. The
cost is two cycles per taken branch; the design accepts that trade rather than
adding a branch predictor.

---

## 5. Peripherals

### GPIO

The simplest block in the system: a one-bit register driving the LED and a
direct read path for the button.

| Address | Access | Function |
|---|---|---|
| `0x40000000` | Write / Read | Bit 0 drives the LED; reads return the value written |
| `0x40000004` | Read | Bit 0 reflects the state of button S1 |

### UART — transmit and receive

Both directions use 8N1 framing at 115200 baud. At 27 MHz each bit lasts
`27_000_000 / 115_200 ≈ 234` cycles — that is the `CLKS_PER_BIT` parameter of
both modules.

| Address | Access | Function |
|---|---|---|
| `0x50000000` | Write | Write a byte in `data[7:0]` to start transmission, provided `tx_busy` is 0 |
| `0x50000004` | Read | Status — bit 0 is `tx_busy`, bit 1 is `rx_valid` |
| `0x50000008` | Read | Received byte in `data[7:0]`; the read clears `rx_valid` |

The transmitter is a four-phase state machine — idle, start bit, eight data
bits, stop bit — counting a full 234 cycles per bit before advancing.

The receiver is more involved because its input arrives from the outside world,
unsynchronised to the FPGA clock. The design addresses three problems:

1. **Metastability.** The RX pin passes through two synchroniser flip-flops
   before use, avoiding metastability when a signal edge lands exactly on a
   clock transition.

2. **Mid-bit sampling.** After detecting the falling edge of the start bit, the
   receiver waits *half* a bit time and re-checks — if the line has returned
   high it was noise and the state machine goes back to idle. If it is still
   low, it was a genuine start bit, and from then on every sample lands in the
   **middle** of a bit where the signal is most stable.

   ```text
   RX  ──┐                                                    ┌──── idle
         │ start │ b0  │ b1  │ ... │ b7  │ stop               │
         └───────┴─────┴─────┴─────┴─────┴────────────────────┘
             ▲       ▲     ▲           ▲     ▲
            ½T       └─────┴─── sample mid-bit every 1T
        re-check
   ```

3. **Frame checking.** Data is shifted in LSB-first per the UART standard, and
   `rx_valid` is only raised once the stop bit is confirmed high, so a malformed
   frame is discarded rather than reported as data.

The receiver holds **exactly one byte**. There is no FIFO and no overrun flag: a
new byte overwrites the previous one if software has not read it yet. See
section 8.

### I2C and the LCD

The I2C master is built from two nested state machines. `i2c_writeframe` drives
one 8-bit frame — START, eight data bits, ACK, optional STOP.
`lcd_write_cmd_data` sits above it and turns one LCD byte into the five frames a
PCF8574 backpack needs: the slave address, then the high nibble twice and the
low nibble twice, toggling the LCD enable line between them.

| Address | Access | Function |
|---|---|---|
| `0x60000000` | Write | `data[7:0]` is the byte; `data[8]` selects command (0) or display data (1) |
| `0x60000004` | Read | Bit 0 is `busy`, bit 1 is the `ack` result |
| `0x60000008` | Write | 7-bit slave address, defaults to `0x27` |

Both state machines run in the **CPU's 27 MHz clock domain** and step on a 1 MHz
tick enable from `clock_enable_divider`. An earlier version clocked them from a
separately divided 1 MHz clock, which meant a one-cycle CPU write strobe could
be missed entirely. Keeping a single clock domain removes that class of bug.

SCL and SDA are driven **open-drain**: the master either pulls the line low or
releases it to high-Z and lets the pull-up do the rest, as the I2C standard
requires.

---

## 6. Software and build flow

The program running on the CPU is written in C and compiled with the standard
RISC-V toolchain using `-march=rv32i -mabi=ilp32 -nostdlib`. An assembly startup
stub sets the stack pointer to the top of RAM and jumps to `main`; the linker
script maps `.text` into ROM and `.data`/`.bss` into RAM according to the
hardware address map.

```text
  main.c  ──gcc + linker.ld──►  firmware.elf  ──objcopy──►  firmware.bin
                                                                 │
                                                          make_hex.py
                                                                 ▼
                          IMEM  ◄──$readmemh at elaboration──  firmware.hex
```

The demo program exercises all three MMIO blocks:

```c
/* sw/main.c — boot banner, I2C scan, LCD output */
uart_putc('B'); uart_putc('O'); uart_putc('O'); uart_putc('T');

lcd_address = lcd_find_address();        /* scan 0x20-0x27 and 0x38-0x3f */
if (lcd_address >= 0) {
  lcd_init();
  lcd_command(0x80);                     /* cursor to row 1 */
  lcd_data('H'); lcd_data('E'); lcd_data('L'); lcd_data('L'); lcd_data('O');
}

while (1) {
  uart_putc('I'); uart_putc('2'); uart_putc('C'); uart_putc(' ');
  uart_hex((unsigned char)lcd_address);  /* report the address found */
  delay_cycles(27000000);
}
```

Characters are emitted one at a time rather than from a string literal. That is
not a style choice: string literals live in `.rodata` inside ROM, and ROM is not
readable over the data bus, so a string read would return zeros. See section 8.

The whole program uses nothing but `volatile` pointer assignments — no library,
no operating system. That is the direct proof that memory-mapped I/O works:
software controls hardware using exactly the instructions the CPU already has.

---

## 7. Verification

The design is confirmed in three independent layers, each catching a different
class of fault: simulation catches logic errors, timing analysis catches speed
errors, and board measurement catches physical integration errors.

### Layer 1 — RTL simulation

```bash
bash tools/run_tests.sh
```

Eighteen self-checking testbenches run under Icarus Verilog; all pass.

| Testbench | What it checks |
|---|---|
| `alu_tb` | All arithmetic, logic and shift operations |
| `control_unit_tb` | Opcode decoding into control signals |
| `imm_gen_tb` | Immediate generation for every instruction format |
| `forwarding_unit_tb` | MEM-before-WB priority |
| `hazard_detection_unit_tb` | Correct detection of the load-use case |
| `pipe_if_id_tb` | Reset, stall and flush behaviour |
| `pipe_id_ex_tb` | Control signal propagation and clearing on flush |
| `pipe_ex_mem_tb` | Latching of the ALU result and branch target |
| `pipe_mem_wb_tb` | Selection between memory data and ALU result |
| `uart_rx_tb` | Start and stop bits, LSB-first assembly, false start rejection, framing error recovery |
| `uart_mmio_tb` | Status register, RX read-clear semantics, TX busy flag |
| `clock_enable_divider_tb` | Tick period |
| `i2c_writeframe_tb` | START, eight data bits, ACK and NACK paths |
| `lcd_write_cmd_data_tb` | The five-frame nibble sequence for one LCD byte |
| `i2c_mmio_tb` | MMIO handshake, busy flag, ACK capture |
| `lcd_display_tb` | The standalone 20x4 sequencer, all 89 output bytes |
| `cpu_top_tb` | Full system integration (below) |
| `uart_hex_cpu_tb` | The `sltiu` plus branch sequence used by hex formatting |

`cpu_top_tb` is the most important integration test: it loads a short RV32I
program exercising forwarding, load-use stalling, branch and JAL flushing,
sub-word memory access, GPIO MMIO, and a complete echo loop that drives `0xA5`
into the RX pin and checks the CPU transmits the same byte back.

### Layer 2 — Synthesis and timing analysis

Gowin EDA V1.9.12.03 completes synthesis, placement, routing, timing analysis
and bitstream generation for the GW1NR-9C against the 27 MHz constraint in
`constr/fpga_project.sdc`.

| Metric | Result | Assessment |
|---|---|---|
| Clock constraint | 27.000 MHz | Onboard oscillator |
| Actual Fmax | 34.937 MHz | 29% margin |
| Setup violated endpoints | 0 | Pass |
| Hold violated endpoints | 0 | Pass |
| Deepest logic level | 12 | Critical path is in the EX stage |
| Logic | 3167 / 8640 (37%) | — |
| Registers | 1587 / 6693 (24%) | — |
| Registers inferred as latch | 0 / 6480 (0%) | Both I2C state machines have explicit default states |
| CLS | 2615 / 4320 (61%) | — |
| BSRAM | 5 / 26 (20%) | IMEM and DMEM |
| I/O ports | 8 / 71 (12%) | — |

Raw log: `logs/02-fpga-build.log`.

### Layer 3 — Board measurement

The bitstream is written into the Tang Nano 9K SRAM over JTAG. The laptop talks
to the board through an external USB-UART module at 115200 baud, 8N1, raw, no
flow control.

| Stimulus | Result | Evidence |
|---|---|---|
| Reset with no device wired | repeated `I2C NACK` | `logs/06-fault-i2c-nack.log` |
| Reset, firmware reading `.rodata` | `I2C ` followed by two `0x00` bytes | `logs/07-fault-rodata-null.log` |
| Reset, hex formatter using the A-F branch | `I2C 2>` instead of `I2C 27` | `logs/08-fault-hex-branch.log` |
| Reset, current firmware | `I2C 21` repeated, LCD shows `HELLO FPGA` | `logs/05-board-uart.log` |

Earlier UART-only measurements with the echo firmware are recorded in
`docs/verification/rv32i_pipeline.md`, including the finding that a 1024-byte
burst loses roughly 0.3% of the stream because the receiver holds only one byte.

The LED result reads inverted with respect to the value software writes, but
that is a board convention rather than a data-path fault: the onboard LED on the
Tang Nano 9K is **active low**. Reading the GPIO register back always returns
exactly what was written.

### Process note — a bring-up lesson

During bring-up the system emitted a repeated `0x56` at roughly 2.6 Hz with the
RX pin completely idle. The symptom looked exactly like an RTL fault.

Isolation method: program two minimal test bitstreams.

1. The first wires `uart_tx_out = uart_rx_in` directly, proving the pin
   assignment and the physical link to the laptop are correct.
2. The second wires `uart_rx` straight into `uart_tx` without the CPU, proving
   the serial RTL is correct.

The real cause: the FPGA was stuck in a corrupted configuration state.
Reprogramming a **byte-identical** bitstream made the symptom vanish. The rule
adopted into the workflow: always reprogram immediately before measuring. Full
bring-up procedure in `docs/bringup.md`.

---

## 8. Limitations and future work

### The register file has no WB-to-ID bypass

The forwarding unit covers EX/MEM and MEM/WB into EX, which handles RAW hazards
at distances one and two. At distance three the consuming instruction is in ID
during the same cycle the producer writes the register file, and the register
file reads combinationally with no internal bypass — so it reads the stale
value. A directed test confirms it:

```text
  source  | distance | expected | actual
  --------+----------+----------+--------
  x1 = 7  |     1    |     7    |  7
  x2 = 8  |     2    |     8    |  8
  x3 = 9  |     3    |     9    |  0     ← wrong
  x4 = 10 |     4    |    10    |  10
```

This surfaced on hardware as `I2C 2>` instead of `I2C 27`: the hex formatter's
`sltiu` plus branch sequence selected the wrong character branch. The firmware
now avoids that branch, but the defect itself is still open. The fix is a
two-line write-first bypass inside `regfile.v`.

### AUIPC is not implemented

Opcode `0010111` is absent from both the control unit and the immediate
generator, so it decodes silently to a NOP. GCC emits AUIPC for `la` and for
far calls, so this blocks any use of globals or string literals.

### ROM is not readable over the data bus

The address decoder has no region `0x0`. `.rodata` therefore reads back as zero,
which is why the firmware spells out characters instead of using string
literals. Adding a read path from IMEM into the decoder would fix it.

### `.data` and `.bss` are not initialised

The linker script places both sections in RAM, but `startup.s` only sets the
stack pointer and jumps to `main` — nothing copies `.data` from its load address
and nothing zeroes `.bss`. The current firmware uses no globals, so this has not
yet surfaced. Together with the two items above, it is the third independent
reason globals are unusable today.

### UART RX has no FIFO

The receiver holds a single byte. It cannot sustain an unbounded stream: at
115200 baud a transmit frame occupies ten bit times, which leaves the polling
loop no slack against a host sending continuously. Bursts up to 256 bytes are
lossless; a 1024-byte burst loses roughly 0.3%. Lossless sustained streaming
requires a FIFO or hardware flow control, which this design deliberately does
not implement.

### I2C does not emit a compliant STOP condition

In the `PreStop` state SCL rises while SDA is still released high, so the
transition that defines a STOP never happens. Whether anything resembling a STOP
appears on the bus depends on the least significant bit of the last byte sent.
The NACK path additionally skips the ninth SCL pulse, leaving an 8-clock frame
where the protocol requires nine. The PCF8574 tolerates both, which is why the
LCD demo works, but the bus is not standard-compliant.

### No branch prediction

Every taken branch costs two cycles. For the current small programs this is
negligible, but it is the clearest performance improvement available.

---

## Appendix — repository layout

```text
src/      SoC RTL: cpu_top, pipeline stages, alu, control_unit, regfile,
          imm_gen, forwarding_unit, hazard_detection_unit, imem, dmem,
          address_decoder, gpio, uart_tx, uart_rx, uart_mmio,
          i2c_mmio, i2c_writeframe, lcd_write_cmd_data, clock_enable_divider
constr/   Pin (.cst) and timing (.sdc) constraints
tb/       18 self-checking SystemVerilog testbenches
sw/       C firmware: main.c, startup.s, linker.ld, firmware.hex
tools/    Scripts for firmware, bitstream, programming and tests
docs/     Design report, register map, bring-up notes, verification results
logs/     Curated verification evidence
```
