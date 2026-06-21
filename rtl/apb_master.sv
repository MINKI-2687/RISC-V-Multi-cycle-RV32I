`timescale 1ns / 1ps

module apb_master (
    input               pclk,
    input               preset,
    //---------------------------------------
    // SoC Internal signal with CPU
    // pc -> master
    input        [31:0] addr,
    input        [31:0] wdata,
    input               wreq,     // write request, signal cpu : dwe
    input               rreq,     // read request,  signal cpu : dre
    // master -> pc
    output       [31:0] rdata,
    output              ready,
    //---------------------------------------
    // APB Interface signal
    // slave -> master
    // ram
    input        [31:0] prdata0,
    input               pready0,
    // gpo
    input        [31:0] prdata1,
    input               pready1,
    // gpi
    input        [31:0] prdata2,
    input               pready2,
    // gpio
    input        [31:0] prdata3,
    input               pready3,
    // fnd
    input        [31:0] prdata4,
    input               pready4,
    // uart
    input        [31:0] prdata5,
    input               pready5,
    // master -> slave
    output logic [31:0] paddr,    // need register
    output logic [31:0] pwdata,   // need register
    output logic        penable,  // need register
    output logic        pwrite,   // need register
    output logic        psel0,    // RAM
    output logic        psel1,    // GPO
    output logic        psel2,    // GPI
    output logic        psel3,    // GPIO
    output logic        psel4,    // FND
    output logic        psel5     // UART
    //--------------------------------------
);
    typedef enum {
        IDLE,
        SETUP,
        ACCESS
    } apb_state_e;

    apb_state_e c_state, n_state;

    logic [31:0] paddr_next, pwdata_next;
    logic decode_en, pwrite_next;

    // SL
    always_ff @(posedge pclk, posedge preset) begin
        if (preset) begin  // negative edge reset
            c_state <= IDLE;
            paddr   <= 32'd0;
            pwdata  <= 32'd0;
            pwrite  <= 1'b0;
        end else begin
            c_state <= n_state;
            paddr   <= paddr_next;
            pwdata  <= pwdata_next;
            pwrite  <= pwrite_next;
        end
    end

    // next CL
    always_comb begin
        n_state     = c_state;
        decode_en   = 1'b0;
        penable     = 1'b0;
        paddr_next  = paddr;
        pwdata_next = pwdata;
        pwrite_next = pwrite;
        case (c_state)
            IDLE: begin
                decode_en   = 0;
                penable     = 1'b0;
                paddr_next  = 32'd0;
                pwdata_next = 32'd0;
                pwrite_next = 1'b0;
                if (wreq || rreq) begin
                    paddr_next  = addr;
                    pwdata_next = wdata;
                    if (wreq) pwrite_next = 1'b1;
                    else pwrite_next = 1'b0;
                    n_state = SETUP;
                end
            end
            SETUP: begin
                decode_en = 1;
                penable   = 0;
                n_state   = ACCESS;
            end
            ACCESS: begin
                decode_en = 1;
                penable   = 1;
                // pready0||pready1||pready2||pready3||pready4||pready5
                if (ready) begin
                    n_state = IDLE;
                end
            end
        endcase
    end

    addr_decoder U_ADDR_DECODER (
        .en   (decode_en),
        .addr (paddr),
        .psel0(psel0),      // RAM
        .psel1(psel1),      // GPO
        .psel2(psel2),      // GPI
        .psel3(psel3),      // GPIO
        .psel4(psel4),      // FND
        .psel5(psel5)       // UART
    );

    apb_mux U_APB_MUX (
        .sel    (paddr),
        .prdata0(prdata0),
        .prdata1(prdata1),
        .prdata2(prdata2),
        .prdata3(prdata3),
        .prdata4(prdata4),
        .prdata5(prdata5),
        .pready0(pready0),
        .pready1(pready1),
        .pready2(pready2),
        .pready3(pready3),
        .pready4(pready4),
        .pready5(pready5),
        .rdata  (rdata),
        .ready  (ready)
    );
endmodule

module addr_decoder (
    input               en,
    input        [31:0] addr,
    output logic        psel0,  // ram
    output logic        psel1,  // gpo
    output logic        psel2,  // gpi
    output logic        psel3,  // gpio
    output logic        psel4,  // fnd
    output logic        psel5   // uart
);
    always_comb begin
        // IDLE : 0
        psel0 = 1'b0;
        psel1 = 1'b0;
        psel2 = 1'b0;
        psel3 = 1'b0;
        psel4 = 1'b0;
        psel5 = 1'b0;
        if (en) begin
            case (addr[31:28])  // instead of casex
                4'h1: psel0 = 1'b1;
                4'h2: begin
                    case (addr[15:12])
                        4'h0: psel1 = 1'b1;
                        4'h1: psel2 = 1'b1;
                        4'h2: psel3 = 1'b1;
                        4'h3: psel4 = 1'b1;
                        4'h4: psel5 = 1'b1;
                    endcase
                end
            endcase
        end
    end
endmodule

module apb_mux (
    input        [31:0] sel,
    input        [31:0] prdata0,
    input        [31:0] prdata1,
    input        [31:0] prdata2,
    input        [31:0] prdata3,
    input        [31:0] prdata4,
    input        [31:0] prdata5,
    input               pready0,
    input               pready1,
    input               pready2,
    input               pready3,
    input               pready4,
    input               pready5,
    output logic [31:0] rdata,
    output logic        ready
);
    always_comb begin
        // IDLE : 0
        rdata = 32'h0000_0000;
        ready = 1'b0;
        case (sel[31:28])  // instead of casex
            4'h1: begin
                rdata = prdata0;
                ready = pready0;
            end
            4'h2: begin
                case (sel[15:12])
                    4'h0: begin
                        rdata = prdata1;
                        ready = pready1;
                    end
                    4'h1: begin
                        rdata = prdata2;
                        ready = pready2;
                    end
                    4'h2: begin
                        rdata = prdata3;
                        ready = pready3;
                    end
                    4'h3: begin
                        rdata = prdata4;
                        ready = pready4;
                    end
                    4'h4: begin
                        rdata = prdata5;
                        ready = pready5;
                    end
                endcase
            end
            default: begin
                rdata = 32'hxxxx_xxxx;
                ready = 1'bx;
            end
        endcase
    end
endmodule
