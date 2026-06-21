//`define SIMULATION

// opcode
`define R_TYPE 7'b011_0011
`define B_TYPE 7'b110_0011
`define S_TYPE 7'b010_0011      // store
`define IL_TYPE 7'b000_0011     // load
`define I_TYPE 7'b001_0011
`define U_TYPE 7'b011_0111      // LUI
`define UPC_TYPE 7'b001_0111    // AUIPC
`define J_TYPE 7'b110_1111      // JAL
`define JL_TYPE 7'b110_0111     // JALR

// ALU Operations
`define ADD 4'b0_000    // R, I, IL, S, UPC-type
`define SUB 4'b1_000    // R-type SUB
`define SLL 4'b0_001
`define SLT 4'b0_010
`define SLTU 4'b0_011
`define XOR 4'b0_100
`define SRL 4'b0_101
`define SRA 4'b1_101
`define OR 4'b0_110
`define AND 4'b0_111

// B-type instruction
`define BEQ 4'b0_000
`define BNE 4'b0_001
`define BLT 4'b0_100
`define BGE 4'b0_101
`define BLTU 4'b0_110
`define BGEU 4'b0_111

// S-type instruction
`define SB 3'b000
`define SH 3'b001
`define SW 3'b010

// IL-type instruction
`define LB 3'b000
`define LH 3'b001
`define LW 3'b010
`define LBU 3'b100
`define LHU 3'b101
