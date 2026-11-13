# SPDX-FileCopyrightText: © 2026 JacKC-s
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, ReadOnly, RisingEdge

# Tiny Tapeout ui_in control bits
GPIO_IN = 0
RUN = 1
LOAD_EN = 2
LOAD_BYTE_SEL = 3

# Instruction encoding: [15:12] opcode, [11:0] operand
OP_SET = 1
OP_WAIT = 2
OP_JMP = 3


async def load_instruction(dut, instruction):
    """Load one 16-bit instruction, high byte first."""
    # High byte
    dut.ui_in.value = 1 << LOAD_EN
    dut.uio_in.value = (instruction >> 8) & 0xFF
    await RisingEdge(dut.clk)
    dut.ui_in.value = 0
    await RisingEdge(dut.clk)

    # Low byte (also triggers the memory write)
    dut.ui_in.value = (1 << LOAD_EN) | (1 << LOAD_BYTE_SEL)
    dut.uio_in.value = instruction & 0xFF
    await RisingEdge(dut.clk)
    dut.ui_in.value = 0
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_protocol_emulator(dut):
    dut._log.info("Start")

    # 10 ns period (100 MHz simulation clock)
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    # Program: set pin0 high, wait 20 cycles, set low, wait 20, jump to 0.
    program = [
        (OP_SET << 12) | 0x001,
        (OP_WAIT << 12) | 0x014,
        (OP_SET << 12) | 0x000,
        (OP_WAIT << 12) | 0x014,
        (OP_JMP << 12) | 0x000,
    ]

    dut._log.info("Load program")
    for instruction in program:
        await load_instruction(dut, instruction)

    # Start execution
    dut.ui_in.value = 1 << RUN
    await ClockCycles(dut.clk, 3)
    await ReadOnly()

    pin0 = int(dut.uo_out.value) & 0x01
    pc = (int(dut.uo_out.value) >> 1) & 0x7F
    assert pin0 == 1, "pin0 should be high after SET 1"
    assert pc == 1, f"expected PC=1 while waiting, got {pc}"

    # Wait for the first WAIT to expire and SET 0 to execute.
    await ClockCycles(dut.clk, 30)
    await ReadOnly()
    pin0 = int(dut.uo_out.value) & 0x01
    assert pin0 == 0, "pin0 should be low after SET 0"

    # The program loops, so pin0 should go high again after the second WAIT.
    await ClockCycles(dut.clk, 20)
    await ReadOnly()
    pin0 = int(dut.uo_out.value) & 0x01
    assert pin0 == 1, "pin0 should be high again after jumping to address 0"

    dut._log.info("Test passed")
