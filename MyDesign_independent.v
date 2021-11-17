// ece564 - project 1 - Arpad Voros
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
					wmem_dut_read_data
					);

// MyDesign - top module without memory
// 				call this in testbench

// ========== IO INTERFACE ==========
// ========== IO INTERFACE ==========
// run and busy flag
input dut_run;
output wire dut_busy;

// reset and clock
input reset_b;
input clk;

// dut -> sram (input)
output wire [11:0] dut_sram_read_address;
// sram -> dut (input)
input [15:0] sram_dut_read_data;

// dut -> sram (weights)
output wire [11:0] dut_wmem_read_address;
// sram -> dut (weights)
input [15:0] wmem_dut_read_data;

// dut -> sram (output)
output wire [11:0] dut_sram_write_address;
output wire [15:0] dut_sram_write_data;
output wire dut_sram_write_enable;


// ========== PARAMETERS ==========
// ========== PARAMETERS ==========
// high and low, used for flags and whatnot
parameter high = 1'b1;
parameter low = 1'b0;

// indicates which modules pass the indicies
parameter top_pipeline_idx = 1'b1;
parameter blw_pipeline_idx = 1'b0;

// end condition
parameter end_condition = 16'h00FF;


// ========== WIRES ==========
// ========== WIRES ==========
// stores weights
wire [15:0] weights_data;

// data input
// pipelined thru conv modules
wire [2:0] d_in;

// column index (for writing)
// pipelined thru conv modules
wire [3:0] coli_in;

// for full adder
wire [2:0] s1_ones;
wire [2:0] s1_twos;
wire [2:0] s2_ones;
wire [2:0] s2_twos;

// logic between controller and datapath
// descriptions in report
wire initialization_flag;
wire last_col_next;
wire last_row_flag;
wire dut_busy_toggle;
wire set_initialization_flag;
wire rst_initialization_flag;
wire incr_col_enable;
wire incr_row_enable;
wire rst_col_counter;
wire rst_row_counter;
wire incr_raddr_enable;
wire rst_dut_sram_write_address;
wire rst_dut_sram_read_address;
wire rst_dut_wmem_read_address;
wire str_weights_dims;
wire str_weights_data;
wire str_input_nrows;
wire str_input_ncols;
wire pln_input_row_enable;
wire str_temp_to_write;
wire update_d_in;
wire load_weights_to_modules;
wire toggle_conv_go_flag;
wire rst_output_row_temp;
wire negative_flag;
wire conv_go_flag;
wire end_condition_met;

// pipelined data
wire d02_out, d01_out, d00_out;
wire d12_out, d11_out, d10_out;
wire d22_out, d21_out, d20_out;

// pipelined column indicies
wire [3:0] c02_out, c01_out, c00_out;
wire [3:0] c12_out, c11_out, c10_out;
wire [3:0] c22_out, c21_out, c20_out;

// negative flags (outputs to be summed)
wire n02, n01, n00;
wire n12, n11, n10;
wire n22, n21, n20;

// stage 1 & 2 full adder outputs
wire FA1_s1_ones, FA1_s1_twos;
wire FA2_s1_ones, FA2_s1_twos;
wire FA3_s1_ones, FA3_s1_twos;
wire FA1_s2_ones, FA1_s2_twos;
wire FA2_s2_twos, FA2_s2_fours;

// end condition met - stop reading
assign end_condition_met = (sram_dut_read_data == end_condition);

// to decrease clock period, add flipflops between full adder stages
assign s1_ones = { FA3_s1_ones, FA2_s1_ones, FA1_s1_ones };
assign s1_twos = { FA3_s1_twos, FA2_s1_twos, FA1_s1_twos };

// negative flag of currently rippled value
// if value 5 or more, then negative. otherwise, positive
// (out of 9 values, hence why '5' indicates majority)
assign negative_flag = (FA1_s2_ones & FA1_s2_twos & FA2_s2_twos) | ((FA1_s2_ones | FA1_s2_twos | FA2_s2_twos) & FA2_s2_fours);


// ========== EXTERNAL MODULES ==========
// ========== EXTERNAL MODULES ==========
// controller
controller ctrl (	// top + mem
					.dut_run(dut_run),
					.reset_b(reset_b),
					.clk(clk),
					// inputs (data + mem conditions)
					.end_condition_met(end_condition_met),
					.initialization_flag(initialization_flag),
					.last_col_next(last_col_next),
					.last_row_flag(last_row_flag),
					// outputs (control logic)
					.dut_busy_toggle(dut_busy_toggle),
					.set_initialization_flag(set_initialization_flag),
					.rst_initialization_flag(rst_initialization_flag),
					.incr_col_enable(incr_col_enable),
					.incr_row_enable(incr_row_enable),
					.rst_col_counter(rst_col_counter),
					.rst_row_counter(rst_row_counter),
					.incr_raddr_enable(incr_raddr_enable),
					.rst_dut_sram_write_address(rst_dut_sram_write_address),
					.rst_dut_sram_read_address(rst_dut_sram_read_address),
					.rst_dut_wmem_read_address(rst_dut_wmem_read_address),
					.str_weights_dims(str_weights_dims),
					.str_weights_data(str_weights_data),
					.str_input_nrows(str_input_nrows),
					.str_input_ncols(str_input_ncols),
					.pln_input_row_enable(pln_input_row_enable),
					.str_temp_to_write(str_temp_to_write),
					.update_d_in(update_d_in),
					.load_weights_to_modules(load_weights_to_modules),
					.toggle_conv_go_flag(toggle_conv_go_flag),
					.rst_output_row_temp(rst_output_row_temp)
					);

// datapath
datapath dp (	// top + mem
				.dut_run(dut_run),
				.reset_b(reset_b),
				.clk(clk),
				.dut_sram_write_address(dut_sram_write_address),
				.dut_sram_write_data(dut_sram_write_data),
				.dut_sram_write_enable(dut_sram_write_enable),
				.dut_sram_read_address(dut_sram_read_address),
				.sram_dut_read_data(sram_dut_read_data),
				.dut_wmem_read_address(dut_wmem_read_address),
				.wmem_dut_read_data(wmem_dut_read_data),
				// inputs (control logic)
				.dut_busy_toggle(dut_busy_toggle),
				.set_initialization_flag(set_initialization_flag),
				.rst_initialization_flag(rst_initialization_flag),
				.incr_col_enable(incr_col_enable),
				.incr_row_enable(incr_row_enable),
				.rst_col_counter(rst_col_counter),
				.rst_row_counter(rst_row_counter),
				.incr_raddr_enable(incr_raddr_enable),
				.rst_dut_sram_write_address(rst_dut_sram_write_address),
				.rst_dut_sram_read_address(rst_dut_sram_read_address),
				.rst_dut_wmem_read_address(rst_dut_wmem_read_address),
				.str_weights_dims(str_weights_dims),
				.str_weights_data(str_weights_data),
				.str_input_nrows(str_input_nrows),
				.str_input_ncols(str_input_ncols),
				.pln_input_row_enable(pln_input_row_enable),
				.str_temp_to_write(str_temp_to_write),
				.update_d_in(update_d_in),
				.toggle_conv_go_flag(toggle_conv_go_flag),
				.rst_output_row_temp(rst_output_row_temp)
				.p_writ_idx(c00_out),
				.s1_ones(s1_ones),
				.s1_twos(s1_twos),
				.negative_flag(negative_flag),
				// outputs (data + some flags)
				.initialization_flag(initialization_flag),
				.last_col_next(last_col_next),
				.last_row_flag(last_row_flag),
				.weights_data(weights_data),
				.d_in(d_in),
				.cidx_out(coli_in),
				.conv_go_flag(conv_go_flag),
				.s2_ones(s2_ones),
				.s2_twos(s2_twos)
				);

// instantiate convolution modules
//  --> --> --> --> --> -->
// [dyx] -> m02, m01, m00 ->
// [dyx] -> m12, m11, m10 ->
// [dyx] -> m22, m21, m20 ->
//  --> --> --> --> --> -->
// first row
conv_module m02 (clk, reset_b, conv_go_flag, load_weights_to_modules, weights_data[2], d_in[0], top_pipeline_idx, coli_in, d02_out, c02_out, n02);
conv_module m01 (clk, reset_b, conv_go_flag, load_weights_to_modules, weights_data[1], d02_out, top_pipeline_idx, c02_out, d01_out, c01_out, n01);
conv_module m00 (clk, reset_b, conv_go_flag, load_weights_to_modules, weights_data[0], d01_out, top_pipeline_idx, c01_out, d00_out, c00_out, n00);
// second row                                                                                                     
conv_module m12 (clk, reset_b, conv_go_flag, load_weights_to_modules, weights_data[5], d_in[1], blw_pipeline_idx, coli_in, d12_out, c12_out, n12);
conv_module m11 (clk, reset_b, conv_go_flag, load_weights_to_modules, weights_data[4], d12_out, blw_pipeline_idx, c12_out, d11_out, c11_out, n11);
conv_module m10 (clk, reset_b, conv_go_flag, load_weights_to_modules, weights_data[3], d11_out, blw_pipeline_idx, c11_out, d10_out, c10_out, n10);
// third row                                                                                                      
conv_module m22 (clk, reset_b, conv_go_flag, load_weights_to_modules, weights_data[8], d_in[2], blw_pipeline_idx, coli_in, d22_out, c22_out, n22);
conv_module m21 (clk, reset_b, conv_go_flag, load_weights_to_modules, weights_data[7], d22_out, blw_pipeline_idx, c22_out, d21_out, c21_out, n21);
conv_module m20 (clk, reset_b, conv_go_flag, load_weights_to_modules, weights_data[6], d21_out, blw_pipeline_idx, c21_out, d20_out, c20_out, n20);

// instantiate adders for pos/neg calculation
// input stage 1 -> output stage 2
full_adder FA1_s1 (n02, n01, n00, FA1_s1_ones, FA1_s1_twos);
full_adder FA2_s1 (n12, n11, n10, FA2_s1_ones, FA2_s1_twos);
full_adder FA3_s1 (n22, n21, n20, FA3_s1_ones, FA3_s1_twos);
// input stage 2 -> output stage 3
full_adder FA1_s2 (s2_ones[0], s2_ones[1], s2_ones[2], FA1_s2_ones, FA1_s2_twos);
full_adder FA2_s2 (s2_twos[0], s2_twos[1], s2_twos[2], FA2_s2_twos, FA2_s2_fours);

endmodule