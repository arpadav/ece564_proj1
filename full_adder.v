// ece 564 - project 1 - Arpad Voros
// full adder
module full_adder (A, B, Cin, S, Cout);
// inputs A, B, carry in
input A;
input B;
input Cin;

// sum and carry out
output S;
output Cout;

// wires
wire ab_xor;
wire S;
wire Cout;

// logic
assign ab_xor = A ^ B;
assign S = ab_xor ^ Cin;
assign Cout = (A & B) | (ab_xor & Cin);

endmodule