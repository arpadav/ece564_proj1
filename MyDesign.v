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
output wire dut_busy;
// wire set_dut_busy;
// reg set_dut_busy;

// reset and clock
input reset_b;
input clk;

// dut -> sram (input)
output wire [11:0] dut_sram_read_address;
// reg [11:0] p_dut_sram_read_address;
// sram -> dut (input)
input [15:0] sram_dut_read_data;

// dut -> sram (weights)
output wire [11:0] dut_wmem_read_address;
// reg [11:0] p_dut_wmem_read_address;
// sram -> dut (weights)
input [15:0] wmem_dut_read_data;

// dut -> sram (output)
output wire [11:0] dut_sram_write_address;
output wire [15:0] dut_sram_write_data;
output wire dut_sram_write_enable;
// wire [11:0] set_dut_sram_write_address;
// wire [15:0] set_dut_sram_write_data;
// wire set_dut_sram_write_enable;
// ========== IO INTERFACE ==========
// ========== IO INTERFACE ==========


// ========== PARAMETERS ==========
// ========== PARAMETERS ==========
// high and low, used for flags and whatnot
parameter high = 1'b1;
parameter low = 1'b0;

// indicates which modules pass the indicies
parameter top_pipeline_idx = 1'b1;
parameter blw_pipeline_idx = 1'b0;

// since weights is limited to 3x3, ONLY second address needed for weights
// parameter weights_dims_addr = 12'h0;
// parameter weights_data_addr = 12'h1;

// increment everything by this much
// parameter incr = 1'b1;

// initial index, address, counter
// parameter indx_init = 4'h0;
// parameter addr_init = 12'h0;
// parameter data_init = 16'h0;

// end condition
parameter end_condition = 16'h00FF;

// states
// parameter [3:0]
	// S0 = 4'b0000,
	// S1 = 4'b0001,
	// S2 = 4'b0010,
	// S3 = 4'b0011,
	// S4 = 4'b0100,
	// S5 = 4'b0101,
	// S6 = 4'b0110,
	// S7 = 4'b0111,
	// S8 = 4'b1000,
	// S9 = 4'b1001,
	// SA = 4'b1010,
	// SB = 4'b1011,
	// SC = 4'b1100,
	// SD = 4'b1101,
	// SE = 4'b1110,
	// SF = 4'b1111;
// ========== PARAMETERS ==========
// ========== PARAMETERS ==========


// ========== REGISTERS ==========
// ========== REGISTERS ==========
// wire [11:0] nxt_dut_wmem_read_address;
wire [15:0] weights_data;

// hard coded to 3 because that is kernel dimension limit
wire [2:0] d_in;

// column index in (for storage)
wire [3:0] coli_in;

// output address pipelined in convolution modules
wire [11:0] output_addr;

// for full adder
wire [2:0] s1_ones;
wire [2:0] s1_twos;

// for full adder
wire [2:0] s2_ones;
wire [2:0] s2_twos;

// store states
// reg [3:0] current_state, next_state;

// store weight dimensions, data
// wire [15:0] weight_dims;
// wire [15:0] weight_data;
// reg [15:0] p_weight_dims;
// reg [15:0] p_weight_data;

// store current read and write address
// reg [11:0] current_input_addr;
// reg [11:0] output_write_addr;
// reg [11:0] p_current_input_addr;
// reg [11:0] p_output_write_addr;

// store number of input rows, columns
// wire [15:0] input_num_rows;
// wire [15:0] input_num_cols;
// reg [15:0] p_input_num_rows;
// reg [15:0] p_input_num_cols;

// store first, second, third row of input
// (hardcoded because kernel limited to 3x3)
// reg [15:0] input_r0;
// reg [15:0] input_r1;
// reg [15:0] input_r2;
// reg [15:0] p_input_r0;
// reg [15:0] p_input_r1;
// reg [15:0] p_input_r2;

// row and column counters
// reg [15:0] ridx_counter;
// reg [15:0] cidx_counter;
// reg [15:0] p_ridx_counter;
// reg [15:0] p_cidx_counter;

// output to store
// reg [15:0] output_row_temp;
// reg [15:0] p_output_row_temp;

// stage 2 index and done flag
// reg s2_done;
// reg set_s2_done;
// reg set_set_s2_done; 

// reg [3:0] s2_idx;
// reg [11:0] s2_waddr;
// reg [11:0] set_s2_waddr;

// stage 3 index and done flag
// reg s3_done;
// reg prev_s3_done;
// reg [3:0] s3_idx;
// reg [11:0] s3_waddr;

// stage 2 full adder inputs
// reg FA1_s2_in1;
// reg FA1_s2_in2;
// reg FA1_s2_in3;
// reg FA2_s2_in1;
// reg FA2_s2_in2;
// reg FA2_s2_in3;

// stage 3, full adder logic for pos/neg checking
// reg ones;
// reg twos1, twos2;
// reg fours;
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
// wire load_weights;
// reg p_load_weights;

// row and column out-of-bounds flags
// wire last_row_flag;
// wire last_col_next;

// end condition met
wire end_condition_met;

// used in storing for output
// wire [15:0] max_col_idx;

// wire used to store output data
// wire negative_flag;

// storage indicator wires
// wire finished_storing;
// wire negedge_done;

// ========== WIRES ==========
// ========== WIRES ==========


// ========== REG/WIRE PAIRS ==========
// ========== REG/WIRE PAIRS ==========
// weights (kernel limited to 3x3, so hardcoding)
// wire w02, w01, w00;
// wire w12, w11, w10;
// wire w22, w21, w20;
// reg p_w02, p_w01, p_w00;
// reg p_w12, p_w11, p_w10;
// reg p_w22, p_w21, p_w20;
// weights (kernel limited to 3x3, so hardcoding)

// input data
// reg d02, d12, d22;
// reg p_d02, p_d12, p_d22;
// input data

// flag to tell each convolution module to pass through data
// wire conv_go;
// reg conv_go;
// reg p_conv_go;
// flag to tell each convolution module to pass through data

// same state indicator
// wire same_state_flag;
// reg p_same_state_flag;
// same state indicator 
// ========== REG/WIRE PAIRS ==========
// ========== REG/WIRE PAIRS ==========

// ========== EXTERNAL MODULES ==========
// ========== EXTERNAL MODULES ==========
// controller
controller ctrl (	dut_run,
					reset_b,
					clk,
					dut_sram_write_enable,
					//
					end_condition_met,
					last_col_next,
					last_row_flag,
					
					dut_busy_toggle,
					
					incr_col_enable,
					incr_row_enable,
					rst_col_counter,
					rst_row_counter,
				
					incr_raddr_enable,
					incr_waddr_enable,
					
					rst_dut_wmem_read_address,
					// nxt_dut_wmem_read_address,
					str_weights_dims,
					str_weights_data,
					
					str_input_nrows,
					str_input_ncols,
					pln_input_row_enable,
					// str_input_data,
					
					str_temp_to_write,
					
					update_d_in,
					
					load_weights_to_modules,
					toggle_conv_go_flag,
					
					incr_output_addr,
					
					rst_output_row_temp
					);

// datapath
datapath dp (	dut_busy,
				reset_b,
				clk,
				dut_sram_write_address,
				dut_sram_write_data,
				dut_sram_write_enable,
				dut_sram_read_address,
				sram_dut_read_data,
				dut_wmem_read_address,
				wmem_dut_read_data,
				//
				dut_busy_toggle,
				
				incr_col_enable,
				incr_row_enable,
				rst_col_counter,
				rst_row_counter,
				
				incr_raddr_enable,
				incr_waddr_enable,
					
				rst_dut_wmem_read_address,
				// nxt_dut_wmem_read_address,
				str_weights_dims,
				str_weights_data,
				
				str_input_nrows,
				str_input_ncols,
				pln_input_row_enable,
				// str_input_data,
				
				str_temp_to_write,
				
				update_d_in,
				
				toggle_conv_go_flag,
				
				incr_output_addr,
				
				rst_output_row_temp,
				
				c00_out,
				s1_ones,
				s1_twos,
				
				negative_flag,
				
				last_col_next,
				last_row_flag,
				
				weights_data,
				d_in,
				coli_in,
				conv_go_flag,
				output_addr,
				
				s2_ones,
				s2_twos
				);

// instantiate convolution modules
//  --> --> --> --> --> -->
// [dyx] -> m02, m01, m00 ->
// [dyx] -> m12, m11, m10 ->
// [dyx] -> m22, m21, m20 ->
//  --> --> --> --> --> -->
// first row
conv_module m02 (clk, reset_b, conv_go_flag, load_weights_to_modules, weights_data[2], d_in[0], top_pipeline_idx, output_addr, coli_in, d02_out, waddr02_out, c02_out, n02);
conv_module m01 (clk, reset_b, conv_go_flag, load_weights_to_modules, weights_data[1], d02_out, top_pipeline_idx, waddr02_out, c02_out, d01_out, waddr01_out, c01_out, n01);
conv_module m00 (clk, reset_b, conv_go_flag, load_weights_to_modules, weights_data[0], d01_out, top_pipeline_idx, waddr01_out, c01_out, d00_out, waddr00_out, c00_out, n00);
// second row
conv_module m12 (clk, reset_b, conv_go_flag, load_weights_to_modules, weights_data[5], d_in[1], blw_pipeline_idx, output_addr, coli_in, d12_out, waddr12_out, c12_out, n12);
conv_module m11 (clk, reset_b, conv_go_flag, load_weights_to_modules, weights_data[4], d12_out, blw_pipeline_idx, waddr12_out, c12_out, d11_out, waddr11_out, c11_out, n11);
conv_module m10 (clk, reset_b, conv_go_flag, load_weights_to_modules, weights_data[3], d11_out, blw_pipeline_idx, waddr11_out, c11_out, d10_out, waddr10_out, c10_out, n10);
// third row 
conv_module m22 (clk, reset_b, conv_go_flag, load_weights_to_modules, weights_data[8], d_in[2], blw_pipeline_idx, output_addr, coli_in, d22_out, waddr22_out, c22_out, n22);
conv_module m21 (clk, reset_b, conv_go_flag, load_weights_to_modules, weights_data[7], d22_out, blw_pipeline_idx, waddr22_out, c22_out, d21_out, waddr21_out, c21_out, n21);
conv_module m20 (clk, reset_b, conv_go_flag, load_weights_to_modules, weights_data[6], d21_out, blw_pipeline_idx, waddr21_out, c21_out, d20_out, waddr20_out, c20_out, n20);

// instantiate adders for pos/neg calculation
// input stage 1 -> output stage 2
full_adder FA1_s1 (n02, n01, n00, FA1_s1_ones, FA1_s1_twos);
full_adder FA2_s1 (n12, n11, n10, FA2_s1_ones, FA2_s1_twos);
full_adder FA3_s1 (n22, n21, n20, FA3_s1_ones, FA3_s1_twos);
// input stage 2 -> output stage 3
full_adder FA1_s2 (s2_ones[0], s2_ones[1], s2_ones[2], FA1_s2_ones, FA1_s2_twos);
full_adder FA2_s2 (s2_twos[0], s2_twos[1], s2_twos[2], FA2_s2_twos, FA2_s2_fours);
// ========== EXTERNAL MODULES ==========
// ========== EXTERNAL MODULES ==========


// ========== FLAGS/INDICATORS ==========
// ========== FLAGS/INDICATORS ==========
// end condition met - stop reading
assign end_condition_met = (sram_dut_read_data == end_condition);

// to decrease clock period, add flipflops between full adder stages
assign s1_ones = { FA3_s1_ones, FA2_s1_ones, FA1_s1_ones };
assign s1_twos = { FA3_s1_twos, FA2_s1_twos, FA1_s1_twos };

// negative flag of currently rippled value
// if value 5 or more, then negative. otherwise, positive
// (out of 9 values, hence why '5' indicates majority)
assign negative_flag = (FA1_s2_ones & FA1_s2_twos & FA2_s2_twos) | ((FA1_s2_ones | FA1_s2_twos | FA2_s2_twos) & FA2_s2_fours);

// ========== FLAGS/INDICATORS ==========
// ========== FLAGS/INDICATORS ==========

endmodule