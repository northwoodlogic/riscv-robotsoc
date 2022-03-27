/* SPDX-License-Identifier: [MIT] */

`default_nettype wire

module wb_bram(
	input clk,
	input rst,
	
// This a 4Kx32 RAM + 2KB
// The lower two address bits are unused but they're
// declared in the module for clarity.
// 2^14 == 16384 bytes
// The 15'th address bit is needed to support 2KB more
// RAM from the 9'th block ram
//
	input  [14:0] 	adr_i,
	input  [31:0] 	dat_i,
	output [31:0] 	dat_o,
	input  [3:0]  	sel_i,
	input 			we_i,
	input 			cyc_i,
	input 			stb_i,
	output 	reg 	ack_o
);

	wire we = we_i && cyc_i && stb_i && !ack_o;
	
	always @ (posedge clk) begin
		ack_o <= cyc_i && stb_i && !ack_o;
	end
	
	// this single port ram is setup with no-register output
	// mode. This means the data will be valid 1 clock cycle
	// after the address has been supplied. This works out
	// because the ack signal is registered in this module,
	// which delays the ack output by 1 cycle. Therefore, the
	// data is valid on the same clock period as ACK=1.
	pmi_ram_dq_be
		#(	.pmi_addr_depth(4608),
			.pmi_addr_width(13),
			.pmi_data_width(32),
			.pmi_regmode("noreg"),
			.pmi_gsr("disable"),
			.pmi_resetmode("sync"),
			.pmi_optimization("speed"),
			.pmi_write_mode("normal"),
			.pmi_family("common"),
			.pmi_init_file_format("hex"),
			// .pmi_init_file("../blinky.hex"),
			.pmi_byte_size(8),
			.module_type("pmi_ram_dq_be"))
	rdq
	(   .Data(dat_i),
		.Address(adr_i[14:2]),
		.Clock(clk),
		.ClockEn(1'b1), /* Note: could put strobe signal here */
		.WE(we),
		.Reset(1'b0),
		.ByteEn(sel_i),
		.Q(dat_o)
	);

endmodule
