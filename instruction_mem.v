module instruction_mem #(parameter DATA_WIDTH = 16, parameter MEM_DEPTH = 256, parameter ADDR_WIDTH = 8)(
    input clk,

    //write and read enables
    input w_en, r_en,

    //address and data inputs
    input [ADDR_WIDTH-1:0] w_addr,
    input [DATA_WIDTH-1:0] w_data,


    input [ADDR_WIDTH-1:0] r_addr,
    output reg [DATA_WIDTH-1:0] instruction
);
    reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    // Write operation into instruction memory
    always @(posedge clk) begin
        if (w_en) begin
            mem[w_addr] <= w_data;
        end
    end

    // Read operation from instruction memory
    assign instruction = (r_en) ? mem[r_addr] : 0;
   
endmodule