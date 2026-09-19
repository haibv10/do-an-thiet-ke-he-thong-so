# Figures

Every file here was reviewed on 2026-09-19 and placed in one of three groups.
The point of the review was that several of these had never been referenced by
any document, so nothing had ever checked whether they describe *this* project.
Three of them do not.

## Used in the documentation

These are accurate for the current design and are linked from the text.

| File | Used by | Shows |
|---|---|---|
| `schematic_1frame_FSM.png` | design report | Each `i2c_writeframe` state mapped onto one I2C write frame: nine SCL pulses, then the STOP |
| `FSM_i2c_writeframe.png` | design report | The `i2c_writeframe` state diagram. The `WaitACK` exit is drawn as a decision on `sda_in`; the RTL leaves that state on the delay counter and samples the ACK in `Ack1` |
| `FSM_lcd_write_cmd_data.png` | design report | The `lcd_write_cmd_data` state diagram, five I2C frames per LCD byte |
| `schematic_lcd_i2c_pcf8574.png` | design report | The PCF8574 backpack. Confirms the P0-P7 pin mapping and that the address straps sit on pull-ups, so the part answers at `0x27` |
| `waveform_lcd_write_cmd_data.png` | verification results | One LCD byte as `4e dc d8 4c 48`, each byte matching what the RTL computes |

The two `.drawio` files are the editable sources for the FSM diagrams, made with
<https://app.diagrams.net>.

## Superseded

Genuine captures of this project, but of revisions that no longer exist. Kept as
history; do not cite them as current behaviour.

| File | Why it is out of date |
|---|---|
| `schematic_top_module.png` | The standalone LCD design before the CPU existed: a `clk_divider` producing a real 1 MHz clock, and 16-character rows |
| `waveform_lcd_display.png` | The 16x2 version of `lcd_display`, with `row1`/`row2` at 128 bits. The module now drives 20x4 with four 160-bit rows |
| `waveform_i2c_writeframe.png` | An earlier `i2c_writeframe` revision; the state sequence does not include `WaitAck` |

## Removed

Three files depicted other people's work on other hardware and were deleted, so
that nothing here can be mistaken for a result of this project.

| File | What it was |
|---|---|
| `demo.jpg` | A different project on an Avnet Zynq board, driving a 16x2 LCD that displayed another person's name |
| `schematic_1.png` | A Xilinx Vivado block design containing a Zynq UltraScale+ processing system |
| `pin_out.png` | An Intel Quartus pin assignment table for a keypad lock design, on an Altera part |

## Reference material, not cited

Generic figures about I2C in general rather than about this design. None has a
recorded source, so none is referenced from the documentation. Give one a source
before citing it, or drop it.

| File | What it is |
|---|---|
| `sda_scl_line.png` | An open-drain bus diagram. It illustrates what `i2c_writeframe` does, but it is somebody's reference drawing |
| `waveform_i2c.png` | An I2C protocol timing figure |
| `i2c_protocol_write.png` | An I2C write-transaction diagram, labelled in Vietnamese |
| `lcd_i2c_module.jpg` | A vendor product photo of a 16x2 LCD and backpack |
