/* SPDX-License-Identifier: [MIT] */

`default_nettype wire

// 8 bit async sram interface
module sram (
    // Local bus interface
    input               clk,    // 50MHz
    input               go,     // start cycle
    input               wr,     // read or write cycle, 1 == write, 0 == read
    output              busy,   // 1 == cycle in progress
    input      [16:0]   adr,    // bus address
    input       [7:0]   dat,    // input (write) data
    output reg  [7:0]   rdt,    // return (read) data
    
    // BS62LV1027SC-70
    output reg          sr_cs,  // active low, 0 == selected
    output reg          sr_we,  // active low, 0 == write cycle, 1 == read cycle
    output reg          sr_oe,  // active low, 0 == sram drives dio if read cycle
    output reg [16:0]   sr_adr, // external bus address 1Mbit
    inout       [7:0]   sr_dio  // external bus data i/o
);

    reg         wr_cyc;
    reg         wr_dir;
    reg [7:0]   wr_data;
    
    parameter [5:0] state_te    = 6'b000000;
    parameter [5:0] state_w0    = 6'b000001;
    parameter [5:0] state_w1    = 6'b000010;
    parameter [5:0] state_w2    = 6'b000100;
    parameter [5:0] state_w3    = 6'b001000;
    parameter [5:0] state_w4    = 6'b010000;
    parameter [5:0] state_id    = 6'b100000;

    reg [5:0] state;

    assign sr_dio = (wr_dir == 1'b1) ? wr_data : 8'bzz;
    assign busy = (state != state_id);

    // This is a 70nS access time memory with 50MHz system clock. The state
    // machine does an external bus cycle in 5 clock periods.
    always @ (posedge clk) begin

        case(state)
            // cycle termination
            state_te: begin
                wr_cyc <= 1'b0;
                wr_dir <= 1'b0;

                sr_cs <= 1'b1;
                sr_we <= 1'b1;
                sr_oe <= 1'b1;
                state <= state_id;
            end

            state_id: begin
                // When starting a bus cycle, register all the local bus
                // interface signals even if it's a read cycle.
                if (go) begin
                    sr_adr  <= adr;
                    wr_data <= dat;
                    wr_cyc  <= wr;

                    sr_cs <= 1'b0;
                    sr_we <= ~wr; // Drive WE low on write cycle
                    sr_oe <=  wr; // Drive OE low on read cycle
                    
                    state <= state_w0;
                end

            end

            state_w0: begin
                    // a 20nS wait state
                    state <= state_w1;
            end

            state_w1: begin
                    // datasheet says says not to drive data bus until 35nS
                    // write cycle starts
                    wr_dir <= wr_cyc;

                    // wait state
                    state <= state_w2;
            end

            state_w2: begin
                    // 20nS wait state
                    state <= state_w3;
            end

            state_w3: begin
                    // 20nS wait state
                    state <= state_w4;
            end

            state_w4: begin
                    // sample return data on bus and go to termination state
                    rdt <= sr_dio;
                    state <= state_te;
            end

            default:
                state <= state_te;

        endcase
    end

endmodule
