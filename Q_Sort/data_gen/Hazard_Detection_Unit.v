module Hazard_Detection_Unit(
    MemRead_i,
    Jalr_ID_i,
    RDaddr_i,
    RS1addr_i,
    RS2addr_i,
    Branch_ID_i,
    Predict_wrong_i,
    Jal_IF_i,
    Jal_EX_i,
    Stall_load_use_o,
    Stall_jal_o,
    Flush_IFID_o,
    Flush_IDEX_o
);

    // Ports
    input        MemRead_i, Branch_ID_i, Jal_IF_i, Jal_EX_i, Jalr_ID_i, Predict_wrong_i;
    input  [4:0] RDaddr_i, RS1addr_i, RS2addr_i;
    output       Stall_load_use_o, Stall_jal_o, Flush_IFID_o, Flush_IDEX_o;

    wire RDRS1, RDRS2;
    assign RDRS1 = (RDaddr_i == RS1addr_i);
    assign RDRS2 = (RDaddr_i == RS2addr_i);

    assign tmp                 = RDRS1 | RDRS2;
    assign Stall_load_use_o    = (RDaddr_i != 5'd0) & (((MemRead_i | Jal_EX_i) & tmp));
    assign Stall_jal_o         = Jal_IF_i & (Jalr_ID_i | Branch_ID_i);
    assign Flush_IDEX_o        = Stall_load_use_o | Predict_wrong_i;
    assign Flush_IFID_o        = Stall_jal_o | Predict_wrong_i;

endmodule