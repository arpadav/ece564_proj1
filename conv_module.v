// ece 564 - project 1 - Arpad Voros
module conv_module (clock,
					reset,
					go,
					load_weight,
					weight_in,
					data_in,
					pipeline_idx_enable,
					write_addr_in,
					idx_in,
					data_out,
					write_addr_out,
					idx_out,
					negative_flag);

input clock;
input reset;
input go;

input load_weight;
input weight_in;

input data_in;
input pipeline_idx_enable;
input [11:0] write_addr_in;
input [3:0] idx_in;

output data_out;
output [11:0] write_addr_out;
output [3:0] idx_out;

output negative_flag;

reg weight;
wire negative_flag;

always@(posedge clock)
begin
	if (!reset) // active low reset
		// reset input indicies
		write_addr_out <= 4'b0;
		idx_out <= 4'b0;
		// reset weight to 0 (negative)
		weight <= 1'b0;
		// reset data to 0 (negative)
		data_out <= 1'b0;
	else
		if (go)
			// start passing values every clockcycle
			data_out <= data_in;
			if (pipeline_idx_enable)
				// pass index forward
				write_addr_out <= write_addr_in;
				idx_out <= idx_in;
			else
				// otherwise retain index
				write_addr_out <= write_addr_out;
				idx_out <= idx_out;
			end
		else
			// otherwise retain values
			data_out <= data_out;
			write_addr_out <= write_addr_out;
			idx_out <= idx_out;
		end
		
		if (load_weight)
			// load weight
			weight <= weight_in;
		else
			// retain weight
			weight <= weight;
		end
	end
end

// multiplication of weight and data. 1 if negative, 0 if positive
assign negative_flag = weight ^ data_out;

endmodule