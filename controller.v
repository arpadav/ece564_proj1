// ece 564 - project 1 - Arpad Voros
module controller (	dut_run,
					//dut_busy,
					reset_b,
					clk,
					// dut_sram_write_address,
					// dut_sram_write_data,
					// dut_sram_write_enable,
					// dut_sram_read_address,
					// sram_dut_read_data,
					// dut_wmem_read_address,
					// wmem_dut_read_data,
					
					// my stuff
					// inputs
					end_condition_met,
					last_col_next,
					last_row_flag,
					
					// outputs
					dut_busy_toggle,
					
					incr_col_enable,
					incr_row_enable,
					rst_col_counter,
					rst_row_counter,
					
					incr_raddr_enable,
					// incr_waddr_enable,
					
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
					
// ========== IO INTERFACE ==========
// ========== IO INTERFACE ==========

// if 1, do convolution
input dut_run;

// set to 1 if calculating, 0 once done and stored
// output reg dut_busy;
// wire dut_busy_toggle;
// reg dut_busy_toggle;

// reset and clock
input reset_b;
input clk;

/* // dut -> sram (input)
output reg [11:0] dut_sram_read_address;
// reg [11:0] p_dut_sram_read_address;
// sram -> dut (input)
input [15:0] sram_dut_read_data;

// dut -> sram (weights)
output reg [11:0] dut_wmem_read_address;
// reg [11:0] p_dut_wmem_read_address;
// sram -> dut (weights)
input [15:0] wmem_dut_read_data;

// dut -> sram (output)
output reg [11:0] dut_sram_write_address;
output reg [15:0] dut_sram_write_data;
output reg dut_sram_write_enable;
// wire [11:0] set_dut_sram_write_address;
// wire [15:0] set_dut_sram_write_data;
// wire set_dut_sram_write_enable; */

input end_condition_met;
input last_col_next;
input last_row_flag;

// output reg dut_sram_write_enable;

output reg dut_busy_toggle;

output reg incr_col_enable;
output reg incr_row_enable;
output reg rst_col_counter;
output reg rst_row_counter;

output reg incr_raddr_enable;
// output reg incr_waddr_enable;

output reg rst_dut_wmem_read_address;
// output reg [11:0] nxt_dut_wmem_read_address;
output reg str_weights_dims;
output reg str_weights_data;

output reg str_input_nrows;
output reg str_input_ncols;
output reg pln_input_row_enable;

output reg str_temp_to_write;

output reg update_d_in;

output reg load_weights_to_modules;
output reg toggle_conv_go_flag;

output reg incr_output_addr;

output reg rst_output_row_temp;

// ========== IO INTERFACE ==========
// ========== IO INTERFACE ==========


// ========== PARAMETERS ==========
// ========== PARAMETERS ==========
// high and low, used for flags and whatnot
parameter high = 1'b1;
parameter low = 1'b0;

/* // indicates which modules pass the indicies
parameter top_pipeline_idx = 1'b1;
parameter rest_pipeline_idx = 1'b0; */

/* // since weights is limited to 3x3, ONLY second address needed for weights
parameter weights_dims_addr = 12'h0;
parameter weights_data_addr = 12'h1; */

/* // increment everything by this much
parameter incr = 1'b1; */

// initial index, address, counter
parameter addr_init = 12'h0;
/* parameter indx_init = 4'h0;
parameter data_init = 16'h0; */

/* // end condition
parameter end_condition = 16'h00FF;
 */

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

// same state indicator
wire same_state_flag;
reg p_same_state_flag;
// ========== REGISTERS ==========
// ========== REGISTERS ==========


// FSM State Register
always@(posedge clk or negedge reset_b)
	if (!reset_b) current_state <= S0;
	else current_state <= next_state;

// Same State Register
always@(posedge clk)
	if (!reset_b) p_same_state_flag <= low;
	else p_same_state_flag <= same_state_flag;

// Logic
always@(current_state or same_state_flag)
begin
	// ========== NEXT STATE LOGIC ==========
	// ========== NEXT STATE LOGIC ==========
	case(current_state)
		S0: next_state = dut_run ? S1 : S0;
		S1: next_state = S2;
		S2: next_state = end_condition_met ? S0 : S3;
		S3: next_state = S4;
		S4: next_state = S5;
		S5: next_state = S6;
		S6: next_state = S7;
		S7: next_state = S8;
		S8: next_state = last_col_next ? S9 : S8;
		S9: next_state = SA;
		SA: next_state = SB;
		SB: next_state = last_row_flag ? SC : S7;
		SC: next_state = S1; //s3_done ? SA : S1;
		default: next_state = S0;
	endcase
	
	// ========== LOGIC FOR OUTPUTS ==========
	// ========== LOGIC FOR OUTPUTS ==========
	
	// defaults
	// dut_sram_write_enable = low;
	
	dut_busy_toggle = low;
	
	incr_col_enable = low;
	incr_row_enable = low;
	rst_col_counter = low;
	rst_row_counter = low;
	
	incr_raddr_enable = low;
	// incr_waddr_enable = low;
	
	rst_dut_wmem_read_address = low;
	// nxt_dut_wmem_read_address = addr_init;
	str_weights_dims = low;
	str_weights_data = low;
	
	str_input_nrows = low;
	str_input_ncols = low;
	pln_input_row_enable = low;
	
	str_temp_to_write = low;
	
	update_d_in = low;
	
	load_weights_to_modules = low;
	toggle_conv_go_flag = low;
	
	incr_output_addr = low;
	
	rst_output_row_temp = low;
	
	case(current_state)
		S0: begin
			if (dut_run) begin
				// load weights data address
				// wmem data will show 2 clock cycles later
				rst_dut_wmem_read_address = high;
				
				// increment to store input dimension 2 (columns)
				// sram data will show 2 clock cycles later
				incr_raddr_enable = high;
				
				// set dut_busy flag
				dut_busy_toggle = high;
			end
		end
		
		S1: begin
			// store input dimension 1 (rows)
			str_input_nrows = high;
			// increment read address
			incr_raddr_enable = high;
			
			// store weight dimensions
			str_weights_dims = high;
		end
		
		S2: begin
			// store input dimension 2 (columns)
			str_input_ncols = high;
			// increment read address
			incr_raddr_enable = high;
			
			// store weight values
			str_weights_data = high;
			
			// set dut_busy flag
			// dut_busy_toggle = end_condition_met ? high : low;
		end
		
		S3: begin
			// read in first row and pipeline the rest
			pln_input_row_enable = high;
			// increment read address
			incr_raddr_enable = high;
			
			// load weights into modules
			load_weights_to_modules = high;
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
			
		end
		
		S7: begin
			// update registers for data input of convolution modules
			update_d_in = high;
			
			// increment column index for next d_in
			incr_col_enable = high;
			
			// set convolution flag to high
			toggle_conv_go_flag = high;
		end
		
		S8: begin
			// update registers for data input of convolution modules
			update_d_in = high;
			
			// increment column index for next d_in
			incr_col_enable = high;
			
			// if moving to S9, increment read address 
			incr_raddr_enable = last_col_next;
		end
		
		S9: begin
			/* // update registers for data input of convolution modules
			update_d_in = high;
			
			// increment column index for next d_in
			incr_col_enable = high; */
			
			// incr_row_enable = last_row_flag ? low : high;
			incr_row_enable = high;
			
			/* // increment read address
			incr_raddr_enable = high; */
			
			// reset column counter
			rst_col_counter = high;
			
			// set convolution flag to high
			toggle_conv_go_flag = high;
		end
		
		SA: begin
			// read in next row and pipeline the rest
			pln_input_row_enable = high;
			// // write row here
			// str_temp_to_write = high;
		end
		
		SB: begin
			// write row here
			str_temp_to_write = high;
		end
		
		SC: begin
			// 
			rst_output_row_temp = high;
			// 
			rst_row_counter = high;
			// 
			rst_dut_wmem_read_address = high;
			// 
			// incr_waddr_enable = high;
		end
		
		default: begin
			// next state			
			// next_state = S0;
		end
	endcase
end

// return same state indicator 
assign same_state_flag = (current_state == next_state) ? ~p_same_state_flag : p_same_state_flag;

// ADD THESE TO DATAPATH, INPUT TO CONTROLLER ?

// row and column out-of-bounds flags
// assign last_row_flag = ((ridx_counter + incr) == input_num_rows);
// assign last_col_next = (cidx_counter == input_num_cols);

endmodule