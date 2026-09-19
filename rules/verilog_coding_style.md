# Verilog / SystemVerilog Coding Style Guide

## 1. Purpose

This document defines the coding conventions for FPGA RTL development using Verilog/SystemVerilog.

The goals are:

* Keep RTL code consistent and readable.
* Make code easy to review and maintain.
* Reduce simulation/synthesis mismatches.
* Make synthesis and linting more predictable.
* Make RTL suitable for AI-assisted code generation and code review.

The default language standard is **SystemVerilog-2017**.

Use SystemVerilog constructs where supported instead of legacy Verilog constructs.

---

## 2. General Rules

### 2.1 Language, and which half of the tree you are in

This repository uses two language standards, split by role.

| Role | Files | Standard |
|---|---|---|
| Synthesizable RTL | `source/**/*.v`, `libs/**/*.v` | Verilog-2001 |
| Verification | `sim/**/*.sv`, `libs/**/*_tb.sv` | SystemVerilog-2017 |

**Synthesizable RTL is Verilog-2001.** The target is a Gowin GW1NR-9C built with
GowinSynthesis, whose Verilog-2001 path is the one this design is closed on;
`tools/build_gowin.tcl` pins `-verilog_std v2001` to say so explicitly. The
design sits at roughly 7% timing margin, so changing the elaboration path is not
a free refactor: it can change inference and therefore placement. RTL therefore
uses `reg`, `wire`, `always @(posedge clk ...)` and `always @(*)`.

```verilog
module core_pc (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        stall,
  input  wire [31:0] pc_next,
  output reg  [31:0] pc
);
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)      pc <= 32'h00000000;
    else if (!stall) pc <= pc_next;
  end
endmodule
```

**Verification is SystemVerilog-2017.** Testbenches are never synthesized, so
nothing is gained by holding them back. Use `logic`, `always_comb`/`always_ff`,
`.*` port connection, `automatic` tasks and functions, `string`, and `$fatal`
with a message that names the expected and actual values.

```systemverilog
module pc_reg_tb;
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  ...
  pc_reg dut (.*);
```

Examples further down this guide are written in whichever form makes the point
clearest, and several use `always_ff` or `always_comb` because the rule under
discussion is about the block, not the keyword. Sections 12 and 13 govern which
keyword actually belongs in which half of the tree.

### 2.2 Constructs to use inside each half

In RTL:

* `localparam` for local constants, including FSM state encodings.
* Parameters for anything a caller may need to override.
* Non-blocking assignment in sequential blocks, blocking in combinational ones.
* A `default` arm on every `case`.

In testbenches, additionally:

* `logic` rather than `reg`/`wire`.
* `always_ff` and `always_comb` where the intent is worth stating.
* `assert` or an explicit `$fatal`, never a silent check.

### 2.3 When this guide and the tree disagree

One of the two is wrong, and leaving them to disagree quietly is what makes a
style guide decorative. Either change the code or change this document, in the
same commit that notices the gap.

The deviations below are deliberate and are not to be "fixed":

| Guide says | This repository does | Because |
|---|---|---|
| `logic`, `always_ff`, `always_comb` in RTL | `reg`/`wire`, `always @` | Verilog-2001 synthesis path, see 2.1 |
| Ports suffixed `_i`, `_o`, `_ni` | Plain functional names | `constr/fpga_project.cst` binds pins to these exact names |
| No `initial` in synthesizable modules | `initial` with `$readmemh` in `mem_instruction_rom.v` | The standard way to give an FPGA block RAM its contents |

---

## 3. File Naming

Use lowercase `snake_case` for RTL source files.

Good:

```text
uart_rx.sv
uart_tx.sv
fifo_sync.sv
axi_lite_slave.sv
packet_parser.sv
clock_divider.sv
```

Avoid:

```text
UART_RX.sv
uartRx.sv
UART-TX.sv
```

Testbench files should use a clear suffix:

```text
uart_rx_tb.sv
fifo_sync_tb.sv
packet_parser_tb.sv
```

---

## 4. Module Naming

Module names must use lowercase `snake_case`.

Good:

```systemverilog
module uart_rx (
    ...
);
```

```systemverilog
module packet_parser (
    ...
);
```

Avoid:

```systemverilog
module UART_RX (
    ...
);
```

```systemverilog
module packetParser (
    ...
);
```

The module name should describe the hardware function rather than the implementation.

Good:

```text
uart_rx
fifo_sync
spi_master
packet_parser
clock_divider
```

Avoid vague names:

```text
module block1
module test
module logic
module module_a
```

---

## 5. Signal Naming

Use lowercase `snake_case`.

```systemverilog
logic        enable;
logic        valid;
logic        ready;
logic [31:0] data;
logic [7:0]  counter;
```

Signal names should describe their meaning.

Bad:

```systemverilog
logic a;
logic b;
logic tmp;
logic x1;
```

unless the meaning is genuinely local and obvious.

Prefer:

```systemverilog
logic        packet_valid;
logic        packet_ready;
logic [31:0] packet_data;
```

---

## 6. Input / Output Naming

Ports take plain functional names. The direction is already in the declaration,
and the top-level names are bound to physical pins in
`constr/fpga_project.cst`, so a rename is a change to the constraints as well.

```verilog
module uart_rx #(
  parameter CLKS_PER_BIT = 234
) (
  input  wire       clk,
  input  wire       rst_n,
  input  wire       rx,
  input  wire       clear,
  output reg  [7:0] data,
  output reg        valid
);
```

Name a port for what it carries, not for where it goes. Where a module has both
a register-facing and a pin-facing version of a signal, distinguish them by
function: `sda` is the pad, `sda_in` is the value read back from it, `sda_out`
is the value driven onto it.

---

## 7. Clock Naming

The primary clock is named:

```text
clk
```

Additional clock domains should have explicit names:

```text
clk_axi
clk_uart
clk_pixel
clk_dma
clk_mem
```

Example:

```verilog
input wire clk;
input wire clk_axi;
input wire clk_uart;
```

This design has a single 27 MHz domain. Slower rates are derived as **clock
enables**, never as separately divided clocks, so that everything stays on one
clock tree: see `clock_enable.v` and the `tick` input on the I2C
modules. A divided clock would create a second domain and with it a crossing to
get wrong.

Do not use ambiguous names:

```text
clock1
clock2
clk1
clk2
```

when multiple clock domains exist.

---

## 8. Reset Naming

Use `_n` to indicate an active-low reset.

Examples:

```text
rst_n
rst_axi_n
rst_uart_n
```

Use `_n` only when the signal is actually active-low.

For active-high reset:

```text
rst
```

Do not name an active-high reset:

```text
rst_n
```

The reset polarity must always match the name.

---

## 9. Register Naming

Use `_q` for the current registered value.

Use `_d` for the next value.

Example:

```systemverilog
logic [7:0] data_q;
logic [7:0] data_d;

logic       busy_q;
logic       busy_d;
```

Typical structure:

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_q <= '0;
    end else begin
        data_q <= data_d;
    end
end

always_comb begin
    data_d = data_q;

    if (enable) begin
        data_d = data_q + 8'd1;
    end
end
```

This naming convention makes the RTL data flow explicit:

```text
data_q → current register
data_d → next register value
```

---

## 10. Parameter and Constant Naming

Use `UPPER_SNAKE_CASE` for constants.

```systemverilog
localparam int unsigned DATA_WIDTH = 32;
localparam int unsigned FIFO_DEPTH = 1024;
localparam int unsigned TIMEOUT_CYCLES = 1000;
```

Do not use unexplained magic numbers.

Bad:

```systemverilog
if (counter_q == 32'd1000000) begin
```

Good:

```systemverilog
localparam int unsigned TIMEOUT_CYCLES = 1_000_000;

if (counter_q == TIMEOUT_CYCLES) begin
```

Prefer symbolic constants because they make the intent clear and simplify future changes.

---

## 11. Indentation and Formatting

Use spaces, not tabs.

Recommended indentation:

```text
4 spaces per indentation level
```

Example:

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        counter_q <= '0;
    end else begin
        if (enable) begin
            counter_q <= counter_q + 1'b1;
        end
    end
end
```

Use spaces around operators:

```systemverilog
a = b + c;
x = (a && b);
count_q <= count_q + 1'b1;
```

Avoid:

```systemverilog
a=b+c;
x=(a&&b);
count_q<=count_q+1'b1;
```

Do not use trailing whitespace.

---

## 12. Sequential Logic

In RTL, sequential logic uses `always @(posedge clk)`. In testbenches, prefer
`always_ff`, which lets the tool check the intent.

```verilog
always @(posedge clk) begin
    q <= d;
end
```

With asynchronous active-low reset:

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        q <= 32'd0;
    end else begin
        q <= d;
    end
end
```

Reset every register the block drives, in the reset branch. A register left out
of that branch powers up undefined and, if it drives a pad, can hold an external
bus in a stuck state before the design has run a single cycle.

Sequential logic must use **non-blocking assignments**:

```systemverilog
q <= d;
```

Do not use blocking assignments inside `always_ff`:

```systemverilog
q = d;
```

Keep sequential blocks simple.

Prefer:

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        counter_q <= '0;
    end else begin
        counter_q <= counter_d;
    end
end
```

over putting complicated combinational calculations directly inside the sequential block.

---

## 13. Combinational Logic

In RTL, use `always @(*)`. In testbenches, prefer `always_comb`.

```verilog
always @(*) begin
    data_next = data;

    if (enable) begin
        data_next = data + 1'b1;
    end
end
```

Assign every output on every path, or the block infers a latch. Section 14 says
how to check that it did not.

Combinational logic must use **blocking assignments**:

```systemverilog
data_d = data_q;
```

Do not use:

```systemverilog
data_d <= data_q;
```

Prefer continuous assignments when the logic is simple:

```systemverilog
assign valid = valid_q && ready_in;
```

instead of:

```systemverilog
always_comb begin
    valid = valid_q && ready_in;
end
```

---

## 14. Avoid Latches

Combinational blocks must assign every output on every possible execution path.

Bad:

```systemverilog
always_comb begin
    if (enable) begin
        data_d = data_q + 1'b1;
    end
end
```

`data_d` is not assigned when `enable == 0`, which can infer a latch.

Good:

```systemverilog
always_comb begin
    data_d = data_q;

    if (enable) begin
        data_d = data_q + 1'b1;
    end
end
```

A default assignment at the beginning of the combinational block is strongly recommended.

Latches should not be inferred unless intentionally required by the design.

---

## 15. Blocking vs Non-Blocking

Use the following rule:

```text
always_ff   → <=
always_comb → =
assign      → =
```

Example:

```systemverilog
always_ff @(posedge clk) begin
    counter_q <= counter_d;
end
```

```systemverilog
always_comb begin
    counter_d = counter_q + 1'b1;
end
```

Never mix blocking and non-blocking assignments arbitrarily.

---

## 16. One Register, One Sequential Driver

A register should normally be assigned in only one `always_ff` block.

Bad:

```systemverilog
always_ff @(posedge clk) begin
    data_q <= data_d;
end

always_ff @(posedge clk) begin
    data_q <= '0;
end
```

Good:

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_q <= '0;
    end else if (enable) begin
        data_q <= data_d;
    end
end
```

Do not create multiple procedural drivers for the same register.

---

## 17. FSM Coding Style

Finite State Machines should normally use a two-process structure:

```text
Process 1:
state register

Process 2:
next-state combinational logic
```

Example:

```systemverilog
typedef enum logic [1:0] {
    ST_IDLE,
    ST_START,
    ST_RUN,
    ST_DONE
} state_t;

state_t state_q;
state_t state_d;
```

State register:

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state_q <= ST_IDLE;
    end else begin
        state_q <= state_d;
    end
end
```

Next-state logic:

```systemverilog
always_comb begin
    state_d = state_q;

    unique case (state_q)
        ST_IDLE: begin
            if (start) begin
                state_d = ST_START;
            end
        end

        ST_START: begin
            state_d = ST_RUN;
        end

        ST_RUN: begin
            if (done) begin
                state_d = ST_DONE;
            end
        end

        ST_DONE: begin
            state_d = ST_IDLE;
        end

        default: begin
            state_d = ST_IDLE;
        end
    endcase
end
```

The default next state should normally be the current state:

```systemverilog
state_d = state_q;
```

Always provide a `default` case.

Do not perform unrelated sequential operations inside the state register process.

---

## 18. Case Statements

Prefer `unique case` when the cases are mutually exclusive and the design intent supports it.

```systemverilog
unique case (state_q)
    ST_IDLE:  ...
    ST_RUN:   ...
    ST_DONE:  ...
    default:  ...
endcase
```

Always provide a `default` branch.

Do not use:

```systemverilog
// synopsys full_case
// synopsys parallel_case
```

or equivalent case pragmas to hide incomplete logic.

These constructs can cause simulation/synthesis mismatches.

---

## 19. Logical vs Bitwise Operators

Use logical operators for control conditions:

```systemverilog
if (valid_in && ready_in) begin
    ...
end
```

Use bitwise operators for data:

```systemverilog
assign result = data_a & data_b;
```

Examples:

```text
Logical:
!   &&   ||   ==   !=

Bitwise:
~   &    |    ^
```

Good:

```systemverilog
if (!rst_n) begin
    ...
end
```

Good:

```systemverilog
assign data_out = data_a & data_b;
```

Avoid using bitwise operators in control expressions when logical operators better express the intent.

---

## 20. Width and Literal Rules

Always make important literal widths explicit.

Good:

```systemverilog
logic [7:0] data;

data = 8'hFF;
data = 8'd100;
data = 8'b1010_1010;
```

Use `_` to improve readability:

```systemverilog
32'hDEAD_BEEF
32'd1_000_000
8'b1010_1100
```

For clearing a vector, prefer:

```systemverilog
data_q <= '0;
```

For setting all bits:

```systemverilog
data_q <= '1;
```

Avoid relying on implicit width extension or truncation when the width matters.

---

## 21. Signed and Unsigned Arithmetic

Be explicit about signed arithmetic.

Example:

```systemverilog
logic signed [15:0] temperature;
logic signed [15:0] offset;
logic signed [16:0] result;
```

Do not mix signed and unsigned signals without explicitly considering the resulting width and sign extension.

When arithmetic crosses different widths, make the intended width explicit.

---

## 22. Avoid Magic Numbers

Bad:

```systemverilog
if (state_q == 3'd5) begin
```

Good:

```systemverilog
localparam int unsigned STATE_TIMEOUT = 5;

if (counter_q == STATE_TIMEOUT) begin
```

For protocol fields or register addresses, use named constants:

```systemverilog
localparam logic [7:0] CMD_READ  = 8'h01;
localparam logic [7:0] CMD_WRITE = 8'h02;
```

---

## 23. Avoid `X` Assignments in RTL

Do not use `X` assignments to indicate don't-care conditions in synthesizable RTL.

Avoid:

```systemverilog
data_out = 8'hXX;
```

or:

```systemverilog
data_out = 'x;
```

Instead, fully define the RTL behavior and use assertions or verification logic to detect invalid conditions.

---

## 24. Avoid Unnecessary Tri-State Logic

Do not use internal tri-state logic for ordinary on-chip muxing.

Bad:

```systemverilog
assign bus = enable_a ? data_a : 'z;
assign bus = enable_b ? data_b : 'z;
```

Prefer explicit mux logic:

```systemverilog
assign bus = enable_a ? data_a :
             enable_b ? data_b :
             '0;
```

Tri-state buffers should normally be restricted to actual FPGA I/O requirements.

---

## 25. Continuous Assignments

Use `assign` when the combinational logic is simple.

Good:

```systemverilog
assign ready = ready_q;
assign valid = valid_q && enable;
assign empty = (count_q == '0);
```

Use `always_comb` when the combinational logic becomes more complex:

```systemverilog
always_comb begin
    ...
end
```

Do not unnecessarily create an `always_comb` block for a single simple expression.

---

## 26. Module Ports

Use ANSI-style module declarations.

Good:

```systemverilog
module fifo_sync #(
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned DEPTH      = 16
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic [DATA_WIDTH-1:0] data_in,
    input  logic                  valid_in,
    output logic                  ready,
    output logic [DATA_WIDTH-1:0] data_out
);
```

Avoid old-style declarations:

```verilog
module fifo_sync (
    clk,
    rst,
    data
);

input clk;
input rst;
input [31:0] data;
```

---

## 27. Parameterization

Hardware modules should be parameterized when the same RTL can reasonably support different configurations.

Example:

```systemverilog
module counter #(
    parameter int unsigned WIDTH = 32
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    output logic [WIDTH-1:0] count
);
```

Do not parameterize everything unnecessarily.

A parameter should represent a meaningful design configuration.

---

## 28. Generate Blocks

Generate blocks should have explicit labels.

Good:

```systemverilog
genvar i;

generate
    for (i = 0; i < WIDTH; i++) begin : gen_bit
        ...
    end
endgenerate
```

Use meaningful labels:

```text
gen_bit
gen_channel
gen_lane
gen_fifo
gen_register
```

Avoid meaningless labels:

```text
gen1
gen2
foo
bar
```

---

## 29. Comments

Comments should explain **why**, not simply repeat **what** the code does.

Bad:

```systemverilog
// Increment counter
counter_q <= counter_q + 1'b1;
```

Better:

```systemverilog
// Count the number of clock cycles while waiting for the response.
counter_q <= counter_q + 1'b1;
```

For non-obvious hardware behavior, explain the design reason.

```systemverilog
// Two flip-flop synchronizer is required because ack
// originates in the asynchronous clock domain.
```

Do not write comments that become incorrect when the code changes.

---

## 30. TODO and FIXME

Use standard tags:

```systemverilog
// TODO: Add timeout handling.
```

```systemverilog
// FIXME: This logic currently assumes a single-cycle response.
```

If a coding-style rule is intentionally violated, explain why:

```systemverilog
// Style exception: blocking assignment is required here because
// this legacy vendor primitive expects procedural combinational logic.
```

---

## 31. Clock Domain Crossing

Signals crossing between asynchronous clock domains must not be treated as ordinary signals.

For a single-bit control signal, use an appropriate synchronizer.

Example:

```systemverilog
logic sync_ff1_q;
logic sync_ff2_q;

always_ff @(posedge clk_dst or negedge rst_dst_n) begin
    if (!rst_dst_n) begin
        sync_ff1_q <= 1'b0;
        sync_ff2_q <= 1'b0;
    end else begin
        sync_ff1_q <= signal_src;
        sync_ff2_q <= sync_ff1_q;
    end
end
```

Do not directly consume asynchronous signals in synchronous logic.

For multi-bit data, use an appropriate CDC architecture such as:

```text
asynchronous FIFO
handshake
Gray-coded counter
protocol-specific CDC mechanism
```

Do not assume that independently synchronizing each bit of a multi-bit bus is sufficient.

---

## 32. Reset Synchronization

Reset strategy must be consistent across the design.

If an external reset is asynchronous, synchronize deassertion appropriately for the target FPGA architecture when required.

Do not arbitrarily mix synchronous and asynchronous reset behavior between related logic blocks.

Reset naming must always match polarity.

---

## 33. Hardware Intent Must Be Explicit

RTL describes hardware, not software.

Every construct should have an intentional hardware interpretation.

Before writing code, determine whether the logic represents:

```text
flip-flop
combinational logic
latch
FIFO
RAM
ROM
FSM
counter
pipeline
clock-domain crossing
synchronizer
```

Avoid writing RTL that relies on accidental synthesis behavior.

---

## 34. Avoid Deeply Nested RTL

Prefer simple and readable structures.

Avoid:

```systemverilog
if (...) begin
    if (...) begin
        if (...) begin
            if (...) begin
                ...
            end
        end
    end
end
```

When logic becomes deeply nested, consider:

* splitting the logic into smaller blocks;
* creating intermediate signals;
* using an FSM;
* using functions where appropriate.

The objective is to make the hardware behavior easy to understand.

---

## 35. Avoid Multiple Assignments to the Same Register

Do not write:

```systemverilog
always_ff @(posedge clk) begin
    if (cond_a) begin
        data_q <= value_a;
    end

    if (cond_b) begin
        data_q <= value_b;
    end
end
```

Even when conditions are currently mutually exclusive, this creates ambiguous priority.

Prefer:

```systemverilog
always_ff @(posedge clk) begin
    if (cond_a) begin
        data_q <= value_a;
    end else if (cond_b) begin
        data_q <= value_b;
    end
end
```

---

## 36. Register Enable Coding

Prefer explicit enable logic.

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_q <= '0;
    end else if (enable) begin
        data_q <= data_d;
    end
end
```

If `enable` is low, the register naturally retains its value.

Do not unnecessarily write:

```systemverilog
else begin
    data_q <= data_q;
end
```

The self-assignment is unnecessary.

---

## 37. Pipeline Registers

Pipeline stages should have clear names.

Good:

```systemverilog
logic [31:0] data_stage1_q;
logic [31:0] data_stage2_q;
logic [31:0] data_stage3_q;
```

For valid pipelines:

```systemverilog
logic valid_stage1_q;
logic valid_stage2_q;
logic valid_stage3_q;
```

The valid signal must be pipelined consistently with the associated data.

---

## 38. Interface and Handshake Signals

For ready/valid interfaces, use consistent naming:

```text
valid_in
ready_in
valid
ready
data_in
data_out
```

A transfer occurs when:

```systemverilog
valid_in && ready
```

Do not invent different names for the same protocol concept across modules.

---

## 39. Register and Memory Interfaces

Use explicit names for address, data, byte enable and control signals.

Example:

```systemverilog
logic [31:0] addr;
logic [31:0] wdata;
logic [31:0] rdata;
logic [3:0]  byte_en;
logic        write_en;
logic        read_en;
```

For interfaces with established protocol naming, follow the protocol specification.

Do not rename standard protocol signals unnecessarily.

---

## 40. Assertions

Assertions should be used to verify important design assumptions.

Example:

```systemverilog
assert property (@(posedge clk)
    valid_in |-> ready);
```

Assertions are preferred over propagating `X` values to represent illegal states.

For critical protocols, assertions should check:

```text
protocol timing
valid/ready behavior
FSM legality
FIFO overflow
FIFO underflow
request/response relationship
reset behavior
CDC assumptions
```

---

## 41. Linting

RTL should be checked with a SystemVerilog-aware linter.

Lint should detect at least:

```text
multiple drivers
unused signals
implicit nets
width mismatch
signed/unsigned mismatch
latch inference
blocking assignment in sequential logic
non-blocking assignment in combinational logic
incomplete case
unreachable code
clock/reset issues
```

Coding conventions should be enforceable by tools whenever possible.

The lowRISC/OpenTitan ecosystem, for example, maintains lint rules corresponding to many of its SystemVerilog style requirements.

---

## 42. `default_nettype`

Avoid accidental implicit nets.

Where compatible with the project and toolchain, use:

```systemverilog
`default_nettype none
```

at the appropriate project level.

This helps detect undeclared signals caused by typos.

Be careful to restore the default when required by external IP or legacy source files.

---

## 43. Tool and Vendor Compatibility

FPGA projects may use vendor-specific tools such as:

```text
AMD/Xilinx Vivado
Intel Quartus
Lattice Radiant
Lattice Diamond
Microchip Libero
```

Vendor-specific primitives and constraints are allowed when required.

However, vendor-specific code should be isolated where practical.

Example:

```text
rtl/
vendor/
constraints/
```

Do not introduce vendor-specific constructs into generic RTL unless necessary.

---

## 44. Synthesizable RTL

Production RTL must be synthesizable unless the file is explicitly designated as simulation/testbench code.

Avoid simulation-only constructs in synthesizable modules:

```verilog
#10
$display(...)
$finish
```

Simulation-specific code belongs in testbench or verification files.

`initial` with `$readmemh` is the exception. It is how an FPGA block RAM is
given its contents, and every vendor supports it for that purpose:

```verilog
initial begin
  for (index = 0; index < 1024; index = index + 1) rom[index] = 32'd0;
  $readmemh(HEX_PATH, rom);
end
```

Clear the array before reading the file. `$readmemh` leaves anything past the
end of the image untouched, so without the loop a stray read returns `x` in
simulation and the file itself has to cover the whole depth to avoid a warning.

---

## 45. Reset Values

Every important register should have an intentional reset behavior when required by the architecture.

Good:

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        valid_q <= 1'b0;
        state_q <= ST_IDLE;
        count_q <= '0;
    end else begin
        ...
    end
end
```

Do not add reset to every register automatically.

For FPGA designs, reset usage should consider:

* FPGA architecture
* initialization support
* timing
* fanout
* resource usage
* system requirements

---

## 46. Avoid Unnecessary Logic Duplication

If the same expression is used repeatedly and has meaningful intent, consider creating an intermediate signal.

Instead of:

```systemverilog
if ((valid_in && ready_in) && (count_q < FIFO_DEPTH)) begin
    ...
end

assign busy = (valid_in && ready_in) && (count_q < FIFO_DEPTH);
```

Prefer:

```systemverilog
logic transfer_allowed;

assign transfer_allowed = valid_in &&
                           ready_in &&
                           (count_q < FIFO_DEPTH);
```

Then:

```systemverilog
if (transfer_allowed) begin
    ...
end

assign busy = transfer_allowed;
```

Do not create intermediate signals for trivial expressions that reduce readability.

---

## 47. Module Size

A module should have one clear responsibility.

If a module contains unrelated functions such as:

```text
UART
SPI
DMA
packet parser
clock control
```

consider splitting them into separate modules.

Prefer:

```text
uart/
    uart_rx.sv
    uart_tx.sv
    uart_baud_gen.sv
    uart_top.sv
```

over one very large RTL file.

---

## 48. Hierarchy

Use a clear hardware hierarchy.

Example:

```text
top
├── clock_manager
├── reset_manager
├── uart
│   ├── uart_rx
│   ├── uart_tx
│   └── uart_baud_gen
├── fifo
└── packet_parser
```

The top-level module should primarily connect major blocks rather than contain large amounts of RTL logic.

---

## 49. Example of Recommended RTL Structure

```systemverilog
module counter #(
    parameter int unsigned WIDTH = 32
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    input  logic             clear,
    output logic [WIDTH-1:0] count
);

    logic [WIDTH-1:0] count_q;
    logic [WIDTH-1:0] count_d;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_q <= '0;
        end else begin
            count_q <= count_d;
        end
    end

    always_comb begin
        count_d = count_q;

        if (clear) begin
            count_d = '0;
        end else if (enable) begin
            count_d = count_q + 1'b1;
        end
    end

    assign count = count_q;

endmodule
```

This structure clearly separates:

```text
input/output
parameter
internal signals
sequential logic
combinational next-state/data logic
output assignment
```

---

## 50. AI Coding Rules

When generating or modifying FPGA RTL, AI must follow this document.

AI must:

1. Use SystemVerilog-2017 unless the project explicitly requires Verilog-2001/2005.
2. Follow the naming conventions defined here.
3. Use `always_ff` for sequential logic.
4. Use `always_comb` for combinational logic.
5. Use non-blocking assignments in sequential logic.
6. Use blocking assignments in combinational logic.
7. Avoid unintended latch inference.
8. Provide default assignments in combinational logic.
9. Provide a `default` branch in case statements.
10. Avoid magic numbers.
11. Use explicit widths for important constants.
12. Avoid implicit signed/unsigned conversions.
13. Avoid multiple drivers for the same signal.
14. Avoid multiple non-blocking assignments to the same register in one sequential block.
15. Keep FSM state logic separate from sequential register logic.
16. Treat clock-domain crossings explicitly.
17. Do not introduce vendor-specific constructs unless required.
18. Do not modify unrelated RTL when implementing a requested change.
19. Preserve existing project conventions when they do not conflict with this document.
20. Explain any intentional violation of this coding standard in a comment.

---

## 51. Rule Priority

When rules conflict, use the following priority:

```text
1. Functional correctness
2. FPGA/toolchain requirements
3. Project-specific architecture requirements
4. This coding standard
5. Personal coding preference
```

A project-specific rule may override this document.

Any intentional exception should be documented.

---

## 52. Reference

This coding standard is primarily based on the lowRISC SystemVerilog/Verilog Coding Style Guide.

Reference:

https://github.com/lowRISC/style-guides/blob/master/VerilogCodingStyle.md

The lowRISC guide recommends SystemVerilog-2017, `logic`, `always_ff`, `always_comb`, explicit signal declarations, symbolic constants, explicit combinational defaults, and other RTL coding practices used in this document.
