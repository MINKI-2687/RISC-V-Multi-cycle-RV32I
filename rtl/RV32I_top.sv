`timescale 1ns / 1ps

module rv32i_mcu (
    input         clk,
    input         rst,
    // gpi, gpo, gpio
    input  [ 7:0] gpi,
    output [ 7:0] gpo,
    inout  [15:0] gpio,
    // fnd
    output [ 3:0] fnd_digit,
    output [ 7:0] fnd_data,
    // uart
    input         uart_rx,
    output        uart_tx
);
    logic [2:0] o_funct3;
    logic [31:0] instr_addr, instr_data, bus_addr, bus_wdata, bus_rdata;
    logic bus_wreq, bus_rreq, bus_ready;

    logic [31:0] paddr, pwdata;
    logic penable, pwrite;
    logic psel0, psel1, psel2, psel3, psel4, psel5;
    logic pready0, pready1, pready2, pready3, pready4, pready5;
    logic [31:0] prdata0, prdata1, prdata2, prdata3, prdata4, prdata5;

    instruction_mem U_INSTRUCTION_MEM (.*);

    rv32i_cpu U_RV32I (.*);

    apb_master U_APB_MASTER (
        .pclk   (clk),
        .preset (rst),
        //---------------------------------------
        // SoC Internal signal with CPU
        //       pc -> master
        .addr   (bus_addr),
        .wdata  (bus_wdata),
        .wreq   (bus_wreq),   // write request, signal cpu : dwe
        .rreq   (bus_rreq),   // read request,  signal cpu : dre
        // master -> pc
        .rdata  (bus_rdata),
        .ready  (bus_ready),
        //---------------------------------------
        // APB Interface signal
        //      slave -> master
        // ram
        .prdata0(prdata0),
        .pready0(pready0),
        // gpo
        .prdata1(prdata1),
        .pready1(pready1),
        // gpi
        .prdata2(prdata2),
        .pready2(pready2),
        // gpio
        .prdata3(prdata3),
        .pready3(pready3),
        // fnd
        .prdata4(prdata4),
        .pready4(pready4),
        // uart
        .prdata5(prdata5),
        .pready5(pready5),
        //      master -> slave
        .paddr  (paddr),      // need register
        .pwdata (pwdata),     // need register
        .penable(penable),    // need register
        .pwrite (pwrite),     // need register
        .psel0  (psel0),      // RAM
        .psel1  (psel1),      // GPO
        .psel2  (psel2),      // GPI
        .psel3  (psel3),      // GPIO
        .psel4  (psel4),      // FND
        .psel5  (psel5)       // UART
        //--------------------------------------
    );

    APB_BRAM U_APB_BRAM (
        .*,
        .pclk  (clk),
        .psel  (psel0),
        .prdata(prdata0),
        .pready(pready0)
    );

    APB_GPO U_APB_GPO (
        .pclk   (clk),
        .preset (rst),
        .paddr  (paddr),
        .pwdata (pwdata),
        .pwrite (pwrite),
        .penable(penable),
        .psel   (psel1),
        .pready (pready1),
        .prdata (prdata1),
        .gpo_out(gpo)
    );

    APB_GPI U_APB_GPI (
        .pclk   (clk),
        .preset (rst),
        .gpi_in (gpi),
        .paddr  (paddr),
        .pwdata (pwdata),
        .pwrite (pwrite),
        .penable(penable),
        .psel   (psel2),
        .pready (pready2),
        .prdata (prdata2)
    );

    APB_GPIO U_APB_GPIO (
        .pclk   (clk),
        .preset (rst),
        .paddr  (paddr),
        .pwdata (pwdata),
        .pwrite (pwrite),
        .penable(penable),
        .psel   (psel3),
        .pready (pready3),
        .prdata (prdata3),
        .gpio   (gpio)
    );

    APB_FND U_APB_FND (
        .pclk       (clk),
        .preset     (rst),
        .paddr      (paddr),
        .pwdata     (pwdata),
        .pwrite     (pwrite),
        .penable    (penable),
        .psel       (psel4),
        .prdata     (prdata4),
        .pready     (pready4),
        .o_fnd_digit(fnd_digit),
        .o_fnd_data (fnd_data)
    );

    APB_UART U_APB_UART (
        .pclk   (clk),
        .preset (rst),
        .paddr  (paddr),
        .pwdata (pwdata),
        .pwrite (pwrite),
        .penable(penable),
        .psel   (psel5),
        .uart_rx(uart_rx),
        .prdata (prdata5),
        .pready (pready5),
        .uart_tx(uart_tx)
    );


    // data_mem U_DATA_MEM (
    //     .*,
    //     .i_funct3(o_funct3)
    // );
endmodule
