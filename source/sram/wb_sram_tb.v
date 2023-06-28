/* SPDX-License-Identifier: [MIT] */

`timescale 1ns / 1ps

module wb_sram_tb();

reg clk;
reg rst;

reg we_i;
reg cyc_i;
reg stb_i;
wire ack_o;
reg [3:0] sel_i;
reg [16:0] wb_adr;
reg [31:0] wb_data_write;
wire [31:0] wb_data_read;


// async sram signals
wire sr_cs;
wire sr_we;
wire sr_oe;
wire [16:0] sr_adr;

reg  [7:0] sr_dio_gen;
wire [7:0] sr_dio_inout;

// sram should drive bus when
// write enable == 1, output enable == 0, chip select == 0
assign sr_dio_inout =
    (sr_we == 1'b1) && (sr_oe == 1'b0) && (sr_cs == 1'b0) ? sr_dio_gen : 8'hzz;

wb_sram dut(
    .clk(clk), .rst(rst),
    .we_i(we_i), .cyc_i(cyc_i), .stb_i(stb_i), .ack_o(ack_o),

    .adr_i(wb_adr),
    .dat_i(wb_data_write),
    .dat_o(wb_data_read),
    .sel_i(sel_i),
    
    // sram stuff.. 
    .sr_cs(sr_cs),
    .sr_we(sr_we),
    .sr_oe(sr_oe),
    .sr_adr(sr_adr),
    .sr_dio(sr_dio_inout)
);


initial begin
    clk = 1'b1;
    rst = 1'b0;
    forever #10 clk = ~clk; // 20nS clock period
end

initial begin
    $dumpfile("wb_sram_tb.vcd");
    $dumpvars;

    we_i = 1'b0;
    cyc_i = 1'b0;
    stb_i = 1'b0;
    sel_i = 4'h0;


    wb_adr = 17'hffff;
    wb_data_write = 8'h0;
    
    sr_dio_gen = 8'had;
    #100

    cyc_i = 1;
    stb_i = 1;
    wb_adr = 17'h5500;
    
    wait (ack_o == 1);
    #20
    cyc_i = 0;
    stb_i = 0;

    @(posedge clk)

    #100
    sel_i <= 4'b1101;
    wb_data_write <= 32'hdeadbeef;
    wb_adr <= 17'haa00;
    cyc_i <= 1;
    stb_i <= 1;
    we_i  <= 1;

    wait (ack_o == 1);
    #20
    cyc_i = 0;
    stb_i = 0;
    we_i = 0;
    #100
    

    $finish;

end

endmodule
