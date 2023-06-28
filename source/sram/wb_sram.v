/* SPDX-License-Identifier: [MIT] */

`default_nettype wire
`timescale 1ns / 1ps

// 32-bit wishbone interface to x8 sram
// 2^17 bytes => 131,072 bytes --> 32768 4-byte words
module wb_sram (
    input               clk,    // 50MHz
    input               rst,

    // Wishbone
    input       [16:0]  adr_i,    // bus address (byte, lower two bits are auto incremented in sram)
    input       [31:0]  dat_i,
    output      [31:0]  dat_o,
    input       [3:0]   sel_i,
    input               we_i,
    input               cyc_i,
    input               stb_i,
    output reg          ack_o,
    
    // BS62LV1027SC-70
    output reg          sr_cs,  // active low, 0 == selected
    output reg          sr_we,  // active low, 0 == write cycle, 1 == read cycle
    output reg          sr_oe,  // active low, 0 == sram drives dio if read cycle
    output      [16:0]  sr_adr, // external bus address 1Mbit
    inout       [7:0]   sr_dio  // external bus data i/o
);

    parameter [7:0] st_idle    = 8'b00000001;
    parameter [7:0] st_wait0   = 8'b00000010;
    parameter [7:0] st_wait1   = 8'b00000100;
    parameter [7:0] st_wait2   = 8'b00001000;
    parameter [7:0] st_wait3   = 8'b00010000;
    parameter [7:0] st_sample  = 8'b00100000;
    parameter [7:0] st_ack     = 8'b01000000;
    
    reg [7:0] state;

    // is write cycle, if so (we == 1'b1)
    wire do_xfer = cyc_i && stb_i;
    wire do_write = we_i && cyc_i && stb_i;
    wire do_read = ~we_i && cyc_i && stb_i;


    // auto incrementing byte address
    reg     [14:0]  word_adr;   // base word address
    reg     [1:0]   byte_off;   // byte offset within word
    assign  sr_adr = {word_adr, byte_off};  // composite byte address
 
    reg     [31:0]  word_dat;   // sram return data
    assign  dat_o = word_dat;

    reg     [31:0]  word_out;   // sraw write data (wb --> sram)
    reg     [7:0]   byte_out;   //
    reg             byte_drv;

    reg             byte_sel;   // current byte select bit for write cycles
    assign sr_dio = byte_drv ? byte_out : 8'bzz;

    // state machine control stuff..
    wire last_byte = &byte_off; // currently working on 4th byte of external bus cycles?
    wire read_sr_bus = (state == st_sample); // sample external bus data lines

    always @ (posedge clk) begin
        ack_o <= (state == st_sample) && last_byte && cyc_i && stb_i;
    end

    // Mux the correct byte onto the 8-bit sram data bus for sram write cycle
    always @(*) begin
        case (byte_off)
            2'h0: byte_out = word_out[7:0];
            2'h1: byte_out = word_out[15:8];
            2'h2: byte_out = word_out[23:16];
            2'h3: byte_out = word_out[31:24];
        endcase
    end

    // Mux out the byte select bit for 'this' sram write cycle
    always @(*) begin
        case (byte_off)
            2'h0: byte_sel = sel_i[0];
            2'h1: byte_sel = sel_i[1];
            2'h2: byte_sel = sel_i[2];
            2'h3: byte_sel = sel_i[3];
        endcase
    end

    // Read external bus data lines into the return data byte offset for sram
    // read cycle
    always @ (posedge clk) begin
        if (read_sr_bus) begin
            case (byte_off)
                2'h0: word_dat[7:0]     <= sr_dio;
                2'h1: word_dat[15:8]    <= sr_dio;
                2'h2: word_dat[23:16]   <= sr_dio;
                2'h3: word_dat[31:24]   <= sr_dio;
            endcase
        end
    end


    always @ (posedge clk) begin

            case(state)
                st_idle: begin
                    sr_cs <= 1'b1;
                    sr_we <= 1'b1;
                    sr_oe <= 1'b1;
                    byte_drv <= 1'b0;

                    if (do_xfer) begin
                        // sram should drive bus on read cycle only, this sram
                        // output is active low, (we_i == 0) is a read cycle!
                        sr_oe <= we_i;

                        // sram controller drives bus on write cycles only!
                        byte_drv <= we_i;

                        // doesn't matter if it's a read or write cycle,
                        // select the sram
                        sr_cs <= 1'b0;
                        
                        word_out <= dat_i;
                       {word_adr, byte_off} <= {adr_i[16:2], 2'h0};
                       
                        state <= st_wait0;
                    end
                end

                st_wait0: begin
                    // only take write signal active if current byte sel bit
                    // is set
                    sr_we <= (we_i & byte_sel) ? 1'b0 : 1'b1;
                    state <= st_wait1;
                end

                st_wait1: begin
                    state <= st_wait2;
                end

                st_wait2: begin
                    state <= st_wait3;
                end

                st_wait3: begin
                        sr_we <= 1'b1;
                        state <= st_sample;
                end

                st_sample: begin
                    // dio lines are sampled in other code block above. Increment
                    // the byte offset if more to read or ack if done
                    state <= last_byte ? st_ack : st_wait0;
                    byte_off <= byte_off + 1;

                    // Quit driving the bus if the cycle is complete. 
                    if (last_byte) begin
                        sr_cs <= 1'b1;
                        sr_oe <= 1'b1;
                        byte_drv <= 1'b0;
                    end
                end

                st_ack: begin
                    // full 32-bit data valid in this clock cycle
                    state <= st_idle;
                end

                default:
                    state <= st_idle;

            endcase

        end

endmodule
