# Protocol Emulator — Jane Street ASIC Competition

A Tiny Tapeout IHP (CMOS5L) implementation of a reprogrammable protocol
emulator, built from the
[ttihp-verilog-template](https://github.com/TinyTapeout/ttihp-verilog-template).

The design is a small CPU whose instruction set is aimed at bit-banging
protocols: set a pin, wait a precise number of cycles, read a pin, and jump
conditionally. UART, SPI, and I2C firmware can be loaded after fabrication,
so the chip is not tied to a fixed set of protocol blocks.

## Repository layout

```
src/                    Synthesisable Verilog sources
  project.v             Tiny Tapeout top level (tt_um_jackc_protocol_emulator)
  execution_controller.v
  instruction_decoder.v
  instruction_mem.v
  program_counter.v
  synchronous_fifo.v
  config.json           Tiny Tapeout / LibreLane configuration
test/                   Cocotb testbench and stand-alone simulation
  tb.v                  Tiny Tapeout pin-level testbench
  tb_protocol_engine.v  Original module-level testbench
  test.py               Cocotb test
  Makefile
docs/info.md            Datasheet source
info.yaml               Tiny Tapeout project metadata (8x4 tiles)
.github/workflows/      GDS, test, docs, and FPGA CI
```

## Architecture

```
program_counter -> instruction_mem -> instruction_decoder -> execution_controller
                         ^                                        |
                         |                                        v
                    host loader                              PIN0 / GPIO_IN
```

Instruction format: `[15:12] opcode`, `[11:0] operand`.

| Opcode | Name     | Operation |
|--------|----------|-----------|
| 0      | NOP      | Drive PIN0 low |
| 1      | SET      | Drive PIN0 to operand[0] |
| 2      | WAIT     | Wait `operand` clock cycles |
| 3      | JMP      | Jump to `operand` |
| 4      | READ     | Sample GPIO_IN |
| 5      | JMP_HIGH | Jump to `operand` if GPIO_IN is high |

The `synchronous_fifo` module is present for future receive/transmit
buffering but is not yet instantiated in the top level.

## Tiny Tapeout pin mapping

| Pin | Function |
|-----|----------|
| `ui_in[0]` | `GPIO_IN` — protocol input sampled by READ / JMP_HIGH |
| `ui_in[1]` | `RUN` — start execution from address 0 |
| `ui_in[2]` | `LOAD_EN` — load one instruction byte |
| `ui_in[3]` | `LOAD_BYTE_SEL` — 0 = high byte, 1 = low byte |
| `uio_in[7:0]` | Host instruction byte |
| `uo_out[0]` | `PIN0` — emulated protocol output |
| `uo_out[7:1]` | Program counter debug (`pc[6:0]`) |

`uio_oe` is tied low, so the bidirectional pins are always inputs driven by
the host. Program loading is byte-wise, high byte first; the internal address
auto-increments after each low byte. Assert `rst_n` low to reset the PC and
the loader.

## Simulation

The template uses [cocotb](https://docs.cocotb.org/) with Icarus Verilog:

```sh
cd test
make
```

The test loads a five-instruction program that blinks `PIN0`, starts the
engine, and checks the pin and program counter.

The original module-level testbench can be run directly:

```sh
iverilog -g2012 -o tb_protocol_engine.vvp \
  test/tb_protocol_engine.v src/*.v
vvp tb_protocol_engine.vvp
```

## Building the ASIC

The GitHub Actions workflows run the Tiny Tapeout flow automatically on
push. The GDS flow uses the `ttihp27a` action with the `ihp-sg13cmos5l` PDK.

## Competition

- [Jane Street protocol emulator ASIC competition](https://blog.janestreet.com/protocol-emulator-asic-competition/)
- [Tiny Tapeout IHP Verilog template](https://github.com/TinyTapeout/ttihp-verilog-template)

## License

Apache-2.0. See [LICENSE](LICENSE).
