/*
Module: register_file
Author: Chia-Jen Nieh
Description:
    When RegWrite_i == 1'b1, write RD_address_i register by RD_data_i on posedge clk.
    Read data from register RS1 and RS2.
*/
module register_file (
    clk_i,
    rst_n_i,
    RegWrite_i,
    RD_address_i,
    RD_data_i,
    RS1_address_i,
    RS2_address_i,
    RS1_data_o,
    RS2_data_o
);

input             clk_i, rst_n_i;
input             RegWrite_i;
input      [4:0]  RD_address_i, RS1_address_i, RS2_address_i;
input      [31:0] RD_data_i;
output reg [31:0] RS1_data_o, RS2_data_o;

reg [31:0] reg_r[0:31];

integer i;

// always@(*) begin
//     reg_r[0] = 32'd0;
// end

always@(*) begin
    RS1_data_o = reg_r[RS1_address_i];
    RS2_data_o = reg_r[RS2_address_i];
end

always@(posedge clk_i) begin
    if (rst_n_i == 1'b0) begin
        for (i = 0; i < 32; i = i+1) begin
            reg_r[i] = 32'd0;
        end
    end
    else begin
        for (i = 0; i < 32; i = i+1) begin
            reg_r[i] = reg_r[i];
        end
        if (RegWrite_i == 1'b1 && RD_address_i != 5'd0) begin
            reg_r[RD_address_i] = RD_data_i;
        end
    end
end	

endmodule
