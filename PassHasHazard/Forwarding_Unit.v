module Forwarding_Unit(
    RS1addr_i,
    RS2addr_i,
    RDaddr_EXMEM_i,
    RegWrite_EXMEM_i,
    RDaddr_MEMWB_i,
    RegWrite_MEMWB_i,
    ForwardA_o,
    ForwardB_o
);

// Ports
input        RegWrite_EXMEM_i, RegWrite_MEMWB_i;
input  [4:0] RDaddr_EXMEM_i, RDaddr_MEMWB_i, RS1addr_i, RS2addr_i;
output [1:0] ForwardA_o, ForwardB_o;
/*
if (EX/MEM.RegWrite
and (EX/MEM.RegisterRd != 0)
and (EX/MEM.RegisterRd == ID/EX.RegisterRs1)) ForwardA = 10
*/
wire cA1 = RegWrite_EXMEM_i & (RDaddr_EXMEM_i != 5'b0) & (RDaddr_EXMEM_i == RS1addr_i);
wire cB1 = RegWrite_EXMEM_i & (RDaddr_EXMEM_i != 5'b0) & (RDaddr_EXMEM_i == RS2addr_i);

/*
if (MEM/WB.RegWrite
and (MEM/WB.RegisterRd != 0)
and not(EX/MEM.RegWrite and (EX/MEM.RegisterRd != 0)
and (EX/MEM.RegisterRd == ID/EX.RegisterRs1))
and (MEM/WB.RegisterRd == ID/EX.RegisterRs1)) ForwardA = 01
*/
wire cA2 = RegWrite_MEMWB_i & (RDaddr_MEMWB_i != 5'b0) & (RDaddr_MEMWB_i == RS1addr_i);
wire cB2 = RegWrite_MEMWB_i & (RDaddr_MEMWB_i != 5'b0) & (RDaddr_MEMWB_i == RS2addr_i);

wire [1:0] tmpA = cA2 ? 2'b01 : 2'b00;
assign ForwardA_o = cA1 ? 2'b10 : tmpA;
wire [1:0] tmpB = cB2 ? 2'b01 : 2'b00;
assign ForwardB_o = cB1 ? 2'b10 : tmpB;
endmodule