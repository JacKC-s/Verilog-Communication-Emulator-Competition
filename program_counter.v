module program_counter #(parameter WIDTH = 8)(
    input clk, rst_n,
    input en,
    input jump,
    input [WIDTH-1:0] jump_addr,
    output reg [WIDTH-1:0] pc
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= 0;
        else if (jump)
            pc <= jump_addr;
        else if (en)
            pc <= pc + 1;
    end
endmodule
