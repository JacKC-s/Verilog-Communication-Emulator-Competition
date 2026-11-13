module instruction_decoder #(parameter DATA_WIDTH = 16)(
    input wire[DATA_WIDTH-1:0] instruction,
    output wire [3:0] opcode,
    output wire [DATA_WIDTH-5:0] operand
);
    
    assign opcode = instruction[DATA_WIDTH-1:DATA_WIDTH-4];
    assign operand = instruction[DATA_WIDTH-5:0];

endmodule
