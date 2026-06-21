# RISC-V RV32I Multi-Cycle MCU with APB Peripheral System

> **RISC-V RV32I** instruction set architecture(ISA)를 기반으로 구현한 **Multi-Cycle CPU**와  
> **AMBA APB** 프로토콜 기반 주변장치(BRAM, GPO, GPI, GPIO, FND, UART)를 통합한 SoC 설계 프로젝트.  
> Xilinx Basys-3 FPGA 보드에서 실제 동작을 검증하였으며, C Firmware를 통한 Memory-Mapped I/O 제어까지 구현하였다.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [System Architecture](#2-system-architecture)
3. [Multi-Cycle CPU Design](#3-multi-cycle-cpu-design)
   - 3.1 [Control Unit FSM](#31-control-unit-fsm)
   - 3.2 [Datapath](#32-datapath)
   - 3.3 [Instruction Set Coverage](#33-instruction-set-coverage)
4. [APB Bus Interface](#4-apb-bus-interface)
   - 4.1 [APB Master FSM](#41-apb-master-fsm)
   - 4.2 [Address Decoder & Memory Map](#42-address-decoder--memory-map)
5. [APB Peripheral Slaves](#5-apb-peripheral-slaves)
   - 5.1 [BRAM (APB_BRAM)](#51-bram-apb_bram)
   - 5.2 [GPO / GPI](#52-gpo--gpi)
   - 5.3 [GPIO (Bidirectional)](#53-gpio-bidirectional)
   - 5.4 [FND Controller](#54-fnd-controller)
   - 5.5 [UART](#55-uart)
6. [C Firmware](#6-c-firmware)
7. [Verification](#7-verification)
8. [FPGA Implementation](#8-fpga-implementation)
9. [File Structure](#9-file-structure)
10. [Skills & Technologies](#10-skills--technologies)

---

## 1. Project Overview

| 항목 | 내용 |
|------|------|
| **Target FPGA** | Xilinx Basys-3 (Artix-7 XC7A35T) |
| **HDL** | SystemVerilog |
| **EDA Tool** | Xilinx Vivado |
| **CPU Architecture** | RISC-V RV32I, Multi-Cycle |
| **Bus Protocol** | AMBA APB (Advanced Peripheral Bus) |
| **Peripherals** | BRAM, GPO, GPI, GPIO, FND, UART |
| **Firmware Language** | C (Memory-Mapped I/O) |
| **Clock** | 50 MHz (Basys-3 onboard) |

**핵심 구현 내용:**
- RV32I 명령어 셋(R/I/S/B/U/J Type) 전체를 Multi-Cycle 방식으로 구현
- AMBA APB 프로토콜 기반 APB Master와 6개의 APB Slave 설계
- C Firmware의 Memory-Mapped I/O 접근이 실제 FPGA 하드웨어까지 연결되는 전체 SoC 스택 구현
- HAL(Hardware Abstraction Layer) 스타일의 드라이버 코드 작성

---

## 2. System Architecture

### 전체 Block Diagram

<!-- 
  [이미지 삽입 위치]
  권장 이미지: Vivado Block Design 또는 발표자료 슬라이드의 전체 Block Diagram 캡처
  파일명 예시: docs/images/block_diagram_top.png
-->

```
                     ┌────────────────────────────────────────────────────────┐
                     │                   rv32i_mcu (Top)                     │
                     │                                                        │
  ┌─────────────┐   │   ┌────────────┐    ┌────────────────────────────────┐ │
  │  Instruction │   │   │            │    │          APB Master            │ │
  │  Memory(ROM) │──┼──▶│  RV32I CPU │───▶│  IDLE ──▶ SETUP ──▶ ACCESS   │ │
  │  (256 x 32b) │   │   │ (Multi-Cyc)│◀──│   Addr Decoder + APB MUX     │ │
  └─────────────┘   │   └────────────┘    └──────┬─────────────────────────┘ │
                     │                           │ paddr/pwdata/psel/penable  │
                     │              ┌────────────┼──────────────────────────┐ │
                     │              ▼            ▼            ▼             │ │
                     │         ┌────────┐  ┌────────┐  ┌────────┐         │ │
                     │         │APB_BRAM│  │APB_GPO │  │APB_GPI │  ...    │ │
                     │         │0x1000_ │  │0x2000_ │  │0x2001_ │         │ │
                     │         │  0000  │  │  0000  │  │  0000  │         │ │
                     │         └────────┘  └────────┘  └────────┘         │ │
                     └────────────────────────────────────────────────────────┘
```

### 모듈 구성

| 모듈 | 역할 |
|------|------|
| `instruction_mem` | RV32I 명령어를 저장하는 ROM (256 x 32-bit) |
| `rv32i_cpu` | Control Unit + Datapath를 포함하는 Multi-Cycle CPU |
| `apb_master` | CPU 메모리 요청을 APB 트랜잭션으로 변환하는 버스 마스터 |
| `APB_BRAM` | 4KB SRAM (Data Memory), 주소 `0x1000_0000` |
| `APB_GPO` | 출력 전용 GPIO (Left LED), 주소 `0x2000_0000` |
| `APB_GPI` | 입력 전용 GPIO (Left Switch), 주소 `0x2001_0000` |
| `APB_GPIO` | 양방향 GPIO (Right LED/SW), 주소 `0x2002_0000` |
| `APB_FND` | 4자리 7-세그먼트 디스플레이, 주소 `0x2003_0000` |
| `APB_UART` | 직렬 통신 (TX/RX Echo), 주소 `0x2004_0000` |

---

## 3. Multi-Cycle CPU Design

### 3.1 Control Unit FSM

Multi-Cycle CPU는 하나의 명령어를 최대 5개의 클럭 사이클에 나누어 처리한다.  
명령어 종류에 따라 사용하는 스테이지 수가 달라지며, APB `ready` 신호에 의해 MEM 스테이지가 연장(stall)된다.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           Control Unit State Machine                         │
│                                                                              │
│                  ┌────────────────────────────────────────────┐              │
│                  │              (always)                       │              │
│                  ▼                                            │              │
│          ┌──────────────┐                                     │              │
│          │   FETCH      │  pc_en = 1                         │              │
│          │   (IF)       │                                     │              │
│          └──────┬───────┘                                     │              │
│                 │                                             │              │
│                 ▼                                             │              │
│          ┌──────────────┐                                     │              │
│          │   DECODE     │  IMM Extend                        │              │
│          │   (ID)       │  Register File Read                │              │
│          └──────┬───────┘                                     │              │
│                 │                                             │              │
│                 ▼                                             │              │
│          ┌──────────────┐   R/I/U/B/J/JL Type ──────────────┘              │
│          │   EXECUTE    │  ALU operation, Branch decision                    │
│          │   (EX)       │  PC next computation                               │
│          └──────┬───────┘                                     │              │
│            S/IL │                                             │              │
│                 ▼                                             │              │
│          ┌──────────────┐                                     │              │
│          │   MEMORY     │  dwe=1 (S-Type: APB Write)         │              │
│          │   (MEM)      │  dre=1 (IL-Type: APB Read)         │              │
│          │              │  Waits for APB pready              │              │
│          └──────┬───────┘                                     │              │
│           IL-T  │                                             │              │
│                 ▼                                             │              │
│          ┌──────────────┐                                     │              │
│          │  WRITE BACK  │  rf_we=1, rfwd_srcsel=MEM_data    │              │
│          │   (WB)       │─────────────────────────────────────┘              │
│          └──────────────┘                                                    │
└──────────────────────────────────────────────────────────────────────────────┘
```

**스테이지별 명령어 분기:**

| Instruction Type | FETCH | DECODE | EXECUTE | MEM | WB |
|-----------------|:-----:|:------:|:-------:|:---:|:--:|
| R-Type          | O     | O      | O (WB)  | -   | -  |
| I-Type (ALU)    | O     | O      | O (WB)  | -   | -  |
| B-Type          | O     | O      | O       | -   | -  |
| U/J/JL-Type     | O     | O      | O (WB)  | -   | -  |
| S-Type (Store)  | O     | O      | O       | O   | -  |
| IL-Type (Load)  | O     | O      | O       | O   | O  |

> **Key Design Point:** EXECUTE 단계에서 R/I/U/B/J/JL 타입은 WB까지 처리한 뒤 바로 FETCH로 복귀.  
> S/IL 타입만 MEM 단계로 진입하여 APB 버스를 통해 외부 메모리/주변장치에 접근.

### 3.2 Datapath

<!-- 
  [이미지 삽입 위치]
  권장 이미지: rv32i_datapath.sv 기반의 Datapath 블록 다이어그램
  (Program Counter, Register File, ALU, IMM Extender, Stage Registers, WB MUX 포함)
  파일명 예시: docs/images/datapath.png
-->

핵심 데이터패스 구성요소:

- **Program Counter (`program_counter`):** `btaken & branch`, `jal`, `jalr` 신호에 따라 PC+4 또는 PC+imm 선택
- **Register File (`register_file`):** 32개의 32-bit 레지스터, `x0`는 항상 0 (hardwired)
- **IMM Extender (`imm_extender`):** opcode 기반으로 6가지 immediate 포맷 자동 생성
- **ALU (`alu`):** 10가지 산술/논리 연산 + B-Type comparator (`btaken` 생성)
- **Stage Registers:** DEC, EXE, MEM 단계 사이에 pipeline register 배치 (multi-cycle 중간값 보존)
- **WB MUX (`mux_5x1`):** ALU result / Mem data / IMM / AUIPC / JAL+4 중 선택하여 레지스터 파일에 기록

```systemverilog
// WB 소스 선택 (rfwd_srcsel 기준)
mux_5x1 U_MUX_WB_REGFILE (
    .in0 (alu_result),   // R/I-Type
    .in1 (o_mem_drdata), // IL-Type (Load)
    .in2 (o_dec_imm),    // U-Type (LUI)
    .in3 (auipc),        // UPC-Type (AUIPC)
    .in4 (j_type),       // J/JL-Type (JAL/JALR)
    .mux_sel(rfwd_srcsel),
    .out_mux(rfwb_data)
);
```

### 3.3 Instruction Set Coverage

```
RV32I Base Integer Instruction Set
├── R-Type  : ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
├── I-Type  : ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
├── I-Type  : LW, LH, LHU, LB, LBU (Load)
├── S-Type  : SW, SH, SB (Store)
├── B-Type  : BEQ, BNE, BLT, BGE, BLTU, BGEU
├── U-Type  : LUI, AUIPC
└── J-Type  : JAL, JALR
```

---

## 4. APB Bus Interface

### 4.1 APB Master FSM

CPU의 `bus_wreq`(write request) / `bus_rreq`(read request) 신호를 감지하여  
AMBA APB 프로토콜 트랜잭션을 생성하는 3상태 FSM.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          APB Master State Machine                           │
│                                                                             │
│                        wreq || rreq                                        │
│          ┌──────────────────────────────────┐                              │
│          │                                  │                              │
│   ┌──────▼──────┐                    ┌──────┴──────┐                      │
│   │    IDLE     │                    │    SETUP    │  psel=1, penable=0   │
│   │             │◀───────────────────│             │  (1 clock)           │
│   │ psel=0      │                    └──────┬──────┘                      │
│   │ penable=0   │                           │                              │
│   └─────────────┘                           ▼                              │
│          ▲                           ┌──────────────┐                      │
│          │      pready == 1          │    ACCESS    │  psel=1, penable=1  │
│          └───────────────────────────│              │  Wait for pready    │
│                                      └──────────────┘                      │
└─────────────────────────────────────────────────────────────────────────────┘
```

| Signal | Direction | Description |
|--------|-----------|-------------|
| `paddr[31:0]` | M → S | 레지스터된 버스 주소 |
| `pwdata[31:0]` | M → S | 레지스터된 쓰기 데이터 |
| `pwrite` | M → S | 1: Write, 0: Read |
| `psel[N]` | M → S | 해당 슬레이브 선택 신호 |
| `penable` | M → S | ACCESS 단계 진입 표시 |
| `prdata[31:0]` | S → M | 슬레이브 읽기 데이터 |
| `pready` | S → M | 트랜잭션 완료 응답 |

> APB 특성상 `paddr`, `pwdata`, `pwrite`는 SETUP 단계 진입 시 레지스터에 래치되어  
> ACCESS 단계 동안 안정적으로 유지된다.

### 4.2 Address Decoder & Memory Map

```
Address Map (32-bit)
─────────────────────────────────────────────────
0x1000_0000  ┌─────────────────────────────┐
             │  BRAM (Data Memory)          │  psel0
             │  4KB (1024 x 32-bit)        │
0x1000_0FFF  └─────────────────────────────┘

0x2000_0000  ┌─────────────────────────────┐
             │  GPO   (Left LED, Output)   │  psel1
0x2000_0004  │  CTRL[0x00] | ODATA[0x04]  │
             └─────────────────────────────┘
0x2001_0000  ┌─────────────────────────────┐
             │  GPI   (Left SW, Input)     │  psel2
0x2001_0004  │  CTRL[0x00] | IDATA[0x04]  │
             └─────────────────────────────┘
0x2002_0000  ┌─────────────────────────────┐
             │  GPIO  (Right SW/LED, Bidir)│  psel3
0x2002_0008  │  CTRL/ODATA/IDATA[0x00~08] │
             └─────────────────────────────┘
0x2003_0000  ┌─────────────────────────────┐
             │  FND   (7-Segment Display)  │  psel4
0x2003_0004  │  CTRL[0x00] | ODATA[0x04]  │
             └─────────────────────────────┘
0x2004_0000  ┌─────────────────────────────┐
             │  UART  (Serial Comm)        │  psel5
0x2004_0010  │  CTRL/BAUD/STATUS/TX/RX    │
             └─────────────────────────────┘
─────────────────────────────────────────────────
```

**Address Decoding Logic (apb_master.sv):**
```systemverilog
case (addr[31:28])
    4'h1: psel0 = 1'b1;          // BRAM
    4'h2: begin
        case (addr[15:12])
            4'h0: psel1 = 1'b1;  // GPO
            4'h1: psel2 = 1'b1;  // GPI
            4'h2: psel3 = 1'b1;  // GPIO
            4'h3: psel4 = 1'b1;  // FND
            4'h4: psel5 = 1'b1;  // UART
        endcase
    end
endcase
```

---

## 5. APB Peripheral Slaves

### 5.1 BRAM (APB_BRAM)

- **Size:** 1024 words × 32-bit = **4KB**
- **Access:** Synchronous Write / Asynchronous Read
- **pready:** `penable & psel` 조합으로 1-cycle latency 구현

```systemverilog
// 비동기 읽기 (pready 즉시 응답)
assign prdata = bmem[paddr[11:2]];
assign pready = (penable & psel) ? 1'b1 : 1'b0;

// 동기 쓰기
always_ff @(posedge pclk) begin
    if (psel & penable & pwrite)
        bmem[paddr[11:2]] <= pwdata;
end
```

### 5.2 GPO / GPI

**GPO (General Purpose Output):** 왼쪽 LED 8개 출력 전용

| 레지스터 | 오프셋 | 기능 |
|---------|--------|------|
| `CTRL` | `0x00` | 비트별 출력 허가 마스크 (`1`: 출력 활성, `0`: 강제 Low) |
| `ODATA` | `0x04` | 출력 데이터 레지스터 |

```systemverilog
// CTRL 마스크를 통한 출력 제어
generate
    for (i = 0; i < 16; i++) begin
        assign gpo_out[i] = (gpo_ctrl_reg[i]) ? gpo_odata_reg[i] : 1'b0;
    end
endgenerate
```

**GPI (General Purpose Input):** 왼쪽 스위치 8개 입력 전용

| 레지스터 | 오프셋 | 기능 |
|---------|--------|------|
| `CTRL` | `0x00` | 비트별 입력 허가 마스크 (`1`: 실제 핀 값, `0`: 강제 0) |
| `IDATA` | `0x04` | 입력 데이터 (read-only) |

> GPI CTRL 레지스터를 `0x00`으로 두면 스위치 값이 항상 0으로 읽힌다.  
> 반드시 `0xFF` 등으로 설정해야 실제 핀 상태가 반영된다.

### 5.3 GPIO (Bidirectional)

CTRL 레지스터의 비트 값에 따라 핀별로 출력/입력 방향을 독립적으로 설정.

```systemverilog
// 3-state 버퍼를 통한 양방향 핀 제어
generate
    for (i = 0; i < 16; i++) begin
        assign gpio[i]   = (ctrl[i]) ? o_data[i] : 1'bz;  // Output or Hi-Z
        assign i_data[i] = (~ctrl[i]) ? gpio[i]  : 1'b0;  // Input capture
    end
endgenerate
```

| 레지스터 | 오프셋 | 기능 |
|---------|--------|------|
| `CTRL` | `0x00` | `1`: Output, `0`: Input (비트별) |
| `ODATA` | `0x04` | 출력 데이터 |
| `IDATA` | `0x08` | 입력 데이터 (read-only) |

**XDC 핀 매핑 (Basys-3):**
- `gpio[7:0]` → 오른쪽 스위치 SW7~SW0
- `gpio[15:8]` → 오른쪽 LED LD7~LD0

### 5.4 FND Controller

4자리 7-세그먼트 디스플레이를 Multiplexing 방식으로 제어.  
APB로부터 BCD 숫자값(0~9999)을 받아 자동으로 각 자리를 분리하여 표시.

<!-- 
  [이미지 삽입 위치]
  권장 이미지: FND 컨트롤러 내부 블록 구조 다이어그램 또는 실제 FND 동작 사진
  파일명 예시: docs/images/fnd_controller.png
-->

```
APB_FND 내부 신호 흐름

fnd_odata_reg[13:0]
       │
       ▼
┌─────────────────┐
│  digit_splitter │  → digit_1000, digit_100, digit_10, digit_1
└────────┬────────┘
         │
         ▼                 ┌──────────┐    ┌──────────┐
┌──────────────┐           │ clk_div  │───▶│counter_4 │──▶ digit_sel[1:0]
│  mux_4x1     │◀──────────└──────────┘    └──────────┘
│(digit_sel로  │
│  자리 선택)  │───▶ ┌───────────┐    ┌──────────────┐
└──────────────┘     │  bcd      │───▶│ decoder_2x4  │──▶ fnd_digit[3:0]
                     │(7-seg LUT)│    └──────────────┘
                     └───────────┘
                          │
                          ▼
                     fnd_data[7:0]
```

**내부 서브모듈 체인:**

| 모듈 | 기능 |
|------|------|
| `digit_splitter` | 14-bit 정수를 4자리로 분리 (나눗셈 연산) |
| `clk_div` | 50MHz → 1kHz 클럭 분주 (multiplexing 속도) |
| `counter_4` | 2-bit 순환 카운터 (자리 선택) |
| `decoder_2x4` | 자리 선택 신호 → 활성 자리 anode 신호 변환 |
| `mux_4x1` | digit_sel에 따라 해당 자리의 BCD 값 선택 |
| `bcd` | BCD 값 → 7-세그먼트 패턴 변환 LUT |

### 5.5 UART

표준 UART 프레임(8N1)을 지원하는 TX/RX 모듈.  
오버샘플링 방식(16x b_tick)으로 노이즈에 강인한 수신을 구현.

<!-- 
  [이미지 삽입 위치]
  권장 이미지: UART 송수신 파형 캡처 (Vivado 시뮬레이션 또는 로직 분석기)
  파일명 예시: docs/images/uart_waveform.png
-->

**레지스터 맵:**

| 레지스터 | 오프셋 | 비트 | 기능 |
|---------|--------|------|------|
| `CTRL` | `0x00` | [0] | `tx_start` 펄스 (1클럭 후 자동 클리어) |
| `BAUD` | `0x04` | [1:0] | `00`: 9600, `01`: 19200, `10`: 57600, `11`: 115200 bps |
| `STATUS` | `0x08` | [31] | `rx_ready` (수신 완료, Clear-on-Read) |
| `STATUS` | `0x08` | [0] | `tx_busy` (전송 중) |
| `TXDATA` | `0x0C` | [7:0] | 전송할 데이터 |
| `RXDATA` | `0x10` | [7:0] | 수신된 데이터 (읽으면 `rx_ready` 클리어) |

**UART TX/RX 내부 FSM:**

```
uart_tx FSM:   IDLE ──▶ START ──▶ DATA ──▶ STOP ──▶ IDLE
                         (16 b_tick)  (8 x 16 b_tick)

uart_rx FSM:   IDLE ──▶ START ──▶ DATA ──▶ STOP ──▶ IDLE
               (start bit detect, 8 b_tick centering)
```

**Baudrate 설정 (baud_tick 모듈):**
```systemverilog
case (uart_baud_reg[1:0])
    2'b00: baudrate_sel = 10'd650;  // 9600 bps
    2'b01: baudrate_sel = 10'd324;  // 19200 bps
    2'b10: baudrate_sel = 10'd107;  // 57600 bps
    2'b11: baudrate_sel = 10'd53;   // 115200 bps
endcase
```

---

## 6. C Firmware

### 6.1 Memory-Mapped I/O 구조

모든 주변장치는 C 코드에서 포인터 역참조를 통해 직접 제어.  
`volatile` 키워드로 컴파일러 최적화 제거를 보장.

```c
/* 메모리 맵 정의 */
#define APB_BRAM             (0x10000000)
#define APB_PERIPHERAL_BASE  (0x20000000)
#define APB_GPO              (APB_PERIPHERAL_BASE + 0x0000U)
#define APB_GPI              (APB_PERIPHERAL_BASE + 0x1000U)
#define APB_GPIO             (APB_PERIPHERAL_BASE + 0x2000U)
#define APB_FND              (APB_PERIPHERAL_BASE + 0x3000U)
#define APB_UART             (APB_PERIPHERAL_BASE + 0x4000U)

/* 레지스터 오프셋 */
#define APB_GPO_CTRL         (APB_GPO  + 0x00U)
#define APB_GPO_ODATA        (APB_GPO  + 0x04U)
#define APB_UART_STATUS      (APB_UART + 0x08U)
#define APB_UART_RXDATA      (APB_UART + 0x10U)
// ...
```

### 6.2 HAL 스타일 구조체 드라이버

```c
/* HAL-Style 주변장치 구조체 (final.c) */

// GPIO: 양방향 제어
typedef struct {
    __IO uint32_t CTRL;
    __IO uint32_t ODATA;
    __IO uint32_t IDATA;
} GPIO_TYPEDEF;
#define GPIOA  ((GPIO_TYPEDEF *) APB_GPIO)

// GPI: 입력 전용
typedef struct {
    __IO uint32_t CTRL;
    __IO uint32_t IDATA;  // ODATA 없음
} GPI_TYPEDEF;
#define GPIA   ((GPI_TYPEDEF *) APB_GPI)

// GPO: 출력 전용
typedef struct {
    __IO uint32_t CTRL;
    __IO uint32_t ODATA;
} GPO_TYPEDEF;
#define GPOA   ((GPO_TYPEDEF *) APB_GPO)
```

### 6.3 테스트 프로그램 목록

| 파일명 | 검증 내용 |
|--------|----------|
| `gpo_gpi.c` | GPI 스위치 값을 읽어 GPO LED에 반영 (단순 미러링) |
| `gpio.c` | GPIO 스위치 → LED 논블로킹 블링크 (SW 딜레이 타이머) |
| `gpio(2).c` | 초단축 딜레이 루프를 이용한 고속 블링크 시뮬레이션 검증용 |
| `ram.c` | BRAM 다중 워드 쓰기/읽기 검증 (`0xDEADBEEF`, `0x12345678` 등) |
| `fnd.c` | GPI(상위 8비트) + GPIO(하위 8비트) → FND 16비트 표시 |
| `uart.c` | UART 수신 후 에코백 + FND 동시 출력 |
| `final.c` | 전체 통합: SW 블링크 + UART 에코 + FND 모드 전환 (SW[15]로 제어) |

### 6.4 final.c 통합 동작 설명

```c
while(1) {
    // [TASK 1] 스위치 16비트 합산
    gpio_sw  = sw_read(GPIOA);          // GPIO 하위 8비트 (오른쪽 SW)
    gpi_sw   = gpi_read(GPIA);          // GPI 상위 8비트 (왼쪽 SW)
    total_sw = (gpi_sw << 8) | gpio_sw; // 16비트 합산

    // [TASK 2] UART RX 폴링 + TX 에코
    if (*(volatile uint32_t*)APB_UART_STATUS & 0x80000000) {  // rx_ready?
        rx_val = *(volatile uint32_t*)APB_UART_RXDATA;
        while (*(volatile uint32_t*)APB_UART_STATUS & 0x01);  // tx_busy?
        *(volatile uint32_t*)APB_UART_TXDATA = rx_val;
        *(volatile uint32_t*)APB_UART_CTRL   = 0x01;          // tx_start
    }

    // [TASK 3] FND 모드 전환 (SW[15] = Mode Select)
    if (total_sw & 0x8000)
        *(volatile uint32_t*)APB_FND_ODATA = last_uart_val;   // UART 수신값 표시
    else
        *(volatile uint32_t*)APB_FND_ODATA = total_sw & 0x7FFF; // SW 값 표시

    // [TASK 4] 논블로킹 LED 블링크 (tick_count 기반)
    if (++tick_count >= 50000) {
        tick_count = 0;
        blink_flag ^= 1;
        led_write(GPIOA, blink_flag ? (gpio_sw << 8) : 0);
        gpo_write(GPOA,  blink_flag ? gpi_sw : 0);
    }
}
```

---

## 7. Verification

### 7.1 Vivado 시뮬레이션 전략

각 기능 블록을 단계적으로 검증하는 Bottom-Up 방식을 채택.

<!-- 
  [이미지 삽입 위치]
  권장 이미지: Vivado 시뮬레이션 파형 캡처
  - Multi-Cycle FSM 상태 전이 파형 (FETCH→DECODE→EXECUTE→MEM→WB)
  - APB 트랜잭션 파형 (IDLE→SETUP→ACCESS, pready 응답)
  - UART TX/RX 파형
  파일명 예시: docs/images/sim_multicycle.png, docs/images/sim_apb.png
-->

**검증 순서:**

1. **RV32I 단일 명령어 검증**
   - R/I/B/S/IL/U/J 타입 각각 시뮬레이션으로 파형 확인
   - `register_file`, `alu`, `program_counter` 개별 동작 확인

2. **Multi-Cycle FSM 검증**
   - S-Type (SW): `FETCH→DECODE→EXECUTE→MEM(Write)` 전이 확인
   - IL-Type (LW): `FETCH→DECODE→EXECUTE→MEM(Read)→WB` 전이 확인
   - `c_state` 신호와 `APB_MASTER.c_state` 동시 관찰

3. **APB 트랜잭션 검증**
   - `IDLE→SETUP→ACCESS(pready=1)→IDLE` 정상 전이 확인
   - `psel`, `penable`, `pready`, `prdata` 타이밍 검증

4. **주변장치별 개별 검증**
   - BRAM: `0xDEADBEEF` 패턴 쓰기→읽기 일치 확인 (ram.c 기반)
   - GPI/GPO: 핀 입력 → 레지스터 → 출력 경로 검증
   - FND: digit_sel 기반 multiplexing 타이밍 확인
   - UART: TX/RX 루프백 파형 확인

5. **C Firmware 통합 시뮬레이션**
   - `.mem` 파일로 컴파일된 어셈블리를 ROM에 로드
   - `instruction_mem.sv`의 `$readmemh()` 파일 스위칭으로 각 시나리오 검증

### 7.2 시뮬레이션 파형 요약

**IL-Type (LW) 명령어 - BRAM에서 읽기:**

```
clk         _____|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_
c_state     FETCH  DECODE  EXECUTE  MEM     WB
instr       ────────────── 0007a783 (LW a5,0(a5)) ──
dre         ______________________________|‾|________
APB.c_state        IDLE    IDLE   IDLE  SETUP ACCESS
APB.pready  __________________________________________|‾|
x15(rd)     0x10000000              ──────── 0x00000001
```

---

## 8. FPGA Implementation

### 8.1 핀 제약 (XDC)

```
Clock:    W5  (50 MHz, period 20ns)
Reset:    U18 (btnC - Center Button)

Switches (Input):
  gpio[7:0]  → SW7~SW0  (오른쪽 스위치)
  gpi[7:0]   → SW15~SW8 (왼쪽 스위치)

LEDs (Output):
  gpio[15:8] → LD7~LD0  (오른쪽 LED, via GPIO)
  gpo[7:0]   → LD15~LD8 (왼쪽 LED, via GPO)

7-Segment:
  fnd_data[7:0]  → CA~DP  (세그먼트 패턴)
  fnd_digit[3:0] → AN3~AN0 (자리 선택)

UART:
  uart_rx → B18
  uart_tx → A18
```

### 8.2 동작 시연 시나리오

<!-- 
  [이미지 삽입 위치]
  권장 이미지: 실제 Basys-3 보드 동작 사진
  - LED 블링크 동작 사진
  - FND 숫자 표시 사진
  - PC와 UART 터미널 연결 화면 (에코백 동작)
  파일명 예시: docs/images/board_fnd.jpg, docs/images/board_uart.jpg
-->

| 시나리오 | 조작 | 예상 동작 |
|---------|------|----------|
| GPO/GPI 미러링 | 왼쪽 스위치 ON | 해당 왼쪽 LED 점등 |
| GPIO 블링크 | 오른쪽 스위치 ON | 해당 오른쪽 LED 주기적 점멸 |
| FND 스위치 표시 | SW15 OFF + 스위치 조작 | FND에 0~9999 범위 숫자 표시 |
| FND UART 표시 | SW15 ON + PC 터미널 입력 | 수신 문자 ASCII 코드 FND 표시 |
| UART 에코백 | PC 터미널에서 문자 송신 | 동일 문자 수신 확인 (echo) |
| 통합 동작 | final.c 로드 | 위 모든 기능 동시 동작 |

---

## 9. File Structure

```
RISC-V_MCU_Project/
├── rtl/                          # SystemVerilog RTL 소스
│   ├── RV32I_top.sv              # Top-level 모듈 (rv32i_mcu)
│   ├── rv32i_cpu.sv              # CPU 최상위 (Control Unit + Datapath)
│   ├── rv32i_datapath.sv         # 데이터패스 (PC, RF, ALU, IMM, Stage Regs)
│   ├── define.vh                 # opcode, ALU op 매크로 정의
│   ├── instruction_mem.sv        # ROM (명령어 메모리)
│   ├── data_mem.sv               # Data Memory (주석처리, APB_BRAM으로 대체)
│   ├── apb_master.sv             # APB Master FSM + Addr Decoder + MUX
│   ├── APB_BRAM.sv               # APB Slave: BRAM (4KB)
│   ├── APB_GPO.sv                # APB Slave: GPO (출력 전용)
│   ├── APB_GPI.sv                # APB Slave: GPI (입력 전용)
│   ├── APB_GPIO.sv               # APB Slave: GPIO (양방향)
│   ├── APB_FND.sv                # APB Slave: FND + fnd_controller
│   └── APB_UART.sv               # APB Slave: UART (TX/RX/Baud)
│
├── mem/                          # 컴파일된 펌웨어 (.mem 파일)
│   ├── APB_GPO.mem               # GPO 출력 패턴 테스트
│   ├── APB_GPI_GPO.mem           # GPI→GPO 미러링
│   ├── APB_BRAM_GPO_GPI.mem      # BRAM + GPI/GPO 통합
│   ├── APB_GPIO_LED_BLINK.mem    # GPIO 블링크
│   ├── APB_FND.mem               # FND 표시 테스트
│   ├── APB_UART.mem              # UART 에코백
│   ├── APB_FINAL.mem             # 최종 통합 펌웨어
│   ├── U_APB_BRAM.mem            # BRAM 단독 검증
│   └── riscv_rv32i_rom_data.mem  # 기본 RV32I 명령어 테스트
│
├── firmware/                     # C 펌웨어 소스
│   ├── gpo_gpi.c                 # GPI→GPO 미러링
│   ├── gpio.c                    # GPIO 블링크
│   ├── ram.c                     # BRAM 쓰기/읽기 검증
│   ├── fnd.c                     # FND 숫자 표시
│   ├── uart.c                    # UART 에코백
│   └── final.c                   # 전체 통합 데모
│
├── constraints/
│   └── Basys-3-Master.xdc        # FPGA 핀 제약
│
└── docs/
    └── RISCV_team_project.pdf    # 발표 자료
```

---

## 10. Skills & Technologies

### Hardware Design
- **SystemVerilog** RTL 설계 (모듈화, generate 구문, typedef enum FSM)
- **AMBA APB** 버스 프로토콜 마스터/슬레이브 구현
- **Multi-Cycle CPU** 아키텍처 설계 및 Control Unit FSM 구현
- **FPGA 구현:** Xilinx Vivado 합성/구현/비트스트림 생성
- **XDC 제약 파일** 작성 및 핀 매핑

### CPU Architecture
- **RISC-V RV32I** 명령어 집합 아키텍처 이해 및 구현
- **Multi-Cycle vs Single-Cycle** 트레이드오프 분석 적용
- **Datapath 설계:** PC, Register File, ALU, IMM Extender, Stage Registers
- **Control Signal 생성:** opcode/funct3/funct7 디코딩

### Peripheral & Protocol Design
- **Memory-Mapped I/O** 설계 패턴 적용
- **UART 설계:** 오버샘플링(16x), Baud Rate Generator, TX/RX FSM
- **FND Multiplexing:** Clock Divider, BCD 디코더, 자리 선택 로직
- **GPIO 3-state 버퍼** 제어 (양방향 핀 I/O)

### Software / Firmware
- **C Firmware** 작성 (bare-metal, Memory-Mapped I/O)
- **HAL 스타일** 드라이버 추상화 (`typedef struct` 기반 레지스터 접근)
- **`volatile` 포인터** 활용한 컴파일러 최적화 방지
- **RISC-V 툴체인** 사용 (C → RISC-V Assembly → Hex Machine Code)

### Verification
- **Vivado 시뮬레이션** (파형 분석, 상태 머신 검증)
- **`$readmemh()`** 기반 ROM 초기화 및 시나리오별 펌웨어 전환
- **Bottom-Up 검증 방식** (단위 → 통합 단계적 검증)

---

## Reference

- [RISC-V ISA Specification](https://riscv.org/technical/specifications/)
- [AMBA APB Protocol Specification](https://developer.arm.com/documentation/ihi0024/latest/)
- [Basys-3 Reference Manual](https://digilent.com/reference/programmable-logic/basys-3/reference-manual)
- [Xilinx Vivado Design Suite User Guide](https://www.xilinx.com/support/documentation/sw_manuals/xilinx2021_2/ug910-vivado-getting-started.pdf)
