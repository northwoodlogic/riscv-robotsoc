/* SPDX-License-Identifier: [MIT] */

`default_nettype wire

/* GPIO module
 * This contains gpio pins and all the other peripheral goodies */
module gio(
    input           wb_clk,
    input           wb_rst,
    
    input           wb_cyc,
    input           wb_stb,
    input           wb_we,
    input   [3:0]   wb_sel,
    input   [7:0]   wb_adr,
    input   [31:0]  wb_dat,
    output  [31:0]  wb_rdt,
    output          wb_ack,
    
    output  [7:0]   q, // 4x LED, 4x GPO

    /*
     * Emergency brake input. It's an active high signal with a pullup enabled
     * on the input pin. The brake is deasserted using a normally closed
     * switch. If the switch opens up or wire harness comes apart then ebrake
     * will assert.
     */
    input           ebrake,

    output          trig,
    output [7:0]    pwm
);


    reg ack;
    assign wb_ack = ack;

    reg [31:0] q_dat;
    assign q = q_dat[7:0];

    /* free running millisecond counter. It's 16 bits and it rolls over every
     * 65.5 seconds */
    reg [15:0] ms_cnt;
    reg [15:0] ms_div;
    wire       ms_tck = (ms_div == 16'd49999);
    always @(posedge wb_clk) begin
        ms_div <= (ms_tck) ? 16'h0 : ms_div + 16'h1;
        ms_cnt <= (ms_tck) ? ms_cnt + 1 : ms_cnt;
    end

    reg [1:0] eb_sync;
    wire eb_rst = eb_sync[1];
    always @(posedge wb_clk)
        eb_sync <= {eb_sync[0], ebrake};


    wire [7:0] strobe;
    wire wstb_q     = strobe[0];
    wire wstb_hb_01 = strobe[1];
    wire wstb_hb_23 = strobe[2];
    wire [31:0] rdt_01;
    wire [31:0] rdt_23;

    /* Address decoder
     * This is used to strobe the write enable on word aligned addresses. The
     * individual byte write enables are available as needed
     */
    dec3x8 wadr_decode(
                .en(wb_cyc & wb_stb & wb_we),
                .adr(wb_adr[4:2]),
                .sel(strobe));
    /* Return data multiplexer. There are no byte level read side effects so
     * byte selects are ignored. Return data is always the full 32-bit word
     */
    mux3x8 rdat_decode(
                .adr(wb_adr[4:2]),
                .rdt(wb_rdt),
                .rdt0(q_dat),
                .rdt1(rdt_01),
                .rdt2(rdt_23),
                .rdt3({eb_rst, 15'h0, ms_cnt}), // Add limit switch inputs in status?
                .rdt4(32'hdead0004),
                .rdt5(32'hdead0005),
                .rdt6(32'hdead0006),
                .rdt7(32'hdead0007));

    always @(posedge wb_clk) begin
        ack <= !ack && wb_cyc && wb_stb;
        
        if (wb_rst) begin
            q_dat <= 32'h0;
        end else if (wstb_q) begin
            q_dat[7:0]      <= (wb_sel[0])  ? wb_dat[7:0]   : q_dat[7:0];
            q_dat[15:8]     <= (wb_sel[1])  ? wb_dat[15:8]  : q_dat[15:8];
            q_dat[23:16]    <= (wb_sel[2])  ? wb_dat[23:16] : q_dat[23:16];
            q_dat[31:24]    <= (wb_sel[3])  ? wb_dat[31:24] : q_dat[31:24];
        end

    end

    pcpwm dual_halfbridge_0(.clk(wb_clk), .rst(eb_rst),
            .we_a(wstb_hb_01 & wb_sel[0]), .we_b(wstb_hb_01 & wb_sel[1]),
            .maga(wb_dat[7:0]), .magb(wb_dat[15:8]),
            .rdta(rdt_01[7:0]), .rdtb(rdt_01[15:8]),
            .pwma(pwm[0]), .pwmb(pwm[1]), .trig(trig));

    pcpwm dual_halfbridge_1(.clk(wb_clk), .rst(eb_rst),
            .we_a(wstb_hb_01 & wb_sel[2]), .we_b(wstb_hb_01 & wb_sel[3]),
            .maga(wb_dat[23:16]), .magb(wb_dat[31:24]),
            .rdta(rdt_01[23:16]), .rdtb(rdt_01[31:24]),
            .pwma(pwm[2]), .pwmb(pwm[3]), .trig());

    pcpwm dual_halfbridge_2(.clk(wb_clk), .rst(eb_rst),
            .we_a(wstb_hb_23 & wb_sel[0]), .we_b(wstb_hb_23 & wb_sel[1]),
            .maga(wb_dat[7:0]), .magb(wb_dat[15:8]),
            .rdta(rdt_23[7:0]), .rdtb(rdt_23[15:8]),
            .pwma(pwm[4]), .pwmb(pwm[5]), .trig());

    pcpwm dual_halfbridge_3(.clk(wb_clk), .rst(eb_rst),
            .we_a(wstb_hb_23 & wb_sel[2]), .we_b(wstb_hb_23 & wb_sel[3]),
            .maga(wb_dat[23:16]), .magb(wb_dat[31:24]),
            .rdta(rdt_23[23:16]), .rdtb(rdt_23[31:24]),
            .pwma(pwm[6]), .pwmb(pwm[7]), .trig());

    
endmodule

/* 3x8 address decoder */
module dec3x8(
    input en,
    input [2:0] adr,
    output reg [7:0] sel
);

    always @(*) begin
        if (en) begin
            case (adr)
                3'h0: sel = 8'h01;
                3'h1: sel = 8'h02;
                3'h2: sel = 8'h04;
                3'h3: sel = 8'h08;
                3'h4: sel = 8'h10;
                3'h5: sel = 8'h20;
                3'h6: sel = 8'h40;
                3'h7: sel = 8'h80;
            endcase
        end else begin
            sel = 8'h0;
        end
    end

endmodule


module mux3x8 (
    input [2:0] adr,
    output reg [31:0] rdt,
    input [31:0] rdt0,
    input [31:0] rdt1,
    input [31:0] rdt2,
    input [31:0] rdt3,
    input [31:0] rdt4,
    input [31:0] rdt5,
    input [31:0] rdt6,
    input [31:0] rdt7
);

    always @(*) begin
        case (adr)
            3'h0: rdt = rdt0;
            3'h1: rdt = rdt1;
            3'h2: rdt = rdt2;
            3'h3: rdt = rdt3;
            3'h4: rdt = rdt4;
            3'h5: rdt = rdt5;
            3'h6: rdt = rdt6;
            3'h7: rdt = rdt7;
        endcase
    end

endmodule
