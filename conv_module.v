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
