// ece 564 - project 1 - Arpad Voros
module MyDesign (	dut_run,
					dut_busy,
					reset_b,
					clk,
					dut_sram_write_address,
					dut_sram_write_data,
					dut_sram_write_enable,
					dut_sram_read_address,
					sram_dut_read_data,
					dut_wmem_read_address,
					wmem_dut_read_data);

// if 1, do convolution
input dut_run;
// set to 1 if calculating, 0 once done and stored
output reg dut_busy;
reg set_dut_busy;

// reset and clock
input reset_b;
input clk;

// dut -> sram (input)
output reg [11:0] dut_sram_read_address;
// sram -> dut (input)
input [15:0] sram_dut_read_data;

// dut -> sram (weights)
output reg [11:0] dut_wmem_read_address;
// sram -> dut (weights)
input [15:0] wmem_dut_read_data;

// dut -> sram (output)
output reg [11:0] dut_sram_write_address;
output reg [15:0] dut_sram_write_data;
output reg dut_sram_write_enable;

// high and low, used for flags and whatnot
parameter high = 1'b1;
parameter low = 1'b0;

// indicates which modules pass the indicies
parameter top_pipeline_idx = 1'b1;
parameter rest_pipeline_idx = 1'b0;

// since weights is limited to 3x3, ONLY second address needed for weights
parameter weights_dims_addr = 12'h0;
parameter weights_data_addr = 12'h1;

// initial address (0)
parameter initial_addr = 12'h0;

// increment everything by this much
parameter incr = 1'b1;

// initial counter
parameter counter_init = 16'h0;

// data size
parameter word_size = 16'h10;

// end condition
parameter end_condition = 16'h00FF;

// states
parameter [3:0]
	S0 = 4'b0000,
	S1 = 4'b0001,
	S2 = 4'b0010,
	S3 = 4'b0011,
	S4 = 4'b0100,
	S5 = 4'b0101,
	S6 = 4'b0110,
	S7 = 4'b0111,
	S8 = 4'b1000,
	S9 = 4'b1001,
	SA = 4'b1010,
	SB = 4'b1011,
	SC = 4'b1100,
	SD = 4'b1101,
	SE = 4'b1110,
	SF = 4'b1111;

// REGISTERS
// store states
reg [3:0] current_state, next_state;

// store weight dimensions
reg [15:0] weight_dims;

// store weight data
reg [15:0] weight_data;

// store current input address
reg [11:0] current_input_addr;

// store current write address for output
reg [11:0] output_write_addr;

// store number of input rows, columns
reg [15:0] input_num_rows;
reg [15:0] input_num_cols;

// store first, second, third row of input
// (hardcoded because kernel limited to 3x3)
reg [15:0] input_r0;
reg [15:0] input_r1;
reg [15:0] input_r2;

// row and column counter
reg [15:0] ridx_counter;
reg [15:0] cidx_counter;

// output to store
reg [15:0] output_row_temp;

// flag to tell each convolution module to pass through data
reg conv_go;

// flag to load in weights to convolution modules
reg load_weights;

// setting stored flag
reg stored_flag;
reg set_stored_flag;
reg loaded_for_sweep;

// weights (kernel limited to 3x3, so hardcoding)
reg w02, w01, w00;
reg w12, w11, w10;
reg w22, w21, w20;

// input data
reg d02;
reg d12;
reg d22;

// stage 1 index and done flag
reg set_s2_done;
reg [11:0] s1_waddr;
reg [11:0] set_s2_waddr;

// stage 2 index and done flag
reg s2_done;
reg [3:0] s2_idx;
reg [11:0] s2_waddr;

// stage 3 index and done flag
reg s3_done;
reg prev_s3_done;
reg [3:0] s3_idx;
reg [11:0] s3_waddr;

// stage 2 full adder inputs
reg FA1_s2_in1;
reg FA1_s2_in2;
reg FA1_s2_in3;
reg FA2_s2_in1;
reg FA2_s2_in2;
reg FA2_s2_in3;

// stage 3, full adder logic for pos/neg checking
reg ones;
reg twos1, twos2;
reg fours;

// DEBUGGING
reg debug;

// WIRES
// pipelined data
wire d02_out, d01_out, d00_out;
wire d12_out, d11_out, d10_out;
wire d22_out, d21_out, d20_out;

// pipelined write address
wire [11:0] waddr02_out, waddr01_out, waddr00_out;
wire [11:0] waddr12_out, waddr11_out, waddr10_out;
wire [11:0] waddr22_out, waddr21_out, waddr20_out;

// pipelined column indicies
wire [3:0] c02_out, c01_out, c00_out;
wire [3:0] c12_out, c11_out, c10_out;
wire [3:0] c22_out, c21_out, c20_out;

// negative flags (outputs to be summed)
wire n02, n01, n00;
wire n12, n11, n10;
wire n22, n21, n20;

// stage 1 full adder outputs
wire FA1_s1_ones;
wire FA1_s1_twos;
wire FA2_s1_ones;
wire FA2_s1_twos;
wire FA3_s1_ones;
wire FA3_s1_twos;

// stage 2 full adder outputs
wire FA1_s2_ones;
wire FA1_s2_twos;
wire FA2_s2_twos;
wire FA2_s2_fours;

// row and column out-of-bounds flags
// wire row_prep_oob;
wire last_row_flag;
wire col_prep_oob;
// wire last_col_flag;

// used in storing for output
wire [15:0] max_col_idx;

// wire used to store output data
wire negative_flag;

// Moore machine, sequential logic
always@(posedge clk or negedge reset_b)
	if (!reset_b) begin
		// go to state 0
		current_state <= S0;
		
		// dut not busy
		dut_busy <= low;
		
		// done flags set low
		s2_done <= low;
		s3_done <= low;
		prev_s3_done <= low;
		
		// SYNOPSIS HERE
		// output temp
		output_row_temp <= counter_init;
	end else begin
		// next state
		current_state <= next_state;
		
		// FA stage 1 -> 2
		FA1_s2_in1 <= FA1_s1_ones;
		FA1_s2_in2 <= FA2_s1_ones;
		FA1_s2_in3 <= FA3_s1_ones;
		FA2_s2_in1 <= FA1_s1_twos;
		FA2_s2_in2 <= FA2_s1_twos;
		FA2_s2_in3 <= FA3_s1_twos;
		
		// storage registers stage 1 -> 2
		s2_done <= set_s2_done; 
		s2_idx <= c00_out; 
		s2_waddr <= set_s2_waddr; 
				
		// FA stage 2 -> 3
		ones <= FA1_s2_ones;
		twos1 <= FA1_s2_twos;
		twos2 <= FA2_s2_twos;
		fours <= FA2_s2_fours;
		
		// storage registers stage 2 -> 3
		s3_done <= s2_done;
		prev_s3_done <= s3_done;
		s3_idx <= s2_idx;
		s3_waddr <= s2_waddr;
		
		// SYNOPSIS HERE
		// output stored flag
		stored_flag <= set_stored_flag;
		
		// dut busy reg
		dut_busy <= set_dut_busy;
	end

// bruh
always@(current_state or dut_run) //
begin
	case(current_state)
		// begin state, look for when to run
		S0: begin
			// check if top module wants us to run
			if (dut_run) begin
				set_dut_busy = high;
				// next state
				next_state = S1;
			end else begin
				set_dut_busy = low;
				// retain state
				next_state = S0;
			end
			
			// debug
			debug = low;
			
			// keep address at 0
			current_input_addr = initial_addr;
			output_write_addr = initial_addr;
			
			// do not do convolution
			conv_go = low;
			
			// values not fully rippled down
			loaded_for_sweep = low;
			
			// reset adder ripple 
			set_s2_done = low;
			set_s2_waddr = initial_addr;
			set_stored_flag = low;
				
			// do not load weights
			load_weights = low;
			
			// set counters to 0
			ridx_counter = counter_init;
			cidx_counter = counter_init;
		end
		
		S1: begin
			// load in weights dimensions
			dut_wmem_read_address = weights_dims_addr;
			
			// load in input dimension 1 (rows)
			dut_sram_read_address = current_input_addr;
			
			// next state
			next_state = S2;
		end
		
		S2: begin
			// store weights dimensions
			weight_dims = wmem_dut_read_data - incr;
			
			// store input dimension 1 (rows)
			input_num_rows = sram_dut_read_data - incr;
			
			// load in weights data
			dut_wmem_read_address = weights_data_addr;
			
			// increment current input address
			// load in input dimension 2 (columns)
			current_input_addr = current_input_addr + incr;
			dut_sram_read_address = current_input_addr;
			
			if (sram_dut_read_data == end_condition) begin
				// done
				// otherwise set dut_busy to 0 and go back to state 0
				set_dut_busy = low;
				// next state
				next_state = S0;
			end else begin
				// next state
				next_state = S3;
			end
		end
		
		S3: begin
			// store weights data
			weight_data = wmem_dut_read_data;
			
			// store input dimension 2 (cols)
			input_num_cols = sram_dut_read_data - incr;
			
			// increment current input address
			// load in FIRST row of input
			current_input_addr = current_input_addr + incr;
			dut_sram_read_address = current_input_addr;
		
			// next state
			next_state = S4;
		end
		
		S4: begin
			// set row counter to weight dim - 1
			ridx_counter = weight_dims - incr;
			
			// (kernel limited to 3x3, so hardcoding)
			w00 = weight_data[0];
			w01 = weight_data[1];
			w02 = weight_data[2];
			w10 = weight_data[3];
			w11 = weight_data[4];
			w12 = weight_data[5];
			w20 = weight_data[6];
			w21 = weight_data[7];
			w22 = weight_data[8];
			
			// load in weights into conv_modules
			load_weights = high;
			
			// store FIRST row of input
			input_r0 = sram_dut_read_data;
			
			// increment current input address
			// load in SECOND row of input
			current_input_addr = current_input_addr + incr;
			dut_sram_read_address = current_input_addr;
			
			// next state
			next_state = S5;
		end
		
		S5: begin
			// stop loading in weights
			load_weights = low;
			
			// store SECOND row of input
			input_r1 = sram_dut_read_data;
			
			// increment current input address
			// load in THIRD row of input
			current_input_addr = current_input_addr + incr;
			dut_sram_read_address = current_input_addr;
			
			// next state
			next_state = S6;
		end
		
		S6: begin
			// store THIRD row of input
			input_r2 = sram_dut_read_data;
			
			// next state
			next_state = S7;
		end
		
		S7: begin
			// start loading for sweep
			// row counter already updated
			// set column to 0
			cidx_counter = counter_init;
				
			// load in data to convolution modules
			d02 = input_r0[cidx_counter[3:0]];
			d12 = input_r1[cidx_counter[3:0]];
			d22 = input_r2[cidx_counter[3:0]];
			
			// start convolution to pass down data
			conv_go = high;
			
			// next state
			next_state = S8;
		end
		
		// =========================================================
		S8: begin
			// debug oscillate
			debug = ~debug;
		
			// increment counter
			cidx_counter = cidx_counter + incr;
			
			// load in data to convolution modules
			d02 = input_r0[cidx_counter[3:0]];
			d12 = input_r1[cidx_counter[3:0]];
			d22 = input_r2[cidx_counter[3:0]];
			
			if (~loaded_for_sweep) begin
				if (cidx_counter == weight_dims) begin
					// set high
					loaded_for_sweep = high;
				end else begin
					// stay low
					loaded_for_sweep = loaded_for_sweep;
				end
				
				if (cidx_counter == weight_dims - incr) begin
					// ripple done flag through adders
					set_s2_done = high;
					set_s2_waddr = output_write_addr;
				end else begin
					// not done
					set_s2_done = set_s2_done;
					set_s2_waddr = set_s2_waddr;
				end
			end else begin
				// stay low
				loaded_for_sweep = low;
				// keep same
				set_s2_done = set_s2_done;
				set_s2_waddr = set_s2_waddr;
			end
			
			// if NEXT clock cycle past dims, request to load new row
			// otherwise loop in this state
			if (col_prep_oob) begin
				if (~last_row_flag) begin
					// increment current input address
					// load in NEXT row of input
					current_input_addr = current_input_addr + incr;
					dut_sram_read_address = current_input_addr;
				end else begin
					// stays the same
					current_input_addr = current_input_addr;
					dut_sram_read_address = dut_sram_read_address;
				end
				// next state
				next_state = S9;
			end else begin
				// next state
				next_state = SB;
			end
		end
		
		SB: begin
			// debug oscillate
			debug = ~debug;
		
			// increment counter
			cidx_counter = cidx_counter + incr;
			
			// load in data to convolution modules
			d02 = input_r0[cidx_counter[3:0]];
			d12 = input_r1[cidx_counter[3:0]];
			d22 = input_r2[cidx_counter[3:0]];
			
			if (~loaded_for_sweep) begin
				if (cidx_counter == weight_dims) begin
					// set high
					loaded_for_sweep = high;
				end else begin
					// stay low
					loaded_for_sweep = loaded_for_sweep;
				end
				
				if (cidx_counter == weight_dims - incr) begin
					// ripple done flag through adders
					set_s2_done = high;
					set_s2_waddr = output_write_addr;
				end else begin
					// not done
					set_s2_done = set_s2_done;
					set_s2_waddr = set_s2_waddr;
				end
			end else begin
				// stay low
				loaded_for_sweep = low;
				// keep same
				set_s2_done = set_s2_done;
				set_s2_waddr = set_s2_waddr;
			end
			
			// if NEXT clock cycle past dims, request to load new row
			// otherwise loop in this state
			if (col_prep_oob) begin
				if (~last_row_flag) begin
					// increment current input address
					// load in NEXT row of input
					current_input_addr = current_input_addr + incr;
					dut_sram_read_address = current_input_addr;
				end else begin
					// stays the same
					current_input_addr = current_input_addr;
					dut_sram_read_address = dut_sram_read_address;
				end
				// next state
				next_state = S9;
			end else begin
				// next state
				next_state = S8;
			end
		end
		// =========================================================
		
		S9: begin
			// increment counter
			cidx_counter = cidx_counter + incr;
			
			// load in data to convolution modules
			d02 = input_r0[cidx_counter[3:0]];
			d12 = input_r1[cidx_counter[3:0]];
			d22 = input_r2[cidx_counter[3:0]];
			
			// stop rippling done flag
			set_s2_done = low;
			
			if (~last_row_flag) begin
				// propagate rows upward
				input_r0 = input_r1;
				input_r1 = input_r2;
				// store NEXT row of input
				input_r2 = sram_dut_read_data;
				
				// increase row counter
				ridx_counter = ridx_counter + incr;
				
				// increase write address
				output_write_addr = output_write_addr + incr;
								
				// convolution passing data
				conv_go = high;
				
				// go back to sweeping
				next_state = S7;
			end else begin
				// stays the same
				input_r0 = input_r0;
				input_r1 = input_r1;
				input_r2 = input_r2;
				output_write_addr = output_write_addr;
				
				// stop convolution passing data, only left for adders to finish rippling
				conv_go = low;
				
				// reset row counter
				ridx_counter = counter_init;
				
				// end, wrap up
				next_state = SA;
			end
		end
		
		// =========================================================
		SA: begin
			// check s3_done, keep looping if high
			if (s3_done) begin
				// keep the same
				current_input_addr = current_input_addr;
				output_write_addr = output_write_addr;
				// next state
				next_state = SF;
			end else begin
				// increment input address for next dimension
				current_input_addr = current_input_addr + incr;
				output_write_addr = output_write_addr + incr;
				// next state
				next_state = S1;
			end
		end
		
		SF: begin
			// check s3_done, keep looping if high
			if (s3_done) begin
				// keep the same
				current_input_addr = current_input_addr;
				output_write_addr = output_write_addr;
				// next state
				next_state = SA;
			end else begin
				// increment input address for next dimension
				current_input_addr = current_input_addr + incr;
				output_write_addr = output_write_addr + incr;
				// next state
				next_state = S1;
			end
		end
		// =========================================================
		
		default: next_state = S0;
	endcase
end

always@(*) //?
begin
	/*if (s3_done) begin
		if (s3_idx > max_col_idx[3:0]) begin
			// SYNOPSIS HERE LATCH ?
			output_row_temp = output_row_temp;
		end else begin
			// add to output for storing
			output_row_temp[s3_idx] = ~negative_flag;
		end
	end else begin
		output_row_temp = output_row_temp;
	end*/
	
	if (s3_done & ~(s3_idx > max_col_idx[3:0])) begin
		// add to output for storing
		output_row_temp[s3_idx] = ~negative_flag;
	end else begin
		// otherwise retain value
		output_row_temp = output_row_temp;
	end
	
	/*if (prev_s3_done) begin 
		// retain these values
		output_row_temp = output_row_temp;
		set_stored_flag = set_stored_flag;
		dut_sram_write_enable = dut_sram_write_enable;
	end else begin
		if (stored_flag) begin
			// reset values
			output_row_temp = counter_init;
			set_stored_flag = low;
			dut_sram_write_enable = low;
		end else begin			
			// otherwise retain values
			output_row_temp = output_row_temp;			
			set_stored_flag = set_stored_flag;
			dut_sram_write_enable = dut_sram_write_enable;
		end
	end*/
	
	if (~prev_s3_done & stored_flag) begin 
		// reset values
		output_row_temp = counter_init;
		set_stored_flag = low;
		dut_sram_write_enable = low;
	end else begin
		// otherwise retain values
		output_row_temp = output_row_temp;			
		set_stored_flag = set_stored_flag;
		dut_sram_write_enable = dut_sram_write_enable;
	end
	
	// negative edge of done flag
	if (~s3_done & prev_s3_done) begin
		// write 
		dut_sram_write_enable = high;
		dut_sram_write_address = s3_waddr;		
		dut_sram_write_data = output_row_temp;
		set_stored_flag = high;
	end else begin
		// do not write, retain
		dut_sram_write_enable = dut_sram_write_enable;
		dut_sram_write_address = dut_sram_write_address;
		dut_sram_write_data = dut_sram_write_data;
		set_stored_flag = set_stored_flag;
	end
end

// row and column out-of-bounds flags
assign last_row_flag = ((ridx_counter + incr) == input_num_rows);
assign col_prep_oob = (cidx_counter == input_num_cols);

// max index to be stored for convolution
assign max_col_idx = input_num_cols - weight_dims;

// negative flag of currently rippled value
assign negative_flag = (ones & twos1 & twos2) | ((ones | twos1 | twos2) & fours);

// instantiate convolution modules
// m02, m01, m00
// m12, m11, m10
// m22, m21, m20
// first row
conv_module m02 (clk, reset_b, conv_go, load_weights, w02, d02, top_pipeline_idx, output_write_addr, cidx_counter[3:0], d02_out, waddr02_out, c02_out, n02);
conv_module m01 (clk, reset_b, conv_go, load_weights, w01, d02_out, top_pipeline_idx, waddr02_out, c02_out, d01_out, waddr01_out, c01_out, n01);
conv_module m00 (clk, reset_b, conv_go, load_weights, w00, d01_out, top_pipeline_idx, waddr01_out, c01_out, d00_out, waddr00_out, c00_out, n00);
// second row
conv_module m12 (clk, reset_b, conv_go, load_weights, w12, d12, rest_pipeline_idx, output_write_addr, cidx_counter[3:0], d12_out, waddr12_out, c12_out, n12);
conv_module m11 (clk, reset_b, conv_go, load_weights, w11, d12_out, rest_pipeline_idx, waddr12_out, c12_out, d11_out, waddr11_out, c11_out, n11);
conv_module m10 (clk, reset_b, conv_go, load_weights, w10, d11_out, rest_pipeline_idx, waddr11_out, c11_out, d10_out, waddr10_out, c10_out, n10);
// third row
conv_module m22 (clk, reset_b, conv_go, load_weights, w22, d22, rest_pipeline_idx, output_write_addr, cidx_counter[3:0], d22_out, waddr22_out, c22_out, n22);
conv_module m21 (clk, reset_b, conv_go, load_weights, w21, d22_out, rest_pipeline_idx, waddr22_out, c22_out, d21_out, waddr21_out, c21_out, n21);
conv_module m20 (clk, reset_b, conv_go, load_weights, w20, d21_out, rest_pipeline_idx, waddr21_out, c21_out, d20_out, waddr20_out, c20_out, n20);

// instantiate adders for pos/neg calculation
// stage 1
full_adder FA1_s1 (n02, n01, n00, FA1_s1_ones, FA1_s1_twos);
full_adder FA2_s1 (n12, n11, n10, FA2_s1_ones, FA2_s1_twos);
full_adder FA3_s1 (n22, n21, n20, FA3_s1_ones, FA3_s1_twos);
// stage 2
full_adder FA1_s2 (FA1_s2_in1, FA1_s2_in2, FA1_s2_in3, FA1_s2_ones, FA1_s2_twos);
full_adder FA2_s2 (FA2_s2_in1, FA2_s2_in2, FA2_s2_in3, FA2_s2_twos, FA2_s2_fours);

endmodule
