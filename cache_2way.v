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

    reg  [1 + 1 + 1 + 26 + 4*32 - 1 : 0] cache_reg_l [0:3];  // valid, dirty, ref, tag, data
    reg  [1 + 1 + 1 + 26 + 4*32 - 1 : 0] cache_reg_r [0:3];
    wire [3:0]  valid_l;
    wire [3:0]  valid_r;
    wire [3:0]  dirty_l;
    wire [3:0]  dirty_r;
    wire [3:0]  ref_l;
    wire [3:0]  ref_r;

    wire        hit, hit_l, hit_r, enable, is_dirty_l, is_dirty_r, need_writeback;
    wire [25:0] tag;
    wire [1:0]  index;
    wire [1:0]  block_offset;

    reg  [3:0]  valid_l_nxt;
    reg  [3:0]  valid_r_nxt;
    reg  [3:0]  dirty_l_nxt;
    reg  [3:0]  dirty_r_nxt;
    reg  [3:0]  ref_l_nxt;
    reg  [3:0]  ref_r_nxt;

    reg  [25:0] tag_l       [0:3];
    reg  [25:0] tag_r       [0:3];
    reg  [25:0] tag_l_nxt   [0:3];
    reg  [25:0] tag_r_nxt   [0:3];
    reg  [31:0] data0_l     [0:3];
    reg  [31:0] data1_l     [0:3];
    reg  [31:0] data2_l     [0:3];
    reg  [31:0] data3_l     [0:3];
    reg  [31:0] data0_r     [0:3];
    reg  [31:0] data1_r     [0:3];
    reg  [31:0] data2_r     [0:3];
    reg  [31:0] data3_r     [0:3];
    reg  [31:0] data0_l_nxt [0:3];
    reg  [31:0] data1_l_nxt [0:3];
    reg  [31:0] data2_l_nxt [0:3];
    reg  [31:0] data3_l_nxt [0:3];
    reg  [31:0] data0_r_nxt [0:3];
    reg  [31:0] data1_r_nxt [0:3];
    reg  [31:0] data2_r_nxt [0:3];
    reg  [31:0] data3_r_nxt [0:3];

    reg  [1:0]   state, state_nxt;
    reg          mem_read_reg, mem_write_reg;
    reg  [31:0]  proc_rdata_reg;
    reg  [27:0]  mem_addr_reg;
    reg  [127:0] mem_wdata_reg;

    parameter CompareTag = 2'b0;
    parameter WriteBack  = 2'b1;
    parameter Allocate   = 2'b10;

    assign valid_l = {cache_reg_l[3][156], cache_reg_l[2][156], cache_reg_l[1][156], cache_reg_l[0][156]};
    assign valid_r = {cache_reg_r[3][156], cache_reg_r[2][156], cache_reg_r[1][156], cache_reg_r[0][156]};
    assign dirty_l = {cache_reg_l[3][155], cache_reg_l[2][155], cache_reg_l[1][155], cache_reg_l[0][155]};
    assign dirty_r = {cache_reg_r[3][155], cache_reg_r[2][155], cache_reg_r[1][155], cache_reg_r[0][155]};
    assign ref_l   = {cache_reg_l[3][154], cache_reg_l[2][154], cache_reg_l[1][154], cache_reg_l[0][154]};
    assign ref_r   = {cache_reg_r[3][154], cache_reg_r[2][154], cache_reg_r[1][154], cache_reg_r[0][154]};
    
    integer i;
    always @(*) begin
        for (i = 0; i <= 3; i = i + 1) begin
            tag_l  [i] = cache_reg_l[i][153:128];
            data0_l[i] = cache_reg_l[i][127:96];
            data1_l[i] = cache_reg_l[i][95:64];
            data2_l[i] = cache_reg_l[i][63:32];
            data3_l[i] = cache_reg_l[i][31:0];
            tag_r  [i] = cache_reg_r[i][153:128];
            data0_r[i] = cache_reg_r[i][127:96];
            data1_r[i] = cache_reg_r[i][95:64];
            data2_r[i] = cache_reg_r[i][63:32];
            data3_r[i] = cache_reg_r[i][31:0];
        end
    end

//==== combinational circuit ==============================
    assign enable = proc_read ^ proc_write;
    assign {tag, index, block_offset} = proc_addr;
    assign hit_l      = (tag_l[index] == tag) && valid_l[index];
    assign hit_r      = (tag_r[index] == tag) && valid_r[index];
    assign hit        = hit_l | hit_r;
    assign is_dirty_l = dirty_l[index];
    assign is_dirty_r = dirty_r[index];
    assign need_writeback = (is_dirty_r && ref_l[index]) | (is_dirty_l && ref_r[index]);
    assign proc_rdata = proc_rdata_reg;

    assign proc_stall = !hit && enable;
    assign mem_read   = mem_read_reg & ~ mem_ready;   
    assign mem_write  = mem_write_reg & ~ mem_ready; 
    assign mem_addr   = mem_addr_reg;
    assign mem_wdata  = mem_wdata_reg;

    always @(*) begin
        if (hit_r) begin
            case(block_offset)
                2'b0:  proc_rdata_reg = data0_r[index];
                2'b1:  proc_rdata_reg = data1_r[index];
                2'b10: proc_rdata_reg = data2_r[index];
                2'b11: proc_rdata_reg = data3_r[index];
            endcase
        end
        else begin
            case(block_offset)
                2'b0:  proc_rdata_reg = data0_l[index];
                2'b1:  proc_rdata_reg = data1_l[index];
                2'b10: proc_rdata_reg = data2_l[index];
                2'b11: proc_rdata_reg = data3_l[index];
            endcase
        end
    end


    always @(*) begin
        for (i = 0; i <= 3; i = i + 1) begin
            valid_l_nxt[i] = valid_l[i];
            valid_r_nxt[i] = valid_r[i];
            dirty_l_nxt[i] = dirty_l[i];
            dirty_r_nxt[i] = dirty_r[i];
            ref_l_nxt  [i] = ref_l  [i];
            ref_r_nxt  [i] = ref_r  [i];
            tag_l_nxt  [i] = tag_l  [i];
            tag_r_nxt  [i] = tag_r  [i];
            data0_l_nxt[i] = data0_l[i];
            data0_r_nxt[i] = data0_r[i];
            data1_l_nxt[i] = data1_l[i];
            data1_r_nxt[i] = data1_r[i];
            data2_l_nxt[i] = data2_l[i];
            data2_r_nxt[i] = data2_r[i];
            data3_l_nxt[i] = data3_l[i];
            data3_r_nxt[i] = data3_r[i];
        end
        mem_read_reg = 0;
        mem_write_reg = 0;
        mem_addr_reg   = proc_addr[29:2];
        mem_wdata_reg  = {data3_l[index], data2_l[index], data1_l[index], data0_l[index]};
        case (state) 
            CompareTag: begin  // write hit
                if (hit && proc_write) begin
                    if (hit_l) begin
                        dirty_l_nxt[index] = 1;
                        ref_l_nxt  [index] = 1;  // recently accessed --> ref = 1
                        ref_r_nxt  [index] = 0;
                        case (block_offset)
                            2'b0:  data0_l_nxt[index] = proc_wdata;
                            2'b1:  data1_l_nxt[index] = proc_wdata;
                            2'b10: data2_l_nxt[index] = proc_wdata;
                            2'b11: data3_l_nxt[index] = proc_wdata;
                        endcase
                    end
                    else begin
                        dirty_r_nxt[index] = 1;
                        ref_l_nxt  [index] = 0;
                        ref_r_nxt  [index] = 1;
                        case (block_offset)
                            2'b0:  data0_r_nxt[index] = proc_wdata;
                            2'b1:  data1_r_nxt[index] = proc_wdata;
                            2'b10: data2_r_nxt[index] = proc_wdata;
                            2'b11: data3_r_nxt[index] = proc_wdata;
                        endcase
                    end
                end
            end
            WriteBack: begin
                mem_write_reg = 1;
                if (ref_l[index]) begin 
                    mem_addr_reg  = {tag_r[index], index};
                    mem_wdata_reg = {data3_r[index], data2_r[index], data1_r[index], data0_r[index]};
                end
                else mem_addr_reg = {tag_l[index], index};
            end
            Allocate: begin
                mem_read_reg  = 1;
                if (mem_ready) begin
                    if (!ref_l[index]) begin
                        data0_l_nxt[index] = mem_rdata[31:0];
                        data1_l_nxt[index] = mem_rdata[63:32];
                        data2_l_nxt[index] = mem_rdata[95:64];
                        data3_l_nxt[index] = mem_rdata[127:96];
                        tag_l_nxt  [index] = tag;
                        valid_l_nxt[index] = 1;
                        dirty_l_nxt[index] = 0;
                        ref_l_nxt  [index] = 1;
                        ref_r_nxt  [index] = 0;
                    end
                    else begin
                        data0_r_nxt[index] = mem_rdata[31:0];
                        data1_r_nxt[index] = mem_rdata[63:32];
                        data2_r_nxt[index] = mem_rdata[95:64];
                        data3_r_nxt[index] = mem_rdata[127:96];
                        tag_r_nxt  [index] = tag;
                        valid_r_nxt[index] = 1;
                        dirty_r_nxt[index] = 0;
                        ref_r_nxt  [index] = 1;
                        ref_l_nxt  [index] = 0;
                    end
                end
            end
        endcase
    end



//==== sequential circuit =================================
    always @(posedge clk) begin
        if( proc_reset ) begin
            for (i = 0; i <= 3; i = i + 1) begin
                cache_reg_l[i] <= 157'b0;
                cache_reg_r[i] <= 157'b0;
            end
        end
        else begin
            for (i = 0; i <= 3; i = i + 1) begin
                cache_reg_l[i][156]     <= valid_l_nxt[i];
                cache_reg_r[i][156]     <= valid_r_nxt[i];
                cache_reg_l[i][155]     <= dirty_l_nxt[i];
                cache_reg_r[i][155]     <= dirty_r_nxt[i];
                cache_reg_l[i][154]     <= ref_l_nxt  [i];
                cache_reg_r[i][154]     <= ref_r_nxt  [i];
                cache_reg_l[i][153:128] <= tag_l_nxt  [i];
                cache_reg_r[i][153:128] <= tag_r_nxt  [i];
                cache_reg_l[i][127:96]  <= data0_l_nxt[i];
                cache_reg_r[i][127:96]  <= data0_r_nxt[i];
                cache_reg_l[i][95:64]   <= data1_l_nxt[i];
                cache_reg_r[i][95:64]   <= data1_r_nxt[i];
                cache_reg_l[i][63:32]   <= data2_l_nxt[i];
                cache_reg_r[i][63:32]   <= data2_r_nxt[i];
                cache_reg_l[i][31:0]    <= data3_l_nxt[i];
                cache_reg_r[i][31:0]    <= data3_r_nxt[i];
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
                    else if (need_writeback) state_nxt = WriteBack;
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
