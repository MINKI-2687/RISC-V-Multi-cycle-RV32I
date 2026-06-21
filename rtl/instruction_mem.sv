`timescale 1ns / 1ps

module instruction_mem (
    input  [31:0] instr_addr,
    output [31:0] instr_data
);
    // 명령어 저장을 위한 rom
    logic [31:0] rom[0:255];

    initial begin
        //$readmemh("riscv_rv32i_rom_data.mem", rom);
        //$readmemh("U_APB_BRAM.mem", rom);
        //$readmemh("APB_GPO.mem", rom);
        //$readmemh("APB_GPI_GPO.mem", rom);
        //$readmemh("APB_BRAM_GPO_GPI.mem", rom);
        //$readmemh("APB_GPIO_LED_BLINK.mem", rom);
        $readmemh("APB_FND.mem", rom);
        //$readmemh("APB_UART.mem", rom);
        //$readmemh("APB_FINAL.mem", rom);
        //// R-type
        //rom[0]  = 32'h0041_82b3;  // ADD x5, x3, x4
        //rom[1]  = 32'h4041_82b3;  // SUB x5, x3, x4
        //rom[2]  = 32'h4032_02b3;  // SUB x5, x4, x3
        //rom[3]  = 32'h0041_92b3;  // SLL x5, x3, x4
        //rom[4]  = 32'h0043_22b3;  // SLT x5, x6, x4
        //rom[5]  = 32'h0043_32b3;  // SLTU x5, x6, x4
        //rom[6]  = 32'h0041_c2b3;  // XOR x5, x3, x4
        //rom[7]  = 32'h0103_52b3;  // SRL x5, x6, x16
        //rom[8]  = 32'h4103_52b3;  // SRA x5, x6, x16
        //rom[9]  = 32'h0041_e2b3;  // OR x5, x3, x4
        //rom[10] = 32'h0041_f2b3;  // AND x5, x3, x4

        //// B-type
        //rom[0] = 32'h0031_8463;  // BEQ x3, x3, 8
        //rom[2] = 32'h0031_9463;  // BNE x3, x3, 8
        //rom[3] = 32'h0062_4463;  // BLT x4, x6, 8
        //rom[4] = 32'h0062_6463;  // BLTU x4, x6, 8
        //rom[6] = 32'h0043_5463;  // BGE x6, x4, 8
        //rom[7] = 32'h0043_7463;  // BGEU x6, x4, 8

        //// S-type
        //rom[0] = 32'h0072_0223;  // SB x7, 4(x4) -> Addr 8  (dmem[2][7:0])
        //rom[1] = 32'h0072_0323;  // SB x7, 6(x4) -> Addr 10 (dmem[2][23:16])
        //rom[2] = 32'h0072_02a3;  // SB x7, 5(x4) -> Addr 9  (dmem[2][15:8])
        //rom[3] = 32'h0072_03a3;  // SB x7, 7(x4) -> Addr 11 (dmem[2][31:24])
        //rom[4] = 32'h0062_1223;  // SH x6, 4(x4) -> Addr 8, 9 (dmem[2][15:0])
        //rom[5] = 32'h0062_1323;  // SH x6, 6(x4) -> Addr 10, 11 (dmem[2][31:16])
        //rom[6] = 32'h0072_2223;  // SW x7, 4(x4)


        //// IL-type
        //rom[0]  = 32'h0072_2223;  // SW x7, 4(x4)
        //rom[1]  = 32'h0082_2423;  // SW x8, 8(x4)
        //rom[2]  = 32'h0082_4283;  // LBU x5, 8(x4)
        //rom[3]  = 32'h0092_4283;  // LBU x5, 9(x4)
        //rom[4]  = 32'h00a2_4283;  // LBU x5, 10(x4)
        //rom[5]  = 32'h00b2_4283;  // LBU x5, 11(x4)
        //rom[6]  = 32'h0082_5283;  // LHU x5, 8(x4)
        //rom[7]  = 32'h00a2_5283;  // LHU x5, 10(x4)
        //rom[8]  = 32'h0042_0283;  // LB x5, 4(x4)
        //rom[9]  = 32'h0042_1283;  // LH x5, 4(x4)
        //rom[10] = 32'h0082_2283;  // LW x5, 8(x4)

        //// I-type
        //rom[0] = 32'h0041_8293;  // ADDi x5, x3, 4

        //// U-type
        //rom[0] = 32'h1000_02b7;  // LUI x5, 0x1000_0
        //// UPC-type
        //rom[1] = 32'h1000_0297;  // AUIPC x5, 0x1000_0

        //// J-type
        //rom[1]  = 32'h0300_00ef;  // JAL x1, 0x30
        //// JL-type
        //rom[13] = 32'h0000_8067;  // JALR x0, 0x0(x1)
        //// JL-type
        ////rom[3]  = 32'h000280e7;  // JALR x1, 0x0(x5)
    end

    // [31:2] 로 시뮬레이션 시간을 단축?
    assign instr_data = rom[instr_addr[31:2]];

endmodule
