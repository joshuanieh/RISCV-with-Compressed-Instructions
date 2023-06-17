module Branch_Prediction_Unit (
    clk,
    rst_n,
    stall,
    taken,
    not_taken,
    PC,
    take_branch
);

    input  clk, rst_n, stall, taken, not_taken;
    input [31:0] PC;
    output take_branch;

    wire PC_digit;
    reg [1:0] state_w1;
    reg [1:0] state_r1;
    reg [1:0] state_w2;
    reg [1:0] state_r2;

    // states
    parameter Strong_not_taken = 2'b00;
    parameter Weak_not_taken   = 2'b01;
    parameter Weak_taken       = 2'b10;
    parameter Strong_taken     = 2'b11;

    assign PC_digit = PC[2] ^ PC[3]; // You can modify the bit
    assign take_branch = (PC_digit)? state_r2[1] : state_r1[1];
    //assign take_branch = 1'b1;

    always @(*) begin
        state_w1 = state_r1;
        state_w2 = state_r2;
        if (PC_digit) begin
            case (state_r2) 
                Strong_not_taken: begin
                    if (taken) state_w2 = Weak_not_taken;
                end
                Weak_not_taken: begin
                    if (taken) state_w2 = Weak_taken;
                    else if (not_taken) state_w2 = Strong_not_taken;
                end
                Weak_taken: begin
                    if (taken) state_w2 = Strong_taken;
                    else if (not_taken) state_w2 = Weak_not_taken;
                end
                Strong_taken: begin
                    if (not_taken) state_w2 = Weak_taken;
                end
            endcase
        end
        else begin
            case (state_r1) 
                Strong_not_taken: begin
                    if (taken) state_w1 = Weak_not_taken;
                end
                Weak_not_taken: begin
                    if (taken) state_w1 = Weak_taken;
                    else if (not_taken) state_w1 = Strong_not_taken;
                end
                Weak_taken: begin
                    if (taken) state_w1 = Strong_taken;
                    else if (not_taken) state_w1 = Weak_not_taken;
                end
                Strong_taken: begin
                    if (not_taken) state_w1 = Weak_taken;
                end
            endcase
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            state_r1 <= 2'b00;
            state_r2 <= 2'b00;
        end
        else if (stall) begin
            state_r1 <= state_r1;
            state_r2 <= state_r2;
        end
        else begin
            state_r1 <= state_w1;
            state_r2 <= state_w2;
        end
    end

endmodule