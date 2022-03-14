/* SPDX-License-Identifier: [MIT] */

`default_nettype wire
module ppmi (
    input clk,           /* 50MHz input */
    input ppm,           /* R/C servo receiver input */
    output reg lock,     /* has signal lock */
    output reg [7:0] mag /* 0-255 position value */
);

    parameter [1:0] state_idle  = 2'b00;
    parameter [1:0] state_acc   = 2'b01;
    parameter [1:0] state_blank = 2'b10;

    reg [1:0] state;

    reg [2:0] pps; /* syncronization register */
    wire pps_up = (pps[2:1] == 2'b01);
    wire pps_dn = (pps[2:1] == 2'b10);

    reg [7:0]  div; /* clock divider */
    reg [12:0] acc; /* measurement accumulator */
    wire err = &acc;
    wire tck = (div == 8'd195);

    always @(posedge clk) begin
        pps <= {pps[1:0], ppm};
        div <= (pps_up | pps_dn | tck) ? 8'h0 : div + 1;
        if (pps_up | pps_dn)
            acc <= 0;
        else if (tck)
            acc <= acc + 1;
    end

    always @(posedge clk) begin

        if (err)
            state <= state_idle;
        else begin
            case (state)
                /* Stay here until rising edge detected */
                state_idle: begin
                    lock <= 1'b0;
                    mag  <= 8'd128;
                    if (pps_up)
                        state <= state_acc;
                end

                /*
                 * Check if signal stuck high. If so go back to idle, report
                 * neutral position, and lost lock.
                 */ 
                state_acc: begin
                    if (pps_dn) begin
                        /* pulse width must be between 1 & 2 mS */
                        if (acc[12:8] == 5'h1) begin
                            lock  <= 1'b1;
                            mag   <= acc[7:0];
                            state <= state_blank;
                        end else begin
                            state <= state_idle;
                        end
                    end
                end

                /*
                 * Check if signal stuck low past blanking period. This
                 * times out after 32mS
                 */
                state_blank: begin
                    if (pps_up)
                        state <= state_acc;
                end

            endcase
        end
    end

endmodule
