/* SPDX-License-Identifier: [MIT] */

`default_nettype wire

module spis(
	input clk,
	
	/* SPI bus signals */
	input  spi_csn,
	input  spi_clk,
	input  spi_mosi,
	output spi_miso,
	
	/* local bus interface signals */
	output xfer, /* transfer in progress */
	output xfer_start, /* chip select falling edge */
	output xfer_end, /* chip select rising edge */
	output boundary, /* 32-bit boundary */
		
	input         i_load, /* save i_data to internal holding register */
	input  [31:0] i_data,
	output [31:0] o_data /* output data */
	
);

	reg [2:0]  i_spi_csn_s;
	reg [2:0]  i_spi_clk_s;
	reg [31:0] i_spi_shft;
	reg [31:0] o_spi_shft;
	
	/* bit counter, only needs to go to 32 */
	reg [5:0]  spi_bitcnt;
	reg        spi_txload;
	reg [31:0] spi_txload_data;
	wire       spi_boundary = (spi_bitcnt == 6'd32);
	
	/* This is an over sampling SPI slave controller */
	wire spi_csn_dn = (i_spi_csn_s[2:1] == 2'b10);
	wire spi_csn_up = (i_spi_csn_s[2:1] == 2'b01);
	wire spi_clk_dn = (i_spi_clk_s[2:1] == 2'b10);
	wire spi_clk_up = (i_spi_clk_s[2:1] == 2'b01);
	
	wire spi_xfer = ~i_spi_csn_s[1]; /* logical 1 when selected */
	
	/* Top level module should drive MISO only when selected */
	assign spi_miso = o_spi_shft[31];
	
	always @ (posedge clk) begin
		i_spi_csn_s <= {i_spi_csn_s[1:0], spi_csn};
		i_spi_clk_s <= {i_spi_clk_s[1:0], spi_clk};
		
		/*
		 * This controller operates in mode 0. Sample on rising edge, shift
		 * or load on falling edge. 
		 *
		 * By software protocol the first 32-bits shifted on MISO are unused.
		 */
		if (spi_csn_dn)
			o_spi_shft <= spi_txload;
		else if (spi_clk_dn)
			o_spi_shft <= spi_txload
							? spi_txload_data
							: {o_spi_shft[30:0], 1'b0};
			
		if (spi_clk_up)
			i_spi_shft <= {i_spi_shft[30:0], spi_mosi};
						
		/*
		 * Keep track of how many bits have been shifted. The bit counter will
		 * pulse for 1 clock cycle on every word (4 byte) boundary. 
		 */
		if (spi_csn_dn || spi_boundary)
			spi_bitcnt <= 6'h0;
		else if (spi_clk_up)
			spi_bitcnt <= spi_bitcnt + 1;
		
		/*
		 * Set a flag to determine what should happen for a given SPI clock
		 * falling edge. If this edge is the one following the 32nd rising
	 	 * edge then parallel load the shift register, otherwise do a left
		 * shift.
		 */
		if (spi_boundary)
			spi_txload <= 1'b1;
		else if (spi_clk_dn)
			spi_txload <= 1'b0;
		
		if (i_load)
			spi_txload_data <= i_data;
		else if (spi_boundary)
			spi_txload_data <= 32'hDEADDEAD;
			
	end

	/* Connect module signals */
	assign o_data = i_spi_shft;
	assign xfer = spi_xfer;
	assign xfer_start = spi_csn_dn;
	assign xfer_end = spi_csn_up;
	assign boundary = spi_boundary;
	
endmodule
