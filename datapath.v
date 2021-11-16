// ece564 - project 1 - Arpad Voros
module datapath (	dut_busy,
					reset_b,
					clk,
					dut_sram_write_address,
					dut_sram_write_data,
					dut_sram_write_enable,
					dut_sram_read_address,
					sram_dut_read_data,
					dut_wmem_read_address,
					wmem_dut_read_data,
					
					// my stuff
					// inputs
					dut_busy_toggle,
					
					set_initialization_flag,
					rst_initialization_flag,
					
					incr_col_enable,
					incr_row_enable,
					rst_col_counter,
					rst_row_counter,
					
					incr_raddr_enable,
					
					rst_dut_wmem_read_address,
					str_weights_dims,
					str_weights_data,
				
					str_input_nrows,
					str_input_ncols,
					pln_input_row_enable,
					
					str_temp_to_write,
					
					update_d_in,
					
					toggle_conv_go_flag,
					
					// incr_output_addr,
					
					rst_output_row_temp,
					
					p_writ_idx,
					s1_ones,
					s1_twos,
					
					negative_flag,
					
					// outputs
					initialization_flag,
					
					last_col_next,
					last_row_flag,
					
					// weights_dims,
					weights_data,
					d_in,
					cidx_out,
					conv_go_flag,
					// output_addr,
					
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

input dut_busy_toggle;

input set_initialization_flag;
input rst_initialization_flag;

input incr_col_enable;
input incr_row_enable;
input rst_col_counter;
input rst_row_counter;

input incr_raddr_enable;

input rst_dut_wmem_read_address;
input str_weights_dims;
input str_weights_data;

input str_input_nrows;
input str_input_ncols;
input pln_input_row_enable;

input str_temp_to_write;

input update_d_in;

input toggle_conv_go_flag;

// input incr_output_addr;

input rst_output_row_temp;

input [3:0] p_writ_idx;
input [2:0] s1_ones;
input [2:0] s1_twos;

input negative_flag;

//

output reg initialization_flag;

output reg last_col_next;
output reg last_row_flag;

output reg [15:0] weights_data;
output reg [2:0] d_in;
output wire [3:0] cidx_out;
output reg conv_go_flag;
// output reg [11:0] output_addr;

output reg [2:0] s2_ones;
output reg [2:0] s2_twos;
// ========== IO INTERFACE ==========
// ========== IO INTERFACE ==========


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
// ========== PARAMETERS ==========
// ========== PARAMETERS ==========


// ========== REGISTERS ==========
// ========== REGISTERS ==========
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
// ========== REGISTERS ==========
// ========== REGISTERS ==========

// calling index from input_rx
wire [3:0] call_idx;
assign call_idx = cidx_counter[3:0];
assign cidx_out = cidx_counter[3:0] - incr;

// falling edge of storing temp array
assign dut_sram_write_enable = ~str_temp_to_write & p_str_temp_to_write;

// ========== MEM INTERFACE ==========
// ========== MEM INTERFACE ==========
// DUT Busy TFF
always@(posedge clk or negedge reset_b)
	if (!reset_b) dut_busy <= low;
	else if (dut_busy_toggle) dut_busy <= ~dut_busy;

// Reset, Set WeightMem Read Address
always@(posedge clk or negedge reset_b)
	if (!reset_b) dut_wmem_read_address <= addr_init;
	else dut_wmem_read_address <= rst_dut_wmem_read_address ? weights_data_addr : addr_init;

// Reset, Increment SRAM Read Address
always@(posedge clk or negedge reset_b)
	if (!reset_b) dut_sram_read_address <= addr_init;
	else if (incr_raddr_enable) dut_sram_read_address <= dut_sram_read_address + incr;

// Reset, Increment SRAM Write Address
always@(posedge clk or negedge reset_b)
	if (!reset_b) dut_sram_write_address <= addr_init;
	else if (dut_sram_write_enable) dut_sram_write_address <= dut_sram_write_address + incr;
	// incr_waddr_enable

// Reset, Set SRAM Write Data
always@(posedge clk or negedge reset_b)
	if (!reset_b) dut_sram_write_data <= data_init;
	else if (str_temp_to_write) dut_sram_write_data <= output_row_temp;
	
// Store Weight Dimensions
always@(posedge clk or negedge reset_b)
	if (!reset_b) weights_dims <= data_init;
	else if (str_weights_dims) weights_dims <= wmem_dut_read_data - incr;
	
// Store Weight Values
always@(posedge clk or negedge reset_b)
	if (!reset_b) weights_data <= data_init;
	else if (str_weights_data) weights_data <= wmem_dut_read_data;
	
// For Write Enable: Falling Edge of Storing Flag of Output Register
always@(posedge clk)
	p_str_temp_to_write <= str_temp_to_write;
// ========== MEM INTERFACE ==========
// ========== MEM INTERFACE ==========

	
// ========== DATA REGISTERS ==========
// ========== DATA REGISTERS ==========
// Store Number of Input Rows
always@(posedge clk or negedge reset_b)
	if (!reset_b) begin 
		input_num_rows <= data_init;
		// max_row_idx <= indx_init;
	end else if (str_input_nrows) begin
		input_num_rows <= sram_dut_read_data - incr;
		// max_row_idx <= sram_dut_read_data - incr - weights_dims;
	end

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
	
// Convolution Module Data Inputs
always@(posedge clk or negedge reset_b)
	if (!reset_b) d_in <= d_in_init;
	else if (update_d_in) d_in <= {	input_r2[call_idx], 
									input_r1[call_idx],
									input_r0[call_idx]};

// Store Output Result in Temporary Register
always@(posedge clk or negedge reset_b)
	if (!reset_b) output_row_temp <= data_init;
	else if (rst_output_row_temp) output_row_temp <= data_init;
	else if (writ_idx <= max_col_idx) output_row_temp[writ_idx] <= ~negative_flag;

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
// ========== DATA REGISTERS ==========
// ========== DATA REGISTERS ==========


// ========== COUNTERS ==========
// ========== COUNTERS ==========
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

/* // Convolution Module Pipeline Write Address
always@(posedge clk or negedge reset_b)
	if (!reset_b) output_addr <= addr_init;
	else if (incr_output_addr) output_addr <= output_addr + incr; */
// ========== COUNTERS ==========
// ========== COUNTERS ==========


// ========== FLAGS / INDICATORS ==========
// ========== FLAGS / INDICATORS ==========
// Convolution Go Flag
always@(posedge clk or negedge reset_b)
	if (!reset_b) conv_go_flag <= low;
	else if (toggle_conv_go_flag) conv_go_flag <= ~conv_go_flag;
	
// Initialization Flag
always@(posedge clk or negedge reset_b)
	if (!reset_b) initialization_flag <= low;
	else if (set_initialization_flag) initialization_flag <= ~rst_initialization_flag;
// ========== FLAGS / INDICATORS ==========
// ========== FLAGS / INDICATORS ==========

endmodule