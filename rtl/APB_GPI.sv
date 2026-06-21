`timescale 1ns / 1ps

module APB_GPI (
    input               pclk,
    input               preset,
    input        [15:0] gpi_in,
    input        [31:0] paddr,
    input        [31:0] pwdata,
    input               pwrite,
    input               penable,
    input               psel,
    output logic        pready,
    output logic [31:0] prdata
);

    localparam [11:0] GPI_CTRL_ADDR = 12'h000;
    localparam [11:0] GPI_IDATA_ADDR = 12'h004;

    logic [15:0] gpi_idata_reg, gpi_ctrl_reg;

    assign pready = (penable & psel) ? 1'b1 : 1'b0;

    assign prdata  = (psel & ~pwrite) ? (
                     (paddr[11:0] == GPI_CTRL_ADDR)  ? {16'h0000, gpi_ctrl_reg}  : 
                     (paddr[11:0] == GPI_IDATA_ADDR) ? {16'h0000, gpi_idata_reg} : 
                     32'hxxxx_xxxx) : 32'h0000_0000;

    always_ff @(posedge pclk, posedge preset) begin
        if (preset) begin
            gpi_ctrl_reg <= 16'd0;
            // gpi_idata_reg <= 16'd0;
        end else begin
            //  for (int i = 0; i < 16; i++) begin
            //      gpi_idata_reg[i] <= (gpi_ctrl_reg[i]) ? gpi_in[i] : 1'bz;
            //  end
            if (pready & pwrite) begin
                case (paddr[11:0])
                    GPI_CTRL_ADDR: gpi_ctrl_reg <= pwdata[15:0];
                endcase
            end
        end
    end

    genvar i;
    generate
        for (i = 0; i < 16; i++) begin
            assign gpi_idata_reg[i] = (gpi_ctrl_reg[i]) ? gpi_in[i] : 1'b0;
        end
    endgenerate
endmodule
