module Hazard_Detection_Unit(
    MemRead_i,
    RDaddr_i,
    RS1addr_i,
    RS2addr_i,
    BranchOrJump_i,
    Stall_load_use_o,
    Flush_IFID_o,
    Flush_IDEX_o
);

    // Ports
    input        MemRead_i, BranchOrJump_i;
    input  [4:0] RDaddr_i, RS1addr_i, RS2addr_i;
    output       Stall_load_use_o, Flush_IFID_o, Flush_IDEX_o;

    assign tmp                 = (RDaddr_i == RS1addr_i) | (RDaddr_i == RS2addr_i);
    assign Stall_load_use_o    = (RDaddr_i != 5'b0) & MemRead_i & tmp;
    assign Flush_IDEX_o        = Stall_load_use_o | BranchOrJump_i;
    assign Flush_IFID_o        = BranchOrJump_i;

endmodule