/* SPDX-License-Identifier: [MIT] */

`default_nettype wire
module gpio(
    input clk,
    input           we,
    input   [3:0]   sel,
    input   [31:0]  dat,
    output  [15:0]  rdt,

    output  [7:0]   gpo,
    input   [7:0]   gpi
);

    reg [7:0] gpor;
    reg [7:0] gpis0;
    reg [7:0] gpis1;
    assign gpo        = gpor;
    assign rdt[7:0]   = gpor;
    assign rdt[15:8]  = gpis1;

    /*
     * Write enable is held for 2 clock cycles on this bus cycle. That's ok
     * for everything but the bit toggling xor operation. Force the write
     * enable to assert for only 1 clock cycle since bit toggle is not
     * idempotent. This prevents a 2nd toggle.
     */ 
    reg we1;
    always @(posedge clk)
        we1 <= !we1 && we;

    always @(posedge clk) begin
        if (we1) begin
            if (sel[0])
                gpor <= dat[7:0];            /* assignment */
            else if (sel[1])
                gpor <= gpor ^ dat[15:8];    /* toggle */
            else if (sel[2])
                gpor <= gpor | dat[23:16];   /* set */
            else if (sel[3])
                gpor <= gpor & ~(dat[31:24]);/* clear */
        end

        gpis0 <= gpi;
        gpis1 <= gpis0;
    end

endmodule
