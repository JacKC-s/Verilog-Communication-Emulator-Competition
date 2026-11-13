`timescale 1ns / 1ps

module tb_protocol_engine;

    reg clk;
    reg rst_n;
    reg run;

    reg load_en;
    reg [15:0] load_addr;
    reg [15:0] load_data;

    wire [15:0] pc;
    wire [15:0] instruction;
    wire [3:0] opcode;
    wire [11:0] operand;
    wire advance;
    wire jump;
    wire [11:0] jump_addr;
    wire pin0;

    initial clk = 0;
    always #5 clk = ~clk;

    program_counter #(.WIDTH(16)) pc_inst (
        .clk(clk),
        .rst_n(rst_n),
        .en(advance),
        .jump(jump),
        .jump_addr(jump_addr),
        .pc(pc)
    );

    instruction_mem #(.DATA_WIDTH(16), .MEM_DEPTH(256), .ADDR_WIDTH(8)) imem_inst (
        .clk(clk),
        .w_en(load_en),
        .r_en(1'b1),
        .w_addr(load_addr),
        .w_data(load_data),
        .r_addr(pc),
        .instruction(instruction)
    );

    instruction_decoder #(.DATA_WIDTH(16)) decoder_inst (
        .instruction(instruction),
        .opcode(opcode),
        .operand(operand)
    );

    execution_controller exec_ctrl_inst (
        .clk(clk),
        .rst(~rst_n),
        .run(run),
        .opcode(opcode),
        .operand(operand),
        .advance(advance),
        .jump(jump),
        .jump_addr(jump_addr),
        .pin0(pin0)
    );

    task write_instruction;
        input [15:0] addr;
        input [15:0] data;
        begin
            load_en = 1;
            load_addr = addr;
            load_data = data;
            @(posedge clk);
            load_en = 1;

            @(negedge clk);
            load_en = 0;
        end
    endtask

    initial begin

        $dumpfile("tb_protocol_engine.vcd");
        $dumpvars(0, tb_protocol_engine);

        rst_n = 0;
        run = 0;
        load_en = 0;
        load_addr = 0;
        load_data = 0;

        // Load the program
        write_instruction(16'd0, 16'h1001);
        write_instruction(16'd1, 16'h2014);
        write_instruction(16'd2, 16'h1000);
        write_instruction(16'd3, 16'h2014);
        write_instruction(16'd4, 16'h3000);

        // Start execution
        rst_n = 1;
        run = 1;

        #500;
        $finish;
    end
endmodule