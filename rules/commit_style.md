# Commit Style Guide

This repository writes commit messages the way the Linux kernel does: a short
subsystem-prefixed subject, a blank line, then prose that explains the problem
before it explains the change.

A commit message is read by someone who has the diff in front of them. The diff
already says what changed. The message has to say what was wrong, or what was
missing, and what the change means for the hardware, the firmware or anyone
reading the tree later.

## Format

```text
<subsystem>: <summary in the imperative, no trailing period>

Body paragraphs wrapped at 72 columns, in the imperative mood, describing
the problem first and the change second.

An optional tag block at the end.
```

## Subject

Prefix with the subsystem the change belongs to, lowercase, followed by a colon
and a space. The subsystems in this tree are:

```text
cpu       pipeline, ALU, control, register file, address decoder
memory    instruction ROM and data RAM
uart      UART RTL and its MMIO peripheral
i2c       I2C RTL and its MMIO peripheral
spi       SPI RTL and its MMIO peripheral
tft       ST7735 panel behaviour
lcd       HD44780 panel behaviour
gpio      LED and other pin-level peripherals
sw        C firmware, startup code, linker script
sim       testbenches with no RTL change
build     synthesis flow, project files, tool scripts
docs      documentation and diagrams
rules     these guides
```

A change that spans two of them belongs in two commits. Where one subsystem
contains an obvious sub-part, nest it: `spi: st7735: ...`.

Write the summary as a command, not a report. `add mode 0 master`, not `added`
or `this adds`. Keep the whole subject line under 72 characters. No trailing
period.

## Body

The body is required. Write it as paragraphs, not as a form to fill in. Do not
use `Context:`, `Changes:` or `Verification:` headers, and do not reduce the
message to a bullet list of file names, which repeats the diff.

Open with the problem. What was broken, missing, or about to become wrong. If
the change is a cleanup with no defect behind it, say what made the old shape
inadequate.

Then state the change in the imperative, as an instruction to the codebase:
"Add a mode 0 shift engine", "Remove the LCD helpers", "Constrain the five pins
to bank 2".

Explain any decision a reader would otherwise question, including the ones that
look arbitrary. A magic constant, a pin choice, a state that exists only to
hold a signal stable for one more cycle: if it took thought, record the thought.

Close with what was verified, in prose. Name the testbenches or the board
observation, and say plainly when something was not run. "Not simulated" is
useful; silence is not.

### What an RTL body has to contain

Record the module and its clock and reset contract. For an FSM, name the states
and what makes them advance, and say what is externally visible. For a bus or
SoC change, record the MMIO address and register layout, and any assumption
about how software has to use it. For a pin or board change, state the FPGA
constraint and why that pin and not another.

## Tags

An optional block at the end, one tag per line, no blank lines inside it.

```text
Fixes: 3910e8d8a237 ("build: add the spi sources to the gowin file list")
Reported-by: Name <email>
Tested-by: Name <email>
Link: https://example.invalid/thread
Signed-off-by: Name <email>
```

Use `Fixes:` when the commit corrects a defect introduced by an earlier commit
in this repository, with the abbreviated hash and the original subject in
parentheses. `git commit -s` appends `Signed-off-by:` for you.

Never add a tag crediting a tool for authorship.

## Examples

```text
spi: add mode 0 write-only master with mmio wrapper

The ST7735 breakout on this board brings only SDA out to its header, so
the link to the panel can never be anything but write-only.  Giving the
master a miso port and a receive register would leave logic with nothing
driving it.

Add a mode 0, MSB first, 8 bit shift engine with no receive path.
CLK_DIV sets the sck half period in clk cycles and defaults to 2, which
gives 6.75 MHz out of the 27 MHz domain, inside the ST7735 write cycle
limit with margin for jumper wiring.

Keep busy set for one further half period after the last bit.  Software
moves cs_n and dc as soon as busy clears, and without that trailing
state either line could change while sck was still high.

Both new testbenches pass under Icarus Verilog.
```

```text
build: add the spi sources to the gowin file list

tools/run_tests.sh collects CPU sources with a glob, but
tools/build_gowin.tcl names every file by hand.  A module added to the
tree therefore passes every testbench while never reaching synthesis,
and the only symptom is the top module quietly becoming a black box.

Nothing in the test suite can catch this, because the suite never reads
the synthesis file list.  Add both SPI sources to build_gowin.tcl, and
to fpga_project.gprj so the IDE flow matches the headless one.

The build now runs through to bitstream generation at Fmax 30.880 MHz
against the 27 MHz constraint with no violated endpoints.
```

## Do not

Do not paste conversation, requests or questions into a message. Do not write
`update code`, `fix bug` or `improve`. Do not describe the change as work that
happened to you; describe it as an instruction to the tree.
