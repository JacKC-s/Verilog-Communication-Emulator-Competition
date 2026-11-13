/*
 * Copyright (c) 2026 JacKC-s
 * SPDX-License-Identifier: Apache-2.0
 *
 * Tiny Tapeout top level for the protocol emulator.
 *
 * Host interface
 * --------------
 * ui_in[0]   gpio_in        Protocol input pin sampled by READ / JMP_HIGH
 * ui_in[1]   run            Start executing from address 0
 * ui_in[2]   load_en        Pulse high for one clock to load one byte
 * ui_in[3]   load_byte_sel  0 = high byte, 1 = low byte (also writes memory)
 * ui_in[7:4] unused
 *
 * uio_in[7:0] host_data     Instruction byte driven by the host
 * uo_out[0]   pin0          Emulated protocol output pin
 * uo_out[7:1] pc[6:0]       Program counter debug output
 *
 * Program loading is byte-wise: send the high byte with load_byte_sel=0,
 * then the low byte with load_byte_sel=1. The address auto-increments after
 * each low byte. Assert rst_n low to reset the PC and the loader.
 */

`default_nettype none

module tt_um_jackc_protocol_emulator (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    wire gpio_in       = ui_in[0];
    wire run           = ui_in[1];
    wire load_en       = ui_in[2];
    wire load_byte_sel = ui_in[3];
    wire [7:0] host_data = uio_in;

    reg  [7:0]  load_addr;
    reg  [7:0]  load_high;
    wire [15:0] load_word = {load_high, host_data};

    wire [7:0]  pc;
    wire [15:0] instruction;
    wire [3:0]  opcode;
    wire [11:0] operand;
    wire        advance;
    wire        jump;
    wire [7:0] jump_addr;
    wire        pin0;
    wire        sampled_bit;

    // Byte-wise program loader. Address auto-increments after each low byte.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_addr <= 8'd0;
            load_high <= 8'd0;
        end else if (load_en) begin
            if (!load_byte_sel) begin
                load_high <= host_data;
            end else begin
                load_addr <= load_addr + 8'd1;
            end
        end
    end

    program_counter #(.WIDTH(8)) u_pc (
        .clk(clk),
        .rst_n(rst_n),
        .en(advance),
        .jump(jump),
        .jump_addr(jump_addr),
        .pc(pc)
    );

    instruction_mem #(
        .DATA_WIDTH(16),
        .MEM_DEPTH(256),
        .ADDR_WIDTH(8)
    ) u_imem (
        .clk(clk),
        .w_en(load_en && load_byte_sel),
        .r_en(1'b1),
        .w_addr(load_addr),
        .w_data(load_word),
        .r_addr(pc),
        .instruction(instruction)
    );

    instruction_decoder #(.DATA_WIDTH(16)) u_decoder (
        .instruction(instruction),
        .opcode(opcode),
        .operand(operand)
    );

    execution_controller u_exec (
        .clk(clk),
        .rst(~rst_n),
        .run(run),
        .opcode(opcode),
        .operand(operand),
        .gpio_in(gpio_in),
        .advance(advance),
        .jump(jump),
        .jump_addr(jump_addr),
        .pin0(pin0),
        .sampled_bit(sampled_bit)
    );

    // uo_out[0] is the emulated protocol pin; uo_out[7:1] is PC debug.
    assign uo_out  = {pc[6:0], pin0};
    assign uio_out = 8'h00;
    assign uio_oe  = 8'h00;  // uio pins are host inputs

    // List all unused inputs to prevent warnings
    wire _unused = &{ena, ui_in[7:4], sampled_bit, 1'b0};

endmodule
