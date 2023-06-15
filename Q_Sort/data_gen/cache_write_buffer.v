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
    

    input          clk;

    // processor interface
    input          proc_reset;
    input          proc_read, proc_write;
    input   [29:0] proc_addr; //4 bytes address, less 2 bits for block offset, 2 bits for modulo, others 26 bits for tag
    input   [31:0] proc_wdata;
    output         proc_stall;
    output  [31:0] proc_rdata;

    // memory interface
    input  [127:0] mem_rdata;
    input          mem_ready;
    output         mem_read, mem_write;
    output  [27:0] mem_addr;
    output [127:0] mem_wdata;

    reg    [2-1:0] state_r;
    reg    [2-1:0] state_w;

    reg  [128-1:0] cache_r[0:4-1][0:2-1]; //A word contains 4 bytes, a block contains 4 words, 8 blocks
    reg  [128-1:0] cache_w[0:4-1][0:2-1]; //A word contains 4 bytes, a block contains 4 words, 8 blocks
 
    reg            valid_r[0:4-1][0:2-1]; //valid bits for blocks
    reg            valid_w[0:4-1][0:2-1]; //valid bits for blocks

    reg            modified_r[0:4-1][0:2-1]; //modified bits for blocks
    reg            modified_w[0:4-1][0:2-1]; //modified bits for blocks

    reg   [26-1:0] tag_r[0:4-1][0:2-1]; //tag bits for blocks
    reg   [26-1:0] tag_w[0:4-1][0:2-1]; //tag bits for blocks
 
    reg            recent_r[0:4-1]; //recent bit for blocks, 1'b0 means cache_r[proc_modulo][0] is recently taken
    reg            recent_w[0:4-1]; //recent bit for blocks

    wire  [26-1:0] proc_tag;
    wire   [2-1:0] proc_modulo;
    wire   [2-1:0] proc_offset;

    reg  [128-1:0] write_buffer_r;
    reg  [128-1:0] write_buffer_w;
    reg   [28-1:0] write_buffer_tag_and_modulo_r;
    reg   [28-1:0] write_buffer_tag_and_modulo_w;
    reg            write_buffer_empty_r;
    reg            write_buffer_empty_w;

    wire           stall; //stall due to nonempty write buffer

    wire           hit;
    wire           read_miss;
    wire           read_hit;
    wire           write_miss;
    wire           write_hit;
    wire           old_valid_and_modified;

    wire           index;

    integer        i, j;

    parameter      STATE_READY = 2'd0;
    parameter      STATE_READ  = 2'd1; //Read from memory
    parameter      STATE_WRITE = 2'd3; //Write to memory

    //Unfold processor address into tag, modulo and offset
    assign proc_tag = proc_addr[26+2+2-1:2+2];
    assign proc_modulo = proc_addr[2+2-1:2];
    assign proc_offset = proc_addr[2-1:0];

    //Control signal
    assign index = proc_tag == tag_r[proc_modulo][1];
    assign hit = (proc_tag == tag_r[proc_modulo][0] && valid_r[proc_modulo][0]) || (proc_tag == tag_r[proc_modulo][1] && valid_r[proc_modulo][1]);
    assign read_hit = proc_read && hit;
    assign read_miss = proc_read && !hit;
    assign write_hit = proc_write && hit;
    assign write_miss = proc_write && !hit;
    assign old_valid_and_modified = valid_r[proc_modulo][~ recent_r[proc_modulo]] && modified_r[proc_modulo][~ recent_r[proc_modulo]];
    assign stall = read_miss || write_miss;

    //Handle state_r (FSM)
    always @(*) begin
        case (state_r)
            STATE_READY:
                if (read_miss || write_miss) begin
                    if (old_valid_and_modified) begin //need write back modified data
                        if (write_buffer_empty_r) begin //write data to write buffer if the buffer is empty and read first
                            state_w = STATE_READ;
                        end
                        else begin //write back write buffer to memory if the buffer is nonempty
                            state_w = STATE_WRITE;
                        end
                    end
                    else begin //data not modified and no need to write memory
                        state_w = STATE_READ;
                    end
                end
                else if (write_buffer_empty_r == 1'b0) begin //if no sequential miss, write the buffer back
                    state_w = STATE_WRITE;
                end
                else begin //no miss and no data in write buffer
                    state_w = STATE_READY;
                end
            STATE_WRITE:
                if (mem_ready) begin //write memory finish
                    state_w = STATE_READY;
                end
                else begin //write memory not finish
                    state_w = STATE_WRITE;
                end
            STATE_READ:
                if (mem_ready) begin //read memory finish
                    state_w = STATE_READY;
                end
                else begin //read memory not finish
                    state_w = STATE_READ;
                end
            default: //dead zone
                state_w = STATE_READY;
        endcase
    end

    always@(posedge clk) begin
        if(proc_reset) begin
            state_r <= STATE_READY;
        end
        else begin
            state_r <= state_w;
        end
    end
    
    //Handle write_buffer_empty_r
    always @(*) begin
        write_buffer_empty_w = write_buffer_empty_r;
        if (state_r == STATE_WRITE && mem_ready) begin //if write finish, set write buffer empty to true
            write_buffer_empty_w = 1'b1;
        end
        else if (state_r == STATE_READY && (read_miss || write_miss) && old_valid_and_modified && write_buffer_empty_r) begin //in ready state, if miss and old data valid and modified and at the same time the write buffer is empty, accomodate the old date 
            write_buffer_empty_w = 1'b0;
        end
    end

    always@(posedge clk) begin
        if(proc_reset) begin
            write_buffer_empty_r <= 1'b1;
        end
        else begin
            write_buffer_empty_r <= write_buffer_empty_w;
        end
    end

    //Handle write_buffer_r
    always @(*) begin
        write_buffer_w = write_buffer_r;
        write_buffer_tag_and_modulo_w = write_buffer_tag_and_modulo_r;
        if (state_r == STATE_READY && (read_miss || write_miss) && old_valid_and_modified && write_buffer_empty_r) begin //in ready state, if miss and old data valid and modified and at the same time the write buffer is empty, accomodate the old date 
           write_buffer_w = cache_r[proc_modulo][~ recent_r[proc_modulo]];
           write_buffer_tag_and_modulo_w = {tag_r[proc_modulo][~ recent_r[proc_modulo]], proc_modulo};
        end
    end

    always @(posedge clk) begin
        if(proc_reset) begin
            write_buffer_r <= 128'd0;
            write_buffer_tag_and_modulo_r <= 28'd0;
        end
        else begin
            write_buffer_r <= write_buffer_w;
            write_buffer_tag_and_modulo_r <= write_buffer_tag_and_modulo_w;
        end
    end

    //Handle cache_r
    always @(*) begin
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 2; j = j + 1) begin
                cache_w[i][j] = cache_r[i][j];
            end
        end
        if (state_r == STATE_READ && mem_ready) begin
            cache_w[proc_modulo][~ recent_r[proc_modulo]] = mem_rdata;
        end
        else if (state_r == STATE_READY && write_hit) begin
            cache_w[proc_modulo][index][(proc_offset+1)*32-1-:32] = proc_wdata;
        end
    end

    always@(posedge clk) begin
        if(proc_reset) begin
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 2; j = j + 1) begin
                    cache_r[i][j] <= 128'd0;
                end
            end
        end
        else begin
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 2; j = j + 1) begin
                    cache_r[i][j] <= cache_w[i][j];
                end
            end
        end
    end

    //Handle valid_r
    always @(*) begin
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 2; j = j + 1) begin
                valid_w[i][j] = valid_r[i][j];
            end
        end
        if (state_r == STATE_READ && mem_ready) begin
            valid_w[proc_modulo][~ recent_r[proc_modulo]] = 1'b1;
        end
    end

    always@(posedge clk) begin
        if(proc_reset) begin
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 2; j = j + 1) begin
                    valid_r[i][j] <= 1'b0;
                end
            end
        end
        else begin
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 2; j = j + 1) begin
                    valid_r[i][j] <= valid_w[i][j];
                end
            end
        end
    end

    //Handle tag_r
    always @(*) begin
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 2; j = j + 1) begin
                tag_w[i][j] = tag_r[i][j];
            end
        end
        if (state_r == STATE_READ && mem_ready) begin
            tag_w[proc_modulo][~ recent_r[proc_modulo]] = proc_tag;
        end
    end

    always@(posedge clk) begin
        if(proc_reset) begin
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 2; j = j + 1) begin
                    tag_r[i][j] <= 26'd0;
                end
            end
        end
        else begin
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 2; j = j + 1) begin
                    tag_r[i][j] <= tag_w[i][j];
                end
            end
        end
    end

    //Handle recent_r
    always @(*) begin
        for (i = 0; i < 4; i = i + 1) begin
            recent_w[i] = recent_r[i];
        end
        if (state_r == STATE_READY && (read_hit || write_hit)) begin
            recent_w[proc_modulo] = index;
        end
    end

    always@(posedge clk) begin
        if(proc_reset) begin
            for (i = 0; i < 4; i = i + 1) begin
                recent_r[i] <= 1'b0;
            end
        end
        else begin
            for (i = 0; i < 4; i = i + 1) begin
                recent_r[i] <= recent_w[i];
            end
        end
    end

    //Handle modified_r
    always @(*) begin
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 2; j = j + 1) begin
                modified_w[i][j] = modified_r[i][j];
            end
        end
        if (state_r == STATE_READ && mem_ready) begin
            modified_w[proc_modulo][~ recent_r[proc_modulo]] = 1'b0;
        end
        else 
        if (write_hit) begin
            modified_w[proc_modulo][index] = 1'b1;
        end
    end

    always@(posedge clk) begin
        if(proc_reset) begin
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 2; j = j + 1) begin
                    modified_r[i][j] <= 1'b0;
                end
            end
        end
        else begin
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 2; j = j + 1) begin
                    modified_r[i][j] <= modified_w[i][j];
                end
            end
        end
    end

    //Output
    assign proc_stall = stall;
    assign proc_rdata = cache_r[proc_modulo][index][(proc_offset+1)*32-1-:32];
    assign mem_read = state_r == STATE_READ & ~ mem_ready;
    assign mem_write = state_r == STATE_WRITE & ~ mem_ready;
    assign mem_addr = state_r == STATE_READ ? {proc_tag, proc_modulo} : write_buffer_tag_and_modulo_r;
    assign mem_wdata = write_buffer_r;
endmodule
