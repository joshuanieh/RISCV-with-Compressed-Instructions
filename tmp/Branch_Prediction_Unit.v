module Branch_Prediction_Unit (
    clk,
    rst_n,
    stall,
    taken,
    not_taken,
    take_branch
);

    input  clk, rst_n, stall, taken, not_taken;
    output take_branch;

    reg [1:0] state_w;
    reg [1:0] state_r;

    // states
    parameter Strong_not_taken = 2'b00;
    parameter Weak_not_taken   = 2'b01;
    parameter Weak_taken       = 2'b10;
    parameter Strong_taken     = 2'b11;

    assign take_branch = state_r[1];
    //assign take_branch = 1'b0;

    always @(*) begin
        state_w = state_r;
        case (state_r) 
            Strong_not_taken: begin
                if (taken) state_w = Weak_not_taken;
            end
            Weak_not_taken: begin
                if (taken) state_w = Weak_taken;
                else if (not_taken) state_w = Strong_not_taken;
            end
            Weak_taken: begin
                if (taken) state_w = Strong_taken;
                else if (not_taken) state_w = Weak_not_taken;
            end
            Strong_taken: begin
                if (not_taken) state_w = Weak_taken;
            end
        endcase
    end

    always @(posedge clk) begin
        if (!rst_n)     state_r = 2'b00;
        else if (stall) state_r <= state_r;
        else            state_r <= state_w;
    end

endmodule