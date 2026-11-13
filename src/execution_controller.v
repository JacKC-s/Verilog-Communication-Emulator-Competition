module execution_controller (
    input wire clk,
    input wire rst,
    input wire run,

    input wire [3:0] opcode,
    input wire [11:0] operand,

    input wire gpio_in,

    output wire advance,
    output wire jump,
    output wire [7:0] jump_addr,

    output reg pin0,
    output reg sampled_bit
);

    localparam [3:0] NOP  = 0;
    localparam [3:0] SET  = 1;
    localparam [3:0] WAIT = 2;
    localparam [3:0] JMP  = 3;
    localparam [3:0] READ = 4;
    localparam [3:0] JMP_HIGH = 5;

    reg [11:0] wait_count;
    reg waiting;

    // Combination logic
    assign jump_addr = operand[7:0];

    assign jump = run && !waiting &&
                  ((opcode == JMP) || ((opcode == JMP_HIGH) && gpio_in));

    assign advance = run && (waiting ? (wait_count == 0)
                                     : !((opcode == WAIT) && (operand != 0)));


    // Sequential execution
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            waiting <= 0;
            wait_count <= 0;
            pin0 <= 0;
            sampled_bit <= 0;
        end else if (run) begin
            if (waiting) begin
                if (wait_count == 0) begin
                    waiting <= 0;
                end else begin
                    wait_count <= wait_count - 1'b1;
                end
            end else if (opcode == WAIT && operand != 0) begin
                waiting <= 1;
                wait_count <= operand - 1'b1;
            end else begin
                case (opcode)
                    NOP: pin0 <= 0;
                    SET: pin0 <= operand[0];
                    READ: sampled_bit <= gpio_in;
                    JMP_HIGH: sampled_bit <= gpio_in;
                    default: pin0 <= pin0;
                endcase
            end
        end
    end

endmodule
