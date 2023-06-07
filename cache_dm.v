module cache(
    clk,
    proc_reset,
    proc_read,
    proc_write,
    proc_addr,
    proc_rdata,
    proc_wdata,
    proc_stall,
    mem_read,
    mem_write,
    mem_addr,
    mem_rdata,
    mem_wdata,
    mem_ready
);
    
//==== input/output definition ============================
    input          clk;
    // processor interface
    input          proc_reset;
    input          proc_read, proc_write;
    input   [29:0] proc_addr;
    input   [31:0] proc_wdata;
    output         proc_stall;
    output  [31:0] proc_rdata;
    // memory interface
    input  [127:0] mem_rdata;
    input          mem_ready;
    output         mem_read, mem_write;
    output  [27:0] mem_addr;
    output [127:0] mem_wdata;
    
//==== wire/reg definition ================================

    reg [1 + 1 + 25 + 4*32 - 1 : 0] cache_reg [0:7];  // valid, dirty, tag, data
    wire [7:0]  valid;
    wire [7:0]  dirty;

    wire        hit, enable, is_dirty;
    wire [24:0] tag;
    wire [2:0]  index;
    wire [1:0]  block_offset;

    reg  [7:0]  valid_nxt;
    reg  [7:0]  dirty_nxt;
    reg  [24:0] tag_reg   [0:7];
    reg  [24:0] tag_nxt   [0:7];
    reg  [31:0] data0     [0:7];
    reg  [31:0] data1     [0:7];
    reg  [31:0] data2     [0:7];
    reg  [31:0] data3     [0:7];
    reg  [31:0] data0_nxt [0:7];
    reg  [31:0] data1_nxt [0:7];
    reg  [31:0] data2_nxt [0:7];
    reg  [31:0] data3_nxt [0:7];

    reg  [1:0] state, state_nxt;
    reg        mem_read_reg, mem_write_reg;

    parameter CompareTag = 2'b0;
    parameter WriteBack  = 2'b1;
    parameter Allocate   = 2'b10;

    assign valid = {cache_reg[7][154], cache_reg[6][154], cache_reg[5][154], cache_reg[4][154], cache_reg[3][154], cache_reg[2][154], cache_reg[1][154], cache_reg[0][154]};
    assign dirty = {cache_reg[7][153], cache_reg[6][153], cache_reg[5][153], cache_reg[4][153], cache_reg[3][153], cache_reg[2][153], cache_reg[1][153], cache_reg[0][153]};
    
    integer i;
    always @(*) begin
        for (i = 0; i <= 7; i = i + 1) begin
            tag_reg[i] = cache_reg[i][152:128];
            data0  [i] = cache_reg[i][127:96];
            data1  [i] = cache_reg[i][95:64];
            data2  [i] = cache_reg[i][63:32];
            data3  [i] = cache_reg[i][31:0];
        end
    end
    

//==== combinational circuit ==============================
    assign enable = proc_read ^ proc_write;
    assign {tag, index, block_offset} = proc_addr;
    assign hit        = (tag_reg[index] == tag) && valid[index];
    assign is_dirty   = dirty[index];
    assign proc_rdata = (block_offset == 2'b0)?  data0[index] :
                        (block_offset == 2'b1)?  data1[index] :
                        (block_offset == 2'b10)? data2[index] : data3[index];
    assign proc_stall = !hit && enable;
    assign mem_read   = mem_read_reg;      //!hit && proc_read;
    assign mem_write  = mem_write_reg;     //!hit && proc_write;
    assign mem_addr   = (state == WriteBack) ? {tag_reg[index], index} : proc_addr[29:2];
    assign mem_wdata  = {data3[index], data2[index], data1[index], data0[index]};

    always @(*) begin
        for (i = 0; i <= 7; i = i + 1) begin
            valid_nxt[i] = valid  [i];
            dirty_nxt[i] = dirty  [i];
            tag_nxt  [i] = tag_reg[i];
            data0_nxt[i] = data0  [i];
            data1_nxt[i] = data1  [i];
            data2_nxt[i] = data2  [i];
            data3_nxt[i] = data3  [i];
        end
        mem_read_reg = 0;
        mem_write_reg = 0;
        case (state) 
            CompareTag: begin  // write hit
                if (hit && proc_write) begin
                    dirty_nxt[index] = 1;
                    case (block_offset)
                        2'b0:  data0_nxt[index] = proc_wdata;
                        2'b1:  data1_nxt[index] = proc_wdata;
                        2'b10: data2_nxt[index] = proc_wdata;
                        2'b11: data3_nxt[index] = proc_wdata;
                    endcase
                end
            end
            WriteBack: begin
                mem_write_reg = 1;
            end
            Allocate: begin
                mem_read_reg  = 1;
                if (mem_ready) begin
                    data0_nxt[index] = mem_rdata[31:0];
                    data1_nxt[index] = mem_rdata[63:32];
                    data2_nxt[index] = mem_rdata[95:64];
                    data3_nxt[index] = mem_rdata[127:96];
                    tag_nxt  [index] = tag;
                    valid_nxt[index] = 1;
                    dirty_nxt[index] = 0;
                end
            end
        endcase
    end




//==== sequential circuit =================================
    always @(posedge clk) begin
        if( proc_reset ) begin
            for (i = 0; i <= 7; i = i + 1) begin
                cache_reg[i] <= 155'b0;
            end
        end
        else begin
            for (i = 0; i <= 7; i = i + 1) begin
                cache_reg[i][154]     <= valid_nxt[i];
                cache_reg[i][153]     <= dirty_nxt[i];
                cache_reg[i][152:128] <= tag_nxt  [i];
                cache_reg[i][127:96]  <= data0_nxt[i];
                cache_reg[i][95:64]   <= data1_nxt[i];
                cache_reg[i][63:32]   <= data2_nxt[i];
                cache_reg[i][31:0]    <= data3_nxt[i];
            end
        end
    end

//----- FSM -----
    always @(*) begin
        state_nxt = CompareTag;
        if (enable) begin
            case(state)
                CompareTag: begin
                    if (hit) state_nxt = CompareTag;
                    else if (is_dirty) state_nxt = WriteBack;
                    else state_nxt = Allocate;
                end
                WriteBack: begin
                    if (mem_ready) state_nxt = Allocate;
                    else state_nxt = WriteBack;
                end
                Allocate: begin
                    if (mem_ready) state_nxt = CompareTag;
                    else state_nxt = Allocate;
                end
            endcase
        end
    end

    always @( posedge clk ) begin
        if (proc_reset) state <= CompareTag;
        else state <= state_nxt;        
    end

endmodule
