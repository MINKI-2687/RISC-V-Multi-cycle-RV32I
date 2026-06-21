`timescale 1ns / 1ps

module APB_GPIO (
    input               pclk,
    input               preset,
    // APB Interface Signal
    input        [31:0] paddr,
    input        [31:0] pwdata,
    input               pwrite,
    input               penable,
    input               psel,
    output logic        pready,
    output logic [31:0] prdata,
    // external port
    inout  logic [15:0] gpio
);

    localparam [11:0] GPIO_CTRL_ADDR = 12'h000;
    localparam [11:0] GPIO_ODATA_ADDR = 12'h004;
    localparam [11:0] GPIO_IDATA_ADDR = 12'h008;
    logic [15:0] gpio_ctrl_reg, gpio_idata_reg, gpio_odata_reg;

    assign pready = (penable & psel) ? 1'b1 : 1'b0;

    assign prdata  = (psel && ~pwrite) ? (
                     (paddr[11:0] == GPIO_CTRL_ADDR)  ? {16'h0000, gpio_ctrl_reg}  : 
                     (paddr[11:0] == GPIO_ODATA_ADDR) ? {16'h0000, gpio_odata_reg} : 
                     (paddr[11:0] == GPIO_IDATA_ADDR) ? {16'h0000, gpio_idata_reg} :
                     32'h0000_0000) : 32'h0000_0000;

    always_ff @(posedge pclk, posedge preset) begin
        if (preset) begin
            gpio_ctrl_reg  <= 16'd0;
            gpio_odata_reg <= 16'd0;
        end else begin
            if (pready & pwrite) begin
                case (paddr[11:0])
                    GPIO_CTRL_ADDR:  gpio_ctrl_reg <= pwdata[15:0];
                    GPIO_ODATA_ADDR: gpio_odata_reg <= pwdata[15:0];
                endcase
            end
        end
    end

    gpio U_GPIO (
        .ctrl  (gpio_ctrl_reg),
        .o_data(gpio_odata_reg),
        .i_data(gpio_idata_reg),
        .gpio  (gpio)
    );
endmodule

module gpio (
    input        [15:0] ctrl,
    input        [15:0] o_data,
    output logic [15:0] i_data,
    inout  logic [15:0] gpio
);
    genvar i;
    generate
        for (i = 0; i < 16; i++) begin
            assign gpio[i]   = (ctrl[i]) ? o_data[i] : 1'bz;
            assign i_data[i] = (~ctrl[i]) ? gpio[i] : 1'b0;
        end
    endgenerate
endmodule
