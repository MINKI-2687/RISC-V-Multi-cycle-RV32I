`timescale 1ns / 1ps

module APB_GPO (
    input               pclk,
    input               preset,
    input        [31:0] paddr,
    input        [31:0] pwdata,
    input               pwrite,
    input               penable,
    input               psel,
    output logic        pready,
    output logic [31:0] prdata,
    output logic [15:0] gpo_out
);

    localparam [11:0] GPO_CTRL_ADDR = 12'h000;
    localparam [11:0] GPO_ODATA_ADDR = 12'h004;

    logic [15:0] gpo_odata_reg, gpo_ctrl_reg;

    assign pready = (penable & psel) ? 1'b1 : 1'b0;

    assign prdata  = (paddr[11:0] == GPO_CTRL_ADDR)  ? {16'h0000, gpo_ctrl_reg}  : 
                     (paddr[11:0] == GPO_ODATA_ADDR) ? {16'h0000, gpo_odata_reg} : 
                     32'hxxxx_xxxx;

    always_ff @(posedge pclk, posedge preset) begin
        if (preset) begin
            gpo_ctrl_reg  <= 16'd0;
            gpo_odata_reg <= 16'd0;
        end else begin
            if (pready & pwrite) begin
                case (paddr[11:0])
                    GPO_CTRL_ADDR:  gpo_ctrl_reg <= pwdata[15:0];
                    GPO_ODATA_ADDR: gpo_odata_reg <= pwdata[15:0];
                endcase
            end
        end
    end

    genvar i;
    generate
        for (i = 0; i < 16; i++) begin
            assign gpo_out[i] = (gpo_ctrl_reg[i]) ? gpo_odata_reg[i] : 1'b0;
        end
    endgenerate

endmodule
