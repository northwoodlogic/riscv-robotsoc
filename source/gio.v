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

    input   [3:0]   busid,
    
    output  [7:0]   gpo, // 7x LED, 1x drive enable
    input   [7:0]   gpi, // 8x active low

    /*
     * Emergency brake input. It's an active high signal with a pullup enabled
     * on the input pin. The brake is deasserted using a normally closed
     * switch. If the switch opens up or wire harness comes apart then ebrake
     * will assert.
     */
    input           ebrake,
    input [1:0]     ppmi,

    output          trig,
    output [7:0]    pwmo,

    output          ppms,   /* PPM stream */
    output  [7:0]   ppmo    /* R/C servo demuxed */
);

    reg ack;
    assign wb_ack = ack;


    /*
     * Free running millisecond counter, rolls over every 65.5 seconds
     */
    reg [15:0] ms_cnt;
    reg [15:0] ms_div;
    wire       ms_tck = (ms_div == 16'd49999);
    always @(posedge wb_clk) begin
        ms_div <= (ms_tck) ? 16'h0 : ms_div + 16'h1;
        ms_cnt <= (ms_tck) ? ms_cnt + 1 : ms_cnt;
    end

    /*
     * Emergency brake input isn't synchronized by top level module.
     */
    reg [1:0] eb_sync;
    wire eb_rst = eb_sync[1];
    always @(posedge wb_clk)
        eb_sync <= {eb_sync[0], ebrake};

    /* Decoded write enable */
    wire [7:0] we_strobe;
    /* we_strobe[1:0] are unused */
    wire we_ppmo_03 = we_strobe[2];
    wire we_ppmo_47 = we_strobe[3];
    wire we_pwmo_03 = we_strobe[4];
    wire we_pwmo_47 = we_strobe[5];
    wire we_gpio_07 = we_strobe[6];
    /* we_strobe[7] is reserved for pulse counter */

    /* GPIO inputs & outputs */
    wire [31:0] rdt_gpio_07;
    assign rdt_gpio_07[31:16] = 16'h0;

    /* PWM outputs */
    wire [31:0] rdt_pwmo_03;
    wire [31:0] rdt_pwmo_47;

    /* R/C transmitter output */
    wire [31:0] rdt_ppmo_03;
    wire [31:0] rdt_ppmo_47;

    /* R/C receiver input */
    wire [31:0] rdt_ppmi_01;
    assign rdt_ppmi_01[15:9]  = 7'h0;
    assign rdt_ppmi_01[31:25] = 7'h0;

    /*
     * Write enable decoder:
     * This is used to strobe the write enable on word aligned addresses.
     * Individual byte write enables are available as needed.
     */
    dec3x8 wadr_decode(
        .en(wb_cyc & wb_stb & wb_we),
        .adr(wb_adr[4:2]),
        .sel(we_strobe));
    /*
     * Return data mux:
     * There are no byte level read side effects so byte selects are ignored.
     * Return data is always the full 32-bit word.
     */
    mux3x8 rdat_decode(
        .adr(wb_adr[4:2]),
        .rdt(wb_rdt),
        .rdt0({eb_rst, 11'h0, busid, ms_cnt}), // Add limit switch input status
        .rdt1(rdt_ppmi_01),
        .rdt2(rdt_ppmo_03),
        .rdt3(rdt_ppmo_47),
        .rdt4(rdt_pwmo_03),
        .rdt5(rdt_pwmo_47),
        .rdt6(rdt_gpio_07),
        .rdt7(32'hdead0005)
    );

    always @(posedge wb_clk) begin
        /* All modules return data within a single cycle */
        ack <= !ack && wb_cyc && wb_stb;
    end

    /* 8x discrete inputs, 8x discrete outputs */
    gpio gpio_07(.clk(wb_clk),
        .we(we_gpio_07),                .sel(wb_sel),
        .dat(wb_dat),                   .rdt(rdt_gpio_07[15:0]),
        .gpi(gpi),                      .gpo(gpo)
    );

    /* 8x pulse width modulators */
    pcpwm hb_01(.clk(wb_clk), .rst(eb_rst), .trig(),
        .we_a(we_pwmo_03 & wb_sel[0]),  .we_b(we_pwmo_03 & wb_sel[1]),
        .maga(wb_dat[7:0]),             .magb(wb_dat[15:8]),
        .rdta(rdt_pwmo_03[7:0]),        .rdtb(rdt_pwmo_03[15:8]),
        .pwma(pwmo[0]),                 .pwmb(pwmo[1])
    );

    pcpwm hb_23(.clk(wb_clk), .rst(eb_rst), .trig(),
        .we_a(we_pwmo_03 & wb_sel[2]),  .we_b(we_pwmo_03 & wb_sel[3]),
        .maga(wb_dat[23:16]),           .magb(wb_dat[31:24]),
        .rdta(rdt_pwmo_03[23:16]),      .rdtb(rdt_pwmo_03[31:24]),
        .pwma(pwmo[2]),                 .pwmb(pwmo[3])
    );

    pcpwm hb_45(.clk(wb_clk), .rst(eb_rst), .trig(),
        .we_a(we_pwmo_47 & wb_sel[0]),  .we_b(we_pwmo_47 & wb_sel[1]),
        .maga(wb_dat[7:0]),             .magb(wb_dat[15:8]),
        .rdta(rdt_pwmo_47[7:0]),        .rdtb(rdt_pwmo_47[15:8]),
        .pwma(pwmo[4]),                 .pwmb(pwmo[5])
    );

    pcpwm hb_67(.clk(wb_clk), .rst(eb_rst), .trig(),
        .we_a(we_pwmo_47 & wb_sel[2]),  .we_b(we_pwmo_47 & wb_sel[3]),
        .maga(wb_dat[23:16]),           .magb(wb_dat[31:24]),
        .rdta(rdt_pwmo_47[23:16]),      .rdtb(rdt_pwmo_47[31:24]),
        .pwma(pwmo[6]),                 .pwmb(pwmo[7])
    );

    /* 2x pulse position inputs */
    ppmi ppmi_00(.clk(wb_clk),          .ppm(ppmi[0]),
        .lock(rdt_ppmi_01[8]),          .mag(rdt_ppmi_01[7:0])
    );

    ppmi ppmi_01(.clk(wb_clk),          .ppm(ppmi[1]),
        .lock(rdt_ppmi_01[24]),         .mag(rdt_ppmi_01[23:16])
    );

    /* 8x pulse position + ppm stream outputs */
    ppmo ppmo_07(.clk(wb_clk), .rst(eb_rst), .trig(trig),
        .dat(wb_dat),                   .sel(wb_sel),
        .we_03(we_ppmo_03),             .we_47(we_ppmo_47),
        .rdt_03(rdt_ppmo_03),           .rdt_47(rdt_ppmo_47),
        .ppms(ppms),                    .ppmo(ppmo)
    );
    
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
