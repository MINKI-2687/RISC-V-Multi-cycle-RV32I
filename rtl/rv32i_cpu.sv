`timescale 1ns / 1ps
`include "define.vh"

module rv32i_cpu (
    input         clk,
    input         rst,
    input  [31:0] instr_data,
    input  [31:0] bus_rdata,
    input         bus_ready,
    output [31:0] instr_addr,
    output        bus_wreq,
    output        bus_rreq,
    output [ 2:0] o_funct3,
    output [31:0] bus_addr,
    output [31:0] bus_wdata
);

    logic pc_en, rf_we, branch, alu_src_sel, jal, jalr;
    logic [3:0] alu_control;
    logic [2:0] rfwd_srcsel;

    control_unit U_CONTROL_UNIT (
        .clk        (clk),
        .rst        (rst),
        .funct7     (instr_data[31:25]),
        .funct3     (instr_data[14:12]),
        .opcode     (instr_data[6:0]),
        .ready      (bus_ready),
        .pc_en      (pc_en),              // for multi cycle FETCH
        .rf_we      (rf_we),
        .branch     (branch),
        .jal        (jal),
        .jalr       (jalr),
        .alu_src_sel(alu_src_sel),
        .alu_control(alu_control),
        .rfwd_srcsel(rfwd_srcsel),
        .o_funct3   (o_funct3),
        .dwe        (bus_wreq),
        .dre        (bus_rreq)
    );

    rv32i_datapath U_DATAPATH (.*);
endmodule

module control_unit (
    input              clk,
    input              rst,
    input        [6:0] funct7,
    input        [2:0] funct3,
    input        [6:0] opcode,
    input              ready,
    output logic       pc_en,
    output logic       rf_we,
    output logic       branch,
    output logic       jal,
    output logic       jalr,
    output logic       alu_src_sel,
    output logic [3:0] alu_control,
    output logic [2:0] rfwd_srcsel,
    output logic [2:0] o_funct3,
    output logic       dwe,
    output logic       dre
);
    // control unit 
    typedef enum {
        FETCH,
        DECODE,
        EXECUTE,
        MEM,
        WB
    } state_e;

    state_e c_state, n_state;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= FETCH;
        end else begin
            c_state <= n_state;
        end
    end

    // next CL
    always_comb begin
        n_state = c_state;
        case (c_state)
            FETCH: begin
                n_state = DECODE;
            end
            DECODE: begin
                n_state = EXECUTE;
            end
            EXECUTE: begin
                case (opcode)
                    `R_TYPE, `I_TYPE, `B_TYPE, `U_TYPE, `UPC_TYPE, `J_TYPE, `JL_TYPE:
                    n_state = FETCH;
                    `S_TYPE, `IL_TYPE: n_state = MEM;
                endcase
            end
            MEM: begin
                case (opcode)
                    `S_TYPE: begin
                        if (ready) n_state = FETCH;
                    end
                    `IL_TYPE: begin
                        if (ready) n_state = WB;
                    end
                endcase
            end
            WB: begin
                n_state = FETCH;
            end
        endcase
    end

    // output CL
    always_comb begin
        pc_en       = 1'b0;
        rf_we       = 1'b0;
        branch      = 1'b0;
        jal         = 1'b0;
        jalr        = 1'b0;
        alu_src_sel = 1'b0;
        alu_control = 4'b0000;
        rfwd_srcsel = 3'd0;
        o_funct3    = 3'b000;  // for S, IL type
        dwe         = 1'b0;  // for S type
        dre         = 1'b0;  // for IL type
        case (c_state)
            FETCH: begin
                pc_en = 1'b1;
            end
            DECODE: begin
            end
            EXECUTE: begin
                case (opcode)
                    `R_TYPE: begin
                        rf_we       = 1'b1;  // next state FETCH
                        alu_src_sel = 1'b0;
                        alu_control = {funct7[5], funct3};
                    end
                    `I_TYPE: begin
                        rf_we       = 1'b1;  // next state FETCH
                        alu_src_sel = 1'b1;
                        if (funct3 == 3'b101) alu_control = {funct7[5], funct3};
                        else alu_control = {1'b0, funct3};
                    end
                    `B_TYPE: begin
                        branch      = 1'b1;
                        alu_src_sel = 1'b0;
                        alu_control = {1'b0, funct3};
                    end
                    `S_TYPE: begin
                        alu_src_sel = 1'b1;
                        alu_control = 4'b0000;  // add for dwaddr
                    end
                    `IL_TYPE: begin
                        alu_src_sel = 1'b1;
                        alu_control = 4'b0000;  // add for dwaddr
                    end
                    `U_TYPE: begin
                        rf_we       = 1'b1;  // next state FETCH
                        rfwd_srcsel = 3'd2;
                    end
                    `UPC_TYPE: begin
                        rf_we       = 1'b1;  // next state FETCH
                        rfwd_srcsel = 3'd3;
                    end
                    `J_TYPE, `JL_TYPE: begin
                        rf_we = 1'b1;  // next state FETCH
                        jal   = 1'b1;
                        if (opcode == `JL_TYPE) jalr = 1'b1;
                        else jalr = 1'b0;
                        rfwd_srcsel = 3'd4;
                    end
                endcase
            end
            MEM: begin
                o_funct3 = funct3;
                if (opcode == `S_TYPE) begin
                    dwe = 1'b1;
                end else if (opcode == `IL_TYPE) begin
                    dre = 1'b1;
                end
            end
            WB: begin
                // IL type
                rf_we       = 1'b1;  // next state FETCH
                rfwd_srcsel = 3'd1;
            end
        endcase
    end
endmodule
