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

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

// ece564 - project 1 - Arpad Voros
module full_adder (A, B, Cin, S, Cout);
// full_adder - a simple full adder

// ========== IO INTERFACE ==========
// ========== IO INTERFACE ==========
// inputs A, B, carry in
input A;
input B;
input Cin;

// sum and carry out
output S;
output Cout;


// ========== WIRES ==========
// ========== WIRES ==========
// wires
wire ab_xor;
wire S;
wire Cout;

// logic
assign ab_xor = A ^ B;
assign S = ab_xor ^ Cin;
assign Cout = (A & B) | (ab_xor & Cin);

endmodule

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

// ece564 - project 1 - Arpad Voros
module controller (	// top + mem
					dut_run,
					reset_b,
					clk,
					// inputs (data + mem conditions)
					end_condition_met,
					initialization_flag,
					last_col_next,
					last_row_flag,
					// outputs (control logic)
					dut_busy_toggle,
					set_initialization_flag,
					rst_initialization_flag,
					incr_col_enable,
					incr_row_enable,
					rst_col_counter,
					rst_row_counter,
					incr_raddr_enable,
					rst_dut_sram_write_address,
					rst_dut_sram_read_address,
					rst_dut_wmem_read_address,
					str_weights_dims,
					str_weights_data,
					str_input_nrows,
					str_input_ncols,
					pln_input_row_enable,
					str_temp_to_write,
					update_d_in,
					load_weights_to_modules,
					toggle_conv_go_flag,
					rst_output_row_temp
					);

// controller - logic controller, sets flags
// 				and indicators and such

// ========== IO INTERFACE ==========
// ========== IO INTERFACE ==========
// run flag from top
input dut_run;

// reset and clock
input reset_b;
input clk;

// inputs (data + mem conditions)
// descriptions in report
input end_condition_met;
input initialization_flag;
input last_col_next;
input last_row_flag;

// outputs (control logic)
// descriptions in report
output reg dut_busy_toggle;
output reg set_initialization_flag;
output reg rst_initialization_flag;
output reg incr_col_enable;
output reg incr_row_enable;
output reg rst_col_counter;
output reg rst_row_counter;
output reg incr_raddr_enable;
output reg rst_dut_sram_write_address;
output reg rst_dut_sram_read_address;
output reg rst_dut_wmem_read_address;
output reg str_weights_dims;
output reg str_weights_data;
output reg str_input_nrows;
output reg str_input_ncols;
output reg pln_input_row_enable;
output reg str_temp_to_write;
output reg update_d_in;
output reg load_weights_to_modules;
output reg toggle_conv_go_flag;
output reg rst_output_row_temp;


// ========== PARAMETERS ==========
// ========== PARAMETERS ==========
// high and low, used for flags and whatnot
parameter high = 1'b1;
parameter low = 1'b0;

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


// ========== LOCAL REGISTERS ==========
// ========== LOCAL REGISTERS ==========
// store states
reg [3:0] current_state, next_state;

// same state indicator
wire same_state_flag;
reg p_same_state_flag;


// ========== FLIP-FLOPS ==========
// ========== FLIP-FLOPS ==========
// FSM State Register
always@(posedge clk or negedge reset_b)
	if (!reset_b) current_state <= S0;
	else current_state <= next_state;

// Same State Register
always@(posedge clk)
	if (!reset_b) p_same_state_flag <= low;
	else p_same_state_flag <= same_state_flag;


// ========== COMBINATIONAL LOGIC ==========
// ========== COMBINATIONAL LOGIC ==========
// Logic
always@(current_state or same_state_flag)
begin
	// ========== NEXT STATE LOGIC ==========
	// ========== NEXT STATE LOGIC ==========
	case(current_state)
		S0: next_state = dut_run ? S1 : S0;
		S1: next_state = S2;
		S2: next_state = S3;
		S3: next_state = S4;
		S4: next_state = S5;
		S5: next_state = S6;
		S6: next_state = S7;
		S7: next_state = S8;
		S8: next_state = end_condition_met ? SD : (last_col_next ? S9 : S8);
		S9: next_state = SA;
		SA: next_state = SB;
		SB: next_state = last_row_flag ? SC : S7;
		SC: next_state = S1;
		SD: next_state = S0;
		default: next_state = S0;
	endcase
	
	
	// ========== LOGIC FOR OUTPUTS ==========
	// ========== LOGIC FOR OUTPUTS ==========
	// defaults	
	dut_busy_toggle = low;
	set_initialization_flag = low;
	rst_initialization_flag = low;
	incr_col_enable = low;
	incr_row_enable = low;
	rst_col_counter = low;
	rst_row_counter = low;
	incr_raddr_enable = low;
	rst_dut_sram_write_address = low;
	rst_dut_sram_read_address = low;
	rst_dut_wmem_read_address = low;
	str_weights_dims = low;
	str_weights_data = low;
	str_input_nrows = low;
	str_input_ncols = low;
	pln_input_row_enable = low;
	str_temp_to_write = low;
	update_d_in = low;
	load_weights_to_modules = low;
	toggle_conv_go_flag = low;
	rst_output_row_temp = low;
	
	case(current_state)
		S0: begin
			if (dut_run) begin
				// set dut_busy flag
				dut_busy_toggle = high;
				// load weights data address
				// wmem data will show 2 clock cycles later
				rst_dut_wmem_read_address = high;
				// increment to store input dimension 2 (columns)
				// sram data will show 2 clock cycles later
				incr_raddr_enable = high;
			end
		end
		S1: begin
			// initializing flag
			// used to determine when a new input/weight
			// is starting to be loaded in
			set_initialization_flag = high;
			// store input dimension 1 (rows)
			str_input_nrows = high;
			// store weight dimensions
			str_weights_dims = high;
			// increment sram read address
			incr_raddr_enable = high;
		end
		S2: begin
			// reset initializing flag if end
			rst_initialization_flag = end_condition_met;
			// store input dimension 2 (columns)
			str_input_ncols = high;
			// store weight values
			str_weights_data = high;
			// increment sram read address
			incr_raddr_enable = high;
		end
		S3: begin
			// read in first row and pipeline the rest
			pln_input_row_enable = high;
			// load weights into convolution modules
			load_weights_to_modules = high;
			// increment sram read address
			incr_raddr_enable = high;
		end
		S4: begin
			// read in second row and pipeline the rest
			pln_input_row_enable = high;
		end
		S5: begin
			// read in third row and pipeline the rest
			pln_input_row_enable = high;
		end
		S6: begin 
			// nothing happens. just delays by 1 clock cycle to
			// let data be loaded in
		end
		S7: begin
			// increment column index for next data to be loaded
			// into convolution modules
			incr_col_enable = high;
			// update registers for data input of convolution modules
			update_d_in = high;
			// set convolution flag to high to pipeline
			// data through convolution modules
			toggle_conv_go_flag = high;
			// if not initializing (i.e., not coming from state 1-6)
			// then this is calculating new output while old output
			// is ready to be stored
			str_temp_to_write = ~initialization_flag;
		end
		S8: begin
			// increment column index for next data to be loaded
			// into convolution modules
			incr_col_enable = high;
			// update registers for data input of convolution modules
			update_d_in = high;
			// if next calculation is for final column (i.e.
			// moving to state 9), increment read address 
			incr_raddr_enable = last_col_next;
		end
		S9: begin
			// increment row index to prepare for next row
			incr_row_enable = high;
			// reset column counter
			rst_col_counter = high;
			// set convolution flag to low to allow for new
			// data to be read
			toggle_conv_go_flag = high;
		end
		SA: begin
			// read in next row and pipeline the rest
			pln_input_row_enable = high;
		end
		SB: begin
			// reset initializing flag
			// since last row was reached. next input
			// is either new input dimensions or EOF
			rst_initialization_flag = high;
		end
		SC: begin
			// last row reached
			rst_row_counter = high;
			// reset output storage register
			rst_output_row_temp = high;
			// going back to state where weight data
			// is stored. set read address to 1 briefly for the read
			rst_dut_wmem_read_address = high;
		end
		SD: begin
			// reset dut_busy flag
			dut_busy_toggle = high;
			// stopping, but expected to continue with convolution
			// therefore toggled once more to turn it off
			toggle_conv_go_flag = high;
			// reset counters, output storage, and addresses
			rst_col_counter = high;
			rst_row_counter = high;
			rst_output_row_temp = high;
			rst_dut_sram_write_address = high;
			rst_dut_sram_read_address = high;
		end
		default: begin end
	endcase
end


// ========== WIRES ==========
// ========== WIRES ==========
// same state indicator 
assign same_state_flag = (current_state == next_state) ? ~p_same_state_flag : p_same_state_flag;

endmodule

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

// ece564 - project 1 - Arpad Voros
module datapath (	// top + mem
					dut_busy,
					reset_b,
					clk,
					dut_sram_write_address,
					dut_sram_write_data,
					dut_sram_write_enable,
					dut_sram_read_address,
					sram_dut_read_data,
					dut_wmem_read_address,
					wmem_dut_read_data,
					// inputs (control logic)
					dut_busy_toggle,
					set_initialization_flag,
					rst_initialization_flag,
					incr_col_enable,
					incr_row_enable,
					rst_col_counter,
					rst_row_counter,
					incr_raddr_enable,
					rst_dut_sram_write_address,
					rst_dut_sram_read_address,
					rst_dut_wmem_read_address,
					str_weights_dims,
					str_weights_data,
					str_input_nrows,
					str_input_ncols,
					pln_input_row_enable,
					str_temp_to_write,
					update_d_in,
					toggle_conv_go_flag,
					rst_output_row_temp,
					p_writ_idx,
					s1_ones,
					s1_twos,
					negative_flag,
					// outputs (data + some flags)
					initialization_flag,
					last_col_next,
					last_row_flag,
					weights_data,
					d_in,
					cidx_out,
					conv_go_flag,
					s2_ones,
					s2_twos
					);

// datapath - using control signals from controller
// 				manipulates registers + data, reads
// 				and writes through top

// ========== IO INTERFACE ==========
// ========== IO INTERFACE ==========
// busy flag
output reg dut_busy;

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
output wire dut_sram_write_enable;

// inputs (control logic)
// descriptions in report
input dut_busy_toggle;
input set_initialization_flag;
input rst_initialization_flag;
input incr_col_enable;
input incr_row_enable;
input rst_col_counter;
input rst_row_counter;
input incr_raddr_enable;
input rst_dut_sram_write_address;
input rst_dut_sram_read_address;
input rst_dut_wmem_read_address;
input str_weights_dims;
input str_weights_data;
input str_input_nrows;
input str_input_ncols;
input pln_input_row_enable;
input str_temp_to_write;
input update_d_in;
input toggle_conv_go_flag;
input rst_output_row_temp;
input [3:0] p_writ_idx;
input [2:0] s1_ones;
input [2:0] s1_twos;
input negative_flag;

// outputs (data + some flags)
// descriptions in report
output reg initialization_flag;
output reg last_col_next;
output reg last_row_flag;
output reg [15:0] weights_data;
output reg [2:0] d_in;
output wire [3:0] cidx_out;
output reg conv_go_flag;
output reg [2:0] s2_ones;
output reg [2:0] s2_twos;


// ========== PARAMETERS ==========
// ========== PARAMETERS ==========
// high and low, used for flags and whatnot
parameter high = 1'b1;
parameter low = 1'b0;

// since weights is limited to 3x3, ONLY second address needed for weights
// parameter weights_dims_addr = 12'h0;
parameter weights_data_addr = 12'h1;

// increment everything by this much
parameter incr = 1'b1;

// initial index, address, counter
parameter d_in_init = 3'h0;
parameter indx_init = 4'h0;
parameter addr_init = 12'h0;
parameter data_init = 16'h0;
parameter cntr_init = 16'h0;


// ========== LOCAL REGISTERS ==========
// ========== LOCAL REGISTERS ==========
// row and column counters
reg [15:0] ridx_counter;
reg [15:0] cidx_counter;

// store weight dimensions, data
reg [15:0] weights_dims;

// store number of input rows, columns
reg [15:0] input_num_rows;
reg [15:0] input_num_cols;

// store first, second, third row of input
// (hardcoded because kernel limited to 3x3)
reg [15:0] input_r0;
reg [15:0] input_r1;
reg [15:0] input_r2;

// maximum row and column index for writing
reg [3:0] max_col_idx;

// write index
reg [3:0] writ_idx;

// temporary output register
reg [15:0] output_row_temp;

// for storing previous value for write enable
reg p_str_temp_to_write;


// ========== WIRES ==========
// ========== WIRES ==========
// calling index from input_rx
wire [3:0] call_idx;
assign call_idx = cidx_counter[3:0];
assign cidx_out = cidx_counter[3:0] - incr;

// falling edge of storing temp array
assign dut_sram_write_enable = ~str_temp_to_write & p_str_temp_to_write;


// ========== FLIP-FLOPS ==========
// ========== FLIP-FLOPS ==========
// DUT Busy TFF
always@(posedge clk or negedge reset_b)
	if (!reset_b) dut_busy <= low;
	else if (dut_busy_toggle) dut_busy <= ~dut_busy;

// READING SRAM (INPUTS) ------------------------------------
// Reset, Increment SRAM Read Address
always@(posedge clk or negedge reset_b)
	if (!reset_b) dut_sram_read_address <= addr_init;
	else if (rst_dut_sram_read_address) dut_sram_read_address <= addr_init;
	else if (incr_raddr_enable) dut_sram_read_address <= dut_sram_read_address + incr;

// Store Number of Input Rows
always@(posedge clk or negedge reset_b)
	if (!reset_b) input_num_rows <= data_init;
	else if (str_input_nrows) input_num_rows <= sram_dut_read_data - incr;

// Store Number of Input Columns
always@(posedge clk or negedge reset_b)
	if (!reset_b) begin 
		input_num_cols <= data_init;
		max_col_idx <= indx_init;
	end else if (str_input_ncols) begin
		input_num_cols <= sram_dut_read_data - incr;
		max_col_idx <= sram_dut_read_data - incr - weights_dims;
	end

// Row 0 Data
always@(posedge clk or negedge reset_b)
	if (!reset_b) input_r0 <= data_init;
	else if (pln_input_row_enable) input_r0 <= input_r1;
	
// Row 1 Data
always@(posedge clk or negedge reset_b)
	if (!reset_b) input_r1 <= data_init;
	else if (pln_input_row_enable) input_r1 <= input_r2;
	
// Row 2 Data
always@(posedge clk or negedge reset_b)
	if (!reset_b) input_r2 <= data_init;
	else if (pln_input_row_enable) input_r2 <= sram_dut_read_data;

// WRITING SRAM (INPUTS) ------------------------------------
// Reset, Increment SRAM Write Address
always@(posedge clk or negedge reset_b)
	if (!reset_b) dut_sram_write_address <= addr_init;
	else if (rst_dut_sram_write_address) dut_sram_write_address <= addr_init;
	else if (dut_sram_write_enable) dut_sram_write_address <= dut_sram_write_address + incr;

// For Write Enable: Falling Edge of Storing Flag of Output Register
always@(posedge clk)
	p_str_temp_to_write <= str_temp_to_write;

// Reset, Set SRAM Write Data
always@(posedge clk or negedge reset_b)
	if (!reset_b) dut_sram_write_data <= data_init;
	else if (str_temp_to_write) dut_sram_write_data <= output_row_temp;

// Store Output Result in Temporary Register
always@(posedge clk or negedge reset_b)
	if (!reset_b) output_row_temp <= data_init;
	else if (rst_output_row_temp) output_row_temp <= data_init;
	else if (writ_idx <= max_col_idx) output_row_temp[writ_idx] <= ~negative_flag;

// READING SRAM (WEIGHTS) ------------------------------------
// Reset, Set WeightMem Read Address
always@(posedge clk or negedge reset_b)
	if (!reset_b) dut_wmem_read_address <= addr_init;
	else dut_wmem_read_address <= rst_dut_wmem_read_address ? weights_data_addr : addr_init;

// Store Weight Dimensions
always@(posedge clk or negedge reset_b)
	if (!reset_b) weights_dims <= data_init;
	else if (str_weights_dims) weights_dims <= wmem_dut_read_data - incr;
	
// Store Weight Values
always@(posedge clk or negedge reset_b)
	if (!reset_b) weights_data <= data_init;
	else if (str_weights_data) weights_data <= wmem_dut_read_data;

// CONVOLUTION MODULE ------------------------------------
// Convolution Module Data Inputs
always@(posedge clk or negedge reset_b)
	if (!reset_b) d_in <= d_in_init;
	else if (update_d_in) d_in <= {	input_r2[call_idx], 
									input_r1[call_idx],
									input_r0[call_idx]};

// Pipeline Full Adder Stage 1 -> 2
always@(posedge clk or negedge reset_b)
	if (!reset_b) begin
		s2_ones <= d_in_init;
		s2_twos <= d_in_init;
		writ_idx <= indx_init;
	end else begin 
		s2_ones <= s1_ones;
		s2_twos <= s1_twos;
		writ_idx <= p_writ_idx;
	end
	
// Convolution Go Flag
always@(posedge clk or negedge reset_b)
	if (!reset_b) conv_go_flag <= low;
	else if (toggle_conv_go_flag) conv_go_flag <= ~conv_go_flag;

// DATA AND STATUS FOR CONTROLLER ------------------------------------
// Column Counter
always@(posedge clk or negedge reset_b)
	if (!reset_b) begin 
		cidx_counter <= cntr_init;
		last_col_next <= low;
	end else if (rst_col_counter) begin
		cidx_counter <= cntr_init;
		last_col_next <= low;
	end	else if (incr_col_enable) begin
		cidx_counter <= cidx_counter + incr;
		last_col_next <= input_num_cols == cidx_counter + incr;
	end

// Row Counter
always@(posedge clk or negedge reset_b)
	if (!reset_b) begin 
		ridx_counter <= cntr_init;
		last_row_flag <= low;
	end else if (rst_row_counter) begin
		ridx_counter <= cntr_init;
		last_row_flag <= low;
	end else if (incr_row_enable) begin 
		ridx_counter <= ridx_counter + incr;
		last_row_flag <= input_num_rows == ridx_counter + incr;
	end

// Initialization Flag
always@(posedge clk or negedge reset_b)
	if (!reset_b) initialization_flag <= low;
	else if (rst_initialization_flag) initialization_flag <= low;
	else if (set_initialization_flag) initialization_flag <= high;

endmodule

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

// ece564 - project 1 - Arpad Voros
module conv_module (// top
					clock,
					reset,
					// inputs (logic, data)
					go,
					load_weight,
					weight_in,
					data_in,
					pipeline_idx_enable,
					idx_in,
					// outputs (data, idx, result)
					data_out,
					idx_out,
					negative_flag
					);

// conv_module - a single module to pipeline
//				data and 'multiply' with each
//				weight. since our weight dimensions
//				are limited to 3x3, there are 9 of these
//				modules declared in top

// ========== IO INTERFACE ==========
// ========== IO INTERFACE ==========
// top inputs
input clock;
input reset;

// inputs (logic, data)
input go;
input load_weight;
input weight_in;
input data_in;
input pipeline_idx_enable;
input [3:0] idx_in;

// outputs (data, idx, result)
output reg data_out;
output reg [3:0] idx_out;
output wire negative_flag;


// ========== LOCAL REGISTERS ==========
// ========== LOCAL REGISTERS ==========
reg weight;


// ========== FLIP-FLOPS ==========
// ========== FLIP-FLOPS ==========
always@(posedge clock)
begin
	// active low reset
	if (!reset) begin
		// reset input indicies
		idx_out <= 4'b0;
		// reset weight to 0 (negative)
		weight <= 1'b0;
		// reset data to 0 (negative)
		data_out <= 1'b0;
	end else begin
		if (go) begin
			// pipelines data
			data_out <= data_in;
			if (pipeline_idx_enable) begin
				// pass index forward
				idx_out <= idx_in;
			end
		end
		if (load_weight) begin
			// load weight
			weight <= weight_in;
		end
	end
end

// ========== WIRES ==========
// ========== WIRES ==========
// multiplication of weight and data. 1 if negative, 0 if positive
assign negative_flag = weight ^ data_out;

endmodule
