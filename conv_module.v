// ece564 - project 1 - Arpad Voros
module conv_module (clock,
					reset,
					go,
					load_weight,
					weight_in,
					data_in,
					pipeline_idx_enable,
					// write_addr_in,
					idx_in,
					data_out,
					// write_addr_out,
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
input clock;
input reset;
input go;

input load_weight;
input weight_in;

input data_in;
input pipeline_idx_enable;
// input [11:0] write_addr_in;
input [3:0] idx_in;

output reg data_out;
// output reg [11:0] write_addr_out;
output reg [3:0] idx_out;

output wire negative_flag;
// ========== IO INTERFACE ==========
// ========== IO INTERFACE ==========

reg weight;

always@(posedge clock)
begin
	// active low reset
	if (!reset) begin
		// reset input indicies
		// write_addr_out <= 4'b0;
		idx_out <= 4'b0;
		// reset weight to 0 (negative)
		weight <= 1'b0;
		// reset data to 0 (negative)
		data_out <= 1'b0;
	end else begin
		if (go) begin
			// start passing values every clockcycle
			data_out <= data_in;
			if (pipeline_idx_enable) begin
				// pass index forward
				// write_addr_out <= write_addr_in;
				idx_out <= idx_in;
			end
		end
		if (load_weight) begin
			// load weight
			weight <= weight_in;
		end
	end
end

// multiplication of weight and data. 1 if negative, 0 if positive
assign negative_flag = weight ^ data_out;

endmodule
