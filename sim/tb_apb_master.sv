`timescale 1ns / 1ps

module tb_apb_master ();

    logic        pclk;
    logic        presetn;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic        wreq;  // write request, signal cpu : dwe
    logic        rreq;  // read request,  signal cpu : dre
    logic [31:0] rdata;
    logic        ready;
    logic [31:0] prdata0;
    logic        pready0;
    logic [31:0] prdata1;
    logic        pready1;
    logic [31:0] prdata2;
    logic        pready2;
    logic [31:0] prdata3;
    logic        pready3;
    logic [31:0] prdata4;
    logic        pready4;
    logic [31:0] prdata5;
    logic        pready5;
    logic [31:0] paddr;  // need register
    logic [31:0] pwdata;  // need register
    logic        penable;  // need register
    logic        pwrite;  // need register
    logic        psel0;  // RAM
    logic        psel1;  // GPO
    logic        psel2;  // GPI
    logic        psel3;  // GPIO
    logic        psel4;  // FND
    logic        psel5;  // UART


    apb_master dut (.*);

    always #5 pclk = ~pclk;


    initial begin
        pclk    = 0;
        presetn = 0;    // negative
        addr    = 0;
        wdata   = 0;
        wreq    = 0;
        rreq    = 0;

        repeat (2) @(posedge pclk);
        presetn = 1;  // negative 

        // RAM Write Test, 0x1000_0000
        // T1
        @(posedge pclk);
        #1;
        wreq  = 1'b1;
        addr  = 32'h1000_0000;
        wdata = 32'h0000_0041;

        //@(posedge pclk);
        //#1;
        @(psel0 & penable);
        pready0 = 1'b1;
        @(posedge pclk);
        #1;
        pready0 = 1'b0;
        wreq = 1'b0;

        // UART Read Test, 0x2000_4000 with waiting for 2-cycle
        @(posedge pclk);
        #1;
        rreq = 1'b1;
        addr = 32'h2000_4000;

        @(psel5 & penable);
        @(posedge pclk);
        @(posedge pclk);
        #1;
        pready5 = 1'b1;
        prdata5 = 32'h0000_0041;
        @(posedge pclk);
        #1;
        pready5 = 1'b0;
        rreq = 1'b0;

        @(posedge pclk);
        @(posedge pclk);

        $stop;
    end
endmodule

//assign pready0 = (penable & psel0);
//assign prdata0 = wdata;

// initial begin
//     pclk    = 0;
//     presetn = 0;    // negative
//     addr    = 0;
//     wdata   = 0;
//     wreq    = 0;
//     rreq    = 0;

//     repeat (2) @(posedge pclk);
//     presetn = 1;  // negative 
//     @(posedge pclk);
//     #1;

//     addr  = 32'h1000_0000;
//     wdata = 32'h0000_0041;
//     wreq  = 1'b1;
//     @(posedge pclk);
//     wreq = 1'b0;

//     wait (ready == 1'b1);
//     @(posedge pclk);

//     addr = 32'h1000_0000;
//     rreq = 1'b1;
//     @(posedge pclk);
//     rreq = 1'b0;

//     repeat (3) @(posedge pclk);
//     wait (ready == 1'b1);
//     @(posedge pclk);

//     $stop;
// end
