module Hazard_Detection_Unit(
    MemRead_i,
    Jalr_i,
    RDaddr_i,
    RS1addr_i,
    RS2addr_i,
    Branch_i,
    Predict_wrong_i,
    Jal_i,
    Stall_load_use_o,
    Flush_IFID_o,
    Flush_IDEX_o
);

    // Ports
    input        MemRead_i, Branch_i, Jal_i, Jalr_i, Predict_wrong_i;
    input  [4:0] RDaddr_i, RS1addr_i, RS2addr_i;
    output       Stall_load_use_o, Flush_IFID_o, Flush_IDEX_o;

    wire RDRS1, RDRS2;
    assign RDRS1 = (RDaddr_i == RS1addr_i);
    assign RDRS2 = (RDaddr_i == RS2addr_i);

    assign tmp                 = RDRS1 | RDRS2;
    assign temp2               = Jalr_i & RDRS1;
    assign Stall_load_use_o    = (RDaddr_i != 5'd0) & (((MemRead_i | Branch_i | Jal_i) & tmp) | temp2);
    assign Flush_IDEX_o        = Stall_load_use_o;
    assign Flush_IFID_o        = (Predict_wrong_i & !((RDaddr_i != 5'd0) & tmp)) | (Jalr_i & !(temp2 & (RDaddr_i != 5'd0)));

endmodule