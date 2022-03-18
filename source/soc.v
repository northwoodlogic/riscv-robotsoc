/* SPDX-License-Identifier: [MIT] */

`default_nettype wire

module soc(
    input   clk,
    output [3:0] led,
    input       ebrake,

    input   spi_csn,
    input   spi_clk,
    input   spi_mosi,
    output  spi_miso,


    // I/O stuff
    input   [1:0] ppmi, // R/C receiver servo pulse input
    output        ppms,
    output  [7:0] ppmo,

    output  [7:0] pwmo,
//  output  [3:0] pwm_en, // Channel pair enable
//  input   [3:0] pwm_in, // Channel pair inhibit
    output  trigger
);
    
    
    ////////////////////////////
    // BUS Mux
    wire            wb_cpu_cyc;
    wire            wb_cpu_stb;
    wire            wb_cpu_we;
    wire            wb_cpu_ack;
    wire    [3:0]   wb_cpu_sel;
    wire    [31:0]  wb_cpu_adr;
    wire    [31:0]  wb_cpu_dat;
    wire    [31:0]  wb_cpu_rdt;
    /* SPI Interface */
    wire            wb_spi_cyc;
    wire            wb_spi_stb;
    wire            wb_spi_we;
    wire            wb_spi_ack;
    wire    [3:0]   wb_spi_sel;
    wire    [31:0]  wb_spi_adr;
    wire    [31:0]  wb_spi_dat;
    wire    [31:0]  wb_spi_rdt;
    /* BUS Interface */
    wire            wb_bus_cyc;
    wire            wb_bus_stb;
    wire            wb_bus_we;
    wire            wb_bus_ack;
    wire    [3:0]   wb_bus_sel;
    wire    [31:0]  wb_bus_adr;
    wire    [31:0]  wb_bus_dat;
    wire    [31:0]  wb_bus_rdt;
    // BUS Mux
    ////////////////////////////

    ////////////////////////////
    // Block RAM
    wire            wb_mem_cyc  = wb_bus_cyc;
    wire            wb_mem_stb;
    wire            wb_mem_we   = wb_bus_we;
    wire            wb_mem_ack;
    wire    [3:0]   wb_mem_sel  = wb_bus_sel;
    wire    [31:0]  wb_mem_adr  = wb_bus_adr;
    wire    [31:0]  wb_mem_dat  = wb_bus_dat;
    wire    [31:0]  wb_mem_rdt;
    // Block RAM
    ///////////////////////////
    
    ////////////////////////////
    // General Purpose I/O Block
    wire            wb_gio_cyc  = wb_bus_cyc;
    wire            wb_gio_stb;
    wire            wb_gio_we   = wb_bus_we;
    wire            wb_gio_ack;
    wire    [3:0]   wb_gio_sel  = wb_bus_sel;
    wire    [31:0]  wb_gio_adr  = wb_bus_adr;
    wire    [31:0]  wb_gio_dat  = wb_bus_dat;
    wire    [31:0]  wb_gio_rdt;
    wire    [7:0]   gio_q;
    // General Purpose I/O Block
    ///////////////////////////
    assign led[2:0] = ~gio_q;
    

    /*
     * This is set in a write-only register settable by the SPI master.
     * It's used to hold the CPU in reset or not.
     */
    reg cpu_reset = 1'h1;
    assign led[3] = ~cpu_reset;
    wire cpu_reset_stb = (wb_spi_adr[20] == 1'b1) && wb_spi_cyc;
    
    always @ (posedge clk) begin
        cpu_reset <= (cpu_reset_stb & wb_spi_we) ? wb_spi_dat[0] : cpu_reset;           
    end


    /* SERV RISC-V CPU implemented with single wishbone bus master interface */
    wb_servant cpu (
        .wb_clk(clk),
        .wb_rst(cpu_reset),

        .wb_cpu_cyc(wb_cpu_cyc),    .wb_cpu_stb(wb_cpu_stb),    .wb_cpu_we(wb_cpu_we),
        .wb_cpu_ack(wb_cpu_ack),    .wb_cpu_sel(wb_cpu_sel),    .wb_cpu_adr(wb_cpu_adr),
        .wb_cpu_dat(wb_cpu_dat),    .wb_cpu_rdt(wb_cpu_rdt)
    );

    /*
     * SPI Slave to Wishbone Master, this can only address bits [23:0]
     */
    wb_spis_master spiwb(
        .clk(clk),
        
        .spi_csn(spi_csn),  .spi_clk(spi_clk),
        .spi_mosi(spi_mosi),.spi_miso(spi_miso),
        
        .cyc_o(wb_spi_cyc), .stb_o(wb_spi_stb), .we_o(wb_spi_we),
        .ack_i(wb_spi_ack), .sel_o(wb_spi_sel), .adr_o(wb_spi_adr),
        .dat_o(wb_spi_dat), .dat_i(wb_spi_rdt)
    );
    
    /* XP2-5 Block RAM, 16384 bytes */
    wb_bram bram (
        .clk(clk),
        .rst(1'b0),
        
        .cyc_i(wb_mem_cyc), .stb_i(wb_mem_stb), .we_i(wb_mem_we),
        .ack_o(wb_mem_ack), .sel_i(wb_mem_sel), .adr_i(wb_mem_adr),
        .dat_i(wb_mem_dat), .dat_o(wb_mem_rdt)
    );
     
    bussel bmux(
        .clk(clk),
        /* CPU Interface */
        .wb_cpu_cyc(wb_cpu_cyc),    .wb_cpu_stb(wb_cpu_stb),    .wb_cpu_we(wb_cpu_we),
        .wb_cpu_ack(wb_cpu_ack),    .wb_cpu_sel(wb_cpu_sel),    .wb_cpu_adr(wb_cpu_adr),
        .wb_cpu_dat(wb_cpu_dat),    .wb_cpu_rdt(wb_cpu_rdt),
        /* SPI Interface */
        .wb_spi_cyc(wb_spi_cyc),    .wb_spi_stb(wb_spi_stb),    .wb_spi_we(wb_spi_we),
        .wb_spi_ack(wb_spi_ack),    .wb_spi_sel(wb_spi_sel),    .wb_spi_adr(wb_spi_adr),
        .wb_spi_dat(wb_spi_dat),    .wb_spi_rdt(wb_spi_rdt),
        /* BUS Interface */
        .wb_bus_cyc(wb_bus_cyc),    .wb_bus_stb(wb_bus_stb),    .wb_bus_we(wb_bus_we),
        .wb_bus_ack(wb_bus_ack),    .wb_bus_sel(wb_bus_sel),    .wb_bus_adr(wb_bus_adr),
        .wb_bus_dat(wb_bus_dat),    .wb_bus_rdt(wb_bus_rdt)
    );
    
    buscon bcon(
        .wb_clk(clk),
        /* Bus interface to CPU or SPI master */
        .wb_bus_cyc(wb_bus_cyc),    .wb_bus_stb(wb_bus_stb),    .wb_bus_adr(wb_bus_adr),
        .wb_bus_rdt(wb_bus_rdt),    .wb_bus_ack(wb_bus_ack),
        /* Block RAM interface. XP2-5 implements 16KB RAM */
        .wb_mem_stb(wb_mem_stb),    .wb_mem_rdt(wb_mem_rdt),    .wb_mem_ack(wb_mem_ack),
        /* General purpose I/O interface */
        .wb_gio_stb(wb_gio_stb),    .wb_gio_rdt(wb_gio_rdt),    .wb_gio_ack(wb_gio_ack)
        /* Add more stuff as needed */
    );
    
    gio fun(
        .wb_clk(clk),
        .wb_rst(1'b0),
        .ebrake(ebrake),

        .ppmi(ppmi),
        .ppmo(ppmo), .ppms(ppms),
    
        .wb_cyc(wb_gio_cyc),    .wb_stb(wb_gio_stb),    .wb_we(wb_gio_we),
        .wb_sel(wb_gio_sel),    .wb_adr(wb_gio_adr),    .wb_dat(wb_gio_dat),
        .wb_rdt(wb_gio_rdt),    .wb_ack(wb_gio_ack),
    
        .q(gio_q),

        /* I/O block stuff */
        .pwmo(pwmo), .trig(trigger)
    );

endmodule


/*
 * Select between the SPI Slave and CPU as the wishbone bus master
 * This arbitration happens automatically. The SPI slave may read or
 * write memory while the CPU is executing.
 */
module bussel(
    input           clk,
    
    /* CPU Interface */
    input           wb_cpu_cyc,
    input           wb_cpu_stb,
    input           wb_cpu_we,
    output          wb_cpu_ack,
    input   [3:0]   wb_cpu_sel,
    input   [31:0]  wb_cpu_adr,
    input   [31:0]  wb_cpu_dat,
    output  [31:0]  wb_cpu_rdt,
    
    /* SPI Interface */
    input           wb_spi_cyc,
    input           wb_spi_stb,
    input           wb_spi_we,
    output          wb_spi_ack,
    input   [3:0]   wb_spi_sel,
    input   [31:0]  wb_spi_adr,
    input   [31:0]  wb_spi_dat,
    output  [31:0]  wb_spi_rdt,
    
    /* BUS Interface */
    output          wb_bus_cyc,
    output          wb_bus_stb,
    output          wb_bus_we,
    input           wb_bus_ack,
    output  [3:0]   wb_bus_sel,
    output  [31:0]  wb_bus_adr,
    output  [31:0]  wb_bus_dat,
    input   [31:0]  wb_bus_rdt
);

    parameter [1:0] state_idle  = 2'b00;
    parameter [1:0] state_gcpu  = 2'b01;
    parameter [1:0] state_gspi  = 2'b10;
    
    reg [1:0] state = state_idle;
    wire grant_cpu = state[0];
    wire grant_spi = state[1];
    wire muxsel = grant_spi;

    always @(posedge clk) begin
        case (state)
            state_idle: begin // Idle, waiting for transfer to start
                state <= wb_cpu_cyc ? state_gcpu :
                            wb_spi_cyc ? state_gspi : state_idle;
                end
            state_gspi: begin
                state <= ~wb_spi_cyc ? state_idle : state;
                end
            state_gcpu: begin
                state <= ~wb_cpu_cyc ? state_idle : state;
                end
            default:
                state <= state_idle; 
        endcase
    end
             
    assign wb_bus_cyc = muxsel ? (wb_spi_cyc & grant_spi) : (wb_cpu_cyc & grant_cpu);
    assign wb_bus_stb = muxsel ? (wb_spi_stb & grant_spi) : (wb_cpu_stb & grant_cpu);
    assign wb_bus_we  = muxsel ? wb_spi_we  : wb_cpu_we;
    assign wb_bus_sel = muxsel ? wb_spi_sel : wb_cpu_sel;
    assign wb_bus_adr = muxsel ? wb_spi_adr : wb_cpu_adr;
    assign wb_bus_dat = muxsel ? wb_spi_dat : wb_cpu_dat;
    
    assign wb_spi_rdt = wb_bus_rdt;
    assign wb_cpu_rdt = wb_bus_rdt;
    
    assign wb_spi_ack = wb_bus_ack &&  muxsel;
    assign wb_cpu_ack = wb_bus_ack && ~muxsel;
    
endmodule



module buscon(
    input           wb_clk,
    input           wb_bus_cyc,
    input           wb_bus_stb,
    input   [31:0]  wb_bus_adr,
    output  [31:0]  wb_bus_rdt,
    output          wb_bus_ack,
    
    /* Block RAM interface. XP2-5 implements 16KB RAM */
    output          wb_mem_stb,
    input   [31:0]  wb_mem_rdt,
    input           wb_mem_ack,
    
    /* General purpose I/O interface */
    output          wb_gio_stb,
    input   [31:0]  wb_gio_rdt,
    input           wb_gio_ack
    
    /* TODO: Add more stuff */
);
 
 /*
  * TODO: Add a bus cycle watchdog timer here and ack after
  * no ack for some number of bus cycles.
  */
/*
    reg [6:0] wdt;
    wire wdt_max = &wdt;
    always @ (posedge clk) begin
        
    end
*/
  
  /*
   * The SPI bus controller can't address the upper 8 bits of address space.
   * This strobe
   * line conforms to the wishbone classic bus cycle. If pipelined cycles are
   * ever needed this will need to get reworked.
   */
    assign wb_mem_stb = (wb_bus_adr[23:22] == 2'b0) && wb_bus_cyc;
    assign wb_gio_stb = (wb_bus_adr[23:22] == 2'b1) && wb_bus_cyc;
 
    assign wb_bus_rdt = (wb_mem_stb) ? wb_mem_rdt :
                        (wb_gio_stb) ? wb_gio_rdt : 32'hdeaddead;

    assign wb_bus_ack = (wb_mem_stb) ? wb_mem_ack :
                        (wb_gio_stb) ? wb_gio_ack : 1'b0;

endmodule

