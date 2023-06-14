// this is a test bench feeds initial instruction and data
// the processor output is not verified

`timescale 1 ns/10 ps
`define START_LOC 0
`define N_PAT 160

`ifdef COMPRESS
	`define END_PC 320
	`define IMEM_INIT "I_mem_compression"
`else
	`define END_PC 400
	`define IMEM_INIT "I_mem"
`endif

`define CYCLE 3.5 // You can modify your clock frequency
`define DMEM_INIT "D_mem"
`define GOLDEN    "D_gold"
`define SDFFILE   "./CHIP_syn.sdf"	// Modify your SDF file name

module Final_scoring;

	reg clk;
	reg rst_n;
	
	wire mem_read_D;
	wire mem_write_D;
	wire [31:4] mem_addr_D;
	wire [127:0] mem_wdata_D;
	wire [127:0] mem_rdata_D;
	wire mem_ready_D;

	wire mem_read_I;
	wire mem_write_I;
	wire [31:4] mem_addr_I;
	wire [127:0] mem_wdata_I;
	wire [127:0] mem_rdata_I;
	wire mem_ready_I;
	
	wire [29:0]	DCACHE_addr;
	wire [31:0]	DCACHE_wdata;
	wire 		DCACHE_wen;
	
	wire [8:0] error_num;
	wire [15:0] duration;
	wire finish;
	wire [31:0] PC;

	// Note the design is connected at testbench, include:
	// 1. CHIP (RISCV + D_cache + I_chache)
	// 2. slow memory for data
	// 3. slow memory for instruction
	
	CHIP chip0 (clk,
				rst_n,
//----------for slow_memD------------	
				mem_read_D,
				mem_write_D,
				mem_addr_D,
				mem_wdata_D,
				mem_rdata_D,
				mem_ready_D,
//----------for slow_memI------------
				mem_read_I,
				mem_write_I,
				mem_addr_I,
				mem_wdata_I,
				mem_rdata_I,
				mem_ready_I,
//----------for TestBed--------------				
				DCACHE_addr,
				DCACHE_wdata,
				DCACHE_wen,
				PC
				);
	
	slow_memory slow_memD(
		.clk        (clk)           ,
		.mem_read   (mem_read_D)    ,
		.mem_write  (mem_write_D)   ,
		.mem_addr   (mem_addr_D)    ,
		.mem_wdata  (mem_wdata_D)   ,
		.mem_rdata  (mem_rdata_D)   ,
		.mem_ready  (mem_ready_D)
	);

	slow_memory slow_memI(
		.clk        (clk)           ,
		.mem_read   (mem_read_I)    ,
		.mem_write  (mem_write_I)   ,
		.mem_addr   (mem_addr_I)    ,
		.mem_wdata  (mem_wdata_I)   ,
		.mem_rdata  (mem_rdata_I)   ,
		.mem_ready  (mem_ready_I)
	);

	TestBed testbed(
		.clk        (clk)           ,
		.rst        (rst_n)         ,
		.addr       (DCACHE_addr)   ,
		.data       (DCACHE_wdata)  ,
		.wen        (DCACHE_wen)    ,
		.PC			(PC)			,
		.error_num  (error_num)     ,
		.finish     (finish)
	);
	
`ifdef SDF
    initial $sdf_annotate(`SDFFILE, chip0);
`endif
	
// Initialize the data memory
	initial begin
		$readmemh (`DMEM_INIT, slow_memD.mem ); // initialize data in DMEM
		$readmemh (`IMEM_INIT, slow_memI.mem ); // initialize data in IMEM

	    // $fsdbDumpfile("Final.fsdb");			
		// $fsdbDumpvars(0,Final_scoring,"+mda");
		// $fsdbDumpvars;
	
		clk = 0;
		rst_n = 1'b1;
		#(`CYCLE*0.6) rst_n = 1'b0;
		#(`CYCLE*8.9) 
		#0.1 rst_n = 1'b1;

		$display("-----------------------------------------------------\n");
	 	$display("START!!! Simulation Start .....\n");
	 	$display("-----------------------------------------------------\n");

     
		#(`CYCLE*10000000) // calculate clock cycles for all operation (you can modify it)
		$display("============================================================================");
		$display("\n           Error!!! There is something wrong with your code ...!          ");
		$display("\n                       The test result is .....FAIL                     \n");
		$display("============================================================================");
	 	$finish;
	end
		
	always #(`CYCLE*0.5) clk = ~clk;
	
	always@(finish)
	    if(finish)
	       #(`CYCLE) $finish;		   
	
endmodule




module	TestBed(
	clk,
	rst,
	addr,
	data,
	wen,
	PC,
	error_num,
	finish
);
	input			clk, rst;
	input	[29:0]	addr;
	input	[31:0]	data;
	input			wen;
	input	[31:0]  PC;
	output	[8:0]	error_num;
	output			finish;


	reg		[1:0]	state_w, state_r;
	parameter		S_IDLE = 0, S_CHECK = 1, S_REPORT= 2, S_END=3;

	reg		[9:0]	counter_r, counter_w;
	reg		[8:0]	error_num_r, error_num_w;
	reg				finish_r, finish_w;

	reg		[31:0]	golden_ans [0:255];
	reg		[31:0]  pseudo_mem [0:255];
	wire signed	[31:0]	golden_dec, pseudo_dec;


	initial	begin
		$readmemh (`DMEM_INIT, pseudo_mem ); // initialize data in DMEM
		$readmemh (`GOLDEN,    golden_ans );
	end

	// output logic
	assign finish = finish_r;
	assign error_num = error_num_r;


	// state machine
	always@(posedge clk) begin
		if( (state_r==S_IDLE) && (wen) ) begin
			pseudo_mem[addr] = data;
		end
	end

	always@(*) begin
		state_w = state_r;
		case( state_r )
			S_IDLE: begin
				if(PC>=`END_PC)
					state_w = S_CHECK;
			end
			S_CHECK: begin
				if(counter_r==255)
				state_w = S_REPORT;
			end
			S_REPORT: begin	
				state_w = S_END;
			end				
		endcase	
	end


	assign pseudo_dec = {pseudo_mem[counter_r][7:0],pseudo_mem[counter_r][15:8],pseudo_mem[counter_r][23:16],pseudo_mem[counter_r][31:24]};
	assign golden_dec = {golden_ans[counter_r][7:0],golden_ans[counter_r][15:8],golden_ans[counter_r][23:16],golden_ans[counter_r][31:24]};

	always@(*) begin
		counter_w = counter_r;
		error_num_w = error_num_r;
		finish_w = finish_r;
		case( state_r )
			S_CHECK: begin
				counter_w = counter_r+1;
				if(pseudo_mem[counter_r] !== golden_ans[counter_r])
					error_num_w = error_num_r + 1;
			end
			S_REPORT: begin
				finish_w = 1;
			end				
		endcase	
	end

	always@(error_num_r) begin
		if(state_r == S_CHECK)
			$display(" error in mem %d (0x%h)  expect:%d (%h),          get:%d (%h)", counter_r[7:0], counter_r<<2, golden_dec, golden_ans[counter_r], pseudo_dec, pseudo_mem[counter_r]);
	end

	always@( negedge clk ) begin
		if(state_r == S_REPORT) begin
			$display("--------------------------- Simulation FINISH !!---------------------------");
			if (|error_num_r) begin 
				$display("============================================================================");
				$display("\n (T_T) FAIL!! The simulation result is FAIL!!! there were %d errors at all.\n", error_num);
				$display("============================================================================");
			end
			 else begin 
				$display("============================================================================");
				$display("\n \\(^o^)/ CONGRATULATIONS!!  The simulation result is PASS!!!\n");
				$display("============================================================================");
			end
		end
	end



	always@( posedge clk or negedge rst ) begin
		if( ~rst ) begin
			state_r 	<= S_IDLE;
			counter_r	<= 0;
			error_num_r	<= 0;
			finish_r	<= 0;
		end
		else begin
			state_r 	<= state_w;
			counter_r	<= counter_w;
			error_num_r	<= error_num_w;
			finish_r	<= finish_w;
		end
	end

endmodule
