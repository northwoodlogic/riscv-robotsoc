/* SPDX-License-Identifier: [MIT] */

`default_nettype wire
module ppmo (
    input           clk,    /* 50MHz input */
    input           rst,
    input   [31:0]  dat,
    input   [3:0]   sel,
    input           we_03,
    input           we_47,
    output  [31:0]  rdt_03,
    output  [31:0]  rdt_47,

    output reg       ppms, /* ppm stream, CW radio or IR TX enable */
    output reg [7:0] ppmo, /* servo channel signals */

    output trig /* debug */
);

    /* 8x servo position holding registers. Initialized to mid-position */
    reg [7:0] mag[0:7]; 
    initial mag[0] = 8'h80;
    initial mag[1] = 8'h80;
    initial mag[2] = 8'h80;
    initial mag[3] = 8'h80;
    initial mag[4] = 8'h80;
    initial mag[5] = 8'h80;
    initial mag[6] = 8'h80;
    initial mag[7] = 8'h80;

    assign rdt_03 = {mag[3], mag[2], mag[1], mag[0]};
    assign rdt_47 = {mag[7], mag[6], mag[5], mag[4]};

    /*
     * 168mS watchdog timer. WDT is reset when any 1 of 8 holding registers
     * are written. If watchdog or module reset asserts then values are set
     * to the initial position. The instantating module should assert reset
     * any time the system level emergency brake input asserts.
     */
    reg [23:0] wdt;
    wire mag_rst = (wdt[23] | rst);
    wire wdt_pet = we_03 | we_47;
    always @(posedge clk) begin
        wdt <= (wdt[23] | wdt_pet) ? 24'h0 : wdt + 1;
    end

    always @(posedge clk) begin
        if (mag_rst) begin
            mag[0] <= 8'h80;
            mag[1] <= 8'h80;
            mag[2] <= 8'h80;
            mag[3] <= 8'h80;
            mag[4] <= 8'h80;
            mag[5] <= 8'h80;
            mag[6] <= 8'h80;
            mag[7] <= 8'h80;
        end else begin
            if (we_03 & sel[0]) mag[0] <= dat[7:0];
            if (we_03 & sel[1]) mag[1] <= dat[15:8];
            if (we_03 & sel[2]) mag[2] <= dat[23:16];
            if (we_03 & sel[3]) mag[3] <= dat[31:24];

            if (we_47 & sel[0]) mag[4] <= dat[7:0];
            if (we_47 & sel[1]) mag[5] <= dat[15:8];
            if (we_47 & sel[2]) mag[6] <= dat[23:16];
            if (we_47 & sel[3]) mag[7] <= dat[31:24];
        end
    end

    reg  [3:0]  chs; /* Channel Select */
    assign trig = chs[3];
    
    reg  [7:0]  chv; /* Channel Value */
    reg  [8:0]  acc; /* Accumulator */
    wire        accm = &acc;
    wire        load = (acc == 9'h0);
    wire        next = (acc >= {1'b1, chv});

    reg [7:0]  div; /* clock divider */
    wire tck = (div == 8'd195);
    always @(posedge clk) begin
        div <= (tck) ? 8'h0 : div + 1;

        if (tck) begin
               /*
                * Channel value is registered at beginning of cycle to
                * prevent glitches if the value is updated mid-cycle.
                */
            if (load) begin
                /*
                 * When channels 8-15 are selected set the value to 1mS. This
                 * will generate a blanking period of 8mS.
                 *
                 * Minimum : All channel values == 0
                 *  (8ch * 1.0mS) + 8mS blank --> 16mS period
                 * Middle  : All channel values == 128
                 *  (8ch * 1.5mS) + 8mS blank --> 20mS period
                 * Maximum : All channel values == 255
                 *  (8ch * 2.0mS) + 8mS blank --> 24mS period
                 */
                chv <= chs[3] ? 8'h0 : mag[chs[2:0]];
            end

            if (next)
                chs <= chs + 1;

            /* Accumulate, or zero if switching to next channel */
            acc <= (next) ? 0 : acc + 1;
        end

        /*
         * Pulse position stream, can drive demuxer or RF / IR TX en. This
         * outputs 9 pulses, the 9'th pulse only provides the leading edge
         * needed to terminate 8'th channel position.
         */
        ppms <= (acc[8:7] == 2'h0) && (chs <= 4'h8);

        /* Demuxed, individual servo pulse position outputs */
        ppmo[0] <= (chs == 4'h0);
        ppmo[1] <= (chs == 4'h1);
        ppmo[2] <= (chs == 4'h2);
        ppmo[3] <= (chs == 4'h3);
        ppmo[4] <= (chs == 4'h4);
        ppmo[5] <= (chs == 4'h5);
        ppmo[6] <= (chs == 4'h6);
        ppmo[7] <= (chs == 4'h7);
    end

endmodule
