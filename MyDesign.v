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

// ========== IO INTERFACE ==========
// ========== IO INTERFACE ==========
// if 1, do convolution
input dut_run;
// set to 1 if calculating, 0 once done and stored
output reg dut_busy;
wire set_dut_busy;

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
wire [11:0] set_dut_sram_write_address;
wire [15:0] set_dut_sram_write_data;
wire set_dut_sram_write_enable;
// ========== IO INTERFACE ==========
// ========== IO INTERFACE ==========


// ========== PARAMETERS ==========
// ========== PARAMETERS ==========
// high and low, used for flags and whatnot
parameter high = 1'b1;
parameter low = 1'b0;

// indicates which modules pass the indicies
parameter top_pipeline_idx = 1'b1;
parameter rest_pipeline_idx = 1'b0;

// since weights is limited to 3x3, ONLY second address needed for weights
parameter weights_dims_addr = 12'h0;
parameter weights_data_addr = 12'h1;

// increment everything by this much
parameter incr = 1'b1;

// initial index, address, counter
parameter indx_init = 4'h0;
parameter addr_init = 12'h0;
parameter data_init = 16'h0;

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
// ========== PARAMETERS ==========
// ========== PARAMETERS ==========


// ========== REGISTERS ==========
// ========== REGISTERS ==========
// store states
reg [3:0] current_state, next_state;

// store weight dimensions, data
wire [15:0] weight_dims;
wire [15:0] weight_data;
reg [15:0] p_weight_dims;
reg [15:0] p_weight_data;

// store current read and write address
reg [11:0] current_input_addr;
reg [11:0] output_write_addr;
reg [11:0] p_current_input_addr;
reg [11:0] p_output_write_addr;

// store number of input rows, columns
wire [15:0] input_num_rows;
wire [15:0] input_num_cols;
reg [15:0] p_input_num_rows;
reg [15:0] p_input_num_cols;

// store first, second, third row of input
// (hardcoded because kernel limited to 3x3)
reg [15:0] input_r0;
reg [15:0] input_r1;
reg [15:0] input_r2;
reg [15:0] p_input_r0;
reg [15:0] p_input_r1;
reg [15:0] p_input_r2;

// row and column counters
reg [15:0] ridx_counter;
reg [15:0] cidx_counter;
reg [15:0] p_ridx_counter;
reg [15:0] p_cidx_counter;

// output to store
reg [15:0] output_row_temp;
reg [15:0] p_output_row_temp;

// stage 2 index and done flag
reg s2_done;
wire set_s2_done;
reg [3:0] s2_idx;
reg [11:0] s2_waddr;
wire [11:0] set_s2_waddr;

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
// ========== REGISTERS ==========
// ========== REGISTERS ==========


// ========== WIRES ==========
// ========== WIRES ==========
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

// flag to load in weights to convolution modules
wire load_weights;

// row and column out-of-bounds flags
wire last_row_flag;
wire col_prep_oob;

// end condition met
wire end_condition_met;

// used in storing for output
wire [15:0] max_col_idx;

// wire used to store output data
wire negative_flag;

// storage indicator wires
wire finished_storing;
wire negedge_done;

// ========== WIRES ==========
// ========== WIRES ==========


// ========== REG/WIRE PAIRS ==========
// ========== REG/WIRE PAIRS ==========
// weights (kernel limited to 3x3, so hardcoding)
wire w02, w01, w00;
wire w12, w11, w10;
wire w22, w21, w20;
reg p_w02, p_w01, p_w00;
reg p_w12, p_w11, p_w10;
reg p_w22, p_w21, p_w20;
// weights (kernel limited to 3x3, so hardcoding)

// input data
wire d02, d12, d22;
reg p_d02, p_d12, p_d22;
wire set_data_flag;
// input data

// flag to tell each convolution module to pass through data
wire conv_go;
reg p_conv_go;
// flag to tell each convolution module to pass through data

// pipelined down to the point where take outputs into account
wire loaded_for_sweep;
reg p_loaded_for_sweep;
// pipelined down to the point where take outputs into account

// same state indicator
wire same_state_flag;
reg p_same_state_flag;
// same state indicator 
// ========== REG/WIRE PAIRS ==========
// ========== REG/WIRE PAIRS ==========


// ========== FSM FLIP-FLOPS ==========
// ========== FSM FLIP-FLOPS ==========
always@(posedge clk or negedge reset_b)
	if (!reset_b) begin
		// starting state
		current_state <= S0;
		
		// dut not busy
		dut_busy <= low;
		
		// reset write enable / stored flag 
		dut_sram_write_enable <= low;
		// reset outputs
		dut_sram_write_address <= addr_init;
		dut_sram_write_data <= data_init;
		// reset temporary output register
		p_output_row_temp <= data_init;
		
		// reset weight information
		p_weight_dims <= data_init;
		p_weight_data <= data_init;
		// reset input information
		p_input_num_rows <= data_init;
		p_input_num_cols <= data_init;
		p_input_r0 <= data_init;
		p_input_r1 <= data_init;
		p_input_r2 <= data_init;
		
		// reset counters
		p_ridx_counter <= data_init;
		p_cidx_counter <= data_init;
		
		// reset read and write address
		p_current_input_addr <= addr_init;
		p_output_write_addr <= addr_init;
		
		// reset storage regs/flags stage 1 -> 2
		// p_set_s2_done <= low;
		s2_done <= low; 
		s2_idx <= indx_init; 
		s2_waddr <= addr_init; 
		
		// reset storage regs/flags stage 2 -> 3
		s3_done <= low;
		prev_s3_done <= low;
		s3_idx <= indx_init;
		s3_waddr <= addr_init;
		
		// reset FA stage 1 -> 2
		FA1_s2_in1 <= low;
		FA1_s2_in2 <= low;
		FA1_s2_in3 <= low;
		FA2_s2_in1 <= low;
		FA2_s2_in2 <= low;
		FA2_s2_in3 <= low;
				
		// reset FA stage 2 -> 3
		ones <= low;
		twos1 <= low;
		twos2 <= low;
		fours <= low;
		
		// reset weight registers
		p_w02 <= low;
		p_w01 <= low;
		p_w00 <= low;
		p_w12 <= low;
		p_w11 <= low;
		p_w10 <= low;
		p_w22 <= low;
		p_w21 <= low;
		p_w20 <= low;
		
		// reset data registers
		p_d02 <= low;
		p_d12 <= low;
		p_d22 <= low;
		
		// reset convolution indicator
		p_conv_go <= low;
		// reset rippled down indicator
		p_loaded_for_sweep <= low;
		// reset same state indicator
		p_same_state_flag <= low;
		
	end else begin
		// next state
		current_state <= next_state;
		
		// dut busy reg
		dut_busy <= set_dut_busy;
		
		// set write enable / stored flag 
		dut_sram_write_enable <= set_dut_sram_write_enable;
		// set outputs
		dut_sram_write_address <= set_dut_sram_write_address;
		dut_sram_write_data <= set_dut_sram_write_data;
		// set temporary output register
		p_output_row_temp <= output_row_temp;
		
		// set weight information
		p_weight_dims <= weight_dims;
		p_weight_data <= weight_data;
		// set input information
		p_input_num_rows <= input_num_rows;
		p_input_num_cols <= input_num_cols;
		p_input_r0 <= input_r0;
		p_input_r1 <= input_r1;
		p_input_r2 <= input_r2;
		
		// set counters
		p_ridx_counter <= ridx_counter;
		p_cidx_counter <= cidx_counter;
		
		// set read and write address
		p_current_input_addr <= current_input_addr;
		p_output_write_addr <= output_write_addr;
		
		// set storage regs/flags stage 1 -> 2
		// p_set_s2_done <= set_s2_done;
		s2_done <= set_s2_done; 
		s2_idx <= c00_out; 
		s2_waddr <= set_s2_waddr; 
		
		// set storage regs/flags stage 2 -> 3
		s3_done <= s2_done;
		prev_s3_done <= s3_done;
		s3_idx <= s2_idx;
		s3_waddr <= s2_waddr;
		
		// set FA stage 1 -> 2
		FA1_s2_in1 <= FA1_s1_ones;
		FA1_s2_in2 <= FA2_s1_ones;
		FA1_s2_in3 <= FA3_s1_ones;
		FA2_s2_in1 <= FA1_s1_twos;
		FA2_s2_in2 <= FA2_s1_twos;
		FA2_s2_in3 <= FA3_s1_twos;
				
		// set FA stage 2 -> 3
		ones <= FA1_s2_ones;
		twos1 <= FA1_s2_twos;
		twos2 <= FA2_s2_twos;
		fours <= FA2_s2_fours;
		
		// set weight registers
		p_w02 <= w02;
		p_w01 <= w01;
		p_w00 <= w00;
		p_w12 <= w12;
		p_w11 <= w11;
		p_w10 <= w10;
		p_w22 <= w22;
		p_w21 <= w21;
		p_w20 <= w20;
		
		// set data registers
		p_d02 <= d02;
		p_d12 <= d12;
		p_d22 <= d22;
		
		// set convolution indicator
		p_conv_go <= conv_go;
		// set rippled down indicator
		p_loaded_for_sweep <= loaded_for_sweep;
		// set same state indicator
		p_same_state_flag <= same_state_flag;
	end
// ========== FSM FLIP-FLOPS ==========
// ========== FSM FLIP-FLOPS ==========

// ========== FSM STATES ==========
// ========== FSM STATES ==========
always@(current_state or dut_run or p_same_state_flag)
begin
	case(current_state)
		// begin state, look for when to run
		S0: begin
			// reset counters
			ridx_counter = data_init;
			cidx_counter = data_init;
			
			// reset read and write address
			current_input_addr = addr_init;
			output_write_addr = addr_init;
			
			// reset three input registers
			input_r0 = data_init;
			input_r1 = data_init;
			input_r2 = data_init;
			
			// next state
			next_state = dut_run ? S1 : S0;
		end
		
		S1: begin
			// counters retain value
			ridx_counter = p_ridx_counter;
			cidx_counter = p_cidx_counter;
			
			// retain read and write address
			current_input_addr = p_current_input_addr;
			output_write_addr = p_output_write_addr;
			
			// retain three input registers
			input_r0 = p_input_r0;
			input_r1 = p_input_r1;
			input_r2 = p_input_r2;
			
			// load in weights dimensions
			dut_wmem_read_address = weights_dims_addr;
			
			// load in input dimension 1 (rows)
			dut_sram_read_address = current_input_addr;
			
			// next state
			next_state = S2;
		end
		
		S2: begin
			// counters retain value
			ridx_counter = p_ridx_counter;
			cidx_counter = p_cidx_counter;
			
			// increment read address. retain write address
			current_input_addr = p_current_input_addr + incr;
			output_write_addr = p_output_write_addr;
			
			// retain three input registers
			input_r0 = p_input_r0;
			input_r1 = p_input_r1;
			input_r2 = p_input_r2;
			
			// load in input dimension 2 (columns)
			dut_sram_read_address = current_input_addr;
			
			/*// store weights dimensions
			weight_dims = wmem_dut_read_data - incr;*/
			
			/*// store input dimension 1 (rows)
			input_num_rows = sram_dut_read_data - incr;*/
			
			// load in weights data
			dut_wmem_read_address = weights_data_addr;
			
			// next state, potentially done
			next_state = end_condition_met ? S0 : S3;
			/*if (end_condition_met) begin
				// done
				// next state
				next_state = S0;
			end else begin
				// next state
				next_state = S3;
			end*/
		end
		
		S3: begin
			// counters retain value
			ridx_counter = p_ridx_counter;
			cidx_counter = p_cidx_counter;
			
			// increment read address. retain write address
			current_input_addr = p_current_input_addr + incr;
			output_write_addr = p_output_write_addr;
			
			// retain three input registers
			input_r0 = p_input_r0;
			input_r1 = p_input_r1;
			input_r2 = p_input_r2;
			
			// load in FIRST row of input
			dut_sram_read_address = current_input_addr;
			
			/*// store weights data
			weight_data = wmem_dut_read_data;*/
			
			/*// store input dimension 2 (cols)
			input_num_cols = sram_dut_read_data - incr;*/
			
			// next state
			next_state = S4;
		end
		
		S4: begin
			// set row counter to weight dim - 1. column retain
			ridx_counter = weight_dims - incr;
			cidx_counter = p_cidx_counter;
			
			// increment read address. retain write address
			current_input_addr = p_current_input_addr + incr;
			output_write_addr = p_output_write_addr;
			
			// input first row
			input_r0 = sram_dut_read_data;
			input_r1 = p_input_r1;
			input_r2 = p_input_r2;
			
			// load in SECOND row of input
			dut_sram_read_address = current_input_addr;
			
			/*// store FIRST row of input
			input_r0 = sram_dut_read_data;*/
			
			// next state
			next_state = S5;
		end
		
		S5: begin
			// counters retain value
			ridx_counter = p_ridx_counter;
			cidx_counter = p_cidx_counter;
			
			// increment read address. retain write address
			current_input_addr = p_current_input_addr + incr;
			output_write_addr = p_output_write_addr;
			
			// input second row
			input_r0 = p_input_r0;
			input_r1 = sram_dut_read_data;
			input_r2 = p_input_r2;
			
			// load in THIRD row of input
			dut_sram_read_address = current_input_addr;
			
			/*// store SECOND row of input
			input_r1 = sram_dut_read_data;*/
			
			// next state
			next_state = S6;
		end
		
		S6: begin
			// counters retain value
			ridx_counter = p_ridx_counter;
			cidx_counter = p_cidx_counter;
			
			// retain read and write address
			current_input_addr = p_current_input_addr;
			output_write_addr = p_output_write_addr;
			
			// input third row
			input_r0 = p_input_r0;
			input_r1 = p_input_r1;
			input_r2 = sram_dut_read_data;
			
			/*// store THIRD row of input
			input_r2 = sram_dut_read_data;*/
			
			// next state
			next_state = S7;
		end
		
		S7: begin
			// start loading for sweep
			// row counter already updated
			// reset column counter
			ridx_counter = p_ridx_counter;
			cidx_counter = data_init;
			
			// retain read and write address
			current_input_addr = p_current_input_addr;
			output_write_addr = p_output_write_addr;
			
			// retain three input registers
			input_r0 = p_input_r0;
			input_r1 = p_input_r1;
			input_r2 = p_input_r2;
			
			// next state
			next_state = S8;
		end
		
		S8: begin
			// increment column counter
			ridx_counter = p_ridx_counter;
			cidx_counter = p_cidx_counter + incr;
			
			// retain write address
			output_write_addr = p_output_write_addr;
			
			// retain three input registers
			input_r0 = p_input_r0;
			input_r1 = p_input_r1;
			input_r2 = p_input_r2;
			
			// if NEXT clock cycle past dims, request to load new row
			// otherwise loop in this state
			if (col_prep_oob & ~last_row_flag) begin
				// increment read address
				current_input_addr = p_current_input_addr + incr;
				// load in NEXT row of input
				dut_sram_read_address = current_input_addr;
			end else begin
				// retain values
				current_input_addr = p_current_input_addr;
				dut_sram_read_address = dut_sram_read_address;
			end
			
			// next state
			next_state = col_prep_oob ? S9 : S8;
		end
		
		S9: begin
			// increment column counter
			cidx_counter = p_cidx_counter + incr;
			
			// retain read address
			current_input_addr = p_current_input_addr;
			
			if (~last_row_flag) begin
				// increase row counter
				ridx_counter = p_ridx_counter + incr;
				
				// propagate rows upward
				input_r0 = p_input_r1;
				input_r1 = p_input_r2;
				// store NEXT row of input
				input_r2 = sram_dut_read_data;
				
				// increment write address
				output_write_addr = p_output_write_addr + incr;
				
				// go back to sweeping
				next_state = S7;
			end else begin
				// reset row counter
				ridx_counter = data_init;
				
				// retain values
				input_r0 = p_input_r0;
				input_r1 = p_input_r1;
				input_r2 = p_input_r2;
				output_write_addr = p_output_write_addr;
				
				// end, wrap up
				next_state = SA;
			end
		end
		
		SA: begin
			// counters retain value
			ridx_counter = p_ridx_counter;
			cidx_counter = p_cidx_counter;
			
			// retain three input registers
			input_r0 = p_input_r0;
			input_r1 = p_input_r1;
			input_r2 = p_input_r2;
			
			// check s3_done, keep looping if high
			if (s3_done) begin
				// retain read and write address
				current_input_addr = p_current_input_addr;
				output_write_addr = p_output_write_addr;
				// next state
				next_state = SA;
			end else begin
				// increment both read and write address
				current_input_addr = p_current_input_addr + incr;
				output_write_addr = p_output_write_addr + incr;
				// next state
				next_state = S1;
			end
		end
		
		default: begin
			// defaults
			
			// next state
			next_state = S0;
			
			// reset counters
			ridx_counter = data_init;
			cidx_counter = data_init;
			
			// reset read and write address
			current_input_addr = addr_init;
			output_write_addr = addr_init;
			
			// reset three input registers
			input_r0 = data_init;
			input_r1 = data_init;
			input_r2 = data_init;
		end
	endcase
end
// ========== FSM STATES ==========
// ========== FSM STATES ==========

// using register + always@* statement, because individual addresses
// are being called instead of the entire register
always@(*)
begin
	// if finished storing, reset 
	if ((current_state == S0) | finished_storing) begin 
		// reset values
		output_row_temp = data_init;
	end else begin
		// otherwise retain values
		output_row_temp = p_output_row_temp;
	end
	// only write to temp register when calculation is ready to be written
	// and when the index does not exceed the maximum potential index
	if (s3_done & ~(s3_idx > max_col_idx[3:0])) begin
		// add to output for storing
		output_row_temp[s3_idx] = ~negative_flag;
	end else begin
		// otherwise retain value
		// output_row_temp = p_output_row_temp;
		output_row_temp[s3_idx] = p_output_row_temp[s3_idx];
	end
end


// ========== FSM WIRES ==========
// ========== FSM WIRES ==========
// when to set dut to busy
assign set_dut_busy = (current_state == S0) ? (dut_run ? high : low) : ((current_state == S2 & end_condition_met) ? low : dut_busy);

// reading weight information
assign weight_dims = (current_state == S2) ? wmem_dut_read_data - incr : p_weight_dims;
assign weight_data = (current_state == S3) ? wmem_dut_read_data : p_weight_data;

// reading input information
assign input_num_rows = (current_state == S2) ? sram_dut_read_data - incr : p_input_num_rows;
assign input_num_cols = (current_state == S3) ? sram_dut_read_data - incr : p_input_num_cols;
// assign input_r0 = (current_state == S4) ? sram_dut_read_data : (((current_state == S9) & ~last_row_flag) ? p_input_r1 : p_input_r0);
// assign input_r1 = (current_state == S5) ? sram_dut_read_data : (((current_state == S9) & ~last_row_flag) ? p_input_r2 : p_input_r1);
// assign input_r2 = (current_state == S6) ? sram_dut_read_data : (((current_state == S9) & ~last_row_flag) ? sram_dut_read_data : p_input_r2);

// load weights flag
assign load_weights = (current_state == S4) ? high : low;

// weight wires
assign w02 = (current_state == S4) ? p_weight_data[2] : p_w02;
assign w01 = (current_state == S4) ? p_weight_data[1] : p_w01;
assign w00 = (current_state == S4) ? p_weight_data[0] : p_w00;
assign w12 = (current_state == S4) ? p_weight_data[5] : p_w12;
assign w11 = (current_state == S4) ? p_weight_data[4] : p_w11;
assign w10 = (current_state == S4) ? p_weight_data[3] : p_w10;
assign w22 = (current_state == S4) ? p_weight_data[8] : p_w22;
assign w21 = (current_state == S4) ? p_weight_data[7] : p_w21;
assign w20 = (current_state == S4) ? p_weight_data[6] : p_w20;

// data wires
assign set_data_flag = (current_state == S7 | current_state == S8 | current_state == S9);
assign d02 = set_data_flag ? input_r0[cidx_counter[3:0]] : p_d02;
assign d12 = set_data_flag ? input_r1[cidx_counter[3:0]] : p_d12;
assign d22 = set_data_flag ? input_r2[cidx_counter[3:0]] : p_d22;

// values are loaded in and ready to output
assign loaded_for_sweep = (current_state == S8) ? ((p_loaded_for_sweep) ? low : ((cidx_counter == weight_dims) ? high : p_loaded_for_sweep)) : p_loaded_for_sweep;

// convolution indicicator
assign conv_go = (current_state == S9) ? (last_row_flag ? low : high) : ((current_state == S7) ? high : p_conv_go);

// return same state indicator 
assign same_state_flag = (current_state == S0) ? p_same_state_flag : ((current_state == next_state) ? ~p_same_state_flag : p_same_state_flag);

// done flag to be pipelined
assign set_s2_done = (current_state == S8) ? ((~p_loaded_for_sweep & (cidx_counter == weight_dims - incr)) ? high : s2_done) : ((current_state == S9) ? low : s2_done);
assign set_s2_waddr = ((current_state == S8) & ~p_loaded_for_sweep & (cidx_counter == weight_dims - incr)) ? output_write_addr : s2_waddr;
// ========== FSM WIRES ==========
// ========== FSM WIRES ==========


// ========== FLAGS/INDICATORS ==========
// ========== FLAGS/INDICATORS ==========
// row and column out-of-bounds flags
assign last_row_flag = ((ridx_counter + incr) == input_num_rows);
assign col_prep_oob = (cidx_counter == input_num_cols);

// max index to be stored for convolution
assign max_col_idx = input_num_cols - weight_dims;

// first condition indicates stored data + not done, meaning transitioning to calculating new row
assign finished_storing = (~prev_s3_done & dut_sram_write_enable);
// second condition indicates negative edge of "done" flag
assign negedge_done = (~s3_done & prev_s3_done);
// when set stored flag, write, etc
assign set_dut_sram_write_enable = finished_storing ? low : (negedge_done ? high : dut_sram_write_enable);
assign set_dut_sram_write_address = negedge_done ? s3_waddr : dut_sram_write_address;
assign set_dut_sram_write_data = negedge_done ? p_output_row_temp : dut_sram_write_data;

// negative flag of currently rippled value
// if value 5 or more, then negative. otherwise, positive
// (out of 9 values, hence why '5' indicates majority)
assign negative_flag = (ones & twos1 & twos2) | ((ones | twos1 | twos2) & fours);

// end condition met - stop reading
assign end_condition_met = (sram_dut_read_data == end_condition);
// ========== FLAGS/INDICATORS ==========
// ========== FLAGS/INDICATORS ==========


// ========== EXTERNAL MODULES ==========
// ========== EXTERNAL MODULES ==========
// instantiate convolution modules
//  --> --> --> --> --> -->
// [dyx] -> m02, m01, m00 ->
// [dyx] -> m12, m11, m10 ->
// [dyx] -> m22, m21, m20 ->
//  --> --> --> --> --> -->
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
// input stage 1 -> output stage 2
full_adder FA1_s1 (n02, n01, n00, FA1_s1_ones, FA1_s1_twos);
full_adder FA2_s1 (n12, n11, n10, FA2_s1_ones, FA2_s1_twos);
full_adder FA3_s1 (n22, n21, n20, FA3_s1_ones, FA3_s1_twos);
// input stage 2 -> output stage 3
full_adder FA1_s2 (FA1_s2_in1, FA1_s2_in2, FA1_s2_in3, FA1_s2_ones, FA1_s2_twos);
full_adder FA2_s2 (FA2_s2_in1, FA2_s2_in2, FA2_s2_in3, FA2_s2_twos, FA2_s2_fours);
// ========== EXTERNAL MODULES ==========
// ========== EXTERNAL MODULES ==========

endmodule
