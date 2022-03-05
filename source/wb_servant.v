/* SPDX-License-Identifier: [MIT] */

`default_nettype none
module wb_servant
(
 input	wire			wb_clk,
 input	wire 			wb_rst,
 output	wire	[31:0]	wb_cpu_adr,
 output	wire	[31:0]	wb_cpu_dat,
 output	wire	[3:0] 	wb_cpu_sel,
 output	wire			wb_cpu_we,
 output	wire			wb_cpu_cyc,
 output	wire			wb_cpu_stb,
 input	wire	[31:0] 	wb_cpu_rdt,
 input	wire			wb_cpu_ack
);

   parameter memsize = 16384;
   parameter reset_strategy = "MINI";
   parameter sim = 0;
   parameter with_csr = 0;
 
   assign wb_cpu_stb = wb_cpu_cyc;

   wire	[31:0]	wb_ibus_adr;
   wire			wb_ibus_cyc;
   wire	[31:0]	wb_ibus_rdt;
   wire			wb_ibus_ack;

   wire	[31:0]	wb_dbus_adr;
   wire	[31:0]	wb_dbus_dat;
   wire	[3:0]	wb_dbus_sel;
   wire			wb_dbus_we;
   wire			wb_dbus_cyc;
   wire	[31:0]	wb_dbus_rdt;
   wire			wb_dbus_ack;

   wire	[31:0]	wb_dmem_adr;
   wire	[31:0]	wb_dmem_dat;
   wire	[3:0]	wb_dmem_sel;
   wire			wb_dmem_we;
   wire			wb_dmem_cyc;
   wire	[31:0]	wb_dmem_rdt;
   wire			wb_dmem_ack;


   servant_arbiter arbiter
     (.i_wb_cpu_dbus_adr (wb_dbus_adr),
      .i_wb_cpu_dbus_dat (wb_dbus_dat),
      .i_wb_cpu_dbus_sel (wb_dbus_sel),
      .i_wb_cpu_dbus_we  (wb_dbus_we ),
      .i_wb_cpu_dbus_cyc (wb_dbus_cyc),
      .o_wb_cpu_dbus_rdt (wb_dbus_rdt),
      .o_wb_cpu_dbus_ack (wb_dbus_ack),

      .i_wb_cpu_ibus_adr (wb_ibus_adr),
      .i_wb_cpu_ibus_cyc (wb_ibus_cyc),
      .o_wb_cpu_ibus_rdt (wb_ibus_rdt),
      .o_wb_cpu_ibus_ack (wb_ibus_ack),

      .o_wb_cpu_adr (wb_cpu_adr),
      .o_wb_cpu_dat (wb_cpu_dat),
      .o_wb_cpu_sel (wb_cpu_sel),
      .o_wb_cpu_we  (wb_cpu_we ),
      .o_wb_cpu_cyc (wb_cpu_cyc),
      .i_wb_cpu_rdt (wb_cpu_rdt),
      .i_wb_cpu_ack (wb_cpu_ack));


   serv_rf_top
     #(.RESET_PC (32'h0000_0000),
       .RESET_STRATEGY (reset_strategy),
       .WITH_CSR (with_csr))
   cpu
     (
      .clk      (wb_clk),
      .i_rst    (wb_rst),
      .i_timer_irq  (1'b0),

      .o_ibus_adr   (wb_ibus_adr),
      .o_ibus_cyc   (wb_ibus_cyc),
      .i_ibus_rdt   (wb_ibus_rdt),
      .i_ibus_ack   (wb_ibus_ack),

      .o_dbus_adr   (wb_dbus_adr),
      .o_dbus_dat   (wb_dbus_dat),
      .o_dbus_sel   (wb_dbus_sel),
      .o_dbus_we    (wb_dbus_we),
      .o_dbus_cyc   (wb_dbus_cyc),
      .i_dbus_rdt   (wb_dbus_rdt),
      .i_dbus_ack   (wb_dbus_ack));

endmodule
