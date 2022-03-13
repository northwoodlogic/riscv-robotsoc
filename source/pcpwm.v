/* SPDX-License-Identifier: [MIT] */

`default_nettype wire

module pcpwm(
    input           clk, // 50MHz
    input           rst,

    input           we_a, /* write channel a */
    input           we_b, /* write channel b */
    input   [7:0]   maga, /* Channel A, 128 = 50% duty cycle */
    input   [7:0]   magb, /* Channel B, 128 = 50% duty cycle */
    output  [7:0]   rdta,
    output  [7:0]   rdtb,
    output  reg     pwma,
    output  reg     pwmb,
    output          trig /* Trigger output */
);

    /*
     * 168mS watchdog timer clears PWM magnitude values on loss of write.
     * Stopping isn't always the best choice depending on the application.
     * The target application is for driving 4x wheels or a positioning
     * servo loop.
     */
    reg [23:0] wdt;
    wire mag_rst = (wdt[23] | rst);
    wire wdt_pet = we_a | we_b;
    always @(posedge clk) begin
        wdt <= (wdt[23] | wdt_pet) ? 24'h0 : wdt + 1;
    end

    /* 11 bit up/down counter. @50MHz --> 12.2KHz frequency. */
    reg         dir;
    assign      trig = dir;

    reg [10:0]  cnt = 11'h0;
    wire        cnt_max = (cnt == 11'h7ff);
    wire        cnt_min = (cnt == 11'h000);

    /* Input holding and readback registers */
    reg [7:0]   data;
    reg [7:0]   datb;
    assign rdta = data;
    assign rdtb = datb;

    /* PWM compare registers, updated when ramp == 0 */
    reg [7:0]   maga_reg;
    reg [7:0]   magb_reg;
    wire        maga_max = &maga_reg;
    wire        magb_max = &magb_reg;

    always @(posedge clk) begin

        if (mag_rst) begin
            data <= 8'h0;
            datb <= 8'h0;
        end else begin
            if (we_a)
                data <= maga;
            if (we_b)
                datb <= magb;
        end

        /*
         * Magnitude values are registered on the beginning of a cycle to
         * prevent glitches in the output.
         */
        maga_reg <= (cnt_min) ? data : maga_reg;
        magb_reg <= (cnt_min) ? datb : magb_reg;

        dir <= (cnt_max) ? 1'b0 :
                (cnt_min) ? 1'b1 : dir;
        /*
         * This counter stays at the min & max values for 2 clock cycles
         */ 
        cnt <= (dir && !(cnt_max)) ? cnt + 1 :
                (!dir && !(cnt_min)) ? cnt - 1 : cnt;
    end

    always @ (posedge clk) begin
        pwma <= ~(cnt[10:3] >= maga_reg) | maga_max;
        pwmb <= ~(cnt[10:3] >= magb_reg) | magb_max;
    end

endmodule
