/* SPDX-License-Identifier: [MIT] */

`timescale 1ns / 1ps

module sram_tb();

reg clk;

reg go;
reg wr;
wire busy;
reg [16:0] adr;
reg [7:0] dat;
wire [7:0] rdt;

wire sr_cs;
wire sr_we;
wire sr_oe;
wire [16:0] sr_adr;

reg  [7:0] sr_dio_gen;
wire [7:0] sr_dio_inout;

assign sr_dio_inout =
    (sr_we == 1'b1) && (sr_oe == 1'b0) && (sr_cs == 1'b0) ? sr_dio_gen : 8'hzz;

sram dut(
    .clk(clk),
    .go(go),
    .wr(wr),
    .busy(busy),
    .adr(adr),
    .dat(dat),
    .rdt(rdt),
    
    .sr_cs(sr_cs),
    .sr_we(sr_we),
    .sr_oe(sr_oe),
    .sr_adr(sr_adr),
    .sr_dio(sr_dio_inout)
);


initial begin
    clk = 1'b1;
    forever #10 clk = ~clk; // 20nS clock period
end

initial begin
    $dumpfile("sram_tb.vcd");
    $dumpvars;

    go = 1'b0;
    wr = 1'b0;
    adr = 17'h0;
    dat = 8'h0;
    sr_dio_gen = 8'had;
    #100

    // read cycle
    go = 1'b1;
    //wr = 1'b1;
    #20;
    go = 1'b0;
    //wr = 1'b0;
    #200


    // write cycle
    go = 1'b1;
    wr = 1'b1;
    dat = 8'hde;
    #20;
    go = 1'b0;
    wr = 1'b0;
    #200


    $finish;

end

endmodule
