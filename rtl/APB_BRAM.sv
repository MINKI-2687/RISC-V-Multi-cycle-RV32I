`timescale 1ns / 1ps

module APB_BRAM (
    // BUS Global signal
    input               pclk,
    // APB Interface Signal
    input        [31:0] paddr,
    input        [31:0] pwdata,
    input               penable,
    input               pwrite,
    input               psel,
    output logic [31:0] prdata,
    output logic        pready
);

    logic [31:0] bmem[0:1023];  // 1024 * 4byte : 4K

    assign pready = (penable & psel) ? 1'b1 : 1'b0;

    always_ff @(posedge pclk) begin
        if (psel & penable & pwrite) begin
            bmem[paddr[11:2]] <= pwdata;
        end
    end

    assign prdata = bmem[paddr[11:2]];
endmodule
