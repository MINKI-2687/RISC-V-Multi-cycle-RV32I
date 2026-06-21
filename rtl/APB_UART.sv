`timescale 1ns / 1ps

module APB_UART (
    input               pclk,
    input               preset,
    input        [31:0] paddr,
    input        [31:0] pwdata,
    input               pwrite,
    input               penable,
    input               psel,
    input               uart_rx,
    output logic [31:0] prdata,
    output logic        pready,
    output logic        uart_tx
);

    localparam [11:0] UART_CTRL_ADDR = 12'h000;
    localparam [11:0] UART_BAUD_ADDR = 12'h004;
    localparam [11:0] UART_STATUS_ADDR = 12'h008;
    localparam [11:0] UART_TX_DATA_ADDR = 12'h00c;
    localparam [11:0] UART_RX_DATA_ADDR = 12'h010;

    // --- 레지스터 선언 ---
    logic       uart_ctrl_reg;
    logic [1:0] uart_baud_reg;
    logic [7:0] uart_tx_data_reg;

    // 수신 데이터를 보관할 버퍼와 상태 플래그
    logic [7:0] rx_data_reg;
    logic       rx_ready_flag;

    // 내부 와이어
    logic tx_busy, rx_done;
    logic [7:0] rx_data_wire;  // 모듈에서 나오는 생(Live) 데이터
    logic [9:0] baudrate_sel;
    logic b_tick;

    assign pready = (penable & psel) ? 1'b1 : 1'b0;

    // --- PRDATA 출력 MUX (상태 비트 위치 수정) ---
    assign prdata = (paddr[11:0] == UART_CTRL_ADDR)    ? {31'd0, uart_ctrl_reg} : 
                    (paddr[11:0] == UART_BAUD_ADDR)    ? {30'd0, uart_baud_reg} :
                    (paddr[11:0] == UART_STATUS_ADDR)  ? {rx_ready_flag, 30'd0, tx_busy} : 
                    (paddr[11:0] == UART_TX_DATA_ADDR) ? {24'd0, uart_tx_data_reg} :
                    (paddr[11:0] == UART_RX_DATA_ADDR) ? {24'd0, rx_data_reg} : 
                    32'hxxxx_xxxx;

    // Baudrate Select (기존 유지)
    always_comb begin
        case (uart_baud_reg[1:0])
            2'b00: baudrate_sel = 10'd650;  // 9600
            2'b01: baudrate_sel = 10'd324;  // 19200
            2'b10: baudrate_sel = 10'd107;  // 57600
            2'b11: baudrate_sel = 10'd53;  // 115200
        endcase
    end

    // --- 메인 제어 로직 ---
    always_ff @(posedge pclk, posedge preset) begin
        if (preset) begin
            uart_ctrl_reg    <= 1'd0;
            uart_baud_reg    <= 2'd0;
            uart_tx_data_reg <= 8'd0;
            rx_data_reg      <= 8'd0;
            rx_ready_flag    <= 1'b0;
        end else begin
            // 1. RX 데이터 캡처 및 플래그 세팅
            if (rx_done) begin
                rx_data_reg   <= rx_data_wire; // 수신 완료 시점에 데이터를 버퍼에 박제
                rx_ready_flag <= 1'b1;         // CPU가 읽어갈 때까지 깃발 올림
            end

            // 2. Clear-on-Read: CPU가 RX 데이터를 읽어가면 플래그 내림
            if (psel && penable && !pwrite && (paddr[11:0] == UART_RX_DATA_ADDR)) begin
                rx_ready_flag <= 1'b0;
            end

            // 3. APB Write 동작
            if (pready & pwrite) begin
                case (paddr[11:0])
                    UART_CTRL_ADDR:    uart_ctrl_reg    <= pwdata[0];
                    UART_BAUD_ADDR:    uart_baud_reg    <= pwdata[1:0];
                    UART_TX_DATA_ADDR: uart_tx_data_reg <= pwdata[7:0];
                endcase
            end else begin
                // tx_start를 1클럭 펄스로 만들어 전송이 반복되는 걸 방지
                uart_ctrl_reg <= 1'b0;
            end
        end
    end

    // --- 모듈 인스턴스 ---
    uart_tx U_UART_TX (
        .clk     (pclk),
        .rst     (preset),
        .tx_start(uart_ctrl_reg),
        .b_tick  (b_tick),
        .tx_data (uart_tx_data_reg),
        .tx_busy (tx_busy),
        .tx_done (),
        .uart_tx (uart_tx)
    );

    uart_rx U_UART_RX (
        .clk    (pclk),
        .rst    (preset),
        .uart_rx(uart_rx),
        .b_tick (b_tick),
        .rx_data(rx_data_wire),  // 내부 와이어에 연결
        .rx_done(rx_done)
    );

    baud_tick U_BAUD_TICK (
        .clk         (pclk),
        .rst         (preset),
        .baudrate_sel(baudrate_sel),
        .b_tick      (b_tick)
    );
endmodule

module uart_tx (
    input        clk,
    input        rst,
    input        tx_start,
    input        b_tick,
    input  [7:0] tx_data,
    output       tx_busy,
    output       tx_done,
    output       uart_tx
);
    localparam IDLE = 2'd0, START = 2'd1;
    localparam DATA = 2'd2, STOP = 2'd3;

    // state reg
    reg [1:0] c_state, n_state;
    reg tx_reg, tx_next;  // for SL output

    // bit_cnt
    reg [2:0] bit_cnt_reg, bit_cnt_next;

    // b_tick_cnt
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;

    // busy, done
    reg busy_reg, busy_next, done_reg, done_next;

    // data_in_buf
    reg [7:0] data_in_buf_reg, data_in_buf_next;

    // connect output, reg type /
    assign uart_tx = tx_reg;
    assign tx_busy = busy_reg;
    assign tx_done = done_reg;

    // state register
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state         <= IDLE;
            tx_reg          <= 1'b1;
            bit_cnt_reg     <= 1'b0;
            b_tick_cnt_reg  <= 4'h0;
            busy_reg        <= 1'b0;
            done_reg        <= 1'b0;
            data_in_buf_reg <= 8'h00;
        end else begin
            c_state         <= n_state;
            tx_reg          <= tx_next;
            bit_cnt_reg     <= bit_cnt_next;
            b_tick_cnt_reg  <= b_tick_cnt_next;
            busy_reg        <= busy_next;
            done_reg        <= done_next;
            data_in_buf_reg <= data_in_buf_next;
        end
    end

    // next CL
    always @(*) begin
        // latch issue
        n_state          = c_state;
        tx_next          = tx_reg;
        bit_cnt_next     = bit_cnt_reg;
        b_tick_cnt_next  = b_tick_cnt_reg;
        busy_next        = busy_reg;
        done_next        = done_reg;
        data_in_buf_next = data_in_buf_reg;
        case (c_state)
            IDLE: begin
                tx_next         = 1'b1;
                bit_cnt_next    = 1'b0;
                b_tick_cnt_next = 4'h0;
                busy_next       = 1'b0;
                done_next       = 1'b0;
                if (tx_start) begin
                    n_state          = START;
                    busy_next        = 1'b1;
                    data_in_buf_next = tx_data;
                end
            end
            // to start uart frame of start bit
            START: begin
                tx_next = 1'b0;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        n_state = DATA;
                        b_tick_cnt_next = 4'h0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                tx_next = data_in_buf_reg[0];
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 4'h0;
                        if (bit_cnt_reg == 7) begin
                            n_state = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                            data_in_buf_next = {1'b0, data_in_buf_reg[7:1]};
                            n_state = DATA;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                tx_next = 1'b1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        done_next = 1'b1;
                        n_state   = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule

module uart_rx (
    input        clk,
    input        rst,
    input        uart_rx,
    input        b_tick,
    output [7:0] rx_data,
    output       rx_done
);
    localparam IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;

    reg [1:0] c_state, n_state;
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    reg done_reg, done_next;
    reg [7:0] buf_reg, buf_next;

    assign rx_data = buf_reg;
    assign rx_done = done_reg;

    // state register
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state        <= 2'd0;
            b_tick_cnt_reg <= 4'd0;
            bit_cnt_reg    <= 3'd0;
            done_reg       <= 1'b0;
            buf_reg        <= 8'd0;
        end else begin
            c_state        <= n_state;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
            done_reg       <= done_next;
            buf_reg        <= buf_next;
        end
    end

    // next output CL
    always @(*) begin
        n_state         = c_state;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;
        done_next       = done_reg;
        buf_next        = buf_reg;
        case (c_state)
            IDLE: begin
                bit_cnt_next    = 3'd0;
                b_tick_cnt_next = 4'd0;
                done_next       = 1'b0;
                if (b_tick && !uart_rx) begin
                    buf_next = 8'd0;
                    n_state  = START;
                end
            end
            START: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 4'd7) begin
                        b_tick_cnt_next = 4'd0;
                        n_state         = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 4'd15) begin
                        b_tick_cnt_next = 4'd0;
                        buf_next = {uart_rx, buf_reg[7:1]};
                        if (bit_cnt_reg == 7) begin
                            n_state = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 4'd15) begin
                        n_state   = IDLE;
                        done_next = 1'b1;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule

module baud_tick (
    input            clk,
    input            rst,
    input      [9:0] baudrate_sel,
    output reg       b_tick
);
    // reg for counter
    logic [9:0] baudrate_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            baudrate_reg <= 0;
            b_tick       <= 1'b0;
        end else begin
            if (baudrate_reg >= baudrate_sel) begin
                baudrate_reg <= 0;
                b_tick       <= 1'b1;
            end else begin
                baudrate_reg <= baudrate_reg + 1;
                b_tick       <= 1'b0;
            end
        end
    end
endmodule
