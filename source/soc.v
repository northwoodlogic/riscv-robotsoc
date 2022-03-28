/* SPDX-License-Identifier: [MIT] */

`default_nettype wire

module soc(
    input   clk,
    output [7:0] led, // Indicators | LEDs
    input  [7:0] gpi,
    input       ebrake, /* Emergency brake */
    output      edrive, /* Motor drive enable */

    input   spi_csn,
    input   spi_clk,
    input   spi_mosi,
    output  spi_miso,


    // I/O stuff
    input   [1:0] ppmi, // R/C receiver servo pulse input
    output        ppms,
    output  [7:0] ppmo,

    output  [7:0] pwmo,
    output  trigger
);
    
    
    ////////////////////////////
    // BUS Mux
    // CPU Interface
    wire            wb_cpu_cyc;
    wire            wb_cpu_stb;
    wire            wb_cpu_we;
    wire            wb_cpu_ack;
    wire    [3:0]   wb_cpu_sel;
    wire    [31:0]  wb_cpu_adr;
    wire    [31:0]  wb_cpu_dat;
    wire    [31:0]  wb_cpu_rdt;
    // AUX Interface
    wire            wb_aux_cyc;
    wire            wb_aux_stb;
    wire            wb_aux_we;
    wire            wb_aux_ack;
    wire    [3:0]   wb_aux_sel;
    wire    [31:0]  wb_aux_adr;
    wire    [31:0]  wb_aux_dat;
    wire    [31:0]  wb_aux_rdt;
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

    wire    [3:0]   busid;
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
    assign led[5:0] = ~gio_q;
    assign edrive = gio_q[7];
    

    /*
     * This is set in a write-only register settable by the SPI master.
     * It's used to hold the CPU in reset or not.
     */
    reg [1:0] cpu_reset = 2'b11;
    assign led[7] = ~cpu_reset[0];
    assign led[6] = ~cpu_reset[1];
    wire cpu_reset_stb = (wb_spi_adr[20] == 1'b1) && wb_spi_cyc;
    
    always @ (posedge clk) begin
        cpu_reset <= (cpu_reset_stb & wb_spi_we) ? wb_spi_dat[1:0] : cpu_reset;           
    end


    /* CPU0 - A SERV RISC-V CPU implemented with single wishbone bus master interface */
    wb_servant cpu (
        .wb_clk(clk),
        .wb_rst(cpu_reset[0]),

        .wb_cpu_cyc(wb_cpu_cyc),    .wb_cpu_stb(wb_cpu_stb),    .wb_cpu_we(wb_cpu_we),
        .wb_cpu_ack(wb_cpu_ack),    .wb_cpu_sel(wb_cpu_sel),    .wb_cpu_adr(wb_cpu_adr),
        .wb_cpu_dat(wb_cpu_dat),    .wb_cpu_rdt(wb_cpu_rdt)
    );

    /* CPU1 - Another SERV RISC-V CPU */
    wb_servant aux (
        .wb_clk(clk),
        .wb_rst(cpu_reset[1]),

        .wb_cpu_cyc(wb_aux_cyc),    .wb_cpu_stb(wb_aux_stb),    .wb_cpu_we(wb_aux_we),
        .wb_cpu_ack(wb_aux_ack),    .wb_cpu_sel(wb_aux_sel),    .wb_cpu_adr(wb_aux_adr),
        .wb_cpu_dat(wb_aux_dat),    .wb_cpu_rdt(wb_aux_rdt)
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
        .clk(clk), .busid(busid),
        /* CPU Interface */
        .wb_cpu_cyc(wb_cpu_cyc),    .wb_cpu_stb(wb_cpu_stb),    .wb_cpu_we(wb_cpu_we),
        .wb_cpu_ack(wb_cpu_ack),    .wb_cpu_sel(wb_cpu_sel),    .wb_cpu_adr(wb_cpu_adr),
        .wb_cpu_dat(wb_cpu_dat),    .wb_cpu_rdt(wb_cpu_rdt),

        /* AUX Interface */
        .wb_aux_cyc(wb_aux_cyc),    .wb_aux_stb(wb_aux_stb),    .wb_aux_we(wb_aux_we),
        .wb_aux_ack(wb_aux_ack),    .wb_aux_sel(wb_aux_sel),    .wb_aux_adr(wb_aux_adr),
        .wb_aux_dat(wb_aux_dat),    .wb_aux_rdt(wb_aux_rdt),

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
   
        .busid(busid), 
        .wb_cyc(wb_gio_cyc),    .wb_stb(wb_gio_stb),    .wb_we(wb_gio_we),
        .wb_sel(wb_gio_sel),    .wb_adr(wb_gio_adr),    .wb_dat(wb_gio_dat),
        .wb_rdt(wb_gio_rdt),    .wb_ack(wb_gio_ack),
    
        .gpo(gio_q),
        .gpi(~gpi),

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

    /* AUX Interface */
    input           wb_aux_cyc,
    input           wb_aux_stb,
    input           wb_aux_we,
    output          wb_aux_ack,
    input   [3:0]   wb_aux_sel,
    input   [31:0]  wb_aux_adr,
    input   [31:0]  wb_aux_dat,
    output  [31:0]  wb_aux_rdt,
    
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
    input   [31:0]  wb_bus_rdt,

    /* Grant Status (bus master ID) */
    output  [3:0]   busid
);

    parameter [3:0] state_gcpu  = 4'b0001;
    parameter [3:0] state_gaux  = 4'b0010;
    parameter [3:0] state_gspi  = 4'b0100;
    parameter [3:0] state_idle  = 4'b1000;
    
    reg [3:0] state = state_idle;
    wire grant_cpu = state[0];
    wire grant_aux = state[1];
    wire grant_spi = state[2];
    assign busid   = state;

    wire cpu_cyc = wb_cpu_cyc & grant_cpu;
    wire aux_cyc = wb_aux_cyc & grant_aux;
    wire spi_cyc = wb_spi_cyc & grant_spi;

    wire cpu_stb = wb_cpu_stb & grant_cpu;
    wire aux_stb = wb_aux_stb & grant_aux;
    wire spi_stb = wb_spi_stb & grant_spi;

    always @(posedge clk) begin
        case (state)
            state_idle: begin // Idle, waiting for transfer to start
                state <= wb_cpu_cyc ? state_gcpu :
                            wb_aux_cyc ? state_gaux :
                                wb_spi_cyc ? state_gspi : state_idle;
                end

            state_gcpu: begin
                state <= ~wb_cpu_cyc ? state_idle : state;
                end

            state_gaux: begin
                state <= ~wb_aux_cyc ? state_idle : state;
                end

            state_gspi: begin
                state <= ~wb_spi_cyc ? state_idle : state;
                end

            default:
                state <= state_idle; 
        endcase
    end
             
    assign wb_bus_cyc = grant_cpu ? cpu_cyc :
                            grant_aux ? aux_cyc : 
                                grant_spi ? spi_cyc : 1'b0;

    assign wb_bus_stb = grant_cpu ? cpu_stb :
                            grant_aux ? aux_stb : 
                                grant_spi ? spi_stb : 1'b0;

    assign wb_bus_we  = grant_cpu ? wb_cpu_we :
                            grant_aux ? wb_aux_we :
                                grant_spi ? wb_spi_we : 1'b0;

    assign wb_bus_sel = grant_cpu ? wb_cpu_sel :
                            grant_aux ? wb_aux_sel :
                                grant_spi ? wb_spi_sel : 1'b0;

    assign wb_bus_adr = grant_cpu ? wb_cpu_adr :
                            grant_aux ? wb_aux_adr :
                                grant_spi ? wb_spi_adr : 0;

    assign wb_bus_dat = grant_cpu ? wb_cpu_dat :
                            grant_aux ? wb_aux_dat :
                                grant_spi ? wb_spi_dat : 0;
    
    assign wb_cpu_rdt = wb_bus_rdt;
    assign wb_aux_rdt = wb_bus_rdt;
    assign wb_spi_rdt = wb_bus_rdt;

    assign wb_cpu_ack = wb_bus_ack && grant_cpu;
    assign wb_aux_ack = wb_bus_ack && grant_aux;
    assign wb_spi_ack = wb_bus_ack && grant_spi;
    
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

