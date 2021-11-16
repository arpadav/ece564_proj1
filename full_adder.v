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
// ========== IO INTERFACE ==========
// ========== IO INTERFACE ==========


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
// ========== WIRES ==========
// ========== WIRES ==========

endmodule