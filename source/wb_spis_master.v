/* SPDX-License-Identifier: [MIT] */

`default_nettype wire

module wb_spis_master(
	input clk,
	
	// SPI slave signals
	input  spi_csn,
	input  spi_clk,
	input  spi_mosi,
	output spi_miso,
	
	// wishbone bus signals
	output [23:0] 	adr_o,
	output [31:0] 	dat_o,
	input  [31:0] 	dat_i,
	output [3:0]  	sel_o,
	output 			we_o,
	output 			cyc_o,
	output 			stb_o,
	input 			ack_i
);

	parameter [5:0] state_idle			= 6'b000000;
	parameter [5:0] state_rcmd			= 6'b000001;
	parameter [5:0] state_rdata_cyc		= 6'b000010;
	parameter [5:0] state_wdata_cyc 	= 6'b000100;
	parameter [5:0] state_wdata_wait	= 6'b001000;
	parameter [5:0] state_rdata_wait	= 6'b010000;

	reg [5:0] state;
	reg [3:0] byte_en;
	reg [23:0] addr;

	/* SPI slave signals */
	wire [31:0]	spi_data;
	wire 		xfer;
	wire 		xfer_start;
	wire 		boundary;
	wire 		op_read  = (spi_data[31:28] == 4'h1);
	wire 		op_write = (spi_data[31:28] == 4'h0);
	wire		spi_load = (state == state_rdata_cyc) && (ack_i);

	spis spi(
		.clk(clk),
		
		.spi_csn(spi_csn),
		.spi_clk(spi_clk),
		.spi_mosi(spi_mosi),
		.spi_miso(spi_miso),
		
		.i_load(spi_load),
		.i_data(dat_i),
		.o_data(spi_data),
		
		.boundary(boundary),
		.xfer(xfer),
		.xfer_start(xfer_start),
		.xfer_end()
	);
	

	/* Wishbone controller state machine signals */
	assign sel_o = byte_en;
	assign adr_o = addr;
	assign dat_o = spi_data;
	assign we_o	= (state == state_wdata_cyc);
	
	/* cycle and strobe lines are always the same in this simple implementation */
	assign cyc_o = (state == state_wdata_cyc) || (state == state_rdata_cyc);
	assign stb_o = (state == state_wdata_cyc) || (state == state_rdata_cyc);
	
	always @(posedge clk) begin
		
		/* If no spi transfer in progress jump back to idle. This is how
		 * the state machine gets reset if a SPI transfer is cut short
		 * or an ack is never received in a bus read / write cycle
		 */
		if (xfer == 1'b0) begin
			state <= state_idle;
			
		end else begin
			case (state)
				state_idle: begin // Idle, waiting for transfer to start
							if (xfer_start)
								state <= state_rcmd;
							end
					
				state_rcmd: begin // Wait until command arrives, then decode
							if (boundary) begin
							
								if (op_read)
									state <= state_rdata_cyc;
								else if (op_write)
									state <= state_wdata_wait;
								else
									state <= state_idle;
								
								/* byte enables and address need to be registered
								* so they state stable though the data phase */
								byte_en <= spi_data[27:24];
								addr    <= spi_data[23:0];
							end
						end
					
				state_rdata_cyc: begin /* Data Read */
						/*
						 * Read cycle, strobe and cycle output are asserted
						 * base on the current state; Wait here for ack then
						 * increment address and get setup for another read.
						 */
						if (ack_i) begin
							addr <= addr + 24'h4;
							state <= state_rdata_wait;
						end
					end
					
				state_rdata_wait: begin
					if (boundary) begin
							state <= state_rdata_cyc;
					end
				end
			
				state_wdata_wait: begin /* Data Write */
					// wait here until the data arrives. When it does transition
					// to the write cycle state. The SPI slave will hold this
					// data for 1/2 of a SPI clock cycle. This is the maximum
					// timing window in which the logic has to supply a return
					// result data. The SPI master controller does not insert
					// a wait period between issuing command and shifting result
					//
					// sysclk = 50MHz
					// spiclk =  1MHz
					// window --> 50MHz / 1MHz --> 50 --> 50 / 2 --> 25 cycles
						if (boundary) begin
							state    <= state_wdata_cyc;
						end
					end
					
				state_wdata_cyc: begin
					
					if (ack_i) begin
						addr <= addr + 24'h4;
						state <= state_wdata_wait;
					end
				end
			
				default:
					state <= state_idle;
		
			endcase
		end
		
	end
	
endmodule
