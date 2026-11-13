

// /============================================================================\
// | Date:        2026-10-28                                                    |
// | Module:      synchronous_fifo                                              |
// | Description: Parameterized synchronous FIFO with configurable data width  |
// |              and depth, write/read enables, active-low reset, and          |
// |              full/empty status flags.                                      |
// \============================================================================/

module synchronous_fifo #(parameter DATA_WIDTH = 8, parameter FIFO_DEPTH = 8)(
    input clk, rst_n,
    input w_en, r_en,
    input [DATA_WIDTH-1:0] data_in,
    output reg [DATA_WIDTH-1:0] data_out,
    output reg full, empty
);
    // write and read pointers
    reg [$clog2(FIFO_DEPTH)-1:0] w_ptr, r_ptr;
    reg [DATA_WIDTH-1:0] fifo_mem [FIFO_DEPTH];

// Resets to default values
always @(posedge clk) begin
    if (!rst_n) begin
        w_ptr <= 0; r_ptr <= 0;
        data_out <= 0;
    end
end

// Write operation into fifo memory 
always @(posedge clk) begin
    if (w_en && !full) begin
        fifo_mem[w_ptr] <= data_in;
        w_ptr <= w_ptr + 1;
    end
end

// Read operation from fifo mem
always @(posedge clk) begin
    if (r_en && !empty) begin
        data_out <= fifo_mem[r_ptr];
        r_ptr <= r_ptr + 1;
    end
end

assign full = ((w_ptr + 1'b1) == r_ptr);
assign empty = (w_ptr == r_ptr);

endmodule
