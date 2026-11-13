<!---
This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This design is a small, reprogrammable protocol engine. A host loads a
program into a 256 x 16-bit instruction memory, then asserts `run`. The
engine executes instructions from that memory and bit-bangs a protocol pin
using the `SET`, `WAIT`, `READ`, `JMP`, and `JMP_HIGH` instructions. The
goal is to emulate protocols such as UART, SPI, and I2C in firmware rather
than with fixed protocol blocks, so new protocols can be added after the
chip is fabricated.

The datapath is:

```
program_counter -> instruction_mem -> instruction_decoder -> execution_controller
                         ^                                        |
                         |                                        v
                    host loader                              PIN0 / GPIO_IN
```

A parameterized synchronous FIFO is included in the source tree for future
buffering work, but it is not yet wired into the datapath.

### Instruction format

Each instruction is 16 bits:

```
[15:12] opcode
[11:0]  operand
```

| Opcode | Name     | Operation |
|--------|----------|-----------|
| 0      | NOP      | Drive PIN0 low |
| 1      | SET      | Drive PIN0 to operand[0] |
| 2      | WAIT     | Wait `operand` clock cycles |
| 3      | JMP      | Jump to `operand` |
| 4      | READ     | Sample GPIO_IN into the `sampled_bit` output |
| 5      | JMP_HIGH | Jump to `operand` if GPIO_IN is high, otherwise continue |

### Host program-loading interface

The host loads one instruction at a time, high byte first:

1. Hold `LOAD_BYTE_SEL = 0`, drive the high byte on `uio_in[7:0]`, and pulse
   `LOAD_EN` for one clock.
2. Hold `LOAD_BYTE_SEL = 1`, drive the low byte on `uio_in[7:0]`, and pulse
   `LOAD_EN` for one clock. This writes the instruction and increments the
   internal load address.
3. Repeat for each instruction. The loader starts at address 0 after reset.
4. Assert `RUN` to start executing from address 0.

`uio_oe` is tied low, so the bidirectional pins are always host inputs.
`uo_out[0]` is the emulated protocol pin and `uo_out[7:1]` exposes the low
seven bits of the program counter for debugging.

## How to test

Run the cocotb testbench in `test/`:

```sh
cd test
make
```

The test loads a five-instruction program that blinks `PIN0`, starts the
engine, and checks that the pin toggles and that the program counter
advances.

## External hardware

None required for the RTL simulation. On the Tiny Tapeout demo board, the
RP2350 can drive the host interface through `ui_in` and `uio_in`.
